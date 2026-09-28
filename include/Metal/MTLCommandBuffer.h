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

@protocol MTLCommandBuffer <NSObject>

@property(readonly) id<MTLCommandQueue> commandQueue;
@property (readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDescriptor: (MTLComputePassDescriptor*)computePassDescriptor;
- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType: (MTLDispatchType)dispatchType;
- (id<MTLComputeCommandEncoder>)computeCommandEncoder;

- (id<MTLRenderCommandEncoder>)renderCommandEncoderWithDescriptor: (MTLRenderPassDescriptor*)renderPassDescriptor;

- (id<MTLBlitCommandEncoder>)blitCommandEncoder;

- (void)addCompletedHandler: (MTLCommandBufferHandler)block;
- (void)waitUntilCompleted;
- (void)presentDrawable: (id<MTLDrawable>)drawable;
- (void)commit;

// TODO: other methods

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOMMANDBUFFER_H_
