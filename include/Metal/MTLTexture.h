// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLTEXTURE_H_
#define _METAL_MTLTEXTURE_H_

#import <Foundation/Foundation.h>
#import <IOSurface/IOSurfaceRef.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLResource.h>
#import <Metal/MTLTypes.h>
#import <Metal/MTLPixelFormat.h>

typedef NS_ENUM(NSUInteger, MTLTextureType) {
	MTLTextureType1D = 0,
	MTLTextureType1DArray = 1,
	MTLTextureType2D = 2,
	MTLTextureType2DArray = 3,
	MTLTextureType2DMultisample = 4,
	MTLTextureTypeCube = 5,
	MTLTextureTypeCubeArray = 6,
	MTLTextureType3D = 7,
	MTLTextureType2DMultisampleArray = 8,
	MTLTextureTypeTextureBuffer = 9,
};

typedef NS_ENUM(uint8, MTLTextureSwizzle) {
	MTLTextureSwizzleZero = 0,
	MTLTextureSwizzleOne = 1,
	MTLTextureSwizzleRed = 2,
	MTLTextureSwizzleGreen = 3,
	MTLTextureSwizzleBlue = 4,
	MTLTextureSwizzleAlpha = 5,
};

typedef NS_OPTIONS(NSUInteger, MTLTextureUsage) {
	MTLTextureUsageUnknown = 0,
	MTLTextureUsageShaderRead = 1 << 0,
	MTLTextureUsageShaderWrite = 1 << 1,
	MTLTextureUsageRenderTarget = 1 << 2,
	MTLTextureUsagePixelFormatView = 1 << 4,
};

typedef struct MTLTextureSwizzleChannels {
	MTLTextureSwizzle red;
	MTLTextureSwizzle green;
	MTLTextureSwizzle blue;
	MTLTextureSwizzle alpha;
} MTLTextureSwizzleChannels;

NS_INLINE
MTLTextureSwizzleChannels MTLTextureSwizzleChannelsMake(MTLTextureSwizzle red, MTLTextureSwizzle green, MTLTextureSwizzle blue, MTLTextureSwizzle alpha) {
	MTLTextureSwizzleChannels channels = { red, green, blue, alpha };
	return channels;
};

#define MTLTextureSwizzleChannelsDefault MTLTextureSwizzleChannelsMake(MTLTextureSwizzleRed, MTLTextureSwizzleGreen, MTLTextureSwizzleBlue, MTLTextureSwizzleAlpha)

@protocol MTLTexture <MTLResource>

@property(readonly) MTLTextureType textureType;
@property(readonly) MTLPixelFormat pixelFormat;
@property(readonly) NSUInteger width;
@property(readonly) NSUInteger height;
@property(readonly) NSUInteger depth;
@property(readonly) NSUInteger mipmapLevelCount;
@property(readonly) NSUInteger arrayLength;
@property(readonly) NSUInteger sampleCount;
@property(readonly, getter=isFramebufferOnly) BOOL framebufferOnly;
@property(readonly) MTLTextureUsage usage;
@property(readonly) BOOL allowGPUOptimizedContents;
@property(readonly, getter=isShareable) BOOL shareable;
@property(readonly, nonatomic) MTLTextureSwizzleChannels swizzle;
@property(readonly) IOSurfaceRef iosurface;
@property(readonly) NSUInteger iosurfacePlane;

- (id<MTLTexture>)newTextureViewWithPixelFormat: (MTLPixelFormat)pixelFormat;

- (id<MTLTexture>)newTextureViewWithPixelFormat: (MTLPixelFormat)pixelFormat
                                    textureType: (MTLTextureType)textureType
                                         levels: (NSRange)levelRange
                                         slices: (NSRange)sliceRange;

- (id<MTLTexture>)newTextureViewWithPixelFormat: (MTLPixelFormat)pixelFormat
                                    textureType: (MTLTextureType)textureType
                                         levels: (NSRange)levelRange
                                         slices: (NSRange)sliceRange
                                        swizzle: (MTLTextureSwizzleChannels)swizzle;

- (void)replaceRegion: (MTLRegion)region
          mipmapLevel: (NSUInteger)level
            withBytes: (const void*)pixelBytes
          bytesPerRow: (NSUInteger)bytesPerRow;

- (void)replaceRegion: (MTLRegion)region
          mipmapLevel: (NSUInteger)level
                slice: (NSUInteger)slice
            withBytes: (const void*)pixelBytes
          bytesPerRow: (NSUInteger)bytesPerRow
        bytesPerImage: (NSUInteger)bytesPerImage;

- (void)getBytes: (void*)pixelBytes
     bytesPerRow: (NSUInteger)bytesPerRow
      fromRegion: (MTLRegion)region
     mipmapLevel: (NSUInteger)level;

- (void)getBytes: (void*)pixelBytes
     bytesPerRow: (NSUInteger)bytesPerRow
   bytesPerImage: (NSUInteger)bytesPerImage
      fromRegion: (MTLRegion)region
     mipmapLevel: (NSUInteger)level
           slice: (NSUInteger)slice;

@end

#endif // _METAL_MTLTEXTURE_H_
