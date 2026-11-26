// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLTYPES_H_
#define _METAL_MTLTYPES_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

typedef struct MTLSize {
	NSUInteger width;
	NSUInteger height;
	NSUInteger depth;
} MTLSize;

NS_INLINE
MTLSize MTLSizeMake(NSUInteger width, NSUInteger height, NSUInteger depth) {
	MTLSize size = { width, height, depth };
	return size;
};

typedef struct MTLOrigin {
	NSUInteger x;
	NSUInteger y;
	NSUInteger z;
} MTLOrigin;

NS_INLINE
MTLOrigin MTLOriginMake(NSUInteger x, NSUInteger y, NSUInteger z) {
	MTLOrigin origin = { x, y, z };
	return origin;
};

typedef struct MTLRegion {
	MTLOrigin origin;
	MTLSize size;
} MTLRegion;

NS_INLINE
MTLRegion MTLRegionMake1D(NSUInteger x, NSUInteger width) {
	MTLRegion region = {
		MTLOriginMake(x, 0, 0),
		MTLSizeMake(width, 1, 1),
	};
	return region;
};

NS_INLINE
MTLRegion MTLRegionMake2D(NSUInteger x, NSUInteger y, NSUInteger width, NSUInteger height) {
	MTLRegion region = {
		MTLOriginMake(x, y, 0),
		MTLSizeMake(width, height, 1),
	};
	return region;
};

NS_INLINE
MTLRegion MTLRegionMake3D(NSUInteger x, NSUInteger y, NSUInteger z, NSUInteger width, NSUInteger height, NSUInteger depth) {
	MTLRegion region = {
		MTLOriginMake(x, y, z),
		MTLSizeMake(width, height, depth),
	};
	return region;
};

// A position in a pixel, from (0, 0) at its top left corner to (1, 1) at its bottom right.
typedef struct MTLSamplePosition {
	float x;
	float y;
} MTLSamplePosition;

NS_INLINE
MTLSamplePosition MTLSamplePositionMake(float x, float y) {
	MTLSamplePosition position = { x, y };
	return position;
};

// A point in the screen or physical space of a rasterization rate map.
typedef MTLSamplePosition MTLCoordinate2D;

NS_INLINE
MTLCoordinate2D MTLCoordinate2DMake(float x, float y) {
	MTLCoordinate2D coordinate = { x, y };
	return coordinate;
};

METAL_DECLARATIONS_END

#endif // _METAL_MTLTYPES_H_
