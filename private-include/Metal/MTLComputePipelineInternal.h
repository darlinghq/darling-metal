/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

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
@property(readonly) std::shared_ptr<Indium::ComputePipelineState> state;

- (instancetype)initWithState: (std::shared_ptr<Indium::ComputePipelineState>)state
                       device: (id<MTLDevice>)device
                        label: (NSString*)label;
#endif

@end

#endif // _METAL_MTLCOMPUTEPIPELINEINTERNAL_H_
