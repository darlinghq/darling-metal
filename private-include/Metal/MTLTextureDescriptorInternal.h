// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLTEXTUREDESCRIPTORINTERNAL_H_
#define _METAL_MTLTEXTUREDESCRIPTORINTERNAL_H_

#import <Metal/MTLTextureDescriptor.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

METAL_DECLARATIONS_BEGIN

#if DARLING_METAL_ENABLED
@interface MTLTextureDescriptor (Internal)

- (Indium::TextureDescriptor)asIndiumDescriptor;

@end
#endif

METAL_DECLARATIONS_END

#endif // _METAL_MTLTEXTUREDESCRIPTORINTERNAL_H_
