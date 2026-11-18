// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLCommandBufferInternal.h>
#import <Metal/MTLBlitCommandEncoderInternal.h>
#import <Metal/MTLBlitPassInternal.h>
#import <Metal/MTLComputeCommandEncoderInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLCommandQueue.h>
#import <Metal/MTLDrawableInternal.h>
#import <Metal/stubs.h>
#import <Metal/MTLRenderCommandEncoderInternal.h>
#import <Metal/MTLParallelRenderCommandEncoderInternal.h>
#import <Metal/MTLIOSurfaceCopy.h>
#import <Metal/MTLEventInternal.h>

#include <mach/mach_time.h>
#include <mutex>

#if DARLING_METAL_ENABLED
// used to take care of RR while passing the block around in C++ code
struct MTLCommandBufferHandlerWrapper {
	MTLCommandBufferHandler handler = nil;
	id<MTLCommandBuffer> commandBuffer = nil;

	MTLCommandBufferHandlerWrapper(MTLCommandBufferHandler theHandler, id<MTLCommandBuffer> theCommandBuffer):
		handler([theHandler copy]),
		commandBuffer([theCommandBuffer retain])
		{};

	MTLCommandBufferHandlerWrapper(const MTLCommandBufferHandlerWrapper& other):
		handler([other.handler copy]),
		commandBuffer([other.commandBuffer retain])
		{};

	~MTLCommandBufferHandlerWrapper() {
		[handler release];
		[commandBuffer release];
	};

	MTLCommandBufferHandlerWrapper& operator=(const MTLCommandBufferHandlerWrapper& other) {
		[handler release];
		handler = [other.handler copy];
		[commandBuffer release];
		commandBuffer = [other.commandBuffer retain];
		return *this;
	};

	void operator()(std::shared_ptr<Indium::CommandBuffer> ignored) {
		// we assume that the Indium command buffer given as an argument refers to the same command buffer
		// as the one that created this wrapper (which is a currently always true).
		handler(commandBuffer);
	};
};
#endif

#if DARLING_METAL_ENABLED
// How Indium's handlers reach a command buffer without keeping it alive: -dealloc empties the box, and a
// handler that is running holds the mutex, so the command buffer is not freed under it.
@class MTLCommandBufferInternal;
struct MTLCommandBufferStatusBox {
	std::mutex mutex;
	MTLCommandBufferInternal* target = nil;
};

// The host clock CACurrentMediaTime() reads, in seconds, which is what the command buffer times are on.
static CFTimeInterval MTLHostTimeNow(void)
{
	static mach_timebase_info_data_t timebase;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		mach_timebase_info(&timebase);
	});
	return (double)mach_absolute_time() * timebase.numer / timebase.denom / 1e9;
}
#endif

@implementation MTLCommandBufferInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::CommandBuffer> _commandBuffer;
	// the status, and the times as the bit patterns of doubles, are written by the thread that commits
	// and by the thread that Indium calls its handlers on, and read by anyone
	MTLCommandBufferStatus _status;
	uint64_t _kernelStartTime;
	uint64_t _kernelEndTime;
	BOOL _retainedReferences;
	MTLCommandBufferErrorOption _errorOptions;
	std::shared_ptr<MTLCommandBufferStatusBox> _statusBox;
}

@synthesize device = _device;
@synthesize commandQueue = _commandQueue;
@synthesize label = _label;
@synthesize retainedReferences = _retainedReferences;
@synthesize errorOptions = _errorOptions;

static CFTimeInterval MTLLoadTime(uint64_t* slot)
{
	uint64_t bits = __atomic_load_n(slot, __ATOMIC_ACQUIRE);
	CFTimeInterval time;
	memcpy(&time, &bits, sizeof(time));
	return time;
}

- (instancetype)initWithCommandBuffer: (std::shared_ptr<Indium::CommandBuffer>)commandBuffer
                         commandQueue: (id<MTLCommandQueue>)commandQueue
{
	return [self initWithCommandBuffer: commandBuffer commandQueue: commandQueue retainedReferences: YES errorOptions: MTLCommandBufferErrorOptionNone];
}

- (instancetype)initWithCommandBuffer: (std::shared_ptr<Indium::CommandBuffer>)commandBuffer
                         commandQueue: (id<MTLCommandQueue>)commandQueue
                   retainedReferences: (BOOL)retainedReferences
                         errorOptions: (MTLCommandBufferErrorOption)errorOptions
{
	self = [super init];
	if (self != nil) {
		_commandBuffer = commandBuffer;
		_device = [commandQueue.device retain];
		_commandQueue = [commandQueue retain];
		_status = MTLCommandBufferStatusNotEnqueued;
		// Indium keeps every resource a command buffer uses alive until it has completed, which is what a
		// command buffer that retains its references does, and is also safe for one that does not.
		_retainedReferences = retainedReferences;
		_errorOptions = errorOptions;

		// These two handlers are added before any the application adds, so the status and the times are
		// already updated when an application's handler looks at them. Indium keeps the handlers until the
		// command buffer has run them, so they must not keep this object alive (an uncommitted command
		// buffer would then never go away); they reach it through a box that -dealloc empties.
		_statusBox = std::make_shared<MTLCommandBufferStatusBox>();
		_statusBox->target = self;
		auto box = _statusBox;
		_commandBuffer->addScheduledHandler([box](std::shared_ptr<Indium::CommandBuffer>) {
			std::lock_guard<std::mutex> lock(box->mutex);
			[box->target commandBufferWasScheduled];
		});
		_commandBuffer->addCompletedHandler([box](std::shared_ptr<Indium::CommandBuffer>) {
			std::lock_guard<std::mutex> lock(box->mutex);
			[box->target commandBufferDidComplete];
		});
	}
	return self;
}

// These two are called from Indium's handlers and from the waits, whichever gets there first: Metal has the
// command buffer scheduled when -waitUntilScheduled returns and completed when -waitUntilCompleted does,
// and Indium wakes a waiter before it runs the handlers.
- (void)commandBufferWasScheduled
{
	uint64_t none = 0;
	CFTimeInterval now = MTLHostTimeNow();
	uint64_t bits;
	memcpy(&bits, &now, sizeof(bits));
	// the start of GPU execution is not observable here; the command buffer is handed to the device when it
	// is scheduled
	__atomic_compare_exchange_n(&_kernelStartTime, &none, bits, false, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE);
	MTLCommandBufferStatus expected = MTLCommandBufferStatusCommitted;
	__atomic_compare_exchange_n(&_status, &expected, MTLCommandBufferStatusScheduled, false, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE);
}

- (void)commandBufferDidComplete
{
	// a command buffer that completed without being seen scheduled started at the latest now
	[self commandBufferWasScheduled];
	uint64_t none = 0;
	CFTimeInterval now = MTLHostTimeNow();
	uint64_t bits;
	memcpy(&bits, &now, sizeof(bits));
	__atomic_compare_exchange_n(&_kernelEndTime, &none, bits, false, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE);
	__atomic_store_n(&_status, MTLCommandBufferStatusCompleted, __ATOMIC_RELEASE);
}

- (MTLCommandBufferStatus)status
{
	return __atomic_load_n(&_status, __ATOMIC_ACQUIRE);
}

- (CFTimeInterval)kernelStartTime
{
	return MTLLoadTime(&_kernelStartTime);
}

- (CFTimeInterval)kernelEndTime
{
	return MTLLoadTime(&_kernelEndTime);
}

- (CFTimeInterval)GPUStartTime
{
	return MTLLoadTime(&_kernelStartTime);
}

- (CFTimeInterval)GPUEndTime
{
	return MTLLoadTime(&_kernelEndTime);
}

- (void)dealloc
{
	if (_statusBox) {
		std::lock_guard<std::mutex> lock(_statusBox->mutex);
		_statusBox->target = nil;
	}
	[_device release];
	[_commandQueue release];
	[_label release];
	[super dealloc];
}

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDescriptor: (MTLComputePassDescriptor*)computePassDescriptor
{
	auto encoder = _commandBuffer->computeCommandEncoder(computePassDescriptor.asIndiumDescriptor);
	if (!encoder) {
		return nil;
	}
	return [[[MTLComputeCommandEncoderInternal alloc] initWithEncoder: encoder device: _device] autorelease];
}

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType: (MTLDispatchType)dispatchType
{
	auto encoder = _commandBuffer->computeCommandEncoder(static_cast<Indium::DispatchType>(dispatchType));
	if (!encoder) {
		return nil;
	}
	return [[[MTLComputeCommandEncoderInternal alloc] initWithEncoder: encoder device: _device] autorelease];
}

- (id<MTLComputeCommandEncoder>)computeCommandEncoder
{
	auto encoder = _commandBuffer->computeCommandEncoder();
	if (!encoder) {
		return nil;
	}
	return [[[MTLComputeCommandEncoderInternal alloc] initWithEncoder: encoder device: _device] autorelease];
}

- (id<MTLRenderCommandEncoder>)renderCommandEncoderWithDescriptor: (MTLRenderPassDescriptor*)renderPassDescriptor
{
	auto encoder = _commandBuffer->renderCommandEncoder([renderPassDescriptor asIndiumDescriptor]);
	if (!encoder) {
		return nil;
	}
	return [[[MTLRenderCommandEncoderInternal alloc] initWithEncoder: encoder device: _device] autorelease];
}

- (id<MTLParallelRenderCommandEncoder>)parallelRenderCommandEncoderWithDescriptor: (MTLRenderPassDescriptor*)renderPassDescriptor
{
	auto encoder = _commandBuffer->parallelRenderCommandEncoder([renderPassDescriptor asIndiumDescriptor]);
	if (!encoder) {
		return nil;
	}
	return [[[MTLParallelRenderCommandEncoderInternal alloc] initWithEncoder: encoder device: _device] autorelease];
}

- (id<MTLBlitCommandEncoder>)blitCommandEncoder
{
	auto encoder = _commandBuffer->blitCommandEncoder();
	if (!encoder) {
		return nil;
	}
	return [[[MTLBlitCommandEncoderInternal alloc] initWithEncoder: encoder device: _device] autorelease];
}

- (id<MTLBlitCommandEncoder>)blitCommandEncoderWithDescriptor: (MTLBlitPassDescriptor*)blitPassDescriptor
{
	auto encoder = _commandBuffer->blitCommandEncoder(blitPassDescriptor.asIndiumDescriptor);
	if (!encoder) {
		return nil;
	}
	return [[[MTLBlitCommandEncoderInternal alloc] initWithEncoder: encoder device: _device] autorelease];
}

- (void)addScheduledHandler: (MTLCommandBufferHandler)block
{
	_commandBuffer->addScheduledHandler(MTLCommandBufferHandlerWrapper(block, self));
}

- (void)waitUntilScheduled
{
	_commandBuffer->waitUntilScheduled();
	if ([self status] >= MTLCommandBufferStatusCommitted) {
		[self commandBufferWasScheduled];
	}
}

- (void)addCompletedHandler: (MTLCommandBufferHandler)block
{
	_commandBuffer->addCompletedHandler(MTLCommandBufferHandlerWrapper(block, self));
}

// Indium currently has no command-buffer error result to translate.
- (NSError *)error
{
	return nil;
}

- (void)waitUntilCompleted
{
	_commandBuffer->waitUntilCompleted();
	if ([self status] >= MTLCommandBufferStatusCommitted) {
		[self commandBufferDidComplete];
	}
}

- (void)presentDrawable: (id<MTLDrawable>)drawable
{
	_commandBuffer->presentDrawable(((id<MTLDrawableInternal>)drawable).drawable);
}

// The drawable decides when the frame is shown (see -[MTLDrawableInternal presentAtTime:]), so a presentation
// time or a minimum duration is a hint that is not honoured: the drawable is presented when the command
// buffer has been scheduled, as -presentDrawable: does.
- (void)presentDrawable: (id<MTLDrawable>)drawable
                 atTime: (CFTimeInterval)presentationTime
{
	[self presentDrawable: drawable];
}

- (void)presentDrawable: (id<MTLDrawable>)drawable
   afterMinimumDuration: (CFTimeInterval)duration
{
	[self presentDrawable: drawable];
}

- (void)enqueue
{
	// Reserves the buffer's place in the queue's execution order: the buffers of a queue run in the order they were
	// enqueued, whatever the order they are committed in.
	_commandBuffer->enqueue();

	MTLCommandBufferStatus expected = MTLCommandBufferStatusNotEnqueued;
	__atomic_compare_exchange_n(&_status, &expected, MTLCommandBufferStatusEnqueued, false, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE);
}

- (void)encodeSignalEvent: (id<MTLEvent>)event
                    value: (uint64_t)value
{
	_commandBuffer->encodeSignalEvent(MTLEventGetIndium(event), value);
}

- (void)encodeWaitForEvent: (id<MTLEvent>)event
                     value: (uint64_t)value
{
	_commandBuffer->encodeWaitForEvent(MTLEventGetIndium(event), value);
}

- (void)commit
{
	// Textures that copy IOSurface planes get the CPU's writes before the GPU runs the work, and
	// the next lock of their surfaces copies its results back.
	MTLIOSurfaceCopyBeforeGPUUse();
	// committing enqueues the command buffer if it has not been
	MTLCommandBufferStatus status = __atomic_load_n(&_status, __ATOMIC_ACQUIRE);
	while (status < MTLCommandBufferStatusCommitted
		&& !__atomic_compare_exchange_n(&_status, &status, MTLCommandBufferStatusCommitted, false, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE)) {
	}
	_commandBuffer->commit();
	MTLIOSurfaceCopyGPUMayHaveWritten();
}

#else

@dynamic commandQueue;
@dynamic device;
@dynamic label;
@dynamic status;
@dynamic retainedReferences;
@dynamic errorOptions;
@dynamic kernelStartTime;
@dynamic kernelEndTime;
@dynamic GPUStartTime;
@dynamic GPUEndTime;

MTL_UNSUPPORTED_CLASS

#endif

@end

#if DARLING_METAL_ENABLED
MTL_EXTERN NSErrorDomain const MTLCommandBufferErrorDomain = @"MTLCommandBufferErrorDomain";
#endif
