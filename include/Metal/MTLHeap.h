// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLHEAP_H_
#define _METAL_MTLHEAP_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLResource.h>

METAL_DECLARATIONS_BEGIN

typedef NS_ENUM(NSInteger, MTLHeapType) {
	MTLHeapTypeAutomatic = 0,
	MTLHeapTypePlacement = 1,
	MTLHeapTypeSparse = 2,
};

/**
 * Describes a heap to allocate from.
 *
 * Every property is stored and returned unchanged, so the descriptor is honest
 * as a value. What is deliberately absent is the operation it exists to feed:
 * -[MTLDevice newHeapWithDescriptor:error:] is not declared, and indium has no
 * heap, no suballocation and no backing memory at all. A declaration that
 * returned a heap would be an object that allocated nothing and reported sizes
 * it invented, so the method stays undefined and the caller gets an
 * unrecognised selector naming the gap instead of a heap that silently fails
 * to allocate.
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

METAL_DECLARATIONS_END

#endif // _METAL_MTLHEAP_H_
