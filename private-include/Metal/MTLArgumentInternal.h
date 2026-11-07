// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLARGUMENTINTERNAL_H_
#define _METAL_MTLARGUMENTINTERNAL_H_

#import <Metal/MTLArgument.h>
#import <Metal/MTLDevice.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>

@interface MTLComputePipelineReflection (Internal)

- (instancetype)initWithFunction: (std::shared_ptr<Indium::Function>)function
                         options: (MTLPipelineOption)options;

@end

@interface MTLRenderPipelineReflection (Internal)

- (instancetype)initWithVertexFunction: (std::shared_ptr<Indium::Function>)vertexFunction
                      fragmentFunction: (std::shared_ptr<Indium::Function>)fragmentFunction
                               options: (MTLPipelineOption)options;

@end
#endif

#endif // _METAL_MTLARGUMENTINTERNAL_H_
