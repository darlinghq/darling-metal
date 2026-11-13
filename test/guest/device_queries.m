// Copyright (C) 2026 Lubos Dolezel
// Darling-specific: MTLDevice's argument-buffer tier and barycentric support answers, and
// MTLCommandBuffer enqueue / scheduling waits. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/message.h>
#include <dispatch/dispatch.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}

		// argumentBuffersSupport returns an 8-byte MTLArgumentBuffersTier; Tier1 is the baseline
		CHECK(sizeof(MTLArgumentBuffersTier) == sizeof(NSUInteger));
		NSUInteger tier = ((NSUInteger (*)(id, SEL))objc_msgSend)(device, @selector(argumentBuffersSupport));
		CHECK(tier == MTLArgumentBuffersTier1);
		CHECK([device respondsToSelector: @selector(argumentBuffersSupport)]);
		CHECK([device respondsToSelector: @selector(supportsShaderBarycentricCoordinates)]);
		BOOL bary = ((BOOL (*)(id, SEL))objc_msgSend)(device, @selector(supportsShaderBarycentricCoordinates));
		CHECK(bary == NO);

		id<MTLCommandQueue> queue = [device newCommandQueue];
		CHECK(queue != nil);
		id<MTLCommandBuffer> cb = [queue commandBuffer];
		CHECK(cb != nil);

		dispatch_semaphore_t scheduled = dispatch_semaphore_create(0);
		__block int scheduledCalls = 0;
		[cb addScheduledHandler: ^(id<MTLCommandBuffer> b) { scheduledCalls++; dispatch_semaphore_signal(scheduled); }];
		[cb enqueue];
		[cb commit];
		[cb waitUntilScheduled];
		CHECK(dispatch_semaphore_wait(scheduled, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0);
		CHECK(scheduledCalls == 1);
		[cb waitUntilCompleted];
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
