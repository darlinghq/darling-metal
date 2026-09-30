// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOUNTERSAMPLEBUFFER_H_
#define _METAL_MTLCOUNTERSAMPLEBUFFER_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLResource.h>

@protocol MTLCounterSet;

/**
 * Describes a counter sample buffer to allocate.
 *
 * A stored value is returned unchanged. The buffer is not provided: indium
 * declares CounterSampleBuffer with sampleCount and resolveCounterRange, but
 * nothing in it can be created, because indium has no counter set, no query
 * pool and no timestamp period to sample against.
 * -[MTLDevice newCounterSampleBufferWithDescriptor:error:] is therefore not
 * declared, so a caller reaches an unrecognised selector rather than a buffer
 * that reports a sample count and resolves to bytes it made up.
 */

METAL_DECLARATIONS_BEGIN

MTL_EXPORT
@interface MTLCounterSampleBufferDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, copy) NSString* label;
@property(nullable, nonatomic, retain) id<MTLCounterSet> counterSet;
@property(nonatomic) MTLStorageMode storageMode;
@property(nonatomic) NSUInteger sampleCount;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOUNTERSAMPLEBUFFER_H_
