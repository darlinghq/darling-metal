// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLFENCEINTERNAL_H_
#define _METAL_MTLFENCEINTERNAL_H_

#import <Metal/MTLFence.h>
#import <Metal/MTLDevice.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

METAL_DECLARATIONS_BEGIN

// private export
MTL_EXPORT
@interface MTLFenceInternal : NSObject <MTLFence>

#if DARLING_METAL_ENABLED
- (instancetype)initWithFence: (std::shared_ptr<Indium::Fence>)fence
                       device: (id<MTLDevice>)device;
#endif

@end

METAL_DECLARATIONS_END

#if DARLING_METAL_ENABLED
// The Indium fence behind `object`, without a message send. Empty for nil and for objects this framework did not
// create.
std::shared_ptr<Indium::Fence> MTLFenceGetIndium(id<MTLFence> object);
#endif

#endif // _METAL_MTLFENCEINTERNAL_H_
