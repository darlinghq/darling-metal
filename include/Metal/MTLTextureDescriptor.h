// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLTEXTUREDESCRIPTOR_H_
#define _METAL_MTLTEXTUREDESCRIPTOR_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLPixelFormat.h>
#import <Metal/MTLResource.h>
#import <Metal/MTLTexture.h>

METAL_DECLARATIONS_BEGIN

MTL_EXPORT
@interface MTLTextureDescriptor : NSObject <NSCopying>

+ (MTLTextureDescriptor*)texture2DDescriptorWithPixelFormat: (MTLPixelFormat)pixelFormat
                                                      width: (NSUInteger)width
                                                     height: (NSUInteger)height
                                                  mipmapped: (BOOL)mipmapped;

+ (MTLTextureDescriptor*)textureCubeDescriptorWithPixelFormat: (MTLPixelFormat)pixelFormat
                                                         size: (NSUInteger)size
                                                    mipmapped: (BOOL)mipmapped;

@property(nonatomic) MTLTextureType textureType;
@property(nonatomic) MTLPixelFormat pixelFormat;
@property(nonatomic) NSUInteger width;
@property(nonatomic) NSUInteger height;
@property(nonatomic) NSUInteger depth;
@property(nonatomic) NSUInteger mipmapLevelCount;
@property(nonatomic) NSUInteger sampleCount;
@property(nonatomic) NSUInteger arrayLength;
@property(nonatomic) MTLResourceOptions resourceOptions;
@property(nonatomic) MTLCPUCacheMode cpuCacheMode;
@property(nonatomic) MTLStorageMode storageMode;
@property(nonatomic) MTLHazardTrackingMode hazardTrackingMode;
@property(nonatomic) BOOL allowGPUOptimizedContents;
@property(nonatomic) MTLTextureUsage usage;
@property(nonatomic) MTLTextureSwizzleChannels swizzle;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLTEXTUREDESCRIPTOR_H_
