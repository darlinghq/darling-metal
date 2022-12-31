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

#import <Metal/MTLRenderCommandEncoderInternal.h>
#import <Metal/stubs.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLRenderPipelineInternal.h>
#import <Metal/MTLTypesInternal.h>

#include <map>

@implementation MTLRenderPassAttachmentDescriptor

#if DARLING_METAL_ENABLED

@synthesize texture = _texture;
@synthesize level = _level;
@synthesize slice = _slice;
@synthesize depthPlane = _depthPlane;
@synthesize loadAction = _loadAction;
@synthesize storeAction = _storeAction;
@synthesize storeActionOptions = _storeActionOptions;
@synthesize resolveTexture = _resolveTexture;
@synthesize resolveLevel = _resolveLevel;
@synthesize resolveSlice = _resolveSlice;
@synthesize resolveDepthPlane = _resolveDepthPlane;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		// replace with MTLLoadActionDontCare for color attachments
		_loadAction = MTLLoadActionClear;
		// replace with MTLStoreActionStore for color attachments
		_storeAction = MTLStoreActionDontCare;
		_storeActionOptions = MTLStoreActionOptionNone;
	}
	return self;
}

- (void)dealloc
{
	[_texture release];
	[_resolveTexture release];
	[super dealloc];
}

- (void)_copyTo: (MTLRenderPassAttachmentDescriptor*)copy
{
	copy.texture = _texture;
	copy.level = _level;
	copy.slice = _slice;
	copy.depthPlane = _depthPlane;
	copy.loadAction = _loadAction;
	copy.storeAction = _storeAction;
	copy.storeActionOptions = _storeActionOptions;
	copy.resolveTexture = _resolveTexture;
	copy.resolveLevel = _resolveLevel;
	copy.resolveSlice = _resolveSlice;
	copy.resolveDepthPlane = _resolveDepthPlane;
}

- (instancetype)copyWithZone: (NSZone*)zone
{
	MTLRenderPassAttachmentDescriptor* copy = [MTLRenderPassAttachmentDescriptor new];
	[self _copyTo: copy];
	return copy;
}

#else

@dynamic texture;
@dynamic level;
@dynamic slice;
@dynamic depthPlane;
@dynamic loadAction;
@dynamic storeAction;
@dynamic storeActionOptions;
@dynamic resolveTexture;
@dynamic resolveLevel;
@dynamic resolveSlice;
@dynamic resolveDepthPlane;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPassAttachmentDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::RenderPassAttachmentDescriptor)asIndiumDescriptor
{
	return Indium::RenderPassAttachmentDescriptor {
		((MTLTextureInternal*)_texture).texture,
		_level,
		_slice,
		_depthPlane,
		((MTLTextureInternal*)_resolveTexture).texture,
		_resolveLevel,
		_resolveSlice,
		_resolveDepthPlane,
		static_cast<Indium::LoadAction>(_loadAction),
		static_cast<Indium::StoreAction>(_storeAction),
		static_cast<Indium::StoreActionOptions>(_storeActionOptions),
	};
}

#endif

@end

@implementation MTLRenderPassColorAttachmentDescriptor

#if DARLING_METAL_ENABLED

@synthesize clearColor = _clearColor;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		self.loadAction = MTLLoadActionDontCare;
		self.storeAction = MTLStoreActionStore;
	}
	return self;
}

- (void)_copyTo: (MTLRenderPassColorAttachmentDescriptor*)copy
{
	[super _copyTo: copy];
	copy.clearColor = _clearColor;
}

- (instancetype)copyWithZone: (NSZone*)zone
{
	MTLRenderPassColorAttachmentDescriptor* copy = [MTLRenderPassColorAttachmentDescriptor new];
	[self _copyTo: copy];
	return copy;
}

#else

@dynamic clearColor;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPassColorAttachmentDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::RenderPassColorAttachmentDescriptor)asIndiumDescriptor
{
	return Indium::RenderPassColorAttachmentDescriptor {
		[super asIndiumDescriptor],
		MTLClearColorToIndium(_clearColor),
	};
}

#endif

@end

@implementation MTLRenderPassDepthAttachmentDescriptor

#if DARLING_METAL_ENABLED

