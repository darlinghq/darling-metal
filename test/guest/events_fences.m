// Copyright (C) 2026 Lubos Dolezel
// MTLEvent, MTLSharedEvent, MTLSharedEventListener and MTLFence: signals and waits across command buffers and
// queues (in either commit order), the rules for the value (it only goes up, from the host and from a command
// buffer), waits on values already reached, the host releasing a waiting command buffer, listeners (queue,
// arguments, order), -waitUntilSignaledValue:timeoutMS:, shared event handles and fences between encoders.
// The expectations were observed on macOS 27.0.1 (Apple silicon) and follow the documented meaning of the calls.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLDevice> device;
static id<MTLCommandQueue> queueA;
static id<MTLCommandQueue> queueB;

// waits up to `seconds` for a condition
#define WAIT_FOR(cond, seconds) ({ BOOL met = NO; for (int polls = 0; polls < (seconds) * 1000 && !(met = (cond)); polls++) usleep(1000); met; })

static void settle(void) { usleep(300 * 1000); }

static BOOL completed(id<MTLCommandBuffer> commands) { return commands.status == MTLCommandBufferStatusCompleted; }

static id<MTLBuffer> newFilledBuffer(uint8_t value) {
	uint8_t bytes[64];
	memset(bytes, value, sizeof(bytes));
	return [device newBufferWithBytes: bytes length: sizeof(bytes) options: MTLResourceStorageModeShared];
}

static BOOL isFilledWith(id<MTLBuffer> buffer, uint8_t value) {
	const uint8_t* bytes = buffer.contents;
	for (int i = 0; i < 64; i++) {
		if (bytes[i] != value) {
			return NO;
		}
	}
	return YES;
}

static void encodeFill(id<MTLCommandBuffer> commands, id<MTLBuffer> buffer, uint8_t value) {
	id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
	[blit fillBuffer: buffer range: NSMakeRange(0, 64) value: value];
	[blit endEncoding];
}

static void encodeCopy(id<MTLCommandBuffer> commands, id<MTLBuffer> source, id<MTLBuffer> destination) {
	id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
	[blit copyFromBuffer: source sourceOffset: 0 toBuffer: destination destinationOffset: 0 size: 64];
	[blit endEncoding];
}

static id<MTLCommandBuffer> emptyBlit(id<MTLCommandQueue> queue) {
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	[[commands blitCommandEncoder] endEncoding];
	return commands;
}

int main(void) {
	@autoreleasepool {
		device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		queueA = [device newCommandQueue];
		queueB = [device newCommandQueue];

		// --- the objects
		{
			id<MTLEvent> event = [device newEvent];
			id<MTLSharedEvent> shared = [device newSharedEvent];
			id<MTLFence> fence = [device newFence];
			CHECK(event != nil && shared != nil && fence != nil);
			CHECK(event.device == device && fence.device == device);
			// a shared event is not tied to a device
			CHECK(shared.device == nil);
			CHECK([shared conformsToProtocol: @protocol(MTLEvent)]);
			CHECK(![(id)event respondsToSelector: @selector(signaledValue)]);
			CHECK(![(id)event respondsToSelector: @selector(setSignaledValue:)]);
			event.label = @"event";
			shared.label = @"shared";
			fence.label = @"fence";
			CHECK([event.label isEqualToString: @"event"] && [shared.label isEqualToString: @"shared"] && [fence.label isEqualToString: @"fence"]);
			CHECK(shared.signaledValue == 0);
		}

		// --- the value from the host only goes up
		{
			id<MTLSharedEvent> shared = [device newSharedEvent];
			shared.signaledValue = 5;
			CHECK(shared.signaledValue == 5);
			shared.signaledValue = 3;
			CHECK(shared.signaledValue == 5);
			shared.signaledValue = 5;
			CHECK(shared.signaledValue == 5);
			shared.signaledValue = 1ull << 40;
			CHECK(shared.signaledValue == 1ull << 40);
			shared.signaledValue = UINT64_MAX;
			CHECK(shared.signaledValue == UINT64_MAX);
		}

		// --- the value from a command buffer only goes up
		{
			id<MTLSharedEvent> shared = [device newSharedEvent];
			id<MTLCommandBuffer> commands = [queueA commandBuffer];
			[commands encodeSignalEvent: shared value: 10];
			[commands commit];
			[commands waitUntilCompleted];
			CHECK(shared.signaledValue == 10);

			commands = [queueA commandBuffer];
			[commands encodeSignalEvent: shared value: 4];
			[commands commit];
			[commands waitUntilCompleted];
			CHECK(completed(commands) && shared.signaledValue == 10);

			shared.signaledValue = 2;
			CHECK(shared.signaledValue == 10);

			commands = [queueA commandBuffer];
			[commands encodeSignalEvent: shared value: 12];
			[commands encodeSignalEvent: shared value: 11];
			[commands commit];
			[commands waitUntilCompleted];
			CHECK(completed(commands) && shared.signaledValue == 12);

			// the event keeps working
			commands = [queueB commandBuffer];
			[commands encodeSignalEvent: shared value: 13];
			[commands commit];
			[commands waitUntilCompleted];
			CHECK(shared.signaledValue == 13);
		}

		// --- a wait on a value that has been reached holds nothing up
		{
			id<MTLSharedEvent> shared = [device newSharedEvent];
			shared.signaledValue = 5;
			id<MTLBuffer> source = newFilledBuffer(0x77);
			id<MTLBuffer> destination = newFilledBuffer(0);
			id<MTLCommandBuffer> commands = [queueA commandBuffer];
			[commands encodeWaitForEvent: shared value: 0];
			[commands encodeWaitForEvent: shared value: 3];
			[commands encodeWaitForEvent: shared value: 5];
			encodeCopy(commands, source, destination);
			[commands commit];
			CHECK(WAIT_FOR(completed(commands), 10));
			CHECK(isFilledWith(destination, 0x77));
		}

		// --- the consumer is committed before the producer, on another queue
		{
			id<MTLEvent> event = [device newEvent];
			id<MTLBuffer> data = newFilledBuffer(0);
			id<MTLBuffer> destination = newFilledBuffer(0);

			id<MTLCommandBuffer> consumer = [queueB commandBuffer];
			[consumer encodeWaitForEvent: event value: 1];
			encodeCopy(consumer, data, destination);
			[consumer commit];
			// a command buffer behind it on its queue, and one on another queue
			id<MTLCommandBuffer> behind = emptyBlit(queueB);
			[behind commit];
			id<MTLCommandBuffer> elsewhere = emptyBlit(queueA);
			[elsewhere commit];
			CHECK(WAIT_FOR(completed(elsewhere), 10));
			settle();
			CHECK(!completed(consumer) && isFilledWith(destination, 0));
			CHECK(!completed(behind));

			id<MTLCommandBuffer> producer = [queueA commandBuffer];
			encodeFill(producer, data, 0x5A);
			[producer encodeSignalEvent: event value: 1];
			[producer commit];
			CHECK(WAIT_FOR(completed(consumer) && completed(behind), 10));
			CHECK(isFilledWith(destination, 0x5A));
		}

		// --- signal and wait in one command buffer
		{
			id<MTLEvent> event = [device newEvent];
			id<MTLBuffer> data = newFilledBuffer(0);
			id<MTLBuffer> destination = newFilledBuffer(0);
			id<MTLCommandBuffer> commands = [queueA commandBuffer];
			encodeFill(commands, data, 0x42);
			[commands encodeSignalEvent: event value: 1];
			[commands encodeWaitForEvent: event value: 1];
			encodeCopy(commands, data, destination);
			[commands commit];
			CHECK(WAIT_FOR(completed(commands), 10));
			CHECK(isFilledWith(destination, 0x42));
		}

		// --- the host releases a waiting command buffer
		{
			id<MTLSharedEvent> shared = [device newSharedEvent];
			id<MTLBuffer> source = newFilledBuffer(0x66);
			id<MTLBuffer> destination = newFilledBuffer(0);
			id<MTLCommandBuffer> commands = [queueA commandBuffer];
			[commands encodeWaitForEvent: shared value: 5];
			encodeCopy(commands, source, destination);
			[commands commit];
			settle();
			CHECK(!completed(commands) && isFilledWith(destination, 0));
			shared.signaledValue = 4;
			settle();
			CHECK(!completed(commands));
			shared.signaledValue = 6;
			CHECK(WAIT_FOR(completed(commands), 10));
			CHECK(isFilledWith(destination, 0x66));
		}

		// --- listeners
		{
			dispatch_queue_t queue = dispatch_queue_create("events_fences.listener", DISPATCH_QUEUE_SERIAL);
			static const char key;
			dispatch_queue_set_specific(queue, &key, (void*)1, NULL);
			MTLSharedEventListener* listener = [[MTLSharedEventListener alloc] initWithDispatchQueue: queue];
			CHECK(listener.dispatchQueue == queue);

			id<MTLSharedEvent> shared = [device newSharedEvent];
			NSMutableArray* calls = [NSMutableArray array];
			__block int sameEvent = 0, onQueue = 0, valueIsRegistered = 0;
			void (^listen)(int, uint64_t) = ^(int tag, uint64_t at) {
				[shared notifyListener: listener atValue: at block: ^(id<MTLSharedEvent> event, uint64_t value) {
					@synchronized (calls) {
						[calls addObject: @(tag)];
						sameEvent += event == shared;
						onQueue += dispatch_get_specific(&key) != NULL;
						valueIsRegistered += value == at;
					}
				}];
			};
			listen(1, 2);
			listen(2, 2);
			listen(3, 1);
			settle();
			CHECK(calls.count == 0);

			// jumps past every value they were registered for
			shared.signaledValue = 5;
			CHECK(WAIT_FOR(({ int n; @synchronized (calls) { n = calls.count; } n == 3; }), 10));
			@synchronized (calls) {
				CHECK([calls isEqualToArray: (@[@1, @2, @3])]);
				CHECK(sameEvent == 3 && onQueue == 3);
				// the value passed is the one the block was registered for, not the one the event has
				CHECK(valueIsRegistered == 3);
			}

			// a value that has been reached already, and 0
			listen(4, 3);
			listen(5, 0);
			CHECK(WAIT_FOR(({ int n; @synchronized (calls) { n = calls.count; } n == 5; }), 10));
			settle();
			@synchronized (calls) {
				CHECK(calls.count == 5 && [calls[3] isEqual: @4] && [calls[4] isEqual: @5]);
			}

			// a command buffer's signal
			listen(6, 20);
			id<MTLCommandBuffer> commands = [queueA commandBuffer];
			[commands encodeSignalEvent: shared value: 20];
			[commands commit];
			CHECK(WAIT_FOR(({ int n; @synchronized (calls) { n = calls.count; } n == 6; }), 10));

			[listener release];
			dispatch_release(queue);
		}

		// --- the default queues of listeners
		{
			MTLSharedEventListener* first = [[[MTLSharedEventListener alloc] init] autorelease];
			MTLSharedEventListener* second = [[[MTLSharedEventListener alloc] init] autorelease];
			// QUIRK test: a listener made with init has a serial queue of its own (macOS 27.0.1 observation)
			CHECK(first.dispatchQueue != dispatch_get_main_queue());
			CHECK(first.dispatchQueue != second.dispatchQueue);
			CHECK(strcmp(dispatch_queue_get_label(first.dispatchQueue), "MTLSharedEventListener") == 0);
			CHECK([MTLSharedEventListener sharedListener] == [MTLSharedEventListener sharedListener]);
			CHECK([MTLSharedEventListener sharedListener].dispatchQueue != dispatch_get_main_queue());
			CHECK(strcmp(dispatch_queue_get_label([MTLSharedEventListener sharedListener].dispatchQueue), "MTLSharedEventListener") == 0);

			// and notifies without a main run loop
			id<MTLSharedEvent> shared = [device newSharedEvent];
			__block int called = 0;
			[shared notifyListener: [MTLSharedEventListener sharedListener] atValue: 1 block: ^(id<MTLSharedEvent> event, uint64_t value) {
				called = 1;
			}];
			shared.signaledValue = 1;
			CHECK(WAIT_FOR(called == 1, 10));
		}

		// --- waiting on the host
		{
			id<MTLSharedEvent> shared = [device newSharedEvent];
			CHECK([shared waitUntilSignaledValue: 0 timeoutMS: 0]);
			CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
			CHECK(![shared waitUntilSignaledValue: 3 timeoutMS: 100]);
			CHECK(CFAbsoluteTimeGetCurrent() - start >= 0.09);
			shared.signaledValue = 3;
			CHECK([shared waitUntilSignaledValue: 3 timeoutMS: 0]);
			CHECK([shared waitUntilSignaledValue: 2 timeoutMS: 0]);

			id<MTLSharedEvent> other = [device newSharedEvent];
			id<MTLCommandBuffer> commands = [queueA commandBuffer];
			[commands encodeSignalEvent: other value: 7];
			[commands commit];
			CHECK([other waitUntilSignaledValue: 7 timeoutMS: 10000]);
		}

		// --- handles
		{
			id<MTLSharedEvent> shared = [device newSharedEvent];
			shared.signaledValue = 7;
			MTLSharedEventHandle* handle = [shared newSharedEventHandle];
			CHECK(handle != nil && handle.label == nil);
			id<MTLSharedEvent> copy = [device newSharedEventWithHandle: handle];
			CHECK(copy != nil && copy != shared && copy.device == nil);
			CHECK(copy.signaledValue == 7);
			copy.signaledValue = 9;
			CHECK(shared.signaledValue == 9);
			id<MTLCommandBuffer> commands = [queueA commandBuffer];
			[commands encodeSignalEvent: copy value: 11];
			[commands commit];
			[commands waitUntilCompleted];
			CHECK(shared.signaledValue == 11);
			// a handle names an event of this process: archiving one is refused
			BOOL refused = NO;
			@try {
				NSError* error = nil;
				NSData* data = [NSKeyedArchiver archivedDataWithRootObject: handle requiringSecureCoding: YES error: &error];
				refused = data == nil;
			} @catch (NSException* exception) {
				refused = YES;
			}
			CHECK(refused);
			[copy release];
			[handle release];
			[shared release];
		}

		// --- fences
		{
			id<MTLFence> fence = [device newFence];
			id<MTLBuffer> data = newFilledBuffer(0);
			id<MTLBuffer> destination = newFilledBuffer(0);
			id<MTLCommandBuffer> commands = [queueA commandBuffer];
			id<MTLBlitCommandEncoder> first = [commands blitCommandEncoder];
			[first fillBuffer: data range: NSMakeRange(0, 64) value: 0x5A];
			[first updateFence: fence];
			[first endEncoding];
			id<MTLBlitCommandEncoder> second = [commands blitCommandEncoder];
			[second waitForFence: fence];
			[second copyFromBuffer: data sourceOffset: 0 toBuffer: destination destinationOffset: 0 size: 64];
			[second updateFence: fence];
			[second endEncoding];
			id<MTLComputeCommandEncoder> compute = [commands computeCommandEncoder];
			[compute waitForFence: fence];
			[compute updateFence: fence];
			[compute endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			CHECK(completed(commands) && isFilledWith(destination, 0x5A));

			// across the command buffers of a queue
			id<MTLCommandBuffer> writer = [queueA commandBuffer];
			id<MTLBlitCommandEncoder> write = [writer blitCommandEncoder];
			[write fillBuffer: data range: NSMakeRange(0, 64) value: 0x33];
			[write updateFence: fence];
			[write endEncoding];
			[writer commit];
			id<MTLCommandBuffer> reader = [queueA commandBuffer];
			id<MTLBlitCommandEncoder> read = [reader blitCommandEncoder];
			[read waitForFence: fence];
			[read copyFromBuffer: data sourceOffset: 0 toBuffer: destination destinationOffset: 0 size: 64];
			[read endEncoding];
			[reader commit];
			[reader waitUntilCompleted];
			CHECK(isFilledWith(destination, 0x33));

			// a render encoder takes the calls with stages
			MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 4 height: 4 mipmapped: NO];
			descriptor.usage = MTLTextureUsageRenderTarget;
			descriptor.storageMode = MTLStorageModePrivate;
			MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
			pass.colorAttachments[0].texture = [device newTextureWithDescriptor: descriptor];
			pass.colorAttachments[0].loadAction = MTLLoadActionClear;
			pass.colorAttachments[0].storeAction = MTLStoreActionStore;
			id<MTLCommandBuffer> rendering = [queueA commandBuffer];
			id<MTLRenderCommandEncoder> render = [rendering renderCommandEncoderWithDescriptor: pass];
			[render waitForFence: fence beforeStages: MTLRenderStageVertex];
			[render updateFence: fence afterStages: MTLRenderStageFragment];
			[render endEncoding];
			[rendering commit];
			[rendering waitUntilCompleted];
			CHECK(completed(rendering));

			// a wait for a fence nothing updated does not hold anything up
			id<MTLFence> never = [device newFence];
			id<MTLCommandBuffer> waiting = [queueA commandBuffer];
			id<MTLBlitCommandEncoder> wait = [waiting blitCommandEncoder];
			[wait waitForFence: never];
			[wait endEncoding];
			[waiting commit];
			CHECK(WAIT_FOR(completed(waiting), 10));
		}

		// --- a long chain between two queues: each queue holds every other step, and each step waits for the one before
		{
			enum { steps = 30 };
			id<MTLSharedEvent> event = [device newSharedEvent];
			NSMutableArray* order = [NSMutableArray array];
			NSLock* orderLock = [[NSLock alloc] init];
			for (int parity = 0; parity < 2; parity++) {
				id<MTLCommandQueue> queue = parity == 0 ? queueB : queueA;
				for (int step = 1 + (parity == 0 ? 1 : 0); step <= steps; step += 2) {
					id<MTLCommandBuffer> commands = [queue commandBuffer];
					if (step > 1) {
						[commands encodeWaitForEvent: event value: step - 1];
					}
					[commands encodeSignalEvent: event value: step];
					[commands addCompletedHandler: ^(id<MTLCommandBuffer> done) {
						[orderLock lock];
						[order addObject: @(step)];
						[orderLock unlock];
					}];
					[commands commit];
				}
				if (parity == 0) {
					settle();
				}
			}
			CHECK(WAIT_FOR(({ [orderLock lock]; NSUInteger n = order.count; [orderLock unlock]; n == steps; }), 10));
			// every step ran, and the last signal came from the last step (the handlers of different command buffers
			// run on different threads, so their order says nothing)
			CHECK(event.signaledValue == steps);
			[orderLock release];
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
