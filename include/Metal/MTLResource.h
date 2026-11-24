// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLRESOURCE_H_
#define _METAL_MTLRESOURCE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLAllocation.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLHeap;

typedef NS_ENUM(NSUInteger, MTLCPUCacheMode) {
	MTLCPUCacheModeDefaultCache = 0,
	MTLCPUCacheModeWriteCombined = 1,
};

typedef NS_ENUM(NSUInteger, MTLStorageMode) {
	MTLStorageModeShared = 0,
	MTLStorageModeManaged = 1,
	MTLStorageModePrivate = 2,
	MTLStorageModeMemoryless = 3,
};

// Whether the system may discard the contents of a resource it needs memory for.
typedef NS_ENUM(NSUInteger, MTLPurgeableState) {
	MTLPurgeableStateKeepCurrent = 1,
	MTLPurgeableStateNonVolatile = 2,
	MTLPurgeableStateVolatile = 3,
	MTLPurgeableStateEmpty = 4,
};

typedef NS_ENUM(NSUInteger, MTLHazardTrackingMode) {
	MTLHazardTrackingModeDefault = 0,
	MTLHazardTrackingModeUntracked = 1,
	MTLHazardTrackingModeTracked = 2,
};

#define MTLResourceCPUCacheModeShift 0
#define MTLResourceStorageModeShift 4
#define MTLResourceHazardTrackingModeShift 8

typedef NS_OPTIONS(NSUInteger, MTLResourceOptions) {
	MTLResourceCPUCacheModeDefaultCache = MTLCPUCacheModeDefaultCache << MTLResourceCPUCacheModeShift,
	MTLResourceCPUCacheModeWriteCombined = MTLCPUCacheModeWriteCombined << MTLResourceCPUCacheModeShift,

	MTLResourceStorageModeShared = MTLStorageModeShared << MTLResourceStorageModeShift,
	MTLResourceStorageModeManaged = MTLStorageModeManaged << MTLResourceStorageModeShift,
	MTLResourceStorageModePrivate = MTLStorageModePrivate << MTLResourceStorageModeShift,
	MTLResourceStorageModeMemoryless = MTLStorageModeMemoryless << MTLResourceStorageModeShift,

	MTLResourceHazardTrackingModeDefault = MTLHazardTrackingModeDefault << MTLResourceHazardTrackingModeShift,
	MTLResourceHazardTrackingModeTracked = MTLHazardTrackingModeTracked << MTLResourceHazardTrackingModeShift,
	MTLResourceHazardTrackingModeUntracked = MTLHazardTrackingModeUntracked << MTLResourceHazardTrackingModeShift,
};

@protocol MTLResource <MTLAllocation>

@property(readonly) id<MTLDevice> device;
@property(readonly) MTLCPUCacheMode cpuCacheMode;
@property(readonly) MTLStorageMode storageMode;
@property(readonly) MTLHazardTrackingMode hazardTrackingMode;
@property(readonly) MTLResourceOptions resourceOptions;
@property(nullable, copy, nonatomic) NSString* label;

// Sets the purgeable state and returns the state the resource was in. Like macOS on Apple silicon, resources are
// never purgeable here: every call returns MTLPurgeableStateNonVolatile and changes nothing.
- (MTLPurgeableState)setPurgeableState: (MTLPurgeableState)state;

// The heap the resource was made from, nil for any other resource. A resource keeps its heap alive.
@property(nullable, readonly) id<MTLHeap> heap;

// Where the resource starts in a placement heap. 0 for every other resource, those of an automatic heap included.
@property(readonly) NSUInteger heapOffset;

// The bytes of device memory the resource takes. For a resource made from a heap this is what the heap counts for it
// (see -[MTLDevice heapBufferSizeAndAlignWithLength:options:]).
@property(readonly) NSUInteger allocatedSize;

// Lets an automatic heap give the resource's memory to other resources made from it. The resource stays valid but
// its contents are no longer kept. Resources of a placement heap are always aliasable; any other resource ignores this.
- (void)makeAliasable;
- (BOOL)isAliasable;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRESOURCE_H_