@synthesize clearDepth = _clearDepth;
@synthesize depthResolveFilter = _depthResolveFilter;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_clearDepth = 1;
		_depthResolveFilter = MTLMultisampleDepthResolveFilterSample0;
	}
	return self;
}

- (void)_copyTo: (MTLRenderPassDepthAttachmentDescriptor*)copy
{
	[super _copyTo: copy];
	copy.clearDepth = _clearDepth;
	copy.depthResolveFilter = _depthResolveFilter;
}

- (instancetype)copyWithZone: (NSZone*)zone
{
	MTLRenderPassDepthAttachmentDescriptor* copy = [MTLRenderPassDepthAttachmentDescriptor new];
	[self _copyTo: copy];
	return copy;
}

#else

@dynamic clearDepth;
@dynamic depthResolveFilter;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPassDepthAttachmentDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::RenderPassDepthAttachmentDescriptor)asIndiumDescriptor
{
	return Indium::RenderPassDepthAttachmentDescriptor {
		[super asIndiumDescriptor],
		_clearDepth,
		static_cast<Indium::MultisampleDepthResolveFilter>(_depthResolveFilter),
	};
}

#endif

@end

@implementation MTLRenderPassStencilAttachmentDescriptor

#if DARLING_METAL_ENABLED

@synthesize stencilResolveFilter = _stencilResolveFilter;
@synthesize clearStencil = _clearStencil;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_stencilResolveFilter = MTLMultisampleStencilResolveFilterSample0;
	}
	return self;
}

- (void)_copyTo: (MTLRenderPassStencilAttachmentDescriptor*)copy
{
	[super _copyTo: copy];
	copy.stencilResolveFilter = _stencilResolveFilter;
	copy.clearStencil = _clearStencil;
}

- (instancetype)copyWithZone: (NSZone*)zone
{
	MTLRenderPassStencilAttachmentDescriptor* copy = [MTLRenderPassStencilAttachmentDescriptor new];
	[self _copyTo: copy];
	return copy;
}

#else

@dynamic stencilResolveFilter;
@dynamic clearStencil;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPassStencilAttachmentDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::RenderPassStencilAttachmentDescriptor)asIndiumDescriptor
{
	return Indium::RenderPassStencilAttachmentDescriptor {
		[super asIndiumDescriptor],
		_clearStencil,
		static_cast<Indium::MultisampleStencilResolveFilter>(_stencilResolveFilter),
	};
}

#endif

@end

@implementation MTLRenderPassColorAttachmentDescriptorArray

#if DARLING_METAL_ENABLED

{
	NSMutableDictionary<NSNumber*, MTLRenderPassColorAttachmentDescriptor*>* _dict;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_dict = [NSMutableDictionary new];
	}
	return self;
}

- (instancetype)initWithDictionary: (NSDictionary<NSNumber*, MTLRenderPassColorAttachmentDescriptor*>*)dictionary
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

- (MTLRenderPassColorAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)index
{
	if (!_dict[@(index)]) {
		_dict[@(index)] = [[MTLRenderPassColorAttachmentDescriptor new] autorelease];
	}
	return [[_dict[@(index)] retain] autorelease];
}

