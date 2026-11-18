// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLRENDERCOMMANDENCODER_H_
#define _METAL_MTLRENDERCOMMANDENCODER_H_

#import <Metal/MTLDefines.h>
#import <Metal/MTLFence.h>
#import <Foundation/Foundation.h>
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLCounters.h>
#import <Metal/MTLRenderPipeline.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLBuffer;
@protocol MTLResource;
@protocol MTLHeap;
@protocol MTLDepthStencilState;
@protocol MTLRasterizationRateMap;
@protocol MTLSamplerState;
@protocol MTLTexture;
@protocol MTLRenderPipelineState;

// The arguments an indirect draw reads from its buffer.
typedef struct {
	uint32_t vertexCount;
	uint32_t instanceCount;
	uint32_t vertexStart;
	uint32_t baseInstance;
} MTLDrawPrimitivesIndirectArguments;

typedef struct {
	uint32_t indexCount;
	uint32_t instanceCount;
	uint32_t indexStart;
	int32_t baseVertex;
	uint32_t baseInstance;
} MTLDrawIndexedPrimitivesIndirectArguments;

@class MTLRenderPassColorAttachmentDescriptorArray;
@class MTLRenderPassDepthAttachmentDescriptor;
@class MTLRenderPassStencilAttachmentDescriptor;
@class MTLRenderPassSampleBufferAttachmentDescriptorArray;
@class MTLRenderPassColorAttachmentDescriptor;
@class MTLRenderPassAttachmentDescriptor;

struct MTLSamplePosition;
typedef struct MTLSamplePosition MTLSamplePosition;

typedef NS_OPTIONS(NSUInteger, MTLRenderStages) {
	MTLRenderStageVertex = 1 << 0,
	MTLRenderStageFragment = 1 << 1,
	MTLRenderStageTile = 1 << 2,
	MTLRenderStageObject = 1 << 3,
	MTLRenderStageMesh = 1 << 4,
};

typedef NS_ENUM(NSUInteger, MTLLoadAction) {
	MTLLoadActionDontCare = 0,
	MTLLoadActionLoad = 1,
	MTLLoadActionClear = 2,
};

typedef NS_ENUM(NSUInteger, MTLStoreAction) {
	MTLStoreActionDontCare = 0,
	MTLStoreActionStore = 1,
	MTLStoreActionMultisampleResolve = 2,
	MTLStoreActionStoreAndMultisampleResolve = 3,
	MTLStoreActionUnknown = 4,
	MTLStoreActionCustomSampleDepthStore = 5,
};

typedef NS_OPTIONS(NSUInteger, MTLStoreActionOptions) {
	MTLStoreActionOptionNone = 0,
	MTLStoreActionOptionCustomSamplePositions = 1,
};

typedef NS_ENUM(NSUInteger, MTLMultisampleDepthResolveFilter) {
	MTLMultisampleDepthResolveFilterSample0 = 0,
	MTLMultisampleDepthResolveFilterMin = 1,
	MTLMultisampleDepthResolveFilterMax = 2,
};

typedef NS_ENUM(NSUInteger, MTLMultisampleStencilResolveFilter) {
	MTLMultisampleStencilResolveFilterSample0 = 0,
	MTLMultisampleStencilResolveFilterDepthResolvedSample = 1,
};

typedef NS_ENUM(NSUInteger, MTLTriangleFillMode) {
	MTLTriangleFillModeFill = 0,
	MTLTriangleFillModeLines = 1,
};

typedef NS_OPTIONS(NSUInteger, MTLCullMode) {
	MTLCullModeNone = 0,
	MTLCullModeFront = 1,
	MTLCullModeBack = 2,
};

typedef NS_ENUM(NSUInteger, MTLDepthClipMode) {
	MTLDepthClipModeClip = 0,
	MTLDepthClipModeClamp = 1,
};

typedef NS_ENUM(NSUInteger, MTLVisibilityResultMode) {
	MTLVisibilityResultModeDisabled = 0,
	MTLVisibilityResultModeBoolean = 1,
	MTLVisibilityResultModeCounting = 2,
};

typedef NS_ENUM(NSUInteger, MTLPrimitiveType) {
	MTLPrimitiveTypePoint = 0,
	MTLPrimitiveTypeLine = 1,
	MTLPrimitiveTypeLineStrip = 2,
	MTLPrimitiveTypeTriangle = 3,
	MTLPrimitiveTypeTriangleStrip = 4,
};

typedef NS_ENUM(NSUInteger, MTLIndexType) {
	MTLIndexTypeUInt16 = 0,
	MTLIndexTypeUInt32 = 1,
};

typedef struct MTLClearColor {
	double red;
	double green;
	double blue;
	double alpha;
} MTLClearColor;

