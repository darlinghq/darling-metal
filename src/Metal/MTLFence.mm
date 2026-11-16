// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLFenceInternal.h>
#import <Metal/stubs.h>

@implementation MTLFenceInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::Fence> _fence;
}

@synthesize device = _device;
@synthesize label = _label;

std::shared_ptr<Indium::Fence> MTLFenceGetIndium(id<MTLFence> object)
{
	static const Class internalClass = [MTLFenceInternal class];

	if (!MTLObjectIsInstanceOf(object, internalClass)) {
		return nullptr;
	}
	return ((MTLFenceInternal*)object)->_fence;
}

- (instancetype)initWithFence: (std::shared_ptr<Indium::Fence>)fence
                       device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_fence = fence;
		_device = [device retain];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[super dealloc];
}

#else

@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
