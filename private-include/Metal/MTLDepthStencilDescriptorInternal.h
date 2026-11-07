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
@property(nonatomic, readonly) std::shared_ptr<Indium::DepthStencilState> state;

- (instancetype)initWithState: (std::shared_ptr<Indium::DepthStencilState>)state
                       device: (id<MTLDevice>)device;
#endif

@end

METAL_DECLARATIONS_END

#if DARLING_METAL_ENABLED
// The Indium object behind `object`, read without a message send or a copy of
// the shared pointer, for the command encoders. Empty for nil and for objects
// this framework did not create.
const std::shared_ptr<Indium::DepthStencilState>& MTLDepthStencilStateGetIndium(id<MTLDepthStencilState> object);
#endif

#endif // _METAL_MTLDEPTHSTENCILDESCRIPTORINTERNAL_H_
