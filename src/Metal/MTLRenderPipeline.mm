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

#import <Metal/MTLRenderPipelineInternal.h>
#import <Metal/stubs.h>
#import <Metal/MTLLibraryInternal.h>
#import <Metal/MTLPipelineInternal.h>
#import <Metal/MTLDevice.h>

#include <map>

@implementation MTLRenderPipelineDescriptor

#if __OBJC2__

@synthesize vertexFunction = _vertexFunction;
@synthesize fragmentFunction = _fragmentFunction;
@synthesize maxVertexCallStackDepth = _maxVertexCallStackDepth;
@synthesize maxFragmentCallStackDepth = _maxFragmentCallStackDepth;
@synthesize vertexDescriptor = _vertexDescriptor;
@synthesize vertexBuffers = _vertexBuffers;
@synthesize fragmentBuffers = _fragmentBuffers;
@synthesize colorAttachments = _colorAttachments;
@synthesize depthAttachmentPixelFormat = _depthAttachmentPixelFormat;
@synthesize stencilAttachmentPixelFormat = _stencilAttachmentPixelFormat;
@synthesize sampleCount = _sampleCount;
@synthesize alphaToCoverageEnabled = _alphaToCoverageEnabled;
@synthesize alphaToOneEnabled = _alphaToOneEnabled;
@synthesize rasterizationEnabled = _rasterizationEnabled;
@synthesize inputPrimitiveTopology = _inputPrimitiveTopology;
@synthesize rasterSampleCount = _rasterSampleCount;
@synthesize maxTessellationFactor = _maxTessellationFactor;
@synthesize tessellationFactorScaleEnabled = _tessellationFactorScaleEnabled;
@synthesize tessellationFactorFormat = _tessellationFactorFormat;
@synthesize tessellationControlPointIndexType = _tessellationControlPointIndexType;
@synthesize tessellationFactorStepFunction = _tessellationFactorStepFunction;
@synthesize tessellationOutputWindingOrder = _tessellationOutputWindingOrder;
@synthesize tessellationPartitionMode = _tessellationPartitionMode;
@synthesize supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
@synthesize maxVertexAmplificationCount = _maxVertexAmplificationCount;
@synthesize supportAddingVertexBinaryFunctions = _supportAddingVertexBinaryFunctions;
@synthesize supportAddingFragmentBinaryFunctions = _supportAddingFragmentBinaryFunctions;
@synthesize binaryArchives = _binaryArchives;
@synthesize vertexLinkedFunctions = _vertexLinkedFunctions;
@synthesize fragmentLinkedFunctions = _fragmentLinkedFunctions;
@synthesize fragmentPreloadedLibraries = _fragmentPreloadedLibraries;
@synthesize vertexPreloadedLibraries = _vertexPreloadedLibraries;

- (void)_doInit
{
	_maxVertexCallStackDepth = 1;
	_maxFragmentCallStackDepth = 1;
	_vertexBuffers = [MTLPipelineBufferDescriptorArray new];
	_fragmentBuffers = [MTLPipelineBufferDescriptorArray new];
	_colorAttachments = [MTLRenderPipelineColorAttachmentDescriptorArray new];
	_depthAttachmentPixelFormat = MTLPixelFormatInvalid;
	_stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
	_sampleCount = 1;
	_rasterizationEnabled = YES;
	_inputPrimitiveTopology = MTLPrimitiveTopologyClassUnspecified;
	_rasterSampleCount = 1; // good guess; TODO: check the actual default
	_maxTessellationFactor = 16;
	_tessellationFactorFormat = MTLTessellationFactorFormatHalf;
	_tessellationControlPointIndexType = MTLTessellationControlPointIndexTypeNone;
	_tessellationFactorStepFunction = MTLTessellationFactorStepFunctionConstant;
	_tessellationOutputWindingOrder = MTLWindingClockwise;
	_tessellationPartitionMode = MTLTessellationPartitionModePow2;
	_fragmentPreloadedLibraries = [NSArray new];
	_vertexPreloadedLibraries = [NSArray new];
}

- (void)_doDealloc
{
	[_vertexFunction release];
	[_fragmentFunction release];
	[_vertexDescriptor release];
	[_vertexBuffers release];
	[_fragmentBuffers release];
	[_colorAttachments release];
	[_binaryArchives release];
	[_vertexLinkedFunctions release];
	[_fragmentLinkedFunctions release];
	[_fragmentPreloadedLibraries release];
	[_vertexPreloadedLibraries release];
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self _doInit];
	}
	return self;
}

- (void)dealloc
{
	[self _doDealloc];
	[super dealloc];
}

