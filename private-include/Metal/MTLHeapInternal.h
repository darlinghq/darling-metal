// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLHEAPINTERNAL_H_
#define _METAL_MTLHEAPINTERNAL_H_

#import <Metal/MTLHeap.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLHeapInternal : NSObject <MTLHeap>

#if DARLING_METAL_ENABLED
- (instancetype)initWithHeap: (std::shared_ptr<Indium::Heap>)heap
                      device: (id<MTLDevice>)device;
#endif

@end

#if DARLING_METAL_ENABLED
// The Indium heap behind `object`, or null when it is not one of ours.
const std::shared_ptr<Indium::Heap>& MTLHeapGetIndium(id<MTLHeap> object);
#endif

#endif // _METAL_MTLHEAPINTERNAL_H_
