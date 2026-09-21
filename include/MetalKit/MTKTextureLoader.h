// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METALKIT_MTKTEXTURELOADER_H_
#define _METALKIT_MTKTEXTURELOADER_H_

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>

@class MDLTexture;

typedef NSString* MTKTextureLoaderError;
typedef NSString* MTKTextureLoaderOption;
typedef NSString* MTKTextureLoaderOrigin;

MTL_EXPORT MTL_EXTERN const MTKTextureLoaderError MTKTextureLoaderErrorDomain;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderError MTKTextureLoaderErrorKey;

MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOption MTKTextureLoaderOptionAllocateMipmaps;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOption MTKTextureLoaderOptionGenerateMipmaps;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOption MTKTextureLoaderOptionSRGB;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOption MTKTextureLoaderOptionTextureUsage;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOption MTKTextureLoaderOptionTextureCPUCacheMode;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOption MTKTextureLoaderOptionTextureStorageMode;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOption MTKTextureLoaderOptionCubeLayout;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOption MTKTextureLoaderOptionOrigin;

MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOrigin MTKTextureLoaderOriginTopLeft;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOrigin MTKTextureLoaderOriginBottomLeft;
MTL_EXPORT MTL_EXTERN const MTKTextureLoaderOrigin MTKTextureLoaderOriginFlippedVertically;

MTL_EXPORT
@interface MTKTextureLoader : NSObject

@property(nonatomic, readonly) id<MTLDevice> device;

- (instancetype)initWithDevice: (id<MTLDevice>)device;

- (id<MTLTexture>)newTextureWithContentsOfURL: (NSURL*)URL
                                      options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                                        error: (NSError**)error;

- (id<MTLTexture>)newTextureWithData: (NSData*)data
                             options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                               error: (NSError**)error;

- (id<MTLTexture>)newTextureWithCGImage: (CGImageRef)cgImage
                                options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                                  error: (NSError**)error;

- (id<MTLTexture>)newTextureWithMDLTexture: (MDLTexture*)texture
                                   options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                                     error: (NSError**)error;

- (id<MTLTexture>)newTextureWithName: (NSString*)name
                         scaleFactor: (CGFloat)scaleFactor
                              bundle: (NSBundle*)bundle
                             options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                               error: (NSError**)error;

@end

#endif // _METALKIT_MTKTEXTURELOADER_H_
