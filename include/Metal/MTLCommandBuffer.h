// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOMMANDBUFFER_H_
#define _METAL_MTLCOMMANDBUFFER_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLEvent.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLCommandBuffer;
@protocol MTLDrawable;
@protocol MTLBlitCommandEncoder;
@protocol MTLComputeCommandEncoder;
@protocol MTLCommandQueue;
@protocol MTLRenderCommandEncoder;
@protocol MTLParallelRenderCommandEncoder;
@protocol MTLResidencySet;

@class MTLBlitPassDescriptor;
@class MTLComputePassDescriptor;
@class MTLRenderPassDescriptor;

typedef NS_ENUM(NSUInteger, MTLDispatchType) {
	MTLDispatchTypeSerial = 0,
	MTLDispatchTypeConcurrent = 1,
};

typedef void (^MTLCommandBufferHandler)(id<MTLCommandBuffer>);

// Where a command buffer is in its life: created, enqueued on its queue, committed, scheduled for
// execution, finished, or finished with an error.
typedef NS_ENUM(NSUInteger, MTLCommandBufferStatus) {
	MTLCommandBufferStatusNotEnqueued = 0,
	MTLCommandBufferStatusEnqueued = 1,
	MTLCommandBufferStatusCommitted = 2,
	MTLCommandBufferStatusScheduled = 3,
	MTLCommandBufferStatusCompleted = 4,
	MTLCommandBufferStatusError = 5,
};

MTL_EXPORT MTL_EXTERN NSErrorDomain const MTLCommandBufferErrorDomain;

typedef NS_ENUM(NSUInteger, MTLCommandBufferError) {
	MTLCommandBufferErrorNone = 0,
	MTLCommandBufferErrorInternal = 1,
	MTLCommandBufferErrorTimeout = 2,
	MTLCommandBufferErrorPageFault = 3,
	MTLCommandBufferErrorBlacklisted = 4,
	MTLCommandBufferErrorAccessRevoked = 4,
	MTLCommandBufferErrorNotPermitted = 7,
	MTLCommandBufferErrorOutOfMemory = 8,
	MTLCommandBufferErrorInvalidResource = 9,
	MTLCommandBufferErrorMemoryless = 10,
	MTLCommandBufferErrorDeviceRemoved = 11,
	MTLCommandBufferErrorStackOverflow = 12,
};

@protocol MTLLogState;

typedef NS_OPTIONS(NSUInteger, MTLCommandBufferErrorOption) {
	MTLCommandBufferErrorOptionNone = 0,
	MTLCommandBufferErrorOptionEncoderExecutionStatus = 1,
};

/**
 * Says how a command buffer should behave.
 *
 * Each stored value is returned unchanged. Only these three properties are
 * declared, because only these three could be confirmed against a reference on
 * this machine: the descriptor's `type` property takes an MTLCommandBufferType
 * whose enumerators are in no header or generated reference available here, and
 * an enum invented to fill a gap would be a wrong answer that looks right.
 * Callers that set `type` get an unrecognised selector.
 */
MTL_EXPORT
@interface MTLCommandBufferDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, retain) id<MTLLogState> logState;
// YES by default, like -[MTLCommandQueue commandBuffer].
@property(nonatomic) BOOL retainedReferences;
@property(nonatomic) MTLCommandBufferErrorOption errorOptions;

@end

@protocol MTLCommandBuffer <NSObject>

@property(readonly) id<MTLCommandQueue> commandQueue;
@property (readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;
@property(nullable, readonly) NSError* error;
@property(readonly) MTLCommandBufferStatus status;
@property(readonly) BOOL retainedReferences;
@property(readonly) MTLCommandBufferErrorOption errorOptions;

// Host times in seconds, on the clock of CACurrentMediaTime(). They are 0 until the command buffer has
// started (kernelStartTime, GPUStartTime) or finished (kernelEndTime, GPUEndTime). They are the times at which
// the command buffer was handed to the device and the completion was seen on the host, not GPU timestamps.
@property(readonly) CFTimeInterval kernelStartTime;
@property(readonly) CFTimeInterval kernelEndTime;
@property(readonly) CFTimeInterval GPUStartTime;
@property(readonly) CFTimeInterval GPUEndTime;

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDescriptor: (MTLComputePassDescriptor*)computePassDescriptor;
- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType: (MTLDispatchType)dispatchType;
- (id<MTLComputeCommandEncoder>)computeCommandEncoder;

- (id<MTLRenderCommandEncoder>)renderCommandEncoderWithDescriptor: (MTLRenderPassDescriptor*)renderPassDescriptor;

// One render pass recorded by several encoders, see MTLParallelRenderCommandEncoder.
- (nullable id<MTLParallelRenderCommandEncoder>)parallelRenderCommandEncoderWithDescriptor: (MTLRenderPassDescriptor*)renderPassDescriptor;

- (id<MTLBlitCommandEncoder>)blitCommandEncoder;
- (id<MTLBlitCommandEncoder>)blitCommandEncoderWithDescriptor: (MTLBlitPassDescriptor*)blitPassDescriptor;

- (void)addScheduledHandler: (MTLCommandBufferHandler)block;
- (void)waitUntilScheduled;
- (void)addCompletedHandler: (MTLCommandBufferHandler)block;
- (void)waitUntilCompleted;
- (void)presentDrawable: (id<MTLDrawable>)drawable;
- (void)presentDrawable: (id<MTLDrawable>)drawable
                  atTime: (CFTimeInterval)presentationTime;
- (void)presentDrawable: (id<MTLDrawable>)drawable
   afterMinimumDuration: (CFTimeInterval)duration;
- (void)enqueue;
- (void)commit;

/* Makes `event` reach `value` once the work encoded before this call has finished. Not allowed while an encoder is active. */
- (void)encodeSignalEvent: (id<MTLEvent>)event
                    value: (uint64_t)value;

/* Holds the work encoded after this call, and the command buffers committed after this one on its queue, until `event` has reached `value`. */
- (void)encodeWaitForEvent: (id<MTLEvent>)event
                     value: (uint64_t)value;

// Residency sets for this command buffer. Every allocation is resident here, so these change nothing.
- (void)useResidencySet: (id<MTLResidencySet>)residencySet;
- (void)useResidencySets: (const id<MTLResidencySet> __nonnull[__nonnull])residencySets
                   count: (NSUInteger)count;


@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOMMANDBUFFER_H_
