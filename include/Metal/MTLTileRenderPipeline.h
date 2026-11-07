// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLTILERENDERPIPELINE_H_
#define _METAL_MTLTILERENDERPIPELINE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLBuffer.h>
#import <Metal/MTLDefines.h>
#import <Metal/MTLLibrary.h>
#import <Metal/MTLPixelFormat.h>
#import <Metal/MTLRenderCommandEncoder.h>
#import <Metal/MTLTypes.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLTileRenderPipelineColorAttachmentDescriptorArray;

/**
 * One colour attachment of a tile render pipeline.
 *
 * Pixel format and store action, stored and returned unchanged.
 */
MTL_EXPORT
@interface MTLTileRenderPipelineColorAttachmentDescriptor : NSObject <NSCopying>

@property(nonatomic) MTLPixelFormat pixelFormat;
@property(nonatomic) MTLStoreAction storeAction;
@property(nonatomic) MTLStoreActionOptions storeActionOptions;

@end

MTL_EXPORT
@protocol MTLTileRenderPipelineColorAttachmentDescriptorArray <NSObject>

- (MTLTileRenderPipelineColorAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)index;
- (void)setObject: (MTLTileRenderPipelineColorAttachmentDescriptor*)object
    atIndexedSubscript: (NSUInteger)index;
- (NSUInteger)count;

@end

/**
 * Describes a tile render pipeline to build.
 *
 * Every property is stored and returned unchanged, and the colour attachment
 * array is a real mutable array, so a caller that assembles this and reads it
 * back gets exactly what it put in.
 *
 * Building it is not provided: indium has no tile or mesh shading pipeline, no
 * MTL4 and no way to express one, so
 * -[MTLDevice newTileRenderPipelineStateWithDescriptor:error:] is not declared.
 */
MTL_EXPORT
@interface MTLTileRenderPipelineDescriptor : NSObject <NSCopying>

- (void)reset;

@property(nullable, nonatomic, copy) NSString* label;
@property(nullable, nonatomic, retain) id<MTLFunction> tileFunction;
@property(nullable, nonatomic, retain) NSArray<id<MTLBuffer>>* tileBuffers;
@property(nonatomic) BOOL threadgroupSizeMatchesTileSize;
@property(nonatomic) NSUInteger rasterSampleCount;
@property(nonatomic) NSUInteger maxTotalThreadsPerThreadgroup;
@property(nonatomic) MTLSize requiredThreadsPerThreadgroup;
// Read-only, and that is Apple's shape: the array comes into existence with
// the descriptor and the caller mutates its elements, it does not supply one.
// A default of one attachment is Apple's default, and a caller that reads
// element 0 has to find an object there rather than an out-of-bounds crash.
@property(nonnull, readonly) id<MTLTileRenderPipelineColorAttachmentDescriptorArray> colorAttachments;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLTILERENDERPIPELINE_H_
