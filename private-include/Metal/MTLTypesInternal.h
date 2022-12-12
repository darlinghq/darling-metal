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

#ifndef _METAL_MTLTYPESINTERNAL_H_
#define _METAL_MTLTYPESINTERNAL_H_

#import <Metal/MTLTypes.h>

#include <indium/indium.hpp>

NS_INLINE
Indium::Size MTLSizeToIndium(MTLSize size) {
	return Indium::Size { size.width, size.height, size.depth };
};

NS_INLINE
Indium::Range<size_t> NSRangeToIndium(NSRange range) {
	return Indium::Range<size_t> { range.location, range.length };
};

#endif // _METAL_MTLTYPESINTERNAL_H_
