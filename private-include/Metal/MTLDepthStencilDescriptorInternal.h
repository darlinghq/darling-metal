// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLDEPTHSTENCILDESCRIPTORINTERNAL_H_
#define _METAL_MTLDEPTHSTENCILDESCRIPTORINTERNAL_H_

#import <Metal/MTLDepthStencilDescriptor.h>
#import <Metal/MTLDevice.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

METAL_DECLARATIONS_BEGIN

#if DARLING_METAL_ENABLED
@interface MTLDepthStencilDescriptor (Internal)

- (Indium::DepthStencilDescriptor)asIndiumDescriptor;

@end
#endif

// private export
MTL_EXPORT
@interface MTLDepthStencilStateInternal : NSObject <MTLDepthStencilState>

#if DARLING_METAL_ENABLED
@property(readonly) std::shared_ptr<Indium::DepthStencilState> state;

- (instancetype)initWithState: (std::shared_ptr<Indium::DepthStencilState>)state
                       device: (id<MTLDevice>)device;
#endif

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLDEPTHSTENCILDESCRIPTORINTERNAL_H_
