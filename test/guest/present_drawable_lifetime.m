// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0
//
// Verifies -[MTLCommandBuffer presentDrawable:] ignores nil, non-drawable objects,
// and uninitialized MTLDrawableInternal (null Indium drawable) without retaining or crashing.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static BOOL sDummyDeallocated = NO;

@interface DummyDrawable : NSObject
@end

@implementation DummyDrawable
- (void)dealloc {
	sDummyDeallocated = YES;
	[super dealloc];
}
@end

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
		id<MTLCommandBuffer> cb = [queue commandBuffer];

		[cb presentDrawable: nil];

		@autoreleasepool {
			DummyDrawable *dummy = [[DummyDrawable alloc] init];
			[cb presentDrawable: (id<MTLDrawable>)dummy];
			[dummy release];
		}
		CHECK(sDummyDeallocated);

		Class drawableCls = NSClassFromString(@"MTLDrawableInternal");
		if (drawableCls != Nil) {
			id emptyDrawable = class_createInstance(drawableCls, 0);
			[cb presentDrawable: (id<MTLDrawable>)emptyDrawable];
			[emptyDrawable release];
		}

		[cb commit];
		[cb waitUntilCompleted];
		CHECK(cb.status == MTLCommandBufferStatusCompleted);

		[queue release];
		[device release];
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
