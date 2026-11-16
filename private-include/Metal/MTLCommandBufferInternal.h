// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLCommandBuffer.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLCommandBufferInternal : NSObject <MTLCommandBuffer>

#if DARLING_METAL_ENABLED
// called from Indium's handlers
- (void)commandBufferWasScheduled;
- (void)commandBufferDidComplete;
#endif

#if DARLING_METAL_ENABLED
- (instancetype)initWithCommandBuffer: (std::shared_ptr<Indium::CommandBuffer>)commandBuffer
                         commandQueue: (id<MTLCommandQueue>)commandQueue;
- (instancetype)initWithCommandBuffer: (std::shared_ptr<Indium::CommandBuffer>)commandBuffer
                         commandQueue: (id<MTLCommandQueue>)commandQueue
                   retainedReferences: (BOOL)retainedReferences
                         errorOptions: (MTLCommandBufferErrorOption)errorOptions;
#endif

@end
