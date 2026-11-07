// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLVERTEXDESCRIPTORINTERNAL_H_
#define _METAL_MTLVERTEXDESCRIPTORINTERNAL_H_

#import <Metal/MTLVertexDescriptor.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>

@interface MTLVertexDescriptor (Internal)

- (Indium::VertexDescriptor)asIndiumDescriptor;

@end
#endif

#endif // _METAL_MTLVERTEXDESCRIPTORINTERNAL_H_
