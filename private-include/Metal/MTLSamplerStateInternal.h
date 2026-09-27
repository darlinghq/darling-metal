// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLSAMPLERSTATEINTERNAL_H_
#define _METAL_MTLSAMPLERSTATEINTERNAL_H_

#import <Metal/MTLSamplerState.h>
#import <Metal/MTLDevice.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

METAL_DECLARATIONS_BEGIN

// private export
MTL_EXPORT
@interface MTLSamplerStateInternal : NSObject <MTLSamplerState>

#if DARLING_METAL_ENABLED
@property(readonly) std::shared_ptr<Indium::SamplerState> state;

- (instancetype)initWithState: (std::shared_ptr<Indium::SamplerState>)state
                       device: (id<MTLDevice>)device;
#endif

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLSAMPLERSTATEINTERNAL_H_
