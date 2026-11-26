// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLRASTERIZATIONRATE_H_
#define _METAL_MTLRASTERIZATIONRATE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLTypes.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLBuffer;

/**
 * Maps a render pass's screen space onto a smaller physical space rasterized at varying rates.
 *
 * Only the protocol is declared: indium has no variable rasterization rate, so a device answers NO to
 * -supportsRasterizationRateMapWithLayerCount: and makes no rate maps, and the descriptor classes rate maps are
 * made from are not provided.
 */
@protocol MTLRasterizationRateMap <NSObject>

@property(readonly) id<MTLDevice> device;
@property(nullable, readonly) NSString* label;
@property(readonly) MTLSize screenSize;
@property(readonly) MTLSize physicalGranularity;
@property(readonly) NSUInteger layerCount;
@property(readonly) MTLSizeAndAlign parameterBufferSizeAndAlign;

- (void)copyParameterDataToBuffer: (id<MTLBuffer>)buffer offset: (NSUInteger)offset;
- (MTLSize)physicalSizeForLayer: (NSUInteger)layerIndex;
- (MTLCoordinate2D)mapScreenToPhysicalCoordinates: (MTLCoordinate2D)screenCoordinates forLayer: (NSUInteger)layerIndex;
- (MTLCoordinate2D)mapPhysicalToScreenCoordinates: (MTLCoordinate2D)physicalCoordinates forLayer: (NSUInteger)layerIndex;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRASTERIZATIONRATE_H_
