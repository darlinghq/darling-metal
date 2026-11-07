// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLTEXTUREINTERNAL_H_
#define _METAL_MTLTEXTUREINTERNAL_H_

#import <Metal/MTLTexture.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#include <Metal/MTLIOSurfaceCopy.h>
#endif

#if DARLING_METAL_ENABLED
NS_INLINE
Indium::TextureSwizzleChannels MTLTextureSwizzleChannelsToIndium(MTLTextureSwizzleChannels channels) {
	return Indium::TextureSwizzleChannels {
		static_cast<Indium::TextureSwizzle>(channels.red),
		static_cast<Indium::TextureSwizzle>(channels.green),
		static_cast<Indium::TextureSwizzle>(channels.blue),
		static_cast<Indium::TextureSwizzle>(channels.alpha),
	};
};

NS_INLINE
MTLTextureSwizzleChannels MTLTextureSwizzleChannelsFromIndium(Indium::TextureSwizzleChannels channels) {
	return MTLTextureSwizzleChannels {
		static_cast<MTLTextureSwizzle>(channels.red),
		static_cast<MTLTextureSwizzle>(channels.green),
		static_cast<MTLTextureSwizzle>(channels.blue),
		static_cast<MTLTextureSwizzle>(channels.alpha),
	};
};
#endif

// private export
MTL_EXPORT
@interface MTLTextureInternal : NSObject <MTLTexture>

#if DARLING_METAL_ENABLED
@property(nonatomic, readonly) std::shared_ptr<Indium::Texture> texture;

- (instancetype)initWithTexture: (std::shared_ptr<Indium::Texture>)texture
                         device: (id<MTLDevice>)device
                resourceOptions: (MTLResourceOptions)options;

// A texture of the given plane of iosurface, which it retains. Its storage is the plane's
// memory, or, with `copy`, a copy that `copy` keeps in step with the plane; the texture owns
// `copy` and destroys it.
- (instancetype)initWithTexture: (std::shared_ptr<Indium::Texture>)texture
                         device: (id<MTLDevice>)device
                resourceOptions: (MTLResourceOptions)options
                      iosurface: (IOSurfaceRef)iosurface
                          plane: (NSUInteger)plane
                           copy: (struct MTLIOSurfaceCopy*)copy;
#endif

@end

#if DARLING_METAL_ENABLED
// The Indium object behind `object`, read without a message send or a copy of
// the shared pointer, for the command encoders. Empty for nil and for objects
// this framework did not create.
const std::shared_ptr<Indium::Texture>& MTLTextureGetIndium(id<MTLTexture> object);
#endif

#endif // _METAL_MTLTEXTUREINTERNAL_H_
