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

#ifndef _METAL_MTLRENDERPIPELINEINTERNAL_H_
#define _METAL_MTLRENDERPIPELINEINTERNAL_H_

#import <Metal/MTLRenderPipeline.h>

#include <indium/indium.hpp>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;

@interface MTLRenderPipelineDescriptor (Internal)

- (Indium::RenderPipelineDescriptor)asIndiumDescriptor;

@end

@interface MTLRenderPipelineColorAttachmentDescriptorArray (Internal) <NSCopying>

- (std::unordered_map<size_t, Indium::RenderPipelineColorAttachmentDescriptor>)asIndiumDescriptors;

- (std::vector<Indium::RenderPipelineColorAttachmentDescriptor>)asContiguousIndiumDescriptors;

@end

@interface MTLRenderPipelineColorAttachmentDescriptor (Internal)

- (Indium::RenderPipelineColorAttachmentDescriptor)asIndiumDescriptor;

@end

@interface MTLRenderPipelineStateInternal : NSObject <MTLRenderPipelineState>

@property(readonly) std::shared_ptr<Indium::RenderPipelineState> state;

- (instancetype)initWithState: (std::shared_ptr<Indium::RenderPipelineState>)state
                       device: (id<MTLDevice>)device;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRENDERPIPELINEINTERNAL_H_
