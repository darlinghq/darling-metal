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

#import <Metal/MTLCommandQueueInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLCommandBufferInternal.h>
#import <Metal/stubs.h>

@implementation MTLCommandQueueInternal

#if __OBJC2__

{
	std::shared_ptr<Indium::CommandQueue> _queue;
}

@synthesize device = _device;

- (instancetype)initWithQueue: (std::shared_ptr<Indium::CommandQueue>)queue
                       device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_queue = queue;
		_device = [device retain];
	}
	return self;
}

- (void)dealloc
{
	[_device release];

	[super dealloc];
}

- (id<MTLCommandBuffer>)commandBuffer
{
	auto buf = _queue->commandBuffer();
	if (!buf) {
		return nil;
	}
	return [[[MTLCommandBufferInternal alloc] initWithCommandBuffer: buf commandQueue: self] autorelease];
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
