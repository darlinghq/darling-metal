// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLRESIDENCYSET_H_
#define _METAL_MTLRESIDENCYSET_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLAllocation.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;

/**
 * Configures a residency set made with -[MTLDevice newResidencySetWithDescriptor:error:]. The set takes the label;
 * the initial capacity is a hint of how many allocations it will hold.
 */
MTL_EXPORT
@interface MTLResidencySetDescriptor : NSObject <NSCopying>

@property(nullable, copy, nonatomic) NSString* label;
@property(nonatomic) NSUInteger initialCapacity;

@end

/**
 * A set of allocations to keep resident while command buffers that use the set run. Vulkan keeps every allocation
 * resident, so here the set only keeps its allocations alive and reports them; attaching it to a command queue or
 * command buffer, and requesting or ending residency, change nothing.
 *
 * Additions and removals are staged and take effect with -commit. Not thread-safe.
 */
@protocol MTLResidencySet <NSObject>

@property(readonly) id<MTLDevice> device;
@property(nullable, readonly) NSString* label;

// The sizes of the committed allocations; a resource made from a heap counts as its whole heap, once.
@property(readonly) uint64_t allocatedSize;

// What the set contains, with the staged changes.
@property(readonly, copy) NSArray<id<MTLAllocation>>* allAllocations;
- (BOOL)containsAllocation: (id<MTLAllocation>)allocation;

// The number of allocations that are committed, staged to be added, or both: until -commit, staged removals count.
@property(readonly) NSUInteger allocationCount;

- (void)addAllocation: (id<MTLAllocation>)allocation;
- (void)addAllocations: (const id<MTLAllocation> __nonnull[__nonnull])allocations
                 count: (NSUInteger)count;
- (void)removeAllocation: (id<MTLAllocation>)allocation;
- (void)removeAllocations: (const id<MTLAllocation> __nonnull[__nonnull])allocations
                    count: (NSUInteger)count;
- (void)removeAllAllocations;

- (void)commit;

- (void)requestResidency;
- (void)endResidency;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRESIDENCYSET_H_
