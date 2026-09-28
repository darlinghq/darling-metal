// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBLITCOMMANDENCODERINTERNAL_H_
#define _METAL_MTLBLITCOMMANDENCODERINTERNAL_H_

#import <Metal/MTLBlitCommandEncoder.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLBlitCommandEncoderInternal : NSObject <MTLBlitCommandEncoder>

#if DARLING_METAL_ENABLED
- (instancetype)initWithEncoder: (std::shared_ptr<Indium::BlitCommandEncoder>)encoder
                         device: (id<MTLDevice>)device;
#endif

@end

#endif // _METAL_MTLBLITCOMMANDENCODERINTERNAL_H_
