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

#ifndef _METAL_MTLTEXTUREINTERNAL_H_
#define _METAL_MTLTEXTUREINTERNAL_H_

#import <Metal/MTLTexture.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
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
@property(readonly) std::shared_ptr<Indium::Texture> texture;

- (instancetype)initWithTexture: (std::shared_ptr<Indium::Texture>)texture
                         device: (id<MTLDevice>)device
                resourceOptions: (MTLResourceOptions)options;
#endif

@end

#endif // _METAL_MTLTEXTUREINTERNAL_H_