- (instancetype)copyWithZone: (NSZone*)zone
{
	MTLRenderPipelineDescriptor* copy = [MTLRenderPipelineDescriptor new];

	copy.vertexFunction = _vertexFunction;
	copy.fragmentFunction = _fragmentFunction;
	copy.maxVertexCallStackDepth = _maxVertexCallStackDepth;
	copy.maxFragmentCallStackDepth = _maxFragmentCallStackDepth;
	copy.vertexDescriptor = _vertexDescriptor;
	[copy->_vertexBuffers release];
	copy->_vertexBuffers = [_vertexBuffers copy];
	[copy->_fragmentBuffers release];
	copy->_fragmentBuffers = [_fragmentBuffers copy];
	[copy->_colorAttachments release];
	copy->_colorAttachments = [_colorAttachments copy];
	copy.depthAttachmentPixelFormat = _depthAttachmentPixelFormat;
	copy.stencilAttachmentPixelFormat = _stencilAttachmentPixelFormat;
	copy.sampleCount = _sampleCount;
	copy.alphaToCoverageEnabled = _alphaToCoverageEnabled;
	copy.alphaToOneEnabled = _alphaToOneEnabled;
	copy.rasterizationEnabled = _rasterizationEnabled;
	copy.inputPrimitiveTopology = _inputPrimitiveTopology;
	copy.rasterSampleCount = _rasterSampleCount;
	copy.maxTessellationFactor = _maxTessellationFactor;
	copy.tessellationFactorScaleEnabled = _tessellationFactorScaleEnabled;
	copy.tessellationFactorFormat = _tessellationFactorFormat;
	copy.tessellationControlPointIndexType = _tessellationControlPointIndexType;
	copy.tessellationFactorStepFunction = _tessellationFactorStepFunction;
	copy.tessellationOutputWindingOrder = _tessellationOutputWindingOrder;
	copy.tessellationPartitionMode = _tessellationPartitionMode;
	copy.supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
	copy.maxVertexAmplificationCount = _maxVertexAmplificationCount;
	copy.supportAddingVertexBinaryFunctions = _supportAddingVertexBinaryFunctions;
	copy.supportAddingFragmentBinaryFunctions = _supportAddingFragmentBinaryFunctions;
	copy.binaryArchives = _binaryArchives;
	copy.vertexLinkedFunctions = _vertexLinkedFunctions;
	copy.fragmentLinkedFunctions = _fragmentLinkedFunctions;
	copy.fragmentPreloadedLibraries = _fragmentPreloadedLibraries;
	copy.vertexPreloadedLibraries = _vertexPreloadedLibraries;

	return copy;
}

- (void)reset
{
	[self _doDealloc];
	[self _doInit];
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPipelineDescriptor (Internal)

#if __OBJC2__

- (Indium::RenderPipelineDescriptor)asIndiumDescriptor
{
	return {
		((MTLFunctionInternal*)_vertexFunction).function,
		((MTLFunctionInternal*)_fragmentFunction).function,
		_maxVertexCallStackDepth,
		_maxFragmentCallStackDepth,
		std::nullopt, // TODO
		[_vertexBuffers asIndiumDescriptors],
		[_fragmentBuffers asIndiumDescriptors],
		[_colorAttachments asContiguousIndiumDescriptors],
		static_cast<Indium::PixelFormat>(_depthAttachmentPixelFormat),
		static_cast<Indium::PixelFormat>(_stencilAttachmentPixelFormat),
		static_cast<bool>(_alphaToCoverageEnabled),
		static_cast<bool>(_alphaToOneEnabled),
		static_cast<bool>(_rasterizationEnabled),
		static_cast<Indium::PrimitiveTopologyClass>(_inputPrimitiveTopology),
		_rasterSampleCount,
		_maxTessellationFactor,
		static_cast<bool>(_tessellationFactorScaleEnabled),
		static_cast<Indium::TessellationFactorFormat>(_tessellationFactorFormat),
		static_cast<Indium::TessellationControlPointIndexType>(_tessellationControlPointIndexType),
		static_cast<Indium::TessellationFactorStepFunction>(_tessellationFactorStepFunction),
		static_cast<Indium::Winding>(_tessellationOutputWindingOrder),
		static_cast<Indium::TessellationPartitionMode>(_tessellationPartitionMode),
		static_cast<bool>(_supportIndirectCommandBuffers),
		_maxVertexAmplificationCount,
		static_cast<bool>(_supportAddingVertexBinaryFunctions),
		static_cast<bool>(_supportAddingFragmentBinaryFunctions),
		{}, // TODO
		nullptr, // TODO
		nullptr, // TODO
	};
}

#endif

@end

@implementation MTLRenderPipelineColorAttachmentDescriptorArray

#if __OBJC2__

{
	NSMutableDictionary<NSNumber*, MTLRenderPipelineColorAttachmentDescriptor*>* _dict;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_dict = [NSMutableDictionary new];
	}
	return self;
}

- (instancetype)initWithDictionary: (NSDictionary<NSNumber*, MTLRenderPipelineColorAttachmentDescriptor*>*)dictionary
{
	self = [super init];
	if (self != nil) {
		_dict = [dictionary mutableCopy];
	}
	return self;
}

- (void)dealloc
{
	[_dict release];
	[super dealloc];
}

- (MTLRenderPipelineColorAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)index
{
	if (!_dict[@(index)]) {
		_dict[@(index)] = [[MTLRenderPipelineColorAttachmentDescriptor new] autorelease];
	}
	return [[_dict[@(index)] retain] autorelease];
}

-    (void)setObject: (MTLRenderPipelineColorAttachmentDescriptor*)desc
  atIndexedSubscript: (NSUInteger)index
{
	_dict[@(index)] = desc;
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPipelineColorAttachmentDescriptorArray (Internal)

#if __OBJC2__

- (id)copyWithZone: (NSZone*)zone
{
	return [[MTLRenderPipelineColorAttachmentDescriptorArray alloc] initWithDictionary: _dict];
}

- (std::unordered_map<size_t, Indium::RenderPipelineColorAttachmentDescriptor>)asIndiumDescriptors
{
	std::unordered_map<size_t, Indium::RenderPipelineColorAttachmentDescriptor> result;

	for (NSNumber* index in _dict) {
		result[[index unsignedIntegerValue]] = [_dict[index] asIndiumDescriptor];
	}

	return result;
}

- (std::vector<Indium::RenderPipelineColorAttachmentDescriptor>)asContiguousIndiumDescriptors
{
	auto tmp1 = [self asIndiumDescriptors];
	std::map<size_t, Indium::RenderPipelineColorAttachmentDescriptor> tmp2(tmp1.begin(), tmp1.end());
	std::vector<Indium::RenderPipelineColorAttachmentDescriptor> result;

	for (const auto& [key, value]: tmp2) {
		result.push_back(value);
	}

	return result;
}

#endif

@end

@implementation MTLRenderPipelineColorAttachmentDescriptor

#if __OBJC2__

@synthesize pixelFormat = _pixelFormat;
@synthesize writeMask = _writeMask;
@synthesize blendingEnabled = _blendingEnabled;
@synthesize alphaBlendOperation = _alphaBlendOperation;
@synthesize rgbBlendOperation = _rgbBlendOperation;
@synthesize destinationAlphaBlendFactor = _destinationAlphaBlendFactor;
@synthesize destinationRGBBlendFactor = _destinationRGBBlendFactor;
@synthesize sourceAlphaBlendFactor = _sourceAlphaBlendFactor;
@synthesize sourceRGBBlendFactor = _sourceRGBBlendFactor;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_pixelFormat = MTLPixelFormatInvalid;
		_writeMask = MTLColorWriteMaskAll;
		_alphaBlendOperation = MTLBlendOperationAdd;
		_rgbBlendOperation = MTLBlendOperationAdd;
		_destinationAlphaBlendFactor = MTLBlendFactorZero;
		_destinationRGBBlendFactor = MTLBlendFactorZero;
		_sourceAlphaBlendFactor = MTLBlendFactorOne;
		_sourceRGBBlendFactor = MTLBlendFactorOne;
	}
	return self;
}

- (instancetype)copyWithZone: (NSZone*)zone
{
	MTLRenderPipelineColorAttachmentDescriptor* copy = [MTLRenderPipelineColorAttachmentDescriptor new];

	copy.pixelFormat = _pixelFormat;
	copy.writeMask = _writeMask;
	copy.blendingEnabled = _blendingEnabled;
	copy.alphaBlendOperation = _alphaBlendOperation;
	copy.rgbBlendOperation = _rgbBlendOperation;
	copy.destinationAlphaBlendFactor = _destinationAlphaBlendFactor;
	copy.destinationRGBBlendFactor = _destinationRGBBlendFactor;
	copy.sourceAlphaBlendFactor = _sourceAlphaBlendFactor;
	copy.sourceRGBBlendFactor = _sourceRGBBlendFactor;

	return copy;
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPipelineColorAttachmentDescriptor (Internal)

#if __OBJC2__

- (Indium::RenderPipelineColorAttachmentDescriptor)asIndiumDescriptor
{
	return Indium::RenderPipelineColorAttachmentDescriptor {
		static_cast<Indium::ColorWriteMask>(_writeMask),
		static_cast<Indium::PixelFormat>(_pixelFormat),
		static_cast<bool>(_blendingEnabled),
		static_cast<Indium::BlendFactor>(_sourceRGBBlendFactor),
		static_cast<Indium::BlendFactor>(_destinationRGBBlendFactor),
		static_cast<Indium::BlendOperation>(_rgbBlendOperation),
		static_cast<Indium::BlendFactor>(_sourceAlphaBlendFactor),
		static_cast<Indium::BlendFactor>(_destinationAlphaBlendFactor),
		static_cast<Indium::BlendOperation>(_alphaBlendOperation),
	};
}

#endif

@end

@implementation MTLRenderPipelineStateInternal

#if __OBJC2__

@synthesize state = _state;
@synthesize device = _device;

- (instancetype)initWithState: (std::shared_ptr<Indium::RenderPipelineState>)state
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
	[super dealloc];
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
