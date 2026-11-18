// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBLITPASSINTERNAL_H_
#define _METAL_MTLBLITPASSINTERNAL_H_

#import <Metal/MTLBlitPass.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLBlitPassSampleBufferAttachmentDescriptorArray (Internal) <NSCopying>

#if DARLING_METAL_ENABLED
- (std::unordered_map<size_t, Indium::BlitPassSampleBufferAttachmentDescriptor>)asIndiumAttachments;
#endif

@end

@interface MTLBlitPassDescriptor (Internal)

#if DARLING_METAL_ENABLED
- (Indium::BlitPassDescriptor)asIndiumDescriptor;
#endif

@end

#endif // _METAL_MTLBLITPASSINTERNAL_H_
