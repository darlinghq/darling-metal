// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOUNTERS_H_
#define _METAL_MTLCOUNTERS_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLResource.h>

@protocol MTLDevice;

METAL_DECLARATIONS_BEGIN

// the sample index that asks for no sample in a pass descriptor
#define MTLCounterDontSample ((NSUInteger)-1)

// what a counter result reads as when it could not be resolved
#define MTLCounterErrorValue ((uint64_t)~0ULL)

typedef NSString* const MTLCommonCounter NS_TYPED_ENUM;

MTL_EXTERN MTLCommonCounter MTLCommonCounterTimestamp;
MTL_EXTERN MTLCommonCounter MTLCommonCounterTessellationInputPatches;
MTL_EXTERN MTLCommonCounter MTLCommonCounterVertexInvocations;
MTL_EXTERN MTLCommonCounter MTLCommonCounterPostTessellationVertexInvocations;
MTL_EXTERN MTLCommonCounter MTLCommonCounterClipperInvocations;
MTL_EXTERN MTLCommonCounter MTLCommonCounterClipperPrimitivesOut;
MTL_EXTERN MTLCommonCounter MTLCommonCounterFragmentInvocations;
MTL_EXTERN MTLCommonCounter MTLCommonCounterFragmentsPassed;
MTL_EXTERN MTLCommonCounter MTLCommonCounterComputeKernelInvocations;
MTL_EXTERN MTLCommonCounter MTLCommonCounterTotalCycles;
MTL_EXTERN MTLCommonCounter MTLCommonCounterVertexCycles;
MTL_EXTERN MTLCommonCounter MTLCommonCounterTessellationCycles;
MTL_EXTERN MTLCommonCounter MTLCommonCounterPostTessellationVertexCycles;
MTL_EXTERN MTLCommonCounter MTLCommonCounterFragmentCycles;
MTL_EXTERN MTLCommonCounter MTLCommonCounterRenderTargetWriteCycles;

typedef NSString* const MTLCommonCounterSet NS_TYPED_ENUM;

MTL_EXTERN MTLCommonCounterSet MTLCommonCounterSetTimestamp;
MTL_EXTERN MTLCommonCounterSet MTLCommonCounterSetStageUtilization;
MTL_EXTERN MTLCommonCounterSet MTLCommonCounterSetStatistic;

typedef struct {
	uint64_t timestamp;
} MTLCounterResultTimestamp;

typedef struct {
	uint64_t totalCycles;
	uint64_t vertexCycles;
	uint64_t tessellationCycles;
	uint64_t postTessellationVertexCycles;
	uint64_t fragmentCycles;
	uint64_t renderTargetCycles;
} MTLCounterResultStageUtilization;

typedef struct {
	uint64_t tessellationInputPatches;
	uint64_t vertexInvocations;
	uint64_t postTessellationVertexInvocations;
	uint64_t clipperInvocations;
	uint64_t clipperPrimitivesOut;
	uint64_t fragmentInvocations;
	uint64_t fragmentsPassed;
	uint64_t computeKernelInvocations;
} MTLCounterResultStatistic;

@protocol MTLCounter <NSObject>

@property(readonly, copy) NSString* name;

@end

@protocol MTLCounterSet <NSObject>

@property(readonly, copy) NSString* name;
@property(readonly, copy) NSArray<id<MTLCounter>>* counters;

@end

MTL_EXPORT
@interface MTLCounterSampleBufferDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, retain) id<MTLCounterSet> counterSet;
@property(nullable, nonatomic, copy) NSString* label;
@property(nonatomic) MTLStorageMode storageMode;
@property(nonatomic) NSUInteger sampleCount;

@end

@protocol MTLCounterSampleBuffer <NSObject>

@property(readonly) id<MTLDevice> device;
@property(readonly) NSString* label;
@property(readonly) NSUInteger sampleCount;

// The samples in `range` as consecutive result structures of the buffer's counter set. A sample not yet
// written reads as zero. Returns nil for an empty or out-of-bounds range.
- (nullable NSData*)resolveCounterRange: (NSRange)range;

@end

MTL_EXTERN NSErrorDomain const MTLCounterErrorDomain;

typedef NS_ENUM(NSInteger, MTLCounterSampleBufferError) {
	MTLCounterSampleBufferErrorOutOfMemory = 0,
	MTLCounterSampleBufferErrorInvalid = 1,
	MTLCounterSampleBufferErrorInternal = 2,
};

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOUNTERS_H_
