// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBUFFERINTERNAL_H_
#define _METAL_MTLBUFFERINTERNAL_H_

#import <Metal/MTLBuffer.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLBufferInternal : NSObject <MTLBuffer>

#if DARLING_METAL_ENABLED
@property(nonatomic, readonly) std::shared_ptr<Indium::Buffer> buffer;

- (instancetype)initWithBuffer: (std::shared_ptr<Indium::Buffer>)buffer
                        device: (id<MTLDevice>)device
               resourceOptions: (MTLResourceOptions)options;
#endif

@end

#if DARLING_METAL_ENABLED
// The Indium object behind `object`, read without a message send or a copy of
// the shared pointer, for the command encoders. Empty for nil and for objects
// this framework did not create.
const std::shared_ptr<Indium::Buffer>& MTLBufferGetIndium(id<MTLBuffer> object);
#endif

#endif // _METAL_MTLBUFFERINTERNAL_H_
