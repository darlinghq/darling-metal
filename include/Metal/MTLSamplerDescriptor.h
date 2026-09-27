// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLSAMPLERDESCRIPTOR_H_
#define _METAL_MTLSAMPLERDESCRIPTOR_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
// for MTLCompareFunction
#import <Metal/MTLDepthStencilDescriptor.h>

METAL_DECLARATIONS_BEGIN

typedef NS_ENUM(NSUInteger, MTLSamplerMinMagFilter) {
	MTLSamplerMinMagFilterNearest = 0,
	MTLSamplerMinMagFilterLinear = 1,
};

typedef NS_ENUM(NSUInteger, MTLSamplerMipFilter) {
	MTLSamplerMipFilterNotMipmapped = 0,
	MTLSamplerMipFilterNearest = 1,
	MTLSamplerMipFilterLinear = 2,
};

typedef NS_ENUM(NSUInteger, MTLSamplerAddressMode) {
	MTLSamplerAddressModeClampToEdge = 0,
	MTLSamplerAddressModeMirrorClampToEdge = 1,
	MTLSamplerAddressModeRepeat = 2,
	MTLSamplerAddressModeMirrorRepeat = 3,
	MTLSamplerAddressModeClampToZero = 4,
	MTLSamplerAddressModeClampToBorderColor = 5,
};

typedef NS_ENUM(NSUInteger, MTLSamplerBorderColor) {
	MTLSamplerBorderColorTransparentBlack = 0,
	MTLSamplerBorderColorOpaqueBlack = 1,
	MTLSamplerBorderColorOpaqueWhite = 2,
};

MTL_EXPORT
@interface MTLSamplerDescriptor : NSObject

@property(nonatomic) MTLSamplerMinMagFilter minFilter;
@property(nonatomic) MTLSamplerMinMagFilter magFilter;
@property(nonatomic) MTLSamplerMipFilter mipFilter;
@property(nonatomic) MTLSamplerAddressMode sAddressMode;
@property(nonatomic) MTLSamplerAddressMode tAddressMode;
@property(nonatomic) MTLSamplerAddressMode rAddressMode;
@property(nonatomic) NSUInteger maxAnisotropy;
@property(nonatomic) BOOL normalizedCoordinates;
@property(nonatomic) float lodMinClamp;
@property(nonatomic) float lodMaxClamp;
@property(nonatomic) BOOL supportArgumentBuffers;
@property(nonatomic) MTLSamplerBorderColor borderColor;
@property(nonatomic) MTLCompareFunction compareFunction;
@property(nullable, copy, nonatomic) NSString* label;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLSAMPLERDESCRIPTOR_H_
