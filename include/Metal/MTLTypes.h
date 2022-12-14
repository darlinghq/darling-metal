/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

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

METAL_DECLARATIONS_END

#endif // _METAL_MTLTYPES_H_
