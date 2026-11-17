// Copyright (C) 2026 Lubos Dolezel

#ifndef _METAL_MTLPARALLELRENDERCOMMANDENCODERINTERNAL_H_
#define _METAL_MTLPARALLELRENDERCOMMANDENCODERINTERNAL_H_

#import <Metal/MTLParallelRenderCommandEncoder.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLParallelRenderCommandEncoderInternal : NSObject <MTLParallelRenderCommandEncoder>

#if DARLING_METAL_ENABLED
- (instancetype)initWithEncoder: (std::shared_ptr<Indium::ParallelRenderCommandEncoder>)encoder
                         device: (id<MTLDevice>)device;
#endif

@end

#endif // _METAL_MTLPARALLELRENDERCOMMANDENCODERINTERNAL_H_
