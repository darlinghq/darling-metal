// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLSamplerDescriptorInternal.h>
#import <Metal/stubs.h>

@implementation MTLSamplerDescriptor

#if DARLING_METAL_ENABLED

@synthesize label = _label;
@synthesize minFilter = _minFilter;
@synthesize magFilter = _magFilter;
@synthesize mipFilter = _mipFilter;
@synthesize sAddressMode = _sAddressMode;
@synthesize tAddressMode = _tAddressMode;
@synthesize rAddressMode = _rAddressMode;
@synthesize maxAnisotropy = _maxAnisotropy;
@synthesize normalizedCoordinates = _normalizedCoordinates;
@synthesize lodMinClamp = _lodMinClamp;
@synthesize lodMaxClamp = _lodMaxClamp;
@synthesize supportArgumentBuffers = _supportArgumentBuffers;
@synthesize borderColor = _borderColor;
@synthesize compareFunction = _compareFunction;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_minFilter = MTLSamplerMinMagFilterNearest;
		_magFilter = MTLSamplerMinMagFilterNearest;
		_mipFilter = MTLSamplerMipFilterNotMipmapped;
		_sAddressMode = MTLSamplerAddressModeClampToEdge;
		_tAddressMode = MTLSamplerAddressModeClampToEdge;
		_rAddressMode = MTLSamplerAddressModeClampToEdge;
		_maxAnisotropy = 1;
		_normalizedCoordinates = YES;
		_lodMinClamp = 0;
		_lodMaxClamp = FLT_MAX;
		_supportArgumentBuffers = NO;
		_borderColor = MTLSamplerBorderColorTransparentBlack;
		_compareFunction = MTLCompareFunctionAlways;
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
@dynamic minFilter;
@dynamic magFilter;
@dynamic mipFilter;
@dynamic sAddressMode;
@dynamic tAddressMode;
@dynamic rAddressMode;
@dynamic maxAnisotropy;
@dynamic normalizedCoordinates;
@dynamic lodMinClamp;
@dynamic lodMaxClamp;
@dynamic supportArgumentBuffers;
@dynamic borderColor;
@dynamic compareFunction;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLSamplerDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::SamplerDescriptor)asIndiumDescriptor
{
	// Every enum Indium wants here is numbered exactly the way Metal numbers it,
	// so all of these are plain casts.
	Indium::SamplerDescriptor descriptor {};
	descriptor.minFilter = static_cast<Indium::SamplerMinMagFilter>(_minFilter);
	descriptor.magFilter = static_cast<Indium::SamplerMinMagFilter>(_magFilter);
	descriptor.mipFilter = static_cast<Indium::SamplerMipFilter>(_mipFilter);
	descriptor.sAddressMode = static_cast<Indium::SamplerAddressMode>(_sAddressMode);
	descriptor.tAddressMode = static_cast<Indium::SamplerAddressMode>(_tAddressMode);
	descriptor.rAddressMode = static_cast<Indium::SamplerAddressMode>(_rAddressMode);
	descriptor.maxAnisotropy = _maxAnisotropy;
	descriptor.normalizedCoordinates = _normalizedCoordinates;
	descriptor.lodMinClamp = _lodMinClamp;
	descriptor.lodMaxClamp = _lodMaxClamp;
	descriptor.supportArgumentBuffers = _supportArgumentBuffers;
	descriptor.borderColor = static_cast<Indium::SamplerBorderColor>(_borderColor);
	descriptor.compareFunction = static_cast<Indium::CompareFunction>(_compareFunction);
	return descriptor;
}

#endif

@end
