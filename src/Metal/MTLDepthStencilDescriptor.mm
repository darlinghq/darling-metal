// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLDepthStencilDescriptorInternal.h>
#import <Metal/stubs.h>

@implementation MTLDepthStencilDescriptor

#if DARLING_METAL_ENABLED

@synthesize label = _label;
@synthesize depthWriteEnabled = _depthWriteEnabled;
@synthesize depthCompareFunction = _depthCompareFunction;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_depthWriteEnabled = YES;
		_depthCompareFunction = MTLCompareFunctionAlways;
	}
	return self;
}

- (void)dealloc
{
	[_label release];
	[super dealloc];
}

#else

@dynamic label;
@dynamic depthWriteEnabled;
@dynamic depthCompareFunction;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLDepthStencilDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::DepthStencilDescriptor)asIndiumDescriptor
{
	// Indium takes the depth format from the render pass' depth attachment, so
	// there is no format to forward here.
	return Indium::DepthStencilDescriptor {
		static_cast<Indium::CompareFunction>(_depthCompareFunction),
		static_cast<bool>(_depthWriteEnabled),
		// MTLStencilDescriptor is still a stub, so there is no stencil to forward.
		std::nullopt,
		std::nullopt,
	};
}

#endif

@end

@implementation MTLDepthStencilStateInternal

#if DARLING_METAL_ENABLED

@synthesize device = _device;
@synthesize label = _label;
@synthesize state = _state;

- (instancetype)initWithState: (std::shared_ptr<Indium::DepthStencilState>)state
                       device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_state = state;
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
