// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOMPUTEPIPELINEINTERNAL_H_
#define _METAL_MTLCOMPUTEPIPELINEINTERNAL_H_

#import <Metal/MTLComputePipeline.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLComputePipelineDescriptor (Internal)

#if DARLING_METAL_ENABLED
- (Indium::ComputePipelineDescriptor)asIndiumDescriptor;
#endif

@end

@interface MTLComputePipelineStateInternal : NSObject <MTLComputePipelineState>

#if DARLING_METAL_ENABLED
@property(nonatomic, readonly) std::shared_ptr<Indium::ComputePipelineState> state;

- (instancetype)initWithState: (std::shared_ptr<Indium::ComputePipelineState>)state
                       device: (id<MTLDevice>)device
                        label: (NSString*)label;
#endif

@end

#if DARLING_METAL_ENABLED
// The Indium object behind `object`, read without a message send or a copy of
// the shared pointer, for the command encoders. Empty for nil and for objects
// this framework did not create.
const std::shared_ptr<Indium::ComputePipelineState>& MTLComputePipelineStateGetIndium(id<MTLComputePipelineState> object);
#endif

#endif // _METAL_MTLCOMPUTEPIPELINEINTERNAL_H_
