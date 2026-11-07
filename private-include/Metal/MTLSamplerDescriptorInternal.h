// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLSAMPLERDESCRIPTORINTERNAL_H_
#define _METAL_MTLSAMPLERDESCRIPTORINTERNAL_H_

#import <Metal/MTLSamplerDescriptor.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

METAL_DECLARATIONS_BEGIN

#if DARLING_METAL_ENABLED
@interface MTLSamplerDescriptor (Internal)

- (Indium::SamplerDescriptor)asIndiumDescriptor;

@end
#endif

METAL_DECLARATIONS_END

#endif // _METAL_MTLSAMPLERDESCRIPTORINTERNAL_H_