-    (void)setObject: (MTLRenderPassColorAttachmentDescriptor*)desc
  atIndexedSubscript: (NSUInteger)index
{
	_dict[@(index)] = desc;
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPassColorAttachmentDescriptorArray (Internal)

#if DARLING_METAL_ENABLED

- (id)copyWithZone: (NSZone*)zone
{
	return [[MTLRenderPassColorAttachmentDescriptorArray alloc] initWithDictionary: _dict];
}

- (std::unordered_map<size_t, Indium::RenderPassColorAttachmentDescriptor>)asIndiumDescriptors
{
	std::unordered_map<size_t, Indium::RenderPassColorAttachmentDescriptor> result;

	for (NSNumber* index in _dict) {
		result[[index unsignedIntegerValue]] = [_dict[index] asIndiumDescriptor];
	}

	return result;
}

- (std::vector<Indium::RenderPassColorAttachmentDescriptor>)asContiguousIndiumDescriptors
{
	auto tmp1 = [self asIndiumDescriptors];
	std::map<size_t, Indium::RenderPassColorAttachmentDescriptor> tmp2(tmp1.begin(), tmp1.end());
	std::vector<Indium::RenderPassColorAttachmentDescriptor> result;

	for (const auto& [key, value]: tmp2) {
		result.push_back(value);
	}

	return result;
}

#endif

@end

@implementation MTLRenderPassDescriptor

#if DARLING_METAL_ENABLED

@synthesize colorAttachments = _colorAttachments;
@synthesize depthAttachment = _depthAttachment;
@synthesize stencilAttachment = _stencilAttachment;
@synthesize visibilityResultBuffer = _visibilityResultBuffer;
@synthesize renderTargetArrayLength = _renderTargetArrayLength;
@synthesize renderTargetWidth = _renderTargetWidth;
@synthesize renderTargetHeight = _renderTargetHeight;
@synthesize imageblockSampleLength = _imageblockSampleLength;
@synthesize threadgroupMemoryLength = _threadgroupMemoryLength;
@synthesize tileWidth = _tileWidth;
@synthesize tileHeight = _tileHeight;
@synthesize defaultRasterSampleCount = _defaultRasterSampleCount;
@synthesize rasterizationRateMap = _rasterizationRateMap;
@synthesize sampleBufferAttachments = _sampleBufferAttachments;

+ (MTLRenderPassDescriptor*)renderPassDescriptor
{
	return [[MTLRenderPassDescriptor new] autorelease];
}

- (void)_doInit
{
	_colorAttachments = [MTLRenderPassColorAttachmentDescriptorArray new];
}

- (void)_doDealloc
{
	[_colorAttachments release];
	[_depthAttachment release];
	[_stencilAttachment release];
	[_visibilityResultBuffer release];
	// TODO: remove cast once we define MTLRasterizationRateMap
	[(id<NSObject>)_rasterizationRateMap release];
	[_sampleBufferAttachments release];
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

- (void)_copyTo: (MTLRenderPassDescriptor*)copy
{
	[copy->_colorAttachments release];
	copy->_colorAttachments = [_colorAttachments copy];
	copy.depthAttachment = _depthAttachment;
	copy.stencilAttachment = _stencilAttachment;
	copy.visibilityResultBuffer = _visibilityResultBuffer;
	copy.renderTargetArrayLength = _renderTargetArrayLength;
	copy.renderTargetWidth = _renderTargetWidth;
	copy.renderTargetHeight = _renderTargetHeight;
	copy.imageblockSampleLength = _imageblockSampleLength;
	copy.threadgroupMemoryLength = _threadgroupMemoryLength;
	copy.tileWidth = _tileWidth;
	copy.tileHeight = _tileHeight;
	copy.defaultRasterSampleCount = _defaultRasterSampleCount;
	copy.rasterizationRateMap = _rasterizationRateMap;
	// TODO: sampleBufferAttachments
}

- (instancetype)copyWithZone: (NSZone*)zone
{
	MTLRenderPassDescriptor* copy = [MTLRenderPassDescriptor new];
	[self _copyTo: copy];
	return copy;
}

- (NSUInteger)getSamplePositions: (MTLSamplePosition*)positions
                           count: (NSUInteger)count
{
	// TODO
	return 0;
}

- (void)setSamplePositions: (const MTLSamplePosition*)positions
                     count: (NSUInteger)count
{
	// TODO
}

#else

@dynamic colorAttachments;
@dynamic depthAttachment;
@dynamic stencilAttachment;
@dynamic visibilityResultBuffer;
@dynamic renderTargetArrayLength;
@dynamic renderTargetWidth;
@dynamic renderTargetHeight;
@dynamic imageblockSampleLength;
@dynamic threadgroupMemoryLength;
@dynamic tileWidth;
@dynamic tileHeight;
@dynamic defaultRasterSampleCount;
@dynamic rasterizationRateMap;
@dynamic sampleBufferAttachments;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLRenderPassDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::RenderPassDescriptor)asIndiumDescriptor
{
	return Indium::RenderPassDescriptor {
		[_colorAttachments asContiguousIndiumDescriptors],
		(_depthAttachment == nil) ? std::nullopt : std::make_optional([_depthAttachment asIndiumDescriptor]),
		(_stencilAttachment == nil) ? std::nullopt : std::make_optional([_stencilAttachment asIndiumDescriptor]),
		((MTLBufferInternal*)_visibilityResultBuffer).buffer,
		_renderTargetArrayLength,
		_imageblockSampleLength,
		_threadgroupMemoryLength,
		_tileWidth,
		_tileHeight,
		_defaultRasterSampleCount,
		_renderTargetWidth,
		_renderTargetHeight,
		nullptr, // TODO
		nullptr, // TODO
		{}, // TODO
	};
}

#endif

@end

@implementation MTLRenderCommandEncoderInternal

#if DARLING_METAL_ENABLED

@synthesize device = _device;
@synthesize encoder = _encoder;
@synthesize label = _label;

- (instancetype)initWithEncoder: (std::shared_ptr<Indium::RenderCommandEncoder>)encoder
                         device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_encoder = encoder;
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

//
// overridden methods
//

- (void)endEncoding
{
	_encoder->endEncoding();
}

//
// methods
//

- (void)setRenderPipelineState: (id<MTLRenderPipelineState>)pipelineState
{
	_encoder->setRenderPipelineState(((MTLRenderPipelineStateInternal*)pipelineState).state);
}

- (void)setTriangleFillMode: (MTLTriangleFillMode)fillMode
{
	_encoder->setTriangleFillMode(static_cast<Indium::TriangleFillMode>(fillMode));
}

- (void)setFrontFacingWinding: (MTLWinding)frontFacingWinding
{
	_encoder->setFrontFacingWinding(static_cast<Indium::Winding>(frontFacingWinding));
}

- (void)setCullMode: (MTLCullMode)cullMode
{
	_encoder->setCullMode(static_cast<Indium::CullMode>(cullMode));
}

- (void)setViewport: (MTLViewport)viewport
{
	_encoder->setViewport(MTLViewportToIndium(viewport));
}

- (void)setViewports: (const MTLViewport*)viewports
               count: (NSUInteger)count
{
	std::vector<Indium::Viewport> tmp;
	for (size_t i = 0; i < count; ++i) {
		tmp.push_back(MTLViewportToIndium(viewports[i]));
	}
	_encoder->setViewports(tmp);
}

- (void)setScissorRect: (MTLScissorRect)rect
{
	_encoder->setScissorRect(MTLScissorRectToIndium(rect));
}

- (void)setScissorRects: (const MTLScissorRect*)scissorRects
                  count: (NSUInteger)count
{
	std::vector<Indium::ScissorRect> tmp;
	for (size_t i = 0; i < count; ++i) {
		tmp.push_back(MTLScissorRectToIndium(scissorRects[i]));
	}
	_encoder->setScissorRects(tmp);
}

- (void)setVertexBuffer: (id<MTLBuffer>)buffer
                 offset: (NSUInteger)offset
                atIndex: (NSUInteger)index
{
	_encoder->setVertexBuffer(((MTLBufferInternal*)buffer).buffer, offset, index);
}

- (void)setVertexBuffers: (const id<MTLBuffer>*)buffers
                 offsets: (const NSUInteger*)offsets
               withRange: (NSRange)range
{
	std::vector<std::shared_ptr<Indium::Buffer>> tmp;
	std::vector<size_t> tmp2(offsets, offsets + range.length);
	for (size_t i = 0; i < range.length; ++i) {
		tmp.push_back(((MTLBufferInternal*)buffers[i]).buffer);
	}
	_encoder->setVertexBuffers(tmp, tmp2, NSRangeToIndium(range));
}

- (void)setVertexBufferOffset: (NSUInteger)offset
                      atIndex: (NSUInteger)index
{
	_encoder->setVertexBufferOffset(offset, index);
}

- (void)setVertexBytes: (const void*)bytes
                length: (NSUInteger)length
               atIndex: (NSUInteger)index
{
	_encoder->setVertexBytes(bytes, length, index);
}

- (void)setFragmentBuffer: (id<MTLBuffer>)buffer
                   offset: (NSUInteger)offset
                  atIndex: (NSUInteger)index
{
	_encoder->setFragmentBuffer(((MTLBufferInternal*)buffer).buffer, offset, index);
}

- (void)setFragmentBuffers: (const id<MTLBuffer>*)buffers
                   offsets: (const NSUInteger*)offsets
                 withRange: (NSRange)range
{
	std::vector<std::shared_ptr<Indium::Buffer>> tmp;
	std::vector<size_t> tmp2(offsets, offsets + range.length);
	for (size_t i = 0; i < range.length; ++i) {
		tmp.push_back(((MTLBufferInternal*)buffers[i]).buffer);
	}
	_encoder->setFragmentBuffers(tmp, tmp2, NSRangeToIndium(range));
}

- (void)setFragmentBufferOffset: (NSUInteger)offset
                        atIndex: (NSUInteger)index
{
	_encoder->setFragmentBufferOffset(offset, index);
}

- (void)setFragmentBytes: (const void*)bytes
                  length: (NSUInteger)length
                 atIndex: (NSUInteger)index
{
	_encoder->setFragmentBytes(bytes, length, index);
}

- (void)drawPrimitives: (MTLPrimitiveType)primitiveType
           vertexStart: (NSUInteger)vertexStart
           vertexCount: (NSUInteger)vertexCount
         instanceCount: (NSUInteger)instanceCount
          baseInstance: (NSUInteger)baseInstance
{
	_encoder->drawPrimitives(static_cast<Indium::PrimitiveType>(primitiveType), vertexStart, vertexCount, instanceCount, baseInstance);
}

- (void)drawPrimitives: (MTLPrimitiveType)primitiveType
           vertexStart: (NSUInteger)vertexStart
           vertexCount: (NSUInteger)vertexCount
         instanceCount: (NSUInteger)instanceCount
{
	_encoder->drawPrimitives(static_cast<Indium::PrimitiveType>(primitiveType), vertexStart, vertexCount, instanceCount);
}

- (void)drawPrimitives: (MTLPrimitiveType)primitiveType
           vertexStart: (NSUInteger)vertexStart
           vertexCount: (NSUInteger)vertexCount
{
	_encoder->drawPrimitives(static_cast<Indium::PrimitiveType>(primitiveType), vertexStart, vertexCount);
}

- (void)drawIndexedPrimitives: (MTLPrimitiveType)primitiveType
                   indexCount: (NSUInteger)indexCount
                    indexType: (MTLIndexType)indexType
                  indexBuffer: (id<MTLBuffer>)indexBuffer
            indexBufferOffset: (NSUInteger)indexBufferOffset
                instanceCount: (NSUInteger)instanceCount
                   baseVertex: (NSInteger)baseVertex
                 baseInstance: (NSUInteger)baseInstance
{
	_encoder->drawIndexedPrimitives(static_cast<Indium::PrimitiveType>(primitiveType), indexCount, static_cast<Indium::IndexType>(indexType), ((MTLBufferInternal*)indexBuffer).buffer, indexBufferOffset, instanceCount, baseVertex, baseInstance);
}

- (void)drawIndexedPrimitives: (MTLPrimitiveType)primitiveType
                   indexCount: (NSUInteger)indexCount
                    indexType: (MTLIndexType)indexType
                  indexBuffer: (id<MTLBuffer>)indexBuffer
            indexBufferOffset: (NSUInteger)indexBufferOffset
                instanceCount: (NSUInteger)instanceCount
{
	_encoder->drawIndexedPrimitives(static_cast<Indium::PrimitiveType>(primitiveType), indexCount, static_cast<Indium::IndexType>(indexType), ((MTLBufferInternal*)indexBuffer).buffer, indexBufferOffset, instanceCount);
}

- (void)drawIndexedPrimitives: (MTLPrimitiveType)primitiveType
                   indexCount: (NSUInteger)indexCount
                    indexType: (MTLIndexType)indexType
                  indexBuffer: (id<MTLBuffer>)indexBuffer
            indexBufferOffset: (NSUInteger)indexBufferOffset
{
	_encoder->drawIndexedPrimitives(static_cast<Indium::PrimitiveType>(primitiveType), indexCount, static_cast<Indium::IndexType>(indexType), ((MTLBufferInternal*)indexBuffer).buffer, indexBufferOffset);
}

#else

@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
