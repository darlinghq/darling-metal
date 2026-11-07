// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLTYPESINTERNAL_H_
#define _METAL_MTLTYPESINTERNAL_H_

#import <Metal/MTLTypes.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>

NS_INLINE
Indium::Size MTLSizeToIndium(MTLSize size) {
	return Indium::Size { size.width, size.height, size.depth };
};

NS_INLINE
Indium::Range<size_t> NSRangeToIndium(NSRange range) {
	return Indium::Range<size_t> { range.location, range.length };
};

NS_INLINE
Indium::Origin MTLOriginToIndium(MTLOrigin origin) {
	return Indium::Origin { origin.x, origin.y, origin.z };
};

NS_INLINE
Indium::Region MTLRegionToIndium(MTLRegion region) {
	return Indium::Region {
		MTLOriginToIndium(region.origin),
		MTLSizeToIndium(region.size),
	};
};
#endif

#endif // _METAL_MTLTYPESINTERNAL_H_
