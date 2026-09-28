// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBLITCOMMANDENCODER_H_
#define _METAL_MTLBLITCOMMANDENCODER_H_

#import <Foundation/Foundation.h>
#import <Metal/MTLDefines.h>
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLResource.h>
#import <Metal/MTLTypes.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLBuffer;
@protocol MTLTexture;

typedef NS_OPTIONS(NSUInteger, MTLBlitOption) {
	MTLBlitOptionNone = 0,
	MTLBlitOptionDepthFromDepthStencil = 1 << 0,
	MTLBlitOptionStencilFromDepthStencil = 1 << 1,
	MTLBlitOptionRowLinearPVRTC = 1 << 2,
};

@protocol MTLBlitCommandEncoder <MTLCommandEncoder>

- (void)copyFromBuffer: (id<MTLBuffer>)sourceBuffer
          sourceOffset: (NSUInteger)sourceOffset
              toBuffer: (id<MTLBuffer>)destinationBuffer
     destinationOffset: (NSUInteger)destinationOffset
                 size: (NSUInteger)size;

- (void)copyFromBuffer: (id<MTLBuffer>)sourceBuffer
          sourceOffset: (NSUInteger)sourceOffset
     sourceBytesPerRow: (NSUInteger)sourceBytesPerRow
   sourceBytesPerImage: (NSUInteger)sourceBytesPerImage
           sourceSize: (MTLSize)sourceSize
             toTexture: (id<MTLTexture>)destinationTexture
    destinationSlice: (NSUInteger)destinationSlice
  destinationLevel: (NSUInteger)destinationLevel
 destinationOrigin: (MTLOrigin)destinationOrigin;

- (void)copyFromBuffer: (id<MTLBuffer>)sourceBuffer
          sourceOffset: (NSUInteger)sourceOffset
     sourceBytesPerRow: (NSUInteger)sourceBytesPerRow
   sourceBytesPerImage: (NSUInteger)sourceBytesPerImage
           sourceSize: (MTLSize)sourceSize
             toTexture: (id<MTLTexture>)destinationTexture
    destinationSlice: (NSUInteger)destinationSlice
  destinationLevel: (NSUInteger)destinationLevel
 destinationOrigin: (MTLOrigin)destinationOrigin
               options: (MTLBlitOption)options;

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
             sourceSlice: (NSUInteger)sourceSlice
             sourceLevel: (NSUInteger)sourceLevel
            sourceOrigin: (MTLOrigin)sourceOrigin
              sourceSize: (MTLSize)sourceSize
                toBuffer: (id<MTLBuffer>)destinationBuffer
       destinationOffset: (NSUInteger)destinationOffset
  destinationBytesPerRow: (NSUInteger)destinationBytesPerRow
destinationBytesPerImage: (NSUInteger)destinationBytesPerImage;

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
             sourceSlice: (NSUInteger)sourceSlice
             sourceLevel: (NSUInteger)sourceLevel
            sourceOrigin: (MTLOrigin)sourceOrigin
              sourceSize: (MTLSize)sourceSize
          sourceOptions: (MTLBlitOption)sourceOptions
                toBuffer: (id<MTLBuffer>)destinationBuffer
       destinationOffset: (NSUInteger)destinationOffset
  destinationBytesPerRow: (NSUInteger)destinationBytesPerRow
destinationBytesPerImage: (NSUInteger)destinationBytesPerImage
               options: (MTLBlitOption)options;

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
             sourceSlice: (NSUInteger)sourceSlice
             sourceLevel: (NSUInteger)sourceLevel
            sourceOrigin: (MTLOrigin)sourceOrigin
              sourceSize: (MTLSize)sourceSize
               toTexture: (id<MTLTexture>)destinationTexture
      destinationSlice: (NSUInteger)destinationSlice
    destinationLevel: (NSUInteger)destinationLevel
   destinationOrigin: (MTLOrigin)destinationOrigin;

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
              toTexture: (id<MTLTexture>)destinationTexture;

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
             sourceSlice: (NSUInteger)sourceSlice
             sourceLevel: (NSUInteger)sourceLevel
               toTexture: (id<MTLTexture>)destinationTexture
      destinationSlice: (NSUInteger)destinationSlice
    destinationLevel: (NSUInteger)destinationLevel
            sliceCount: (NSUInteger)sliceCount
            levelCount: (NSUInteger)levelCount;

- (void)fillBuffer: (id<MTLBuffer>)buffer
              range: (NSRange)range
             value: (uint8_t)value;

- (void)generateMipmapsForTexture: (id<MTLTexture>)texture;

// TODO: the synchronize methods; indium has no equivalent

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLBLITCOMMANDENCODER_H_
