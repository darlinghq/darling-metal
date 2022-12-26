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
	return MTLSize { width, height, depth };
};

typedef struct MTLOrigin {
	NSUInteger x;
	NSUInteger y;
	NSUInteger z;
} MTLOrigin;

NS_INLINE
MTLOrigin MTLOriginMake(NSUInteger x, NSUInteger y, NSUInteger z) {
	return MTLOrigin { x, y, z };
};

typedef struct MTLRegion {
	MTLOrigin origin;
	MTLSize size;
} MTLRegion;

NS_INLINE
MTLRegion MTLRegionMake1D(NSUInteger x, NSUInteger width) {
	return MTLRegion {
		MTLOrigin { x, 0, 0 },
		MTLSize { width, 1, 1 },
	};
};

NS_INLINE
MTLRegion MTLRegionMake2D(NSUInteger x, NSUInteger y, NSUInteger width, NSUInteger height) {
	return MTLRegion {
		MTLOrigin { x, y, 0 },
		MTLSize { width, height, 1 },
	};
};

NS_INLINE
MTLRegion MTLRegionMake3D(NSUInteger x, NSUInteger y, NSUInteger z, NSUInteger width, NSUInteger height, NSUInteger depth) {
	return MTLRegion {
		MTLOrigin { x, y, z },
		MTLSize { width, height, depth },
	};
};

METAL_DECLARATIONS_END

#endif // _METAL_MTLTYPES_H_