typedef struct MTLViewport {
	double originX;
	double originY;
	double width;
	double height;
	double znear;
	double zfar;
} MTLViewport;

typedef struct MTLScissorRect {
	NSUInteger x;
	NSUInteger y;
	NSUInteger width;
	NSUInteger height;
} MTLScissorRect;

NS_INLINE
MTLClearColor MTLClearColorMake(double red, double green, double blue, double alpha) {
	MTLClearColor color = { red, green, blue, alpha };
  return color;
};

MTL_EXPORT
@interface MTLRenderPassAttachmentDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, strong) id<MTLTexture> texture;
@property(nonatomic) NSUInteger level;
@property(nonatomic) NSUInteger slice;
@property(nonatomic) NSUInteger depthPlane;
@property(nonatomic) MTLLoadAction loadAction;
@property(nonatomic) MTLStoreAction storeAction;
@property(nonatomic) MTLStoreActionOptions storeActionOptions;
@property(nullable, nonatomic, strong) id<MTLTexture> resolveTexture;
@property(nonatomic) NSUInteger resolveLevel;
@property(nonatomic) NSUInteger resolveSlice;
@property(nonatomic) NSUInteger resolveDepthPlane;

@end

MTL_EXPORT
@interface MTLRenderPassColorAttachmentDescriptor : MTLRenderPassAttachmentDescriptor

@property(nonatomic) MTLClearColor clearColor;

@end

MTL_EXPORT
@interface MTLRenderPassDepthAttachmentDescriptor : MTLRenderPassAttachmentDescriptor

@property(nonatomic) double clearDepth;
@property(nonatomic) MTLMultisampleDepthResolveFilter depthResolveFilter;

@end

MTL_EXPORT
@interface MTLRenderPassStencilAttachmentDescriptor : MTLRenderPassAttachmentDescriptor

@property(nonatomic) MTLMultisampleStencilResolveFilter stencilResolveFilter;
@property(nonatomic) uint32_t clearStencil;

@end

MTL_EXPORT
@interface MTLRenderPassColorAttachmentDescriptorArray : NSObject

- (MTLRenderPassColorAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)attachmentIndex;

-    (void)setObject: (MTLRenderPassColorAttachmentDescriptor*)attachment
  atIndexedSubscript: (NSUInteger)attachmentIndex;

@end

MTL_EXPORT
@interface MTLRenderPassSampleBufferAttachmentDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, retain) id<MTLCounterSampleBuffer> sampleBuffer;
// MTLCounterDontSample (the default) takes no sample. Where the device cannot tell the stages apart at the edges
// of a pass, the start samples are taken when the pass begins and the end samples when it ends.
@property(nonatomic) NSUInteger startOfVertexSampleIndex;
@property(nonatomic) NSUInteger endOfVertexSampleIndex;
@property(nonatomic) NSUInteger startOfFragmentSampleIndex;
@property(nonatomic) NSUInteger endOfFragmentSampleIndex;

@end

MTL_EXPORT
@interface MTLRenderPassSampleBufferAttachmentDescriptorArray : NSObject

- (MTLRenderPassSampleBufferAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)attachmentIndex;

-    (void)setObject: (nullable MTLRenderPassSampleBufferAttachmentDescriptor*)attachment
  atIndexedSubscript: (NSUInteger)attachmentIndex;

@end

MTL_EXPORT
@interface MTLRenderPassDescriptor : NSObject <NSCopying>

@property(readonly) MTLRenderPassColorAttachmentDescriptorArray* colorAttachments;
@property(copy, nonatomic) MTLRenderPassDepthAttachmentDescriptor* depthAttachment;
@property(copy, nonatomic) MTLRenderPassStencilAttachmentDescriptor* stencilAttachment;
@property(nullable, nonatomic, strong) id<MTLBuffer> visibilityResultBuffer;
@property(nonatomic) NSUInteger renderTargetArrayLength;
@property(nonatomic) NSUInteger renderTargetWidth;
@property(nonatomic) NSUInteger renderTargetHeight;
@property(nonatomic) NSUInteger imageblockSampleLength;
@property(nonatomic) NSUInteger threadgroupMemoryLength;
@property(nonatomic) NSUInteger tileWidth;
@property(nonatomic) NSUInteger tileHeight;
@property(nonatomic) NSUInteger defaultRasterSampleCount;
@property(nullable, nonatomic, strong) id<MTLRasterizationRateMap> rasterizationRateMap;
@property(readonly) MTLRenderPassSampleBufferAttachmentDescriptorArray* sampleBufferAttachments;

+ (MTLRenderPassDescriptor*)renderPassDescriptor;

