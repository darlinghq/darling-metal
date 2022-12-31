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

#ifndef _METAL_MTLPIPELINEINTERNAL_H_
#define _METAL_MTLPIPELINEINTERNAL_H_

#import <Metal/MTLPipeline.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLPipelineBufferDescriptor (Internal)

#if DARLING_METAL_ENABLED
- (Indium::PipelineBufferDescriptor)asIndiumDescriptor;
#endif

@end

@interface MTLPipelineBufferDescriptorArray (Internal) <NSCopying>

#if DARLING_METAL_ENABLED
- (std::unordered_map<size_t, Indium::PipelineBufferDescriptor>)asIndiumDescriptors;
#endif

@end

#endif // _METAL_MTLPIPELINEINTERNAL_H_
