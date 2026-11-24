// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLHEAP_H_
#define _METAL_MTLHEAP_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLAllocation.h>
#import <Metal/MTLResource.h>

METAL_DECLARATIONS_BEGIN

typedef NS_ENUM(NSInteger, MTLHeapType) {
	MTLHeapTypeAutomatic = 0,
	MTLHeapTypePlacement = 1,
	MTLHeapTypeSparse = 2,
};

@class MTLTextureDescriptor;
@protocol MTLBuffer;
@protocol MTLTexture;

/**
 * Describes a heap to allocate from with -[MTLDevice newHeapWithDescriptor:].
 *
 * The storage mode defaults to private. Shared and private heaps are supported; heaps of any other storage mode, and
 * sparse heaps, cannot be made.
 */
MTL_EXPORT
@interface MTLHeapDescriptor : NSObject <NSCopying>

@property(nonatomic) NSUInteger size;
@property(nonatomic) MTLStorageMode storageMode;
@property(nonatomic) MTLCPUCacheMode cpuCacheMode;
@property(nonatomic) MTLHazardTrackingMode hazardTrackingMode;
@property(nonatomic) MTLResourceOptions resourceOptions;
@property(nonatomic) MTLHeapType type;

@end

/**
 * A block of device memory that buffers and textures are made from. The memory is allocated when the heap is created.
 *
 * Resources are made with the heap's storage mode and CPU cache mode (a request for any other is refused with nil) and
 * have the heap's hazard tracking mode, untracked unless the descriptor said tracked. An automatic heap places the
 * resources itself; a placement heap makes them at the offsets given, a multiple of the alignment
 * -[MTLDevice heapBufferSizeAndAlignWithLength:options:] and heapTextureSizeAndAlignWithDescriptor: return, and
 * resources that overlap share their memory.
 */
@protocol MTLHeap <MTLAllocation>

@property(nullable, copy, nonatomic) NSString* label;
@property(readonly) id<MTLDevice> device;
@property(readonly) MTLStorageMode storageMode;
@property(readonly) MTLCPUCacheMode cpuCacheMode;
@property(readonly) MTLHazardTrackingMode hazardTrackingMode;
@property(readonly) MTLResourceOptions resourceOptions;
@property(readonly) MTLHeapType type;

// The descriptor's size rounded up to whole pages.
@property(readonly) NSUInteger size;

// The sum of the sizes of the resources an automatic heap holds, not counting those made aliasable. Always 0 for a
// placement heap.
@property(readonly) NSUInteger usedSize;

// The memory the heap has allocated: all of it.
@property(readonly) NSUInteger currentAllocatedSize;

// The memory the heap takes, its size.
@property(readonly) NSUInteger allocatedSize;

// The size of the largest resource an automatic heap could place now at an offset that is a multiple of `alignment`.
// Always 0 for a placement heap.
- (NSUInteger)maxAvailableSizeWithAlignment: (NSUInteger)alignment;

// Resources from an automatic heap: nil if there is no room, the options do not match the heap's storage mode and
// cache mode, or the heap is a placement heap.
- (nullable id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                                      options: (MTLResourceOptions)options;
- (nullable id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor;

// Resources from a placement heap, at a byte offset that is a multiple of the resource's alignment and leaves it
// inside the heap; nil otherwise, and for an automatic heap.
- (nullable id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                                      options: (MTLResourceOptions)options
                                       offset: (NSUInteger)offset;
- (nullable id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor
                                             offset: (NSUInteger)offset;

// Returns the previous state, and applies `state` unless it is MTLPurgeableStateKeepCurrent. The contents of a
// heap are never discarded, whatever the state.
- (MTLPurgeableState)setPurgeableState: (MTLPurgeableState)state;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLHEAP_H_