- (NSUInteger)getSamplePositions: (MTLSamplePosition*)positions
                           count: (NSUInteger)count;

- (void)setSamplePositions: (const MTLSamplePosition*)positions
                     count: (NSUInteger)count;

@end

@protocol MTLRenderCommandEncoder <MTLCommandEncoder>

// Samples the counters of `sampleBuffer` into `sampleIndex` at this point in the encoder. Taking a sample inside
// the pass is supported where -supportsCounterSampling: says so for the matching sampling point.
- (void)sampleCountersInBuffer: (id<MTLCounterSampleBuffer>)sampleBuffer
                 atSampleIndex: (NSUInteger)sampleIndex
                   withBarrier: (BOOL)barrier;

- (void)setRenderPipelineState: (id<MTLRenderPipelineState>)pipelineState;
- (void)setTriangleFillMode: (MTLTriangleFillMode)fillMode;
- (void)setFrontFacingWinding: (MTLWinding)frontFacingWinding;
- (void)setCullMode: (MTLCullMode)cullMode;
- (void)setDepthClipMode: (MTLDepthClipMode)depthClipMode;
- (void)setViewport: (MTLViewport)viewport;
- (void)setViewports: (const MTLViewport*)viewports
               count: (NSUInteger)count;
- (void)setScissorRect: (MTLScissorRect)rect;
- (void)setScissorRects: (const MTLScissorRect*)scissorRects
                  count: (NSUInteger)count;
- (void)setBlendColorRed: (float)red
                   green: (float)green
                    blue: (float)blue
                   alpha: (float)alpha;
- (void)setStencilReferenceValue: (uint32_t)refValue;
- (void)setDepthBias: (float)depthBias
          slopeScale: (float)slopeScale
               clamp: (float)clamp;
- (void)setDepthStencilState: (id<MTLDepthStencilState>)state;
- (void)memoryBarrierWithScope: (MTLBarrierScope)scope
                   afterStages: (MTLRenderStages)after
                  beforeStages: (MTLRenderStages)before;

/* Updates `fence` once the work of the `stages` of the commands encoded so far has finished. */
- (void)updateFence: (id<MTLFence>)fence
        afterStages: (MTLRenderStages)stages;

/* Holds the `stages` of the commands encoded after this call back until the work the fence was updated after in earlier encoders has finished. */
- (void)waitForFence: (id<MTLFence>)fence
        beforeStages: (MTLRenderStages)stages;
- (void)setVisibilityResultMode: (MTLVisibilityResultMode)mode
                          offset: (NSUInteger)offset;

- (void)setVertexBuffer: (id<MTLBuffer>)buffer
                 offset: (NSUInteger)offset
                atIndex: (NSUInteger)index;
- (void)setVertexBuffers: (const id<MTLBuffer>*)buffers
                 offsets: (const NSUInteger*)offsets
               withRange: (NSRange)range;

- (void)setVertexBufferOffset: (NSUInteger)offset
                      atIndex: (NSUInteger)index;

- (void)setVertexBytes: (const void*)bytes
                length: (NSUInteger)length
               atIndex: (NSUInteger)index;

- (void)setVertexTexture: (id<MTLTexture>)texture
                atIndex: (NSUInteger)index;
- (void)setVertexTextures: (const id<MTLTexture>*)textures
                withRange: (NSRange)range;

- (void)setVertexSamplerState: (id<MTLSamplerState>)sampler
                      atIndex: (NSUInteger)index;
- (void)setVertexSamplerStates: (const id<MTLSamplerState>*)samplers
                      withRange: (NSRange)range;
- (void)setVertexSamplerState: (id<MTLSamplerState>)sampler
                   lodMinClamp: (float)lodMinClamp
                   lodMaxClamp: (float)lodMaxClamp
                      atIndex: (NSUInteger)index;
- (void)setVertexSamplerStates: (const id<MTLSamplerState>*)samplers
                   lodMinClamps: (const float*)lodMinClamps
                   lodMaxClamps: (const float*)lodMaxClamps
                      withRange: (NSRange)range;

- (void)setFragmentBuffer: (id<MTLBuffer>)buffer
                   offset: (NSUInteger)offset
                  atIndex: (NSUInteger)index;
- (void)setFragmentBuffers: (const id<MTLBuffer>*)buffers
                   offsets: (const NSUInteger*)offsets
                 withRange: (NSRange)range;

- (void)setFragmentBufferOffset: (NSUInteger)offset
                        atIndex: (NSUInteger)index;

- (void)setFragmentBytes: (const void*)bytes
                  length: (NSUInteger)length
                 atIndex: (NSUInteger)index;

- (void)setFragmentTexture: (id<MTLTexture>)texture
                  atIndex: (NSUInteger)index;
