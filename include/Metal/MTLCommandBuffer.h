/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _METAL_MTLCOMMANDBUFFER_H_
#define _METAL_MTLCOMMANDBUFFER_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLCommandBuffer;
@protocol MTLDrawable;
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

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDescriptor: (MTLComputePassDescriptor*)computePassDescriptor;
- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType: (MTLDispatchType)dispatchType;
- (id<MTLComputeCommandEncoder>)computeCommandEncoder;

- (id<MTLRenderCommandEncoder>)renderCommandEncoderWithDescriptor: (MTLRenderPassDescriptor*)renderPassDescriptor;

- (void)addCompletedHandler: (MTLCommandBufferHandler)block;
- (void)waitUntilCompleted;
- (void)presentDrawable: (id<MTLDrawable>)drawable;
- (void)commit;

// TODO: other methods

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOMMANDBUFFER_H_
