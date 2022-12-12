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

#import <Metal/MTLCommandBufferInternal.h>
#import <Metal/MTLComputeCommandEncoderInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLCommandQueue.h>
#import <Metal/MTLDrawableInternal.h>
#import <Metal/stubs.h>

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

@implementation MTLCommandBufferInternal

#if __OBJC2__

{
	std::shared_ptr<Indium::CommandBuffer> _commandBuffer;
}

@synthesize device = _device;
@synthesize commandQueue = _commandQueue;

- (instancetype)initWithCommandBuffer: (std::shared_ptr<Indium::CommandBuffer>)commandBuffer
                         commandQueue: (id<MTLCommandQueue>)commandQueue
{
	self = [super init];
	if (self != nil) {
		_commandBuffer = commandBuffer;
		_device = [commandQueue.device retain];
		_commandQueue = [_commandQueue retain];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_commandQueue release];
	[super dealloc];
}

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDescriptor: (MTLComputePassDescriptor*)computePassDescriptor
{
	auto encoder = _commandBuffer->computeCommandEncoder(computePassDescriptor.asIndiumDescriptor);
	if (!encoder) {
		return nil;
	}
	return [[MTLComputeCommandEncoderInternal alloc] initWithEncoder: encoder device: _device];
}

- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType: (MTLDispatchType)dispatchType
{
	auto encoder = _commandBuffer->computeCommandEncoder(static_cast<Indium::DispatchType>(dispatchType));
	if (!encoder) {
		return nil;
	}
	return [[MTLComputeCommandEncoderInternal alloc] initWithEncoder: encoder device: _device];
}

- (id<MTLComputeCommandEncoder>)computeCommandEncoder
{
	auto encoder = _commandBuffer->computeCommandEncoder();
	if (!encoder) {
		return nil;
	}
	return [[MTLComputeCommandEncoderInternal alloc] initWithEncoder: encoder device: _device];
}

- (void)addCompletedHandler: (MTLCommandBufferHandler)block
{
	_commandBuffer->addCompletedHandler(MTLCommandBufferHandlerWrapper(block, self));
}

- (void)waitUntilCompleted
{
	_commandBuffer->waitUntilCompleted();
}

- (void)presentDrawable: (id<MTLDrawable>)drawable
{
	_commandBuffer->presentDrawable(((id<MTLDrawableInternal>)drawable).drawable);
}

- (void)commit
{
	_commandBuffer->commit();
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