- (void)setFragmentTextures: (const id<MTLTexture>*)textures
                  withRange: (NSRange)range;

- (void)setFragmentSamplerState: (id<MTLSamplerState>)sampler
                        atIndex: (NSUInteger)index;
- (void)setFragmentSamplerStates: (const id<MTLSamplerState>*)samplers
                        withRange: (NSRange)range;
- (void)setFragmentSamplerState: (id<MTLSamplerState>)sampler
                     lodMinClamp: (float)lodMinClamp
                     lodMaxClamp: (float)lodMaxClamp
                        atIndex: (NSUInteger)index;
- (void)setFragmentSamplerStates: (const id<MTLSamplerState>*)samplers
                     lodMinClamps: (const float*)lodMinClamps
                     lodMaxClamps: (const float*)lodMaxClamps
                        withRange: (NSRange)range;

- (void)drawPrimitives: (MTLPrimitiveType)primitiveType
           vertexStart: (NSUInteger)vertexStart
           vertexCount: (NSUInteger)vertexCount
         instanceCount: (NSUInteger)instanceCount
          baseInstance: (NSUInteger)baseInstance;

- (void)drawPrimitives: (MTLPrimitiveType)primitiveType
           vertexStart: (NSUInteger)vertexStart
           vertexCount: (NSUInteger)vertexCount
         instanceCount: (NSUInteger)instanceCount;

- (void)drawPrimitives: (MTLPrimitiveType)primitiveType
           vertexStart: (NSUInteger)vertexStart
           vertexCount: (NSUInteger)vertexCount;

- (void)drawIndexedPrimitives: (MTLPrimitiveType)primitiveType
                   indexCount: (NSUInteger)indexCount
                    indexType: (MTLIndexType)indexType
                  indexBuffer: (id<MTLBuffer>)indexBuffer
            indexBufferOffset: (NSUInteger)indexBufferOffset
                instanceCount: (NSUInteger)instanceCount
                   baseVertex: (NSInteger)baseVertex
                 baseInstance: (NSUInteger)baseInstance;

- (void)drawIndexedPrimitives: (MTLPrimitiveType)primitiveType
                   indexCount: (NSUInteger)indexCount
                    indexType: (MTLIndexType)indexType
                  indexBuffer: (id<MTLBuffer>)indexBuffer
            indexBufferOffset: (NSUInteger)indexBufferOffset
                instanceCount: (NSUInteger)instanceCount;

- (void)drawIndexedPrimitives: (MTLPrimitiveType)primitiveType
                   indexCount: (NSUInteger)indexCount
                    indexType: (MTLIndexType)indexType
                  indexBuffer: (id<MTLBuffer>)indexBuffer
            indexBufferOffset: (NSUInteger)indexBufferOffset;

- (void)drawPrimitives: (MTLPrimitiveType)primitiveType
         indirectBuffer: (id<MTLBuffer>)indirectBuffer
   indirectBufferOffset: (NSUInteger)indirectBufferOffset;

- (void)drawIndexedPrimitives: (MTLPrimitiveType)primitiveType
                    indexType: (MTLIndexType)indexType
                  indexBuffer: (id<MTLBuffer>)indexBuffer
            indexBufferOffset: (NSUInteger)indexBufferOffset
               indirectBuffer: (id<MTLBuffer>)indirectBuffer
         indirectBufferOffset: (NSUInteger)indirectBufferOffset;

// The resources the draws that follow use through an argument buffer or a heap. Every resource is resident
// here; the declaration tells the encoder what to order the work by.
- (void)useResource: (id<MTLResource>)resource
              usage: (MTLResourceUsage)usage;
- (void)useResources: (const id<MTLResource> __nonnull [__nonnull])resources
               count: (NSUInteger)count
               usage: (MTLResourceUsage)usage;
- (void)useResource: (id<MTLResource>)resource
              usage: (MTLResourceUsage)usage
             stages: (MTLRenderStages)stages;
- (void)useResources: (const id<MTLResource> __nonnull [__nonnull])resources
               count: (NSUInteger)count
               usage: (MTLResourceUsage)usage
              stages: (MTLRenderStages)stages;
- (void)useHeap: (id<MTLHeap>)heap;
- (void)useHeaps: (const id<MTLHeap> __nonnull [__nonnull])heaps
           count: (NSUInteger)count;
- (void)useHeap: (id<MTLHeap>)heap
         stages: (MTLRenderStages)stages;
- (void)useHeaps: (const id<MTLHeap> __nonnull [__nonnull])heaps
           count: (NSUInteger)count
          stages: (MTLRenderStages)stages;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRENDERCOMMANDENCODER_H_
