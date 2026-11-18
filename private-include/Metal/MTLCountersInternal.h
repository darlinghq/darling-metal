// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOUNTERSINTERNAL_H_
#define _METAL_MTLCOUNTERSINTERNAL_H_

#import <Metal/MTLCounters.h>
#import <Metal/MTLDevice.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

METAL_DECLARATIONS_BEGIN

// private export
MTL_EXPORT
@interface MTLCounterInternal : NSObject <MTLCounter>

- (instancetype)initWithName: (NSString*)name;

@end

// private export
MTL_EXPORT
@interface MTLCounterSetInternal : NSObject <MTLCounterSet>

- (instancetype)initWithName: (NSString*)name counters: (NSArray<id<MTLCounter>>*)counters;

@end

// private export
MTL_EXPORT
@interface MTLCounterSampleBufferInternal : NSObject <MTLCounterSampleBuffer>

#if DARLING_METAL_ENABLED
- (instancetype)initWithSampleBuffer: (std::shared_ptr<Indium::CounterSampleBuffer>)sampleBuffer
                              device: (id<MTLDevice>)device
                               label: (NSString*)label;
#endif

@end

METAL_DECLARATIONS_END

#if DARLING_METAL_ENABLED
// The Indium sample buffer behind `object`, without a message send. Empty for nil and for objects this framework did
// not create.
std::shared_ptr<Indium::CounterSampleBuffer> MTLCounterSampleBufferGetIndium(id<MTLCounterSampleBuffer> object);
#endif

#endif // _METAL_MTLCOUNTERSINTERNAL_H_
