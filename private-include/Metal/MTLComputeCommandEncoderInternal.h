// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLComputeCommandEncoder.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLComputePassSampleBufferAttachmentDescriptorArray (Internal) <NSCopying>

#if DARLING_METAL_ENABLED
- (std::unordered_map<size_t, Indium::ComputePassSampleBufferAttachmentDescriptor>)asIndiumAttachments;
#endif

@end

@interface MTLComputePassDescriptor (Internal)

#if DARLING_METAL_ENABLED
- (Indium::ComputePassDescriptor)asIndiumDescriptor;
#endif

@end

@interface MTLComputeCommandEncoderInternal : NSObject <MTLComputeCommandEncoder>

#if DARLING_METAL_ENABLED
- (instancetype)initWithEncoder: (std::shared_ptr<Indium::ComputeCommandEncoder>)encoder
                         device: (id<MTLDevice>)device;
#endif

@end
