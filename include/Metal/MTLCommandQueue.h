// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOMMANDQUEUE_H_
#define _METAL_MTLCOMMANDQUEUE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLCommandBuffer;
@protocol MTLCommandQueue;

@class MTLCommandBufferDescriptor;
@protocol MTLResidencySet;

@protocol MTLCommandQueue <NSObject>

@property(readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;

- (id<MTLCommandBuffer>)commandBuffer;

// A command buffer that does not keep the resources it uses alive: the application keeps them until the
// command buffer has completed.
- (nullable id<MTLCommandBuffer>)commandBufferWithUnretainedReferences;
- (nullable id<MTLCommandBuffer>)commandBufferWithDescriptor: (MTLCommandBufferDescriptor*)descriptor;

// Residency sets for the queue's command buffers. Every allocation is resident here, so these change nothing.
- (void)addResidencySet: (id<MTLResidencySet>)residencySet;
- (void)addResidencySets: (const id<MTLResidencySet> __nonnull[__nonnull])residencySets
                   count: (NSUInteger)count;
- (void)removeResidencySet: (id<MTLResidencySet>)residencySet;
- (void)removeResidencySets: (const id<MTLResidencySet> __nonnull[__nonnull])residencySets
                      count: (NSUInteger)count;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOMMANDQUEUE_H_
