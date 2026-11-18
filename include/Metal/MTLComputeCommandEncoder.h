// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Foundation/Foundation.h>

#import <Metal/MTLCommandBuffer.h>
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLComputePipeline.h>
#import <Metal/MTLCounters.h>
#import <Metal/MTLDefines.h>
#import <Metal/MTLFence.h>
#import <Metal/MTLTypes.h>

METAL_DECLARATIONS_BEGIN

// The arguments an indirect dispatch reads from its buffer: the grid size in threadgroups.
typedef struct {
	uint32_t threadgroupsPerGrid[3];
} MTLDispatchThreadgroupsIndirectArguments;

@protocol MTLComputeCommandEncoder;
@protocol MTLCounterSampleBuffer;
@protocol MTLBuffer;
@protocol MTLSamplerState;
@protocol MTLTexture;
@protocol MTLResource;
@protocol MTLHeap;

@class MTLComputePassDescriptor;
@class MTLComputePassSampleBufferAttachmentDescriptorArray;
@class MTLComputePassSampleBufferAttachmentDescriptor;

MTL_EXPORT
@interface MTLComputePassSampleBufferAttachmentDescriptor : NSObject <NSCopying>

@property(readwrite, nullable, nonatomic, retain) id<MTLCounterSampleBuffer> sampleBuffer;
@property(readwrite, nonatomic, assign) NSUInteger startOfEncoderSampleIndex;
@property(nonatomic) NSUInteger endOfEncoderSampleIndex;

@end

MTL_EXPORT
@interface MTLComputePassSampleBufferAttachmentDescriptorArray : NSObject

- (MTLComputePassSampleBufferAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)index;
-    (void)setObject: (MTLComputePassSampleBufferAttachmentDescriptor*)attachment
  atIndexedSubscript: (NSUInteger)index;

@end

MTL_EXPORT
@interface MTLComputePassDescriptor : NSObject <NSCopying>

+ (MTLComputePassDescriptor*)computePassDescriptor;

@property(readwrite, nonatomic, assign) MTLDispatchType dispatchType;
@property(readonly) MTLComputePassSampleBufferAttachmentDescriptorArray* sampleBufferAttachments;

@end

@protocol MTLComputeCommandEncoder <MTLCommandEncoder>

/* See MTLBlitCommandEncoder. */
- (void)updateFence: (id<MTLFence>)fence;
- (void)waitForFence: (id<MTLFence>)fence;

@property(readonly) MTLDispatchType dispatchType;

- (void)setComputePipelineState:(id<MTLComputePipelineState>)state;

- (void)setStageInRegion:(MTLRegion)region;

- (void)setBuffer: (id<MTLBuffer>)buffer
           offset: (NSUInteger)offset
          atIndex: (NSUInteger)index;

- (void)setBuffers: (const id<MTLBuffer>*)buffers
           offsets: (const NSUInteger *)offsets
         withRange: (NSRange)range;

- (void)setBufferOffset: (NSUInteger)offset
                atIndex: (NSUInteger)index;

- (void)setBytes: (const void*)bytes
          length: (NSUInteger)length
         atIndex: (NSUInteger)index;

- (void)setTexture: (id<MTLTexture>)texture
          atIndex: (NSUInteger)index;

- (void)setTextures: (const id<MTLTexture>*)textures
          withRange: (NSRange)range;

- (void)setSamplerState: (id<MTLSamplerState>)sampler
                atIndex: (NSUInteger)index;

- (void)setSamplerStates: (const id<MTLSamplerState>*)samplers
                withRange: (NSRange)range;

- (void)setSamplerState: (id<MTLSamplerState>)sampler
             lodMinClamp: (float)lodMinClamp
             lodMaxClamp: (float)lodMaxClamp
                atIndex: (NSUInteger)index;

- (void)setSamplerStates: (const id<MTLSamplerState>*)samplers
             lodMinClamps: (const float*)lodMinClamps
             lodMaxClamps: (const float*)lodMaxClamps
                withRange: (NSRange)range;

- (void)setThreadgroupMemoryLength: (NSUInteger)length
                          atIndex: (NSUInteger)index;

- (void)dispatchThreadgroups: (MTLSize)threadgroupsPerGrid
       threadsPerThreadgroup: (MTLSize)threadsPerThreadgroup;

- (void)dispatchThreads: (MTLSize)threadsPerGrid 
  threadsPerThreadgroup: (MTLSize)threadsPerThreadgroup;

- (void)dispatchThreadgroupsWithIndirectBuffer: (id<MTLBuffer>)indirectBuffer
                          indirectBufferOffset: (NSUInteger)indirectBufferOffset
                         threadsPerThreadgroup: (MTLSize)threadsPerThreadgroup;

// The resources the commands that follow use through an argument buffer or a heap. Every resource is resident
// here; the declaration tells the encoder what to order the commands by.
- (void)useResource: (id<MTLResource>)resource
              usage: (MTLResourceUsage)usage;
- (void)useResources: (const id<MTLResource> __nonnull [__nonnull])resources
               count: (NSUInteger)count
               usage: (MTLResourceUsage)usage;
- (void)useHeap: (id<MTLHeap>)heap;
- (void)useHeaps: (const id<MTLHeap> __nonnull [__nonnull])heaps
           count: (NSUInteger)count;

/* Orders what the dispatches encoded so far wrote before what the ones encoded next read or write: for the
 * concurrent dispatch type, and for resources that are not tracked. */
- (void)memoryBarrierWithScope: (MTLBarrierScope)scope;
- (void)memoryBarrierWithResources: (const id<MTLResource> __nonnull [__nonnull])resources
                             count: (NSUInteger)count;

// Samples the counters of `sampleBuffer` into `sampleIndex` at this point in the encoder. Taking a sample inside
// the pass is supported where -supportsCounterSampling: says so for the matching sampling point.
- (void)sampleCountersInBuffer: (id<MTLCounterSampleBuffer>)sampleBuffer
                 atSampleIndex: (NSUInteger)sampleIndex
                   withBarrier: (BOOL)barrier;

@end

METAL_DECLARATIONS_END
