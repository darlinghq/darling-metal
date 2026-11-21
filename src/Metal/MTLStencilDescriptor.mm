// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLStencilDescriptor.h>
#import <Metal/MTLDepthStencilDescriptorInternal.h>
#import <Metal/stubs.h>

@implementation MTLStencilDescriptor

#if DARLING_METAL_ENABLED

@synthesize stencilCompareFunction = _stencilCompareFunction;
@synthesize stencilFailureOperation = _stencilFailureOperation;
@synthesize depthFailureOperation = _depthFailureOperation;
@synthesize depthStencilPassOperation = _depthStencilPassOperation;
@synthesize readMask = _readMask;
@synthesize writeMask = _writeMask;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_stencilCompareFunction = MTLCompareFunctionAlways;
		_stencilFailureOperation = MTLStencilOperationKeep;
		_depthFailureOperation = MTLStencilOperationKeep;
		_depthStencilPassOperation = MTLStencilOperationKeep;
		_readMask = UINT32_MAX;
		_writeMask = UINT32_MAX;
	}
	return self;
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLStencilDescriptor* copy = [[[self class] allocWithZone: zone] init];
	copy->_stencilCompareFunction = _stencilCompareFunction;
	copy->_stencilFailureOperation = _stencilFailureOperation;
	copy->_depthFailureOperation = _depthFailureOperation;
	copy->_depthStencilPassOperation = _depthStencilPassOperation;
	copy->_readMask = _readMask;
	copy->_writeMask = _writeMask;
	return copy;
}

#else

@dynamic stencilCompareFunction;
@dynamic stencilFailureOperation;
@dynamic depthFailureOperation;
@dynamic depthStencilPassOperation;
@dynamic readMask;
@dynamic writeMask;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLStencilDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (BOOL)hasEffect
{
	// A descriptor that always passes and never changes the stencil buffer is what an unset descriptor
	// is; it needs no stencil test.
	return _stencilCompareFunction != MTLCompareFunctionAlways
		|| _stencilFailureOperation != MTLStencilOperationKeep
		|| _depthFailureOperation != MTLStencilOperationKeep
		|| _depthStencilPassOperation != MTLStencilOperationKeep;
}

- (Indium::StencilDescriptor)asIndiumDescriptor
{
	return Indium::StencilDescriptor {
		static_cast<Indium::CompareFunction>(_stencilCompareFunction),
		static_cast<Indium::StencilOperation>(_stencilFailureOperation),
		static_cast<Indium::StencilOperation>(_depthFailureOperation),
		static_cast<Indium::StencilOperation>(_depthStencilPassOperation),
		_readMask,
		_writeMask,
	};
}

#endif

@end
