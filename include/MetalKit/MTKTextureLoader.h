// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METALKIT_MTKTEXTURELOADER_H_
#define _METALKIT_MTKTEXTURELOADER_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
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

typedef void (^MTKTextureLoaderCallback)(id<MTLTexture> texture, NSError* error);
typedef void (^MTKTextureLoaderArrayCallback)(NSArray<id<MTLTexture>>* textures, NSError* error);

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

- (void)newTextureWithContentsOfURL: (NSURL*)URL
                           options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                 completionHandler: (MTKTextureLoaderCallback)completionHandler;

- (void)newTextureWithData: (NSData*)data
                   options: (NSDictionary<MTKTextureLoaderOption, id>*)options
         completionHandler: (MTKTextureLoaderCallback)completionHandler;

- (void)newTextureWithCGImage: (CGImageRef)cgImage
                      options: (NSDictionary<MTKTextureLoaderOption, id>*)options
            completionHandler: (MTKTextureLoaderCallback)completionHandler;

- (void)newTextureWithMDLTexture: (MDLTexture*)texture
                         options: (NSDictionary<MTKTextureLoaderOption, id>*)options
               completionHandler: (MTKTextureLoaderCallback)completionHandler;

- (void)newTextureWithName: (NSString*)name
               scaleFactor: (CGFloat)scaleFactor
                    bundle: (NSBundle*)bundle
                   options: (NSDictionary<MTKTextureLoaderOption, id>*)options
         completionHandler: (MTKTextureLoaderCallback)completionHandler;

- (id<MTLTexture>)newTextureWithName: (NSString*)name
                         scaleFactor: (CGFloat)scaleFactor
                        displayGamut: (NSDisplayGamut)displayGamut
                              bundle: (NSBundle*)bundle
                             options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                               error: (NSError**)error;

- (void)newTextureWithName: (NSString*)name
               scaleFactor: (CGFloat)scaleFactor
              displayGamut: (NSDisplayGamut)displayGamut
                    bundle: (NSBundle*)bundle
                   options: (NSDictionary<MTKTextureLoaderOption, id>*)options
         completionHandler: (MTKTextureLoaderCallback)completionHandler;

- (void)newTexturesWithNames: (NSArray<NSString*>*)names
                 scaleFactor: (CGFloat)scaleFactor
                displayGamut: (NSDisplayGamut)displayGamut
                      bundle: (NSBundle*)bundle
                     options: (NSDictionary<MTKTextureLoaderOption, id>*)options
           completionHandler: (MTKTextureLoaderArrayCallback)completionHandler;

- (NSArray<id<MTLTexture>>*)newTexturesWithContentsOfURLs: (NSArray<NSURL*>*)URLs
                                                  options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                                                    error: (NSError**)error;

- (void)newTexturesWithContentsOfURLs: (NSArray<NSURL*>*)URLs
                              options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                    completionHandler: (MTKTextureLoaderArrayCallback)completionHandler;

- (void)newTexturesWithNames: (NSArray<NSString*>*)names
                 scaleFactor: (CGFloat)scaleFactor
                      bundle: (NSBundle*)bundle
                     options: (NSDictionary<MTKTextureLoaderOption, id>*)options
           completionHandler: (MTKTextureLoaderArrayCallback)completionHandler;

@end

#endif // _METALKIT_MTKTEXTURELOADER_H_
