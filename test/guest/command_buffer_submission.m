// Copyright (C) 2026 Lubos Dolezel
// How a command queue takes command buffers and reports on them: the status goes NotEnqueued, Enqueued, Committed,
// Scheduled, Completed; -commit returns without waiting for the GPU; command buffers run in the order they were
// enqueued (in commit order when they were not enqueued); the scheduled and completed handlers of a queue's command
// buffers are called in order, in the order they were added, on a thread other than the one that committed;
// -waitUntilScheduled and -waitUntilCompleted wake threads other than the committing one; a completed handler may
// commit further command buffers; many threads may commit to one queue.
// The expectations follow the documented meaning of the calls and were checked on macOS 27 (Apple silicon).
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <dispatch/dispatch.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

#define WAIT_FOR(cond, seconds) ({ BOOL met = NO; for (int polls = 0; polls < (seconds) * 1000 && !(met = (cond)); polls++) usleep(1000); met; })

static id<MTLDevice> device;
static id<MTLBuffer> scratch;

// a command buffer with a little GPU work
static id<MTLCommandBuffer> makeCommands(id<MTLCommandQueue> queue) {
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
	[blit fillBuffer: scratch range: NSMakeRange(0, 64) value: 1];
	[blit endEncoding];
	return commands;
}

// the handlers of a set of command buffers record what happened here, in order
@interface Log: NSObject {
	NSLock* lock;
	NSMutableArray* events;
	NSMutableSet* threads;
}
- (void)add: (NSString*)kind id: (int)ident;
- (NSArray*)events;
- (NSUInteger)count;
- (BOOL)anyHandlerOnThread: (NSThread*)thread;
@end

@implementation Log
- (instancetype)init {
	self = [super init];
	lock = [NSLock new];
	events = [NSMutableArray new];
	threads = [NSMutableSet new];
	return self;
}
- (void)dealloc { [lock release]; [events release]; [threads release]; [super dealloc]; }
- (void)add: (NSString*)kind id: (int)ident {
	[lock lock];
	[events addObject: [NSString stringWithFormat: @"%@%d", kind, ident]];
	[threads addObject: [NSValue valueWithPointer: [NSThread currentThread]]];
	[lock unlock];
}
- (NSArray*)events { [lock lock]; NSArray* copy = [[events copy] autorelease]; [lock unlock]; return copy; }
- (NSUInteger)count { [lock lock]; NSUInteger n = events.count; [lock unlock]; return n; }
- (BOOL)anyHandlerOnThread: (NSThread*)thread {
	[lock lock];
	BOOL found = [threads containsObject: [NSValue valueWithPointer: thread]];
	[lock unlock];
	return found;
}
@end

static void addLogging(id<MTLCommandBuffer> commands, Log* log, int ident) {
	[commands addScheduledHandler: ^(id<MTLCommandBuffer> cb) { [log add: @"S" id: ident]; }];
	[commands addCompletedHandler: ^(id<MTLCommandBuffer> cb) { [log add: @"C" id: ident]; }];
}

static void statusTransitions(id<MTLCommandQueue> queue) {
	id<MTLCommandBuffer> commands = makeCommands(queue);
	__block MTLCommandBufferStatus inScheduled = MTLCommandBufferStatusNotEnqueued;
	__block MTLCommandBufferStatus inCompleted = MTLCommandBufferStatusNotEnqueued;
	[commands addScheduledHandler: ^(id<MTLCommandBuffer> cb) { inScheduled = cb.status; }];
	[commands addCompletedHandler: ^(id<MTLCommandBuffer> cb) { inCompleted = cb.status; }];
	CHECK(commands.status == MTLCommandBufferStatusNotEnqueued);
	[commands enqueue];
	CHECK(commands.status == MTLCommandBufferStatusEnqueued);
	[commands commit];
	CHECK(commands.status >= MTLCommandBufferStatusCommitted);
	[commands waitUntilCompleted];
	CHECK(commands.status == MTLCommandBufferStatusCompleted);
	CHECK(WAIT_FOR(inCompleted == MTLCommandBufferStatusCompleted, 10));
	CHECK(inScheduled == MTLCommandBufferStatusScheduled || inScheduled == MTLCommandBufferStatusCompleted);
	CHECK(commands.error == nil);
}

static void handlerOrder(id<MTLCommandQueue> queue) {
	enum { count = 100 };
	Log* log = [Log new];
	NSMutableArray* all = [NSMutableArray array];
	for (int i = 0; i < count; i++) {
		id<MTLCommandBuffer> commands = makeCommands(queue);
		addLogging(commands, log, i);
		[all addObject: commands];
		[commands commit];
	}
	[[all lastObject] waitUntilCompleted];
	CHECK(WAIT_FOR([log count] == 2 * count, 10));

	BOOL scheduledInOrder = YES, completedInOrder = YES, scheduledFirst = YES;
	NSMutableSet* scheduled = [NSMutableSet set];
	int lastScheduled = -1, lastCompleted = -1;
	for (NSString* event in [log events]) {
		int ident = [[event substringFromIndex: 1] intValue];
		if ([event hasPrefix: @"S"]) {
			scheduledInOrder &= ident == lastScheduled + 1;
			lastScheduled = ident;
			[scheduled addObject: @(ident)];
		} else {
			completedInOrder &= ident == lastCompleted + 1;
			lastCompleted = ident;
			scheduledFirst &= [scheduled containsObject: @(ident)];
		}
	}
	CHECK(scheduledInOrder);
	CHECK(completedInOrder);
	CHECK(scheduledFirst);
	CHECK(![log anyHandlerOnThread: [NSThread currentThread]]);
	[log release];

	// several handlers of one kind are called in the order they were added
	NSMutableArray* order = [NSMutableArray array];
	id<MTLCommandBuffer> commands = makeCommands(queue);
	for (int i = 0; i < 3; i++) {
		[commands addScheduledHandler: ^(id<MTLCommandBuffer> cb) { @synchronized(order) { [order addObject: @(i)]; } }];
		[commands addCompletedHandler: ^(id<MTLCommandBuffer> cb) { @synchronized(order) { [order addObject: @(10 + i)]; } }];
	}
	[commands commit];
	[commands waitUntilCompleted];
	CHECK(WAIT_FOR(order.count == 6, 10));
	CHECK([order isEqualToArray: (@[@0, @1, @2, @10, @11, @12])]);
}

static void enqueueOrder(id<MTLCommandQueue> queue) {
	Log* log = [Log new];
	id<MTLCommandBuffer> first = makeCommands(queue);
	id<MTLCommandBuffer> second = makeCommands(queue);
	id<MTLCommandBuffer> third = makeCommands(queue);
	addLogging(first, log, 1);
	addLogging(second, log, 2);
	addLogging(third, log, 3);
	[first enqueue];
	[second enqueue];
	[third enqueue];
	[third commit];
	[second commit];
	usleep(300 * 1000);
	CHECK([log count] == 0);
	[first commit];
	[third waitUntilCompleted];
	CHECK(WAIT_FOR([log count] == 6, 10));
	NSMutableArray* completed = [NSMutableArray array];
	for (NSString* event in [log events]) {
		if ([event hasPrefix: @"C"]) [completed addObject: event];
	}
	CHECK([completed isEqualToArray: (@[@"C1", @"C2", @"C3"])]);
	[log release];
}

static void commitDoesNotWait(id<MTLCommandQueue> queue) {
	if (![device respondsToSelector: @selector(newSharedEvent)]) return;
	id<MTLSharedEvent> event = [device newSharedEvent];
	id<MTLCommandBuffer> commands = makeCommands(queue);
	[commands encodeWaitForEvent: event value: 1];
	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	[commands commit];
	CHECK([NSDate timeIntervalSinceReferenceDate] - start < 2.0);
	usleep(200 * 1000);
	CHECK(commands.status != MTLCommandBufferStatusCompleted);

	// waits from other threads wake once the GPU is done
	__block int returned = 0;
	NSLock* lock = [NSLock new];
	for (int i = 0; i < 2; i++) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[commands waitUntilCompleted];
			[lock lock]; returned++; [lock unlock];
		});
	}
	usleep(200 * 1000);
	[lock lock]; CHECK(returned == 0); [lock unlock];
	event.signaledValue = 1;
	CHECK(WAIT_FOR(({ [lock lock]; int r = returned; [lock unlock]; r == 2; }), 10));
	CHECK(commands.status == MTLCommandBufferStatusCompleted);
	[lock release];
	[event release];
}

static void scheduledWait(id<MTLCommandQueue> queue) {
	id<MTLCommandBuffer> commands = makeCommands(queue);
	__block BOOL handlerReturned = NO;
	[commands addScheduledHandler: ^(id<MTLCommandBuffer> cb) { usleep(100 * 1000); handlerReturned = YES; }];
	[commands commit];
	[commands waitUntilScheduled];
	CHECK(commands.status >= MTLCommandBufferStatusScheduled);
	CHECK(handlerReturned);
	[commands waitUntilCompleted];
}

static void manyThreads(id<MTLCommandQueue> queue) {
	enum { threadCount = 6, perThread = 100 };
	Log* log = [Log new];
	NSLock* lock = [NSLock new];
	__block int finishedThreads = 0;
	NSMutableArray* kept = [NSMutableArray array];
	for (int t = 0; t < threadCount; t++) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			@autoreleasepool {
				for (int i = 0; i < perThread; i++) {
					id<MTLCommandBuffer> commands = makeCommands(queue);
					addLogging(commands, log, t * 1000 + i);
					[commands commit];
					[lock lock]; [kept addObject: commands]; [lock unlock];
				}
			}
			[lock lock]; finishedThreads++; [lock unlock];
		});
	}
	CHECK(WAIT_FOR(({ [lock lock]; int f = finishedThreads; [lock unlock]; f == threadCount; }), 30));
	CHECK(WAIT_FOR([log count] == 2 * threadCount * perThread, 30));
	int lastScheduled[threadCount], lastCompleted[threadCount];
	for (int t = 0; t < threadCount; t++) lastScheduled[t] = lastCompleted[t] = -1;
	BOOL ordered = YES;
	for (NSString* event in [log events]) {
		int ident = [[event substringFromIndex: 1] intValue];
		int t = ident / 1000, i = ident % 1000;
		int* last = [event hasPrefix: @"S"] ? lastScheduled : lastCompleted;
		ordered &= i == last[t] + 1;
		last[t] = i;
	}
	CHECK(ordered);
	[lock release];
	[log release];
}

static void reentrancy(id<MTLCommandQueue> queue) {
	// a completed handler may commit another command buffer (it is not waited for: a handler that waits for work
	// behind it on the same queue can hold that work up)
	__block BOOL chained = NO;
	id<MTLCommandBuffer> outer = makeCommands(queue);
	[outer addCompletedHandler: ^(id<MTLCommandBuffer> cb) {
		id<MTLCommandBuffer> inner = makeCommands(queue);
		[inner addCompletedHandler: ^(id<MTLCommandBuffer> innerDone) { chained = YES; }];
		[inner commit];
	}];
	[outer commit];
	CHECK(WAIT_FOR(chained, 10));
}

int main(void) {
	@autoreleasepool {
		device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		scratch = [device newBufferWithLength: 64 options: MTLResourceStorageModeShared];
		id<MTLCommandQueue> queue = [device newCommandQueue];

		statusTransitions(queue);
		handlerOrder(queue);
		enqueueOrder(queue);
		commitDoesNotWait(queue);
		scheduledWait(queue);
		manyThreads(queue);
		reentrancy(queue);

		[queue release];
		[scratch release];
	}
	if (failures) {
		printf("FAILED: %d\n", failures);
		return 1;
	}
	printf("OK\n");
	return 0;
}
