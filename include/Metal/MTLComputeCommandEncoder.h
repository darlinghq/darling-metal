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

#import <Foundation/Foundation.h>

#import <Metal/MTLCommandBuffer.h>
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLComputePipeline.h>
#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLComputeCommandEncoder;
@protocol MTLCounterSampleBuffer;
@protocol MTLBuffer;

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

- (void)dispatchThreadgroups: (MTLSize)threadgroupsPerGrid
       threadsPerThreadgroup: (MTLSize)threadsPerThreadgroup;

- (void)dispatchThreads: (MTLSize)threadsPerGrid 
  threadsPerThreadgroup: (MTLSize)threadsPerThreadgroup;

@end

METAL_DECLARATIONS_END
