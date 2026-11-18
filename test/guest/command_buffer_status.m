// Copyright (C) 2026 Lubos Dolezel
// MTLCommandBuffer status and times, MTLCommandQueue commandBufferWithUnretainedReferences and
// commandBufferWithDescriptor:. The status of a command buffer goes NotEnqueued, Enqueued (after -enqueue),
// Committed, Scheduled, Completed, it is Scheduled in a scheduled handler and Completed in a completed handler and
// when -waitUntilCompleted returns; the host times are 0 until they happen and then bracket the real time.
// The expectations follow the documented meaning of the status values and the times; no Mac GPU was
// available to observe them.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <mach/mach_time.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

// the clock CACurrentMediaTime() reads
static double hostTime(void) {
	static mach_timebase_info_data_t timebase;
	if (timebase.denom == 0) mach_timebase_info(&timebase);
	return (double)mach_absolute_time() * timebase.numer / timebase.denom / 1e9;
}

static void runEmptyBlit(id<MTLCommandBuffer> commands) {
	id<MTLBlitCommandEncoder> encoder = [commands blitCommandEncoder];
	[encoder endEncoding];
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];

		// --- the life of a command buffer
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		CHECK(commands.status == MTLCommandBufferStatusNotEnqueued);
		CHECK(commands.retainedReferences == YES);
		CHECK(commands.errorOptions == MTLCommandBufferErrorOptionNone);
		CHECK(commands.GPUStartTime == 0 && commands.GPUEndTime == 0);
		CHECK(commands.kernelStartTime == 0 && commands.kernelEndTime == 0);
		CHECK(commands.error == nil);
		runEmptyBlit(commands);
		[commands enqueue];
		CHECK(commands.status == MTLCommandBufferStatusEnqueued);

		__block MTLCommandBufferStatus statusWhenScheduled = MTLCommandBufferStatusNotEnqueued;
		__block MTLCommandBufferStatus statusWhenCompleted = MTLCommandBufferStatusNotEnqueued;
		__block double startInHandler = -1, endInHandler = -1;
		[commands addScheduledHandler: ^(id<MTLCommandBuffer> cb) {
			statusWhenScheduled = cb.status;
		}];
		[commands addCompletedHandler: ^(id<MTLCommandBuffer> cb) {
			statusWhenCompleted = cb.status;
			startInHandler = cb.GPUStartTime;
			endInHandler = cb.GPUEndTime;
		}];
		double before = hostTime();
		[commands commit];
		CHECK(commands.status >= MTLCommandBufferStatusCommitted);
		[commands waitUntilCompleted];
		double after = hostTime();
		CHECK(commands.status == MTLCommandBufferStatusCompleted);
		CHECK(commands.error == nil);
		CHECK(commands.GPUStartTime >= before && commands.GPUStartTime <= commands.GPUEndTime && commands.GPUEndTime <= after);
		CHECK(commands.kernelStartTime >= before && commands.kernelStartTime <= commands.kernelEndTime && commands.kernelEndTime <= after);

		// the handlers have run by the time the queue is drained
		id<MTLCommandBuffer> drain = [queue commandBuffer];
		runEmptyBlit(drain);
		[drain commit];
		[drain waitUntilCompleted];
		for (int i = 0; i < 200 && (statusWhenCompleted != MTLCommandBufferStatusCompleted || statusWhenScheduled != MTLCommandBufferStatusScheduled); i++) usleep(5000);
		CHECK(statusWhenScheduled == MTLCommandBufferStatusScheduled);
		CHECK(statusWhenCompleted == MTLCommandBufferStatusCompleted);
		CHECK(startInHandler >= before && endInHandler >= startInHandler);

		// committing enqueues
		commands = [queue commandBuffer];
		runEmptyBlit(commands);
		[commands commit];
		CHECK(commands.status >= MTLCommandBufferStatusCommitted);
		[commands waitUntilCompleted];
		CHECK(commands.status == MTLCommandBufferStatusCompleted);

		// --- the other ways to make a command buffer
		commands = [queue commandBufferWithUnretainedReferences];
		CHECK(commands != nil);
		CHECK(commands.retainedReferences == NO);
		CHECK(commands.status == MTLCommandBufferStatusNotEnqueued);
		runEmptyBlit(commands);
		[commands commit];
		[commands waitUntilCompleted];
		CHECK(commands.status == MTLCommandBufferStatusCompleted);

		MTLCommandBufferDescriptor* descriptor = [[MTLCommandBufferDescriptor alloc] init];
		descriptor.retainedReferences = NO;
		descriptor.errorOptions = MTLCommandBufferErrorOptionEncoderExecutionStatus;
		commands = [queue commandBufferWithDescriptor: descriptor];
		CHECK(commands != nil);
		CHECK(commands.retainedReferences == NO);
		CHECK(commands.errorOptions == MTLCommandBufferErrorOptionEncoderExecutionStatus);
		runEmptyBlit(commands);
		[commands commit];
		[commands waitUntilCompleted];
		CHECK(commands.status == MTLCommandBufferStatusCompleted);
		descriptor.retainedReferences = YES;
		descriptor.errorOptions = MTLCommandBufferErrorOptionNone;
		commands = [queue commandBufferWithDescriptor: descriptor];
		CHECK(commands.retainedReferences == YES);
		CHECK(commands.errorOptions == MTLCommandBufferErrorOptionNone);
		[descriptor release];

		// a command buffer that is never committed goes away
		@autoreleasepool {
			id<MTLCommandBuffer> unused = [queue commandBuffer];
			runEmptyBlit(unused);
		}

		// a command buffer released right after commit, with no handler, still completes
		@autoreleasepool {
			id<MTLCommandBuffer> forgotten = [queue commandBuffer];
			runEmptyBlit(forgotten);
			[forgotten commit];
		}
		id<MTLCommandBuffer> last = [queue commandBuffer];
		runEmptyBlit(last);
		[last commit];
		[last waitUntilCompleted];
		CHECK(last.status == MTLCommandBufferStatusCompleted);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
