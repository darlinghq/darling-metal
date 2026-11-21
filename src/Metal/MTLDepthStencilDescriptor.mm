// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLDepthStencilDescriptorInternal.h>
#import <Metal/stubs.h>

@implementation MTLDepthStencilDescriptor
#if DARLING_METAL_ENABLED
{
	MTLStencilDescriptor* _frontFaceStencil;
	MTLStencilDescriptor* _backFaceStencil;
}
#endif

#if DARLING_METAL_ENABLED

@synthesize label = _label;
@synthesize depthWriteEnabled = _depthWriteEnabled;
@synthesize depthCompareFunction = _depthCompareFunction;

- (MTLStencilDescriptor*)frontFaceStencil
{
	return _frontFaceStencil;
}

- (void)setFrontFaceStencil: (MTLStencilDescriptor*)stencil
{
	// null_resettable: nil restores a default descriptor. The descriptor is copied, so later changes to
	// the argument do not affect this one.
	MTLStencilDescriptor* copy = stencil != nil ? [stencil copy] : [[MTLStencilDescriptor alloc] init];
	[_frontFaceStencil release];
	_frontFaceStencil = copy;
}

- (MTLStencilDescriptor*)backFaceStencil
{
	return _backFaceStencil;
}

- (void)setBackFaceStencil: (MTLStencilDescriptor*)stencil
{
	MTLStencilDescriptor* copy = stencil != nil ? [stencil copy] : [[MTLStencilDescriptor alloc] init];
	[_backFaceStencil release];
	_backFaceStencil = copy;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_depthWriteEnabled = YES;
		_depthCompareFunction = MTLCompareFunctionAlways;
		_frontFaceStencil = [[MTLStencilDescriptor alloc] init];
		_backFaceStencil = [[MTLStencilDescriptor alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_label release];
	[_frontFaceStencil release];
	[_backFaceStencil release];
	[super dealloc];
}

#else

@dynamic label;
@dynamic depthWriteEnabled;
@dynamic depthCompareFunction;
@dynamic frontFaceStencil;
@dynamic backFaceStencil;

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
		[_frontFaceStencil hasEffect] ? std::optional<Indium::StencilDescriptor>([_frontFaceStencil asIndiumDescriptor]) : std::nullopt,
		[_backFaceStencil hasEffect] ? std::optional<Indium::StencilDescriptor>([_backFaceStencil asIndiumDescriptor]) : std::nullopt,
	};
}

#endif

@end

@implementation MTLDepthStencilStateInternal

#if DARLING_METAL_ENABLED

@synthesize device = _device;
@synthesize label = _label;
@synthesize state = _state;

const std::shared_ptr<Indium::DepthStencilState>& MTLDepthStencilStateGetIndium(id<MTLDepthStencilState> object)
{
	static const std::shared_ptr<Indium::DepthStencilState> none;
	static const Class internalClass = [MTLDepthStencilStateInternal class];

	if (!MTLObjectIsInstanceOf(object, internalClass)) {
		return none;
	}
	return ((MTLDepthStencilStateInternal*)object)->_state;
}

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
