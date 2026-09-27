// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Foundation/Foundation.h>

#import <Metal/MTLCommandBuffer.h>
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLComputePipeline.h>
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLComputeCommandEncoder;
@protocol MTLCounterSampleBuffer;
@protocol MTLBuffer;
@protocol MTLSamplerState;
@protocol MTLTexture;

@class MTLComputePassDescriptor;
@class MTLComputePassSampleBufferAttachmentDescriptorArray;
@class MTLComputePassSampleBufferAttachmentDescriptor;

// TODO: check what the actual value is
#define MTLCounterDontSample 0

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

@end

METAL_DECLARATIONS_END
