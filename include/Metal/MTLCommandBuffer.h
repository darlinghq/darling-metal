// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOMMANDBUFFER_H_
#define _METAL_MTLCOMMANDBUFFER_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLCommandBuffer;
@protocol MTLDrawable;
@protocol MTLBlitCommandEncoder;
@protocol MTLComputeCommandEncoder;
@protocol MTLCommandQueue;
@protocol MTLRenderCommandEncoder;

@class MTLComputePassDescriptor;
@class MTLRenderPassDescriptor;

typedef NS_ENUM(NSUInteger, MTLDispatchType) {
	MTLDispatchTypeSerial = 0,
	MTLDispatchTypeConcurrent = 1,
};

typedef void (^MTLCommandBufferHandler)(id<MTLCommandBuffer>);

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
@property(nonatomic) BOOL retainedReferences;
@property(nonatomic) MTLCommandBufferErrorOption errorOptions;

@end

@protocol MTLCommandBuffer <NSObject>

@property(readonly) id<MTLCommandQueue> commandQueue;
@property (readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;
@property(nullable, readonly) NSError* error;

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDescriptor: (MTLComputePassDescriptor*)computePassDescriptor;
- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType: (MTLDispatchType)dispatchType;
- (id<MTLComputeCommandEncoder>)computeCommandEncoder;

- (id<MTLRenderCommandEncoder>)renderCommandEncoderWithDescriptor: (MTLRenderPassDescriptor*)renderPassDescriptor;

- (id<MTLBlitCommandEncoder>)blitCommandEncoder;

- (void)addScheduledHandler: (MTLCommandBufferHandler)block;
- (void)waitUntilScheduled;
- (void)addCompletedHandler: (MTLCommandBufferHandler)block;
- (void)waitUntilCompleted;
- (void)presentDrawable: (id<MTLDrawable>)drawable;
- (void)enqueue;
- (void)commit;

// TODO: other methods

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOMMANDBUFFER_H_
