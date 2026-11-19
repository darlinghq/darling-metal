// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBLITCOMMANDENCODERINTERNAL_H_
#define _METAL_MTLBLITCOMMANDENCODERINTERNAL_H_

#import <Metal/MTLBlitCommandEncoder.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#include <Metal/MTLIOSurfaceCopy.h>
#endif

@interface MTLBlitCommandEncoderInternal : NSObject <MTLBlitCommandEncoder>

#if DARLING_METAL_ENABLED
- (instancetype)initWithEncoder: (std::shared_ptr<Indium::BlitCommandEncoder>)encoder
                         device: (id<MTLDevice>)device;

// The set that collects the IOSurfaces the encoder's commands write, which the command buffer
// reports when it completes.
- (void)setIOSurfaceWrites: (std::shared_ptr<MTLIOSurfaceWriteSet>)writes;
#endif

@end

#endif // _METAL_MTLBLITCOMMANDENCODERINTERNAL_H_
