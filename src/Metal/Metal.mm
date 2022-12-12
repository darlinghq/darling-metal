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

#import <Metal/Metal.h>
#include <indium/indium.hpp>
#import <Metal/MTLDeviceInternal.h>

#if __OBJC2__

// TODO: add some extension here that MetalKit needs.
//
// because MetalKit gets loaded after we do, it has no way to tell us what extensions it needs.
// so, we have to hardcode it here and always require those extensions, even if we don't actually
// use MetalKit. TODO: find some way to avoid hardcoding these extensions.
static const char* additionalExtensions[] = {};

__attribute__((constructor))
static void initMetal(void) {
	bool enableValidation = false;

	if (getenv("METAL_INDIUM_VALIDATION")) {
		enableValidation = true;
	}

	Indium::init(additionalExtensions, sizeof(additionalExtensions) / sizeof(*additionalExtensions), enableValidation);
};

__attribute__((destructor))
static void finitMetal(void) {
	MTLDeviceDestroyAll();
	Indium::finit();
};

#endif
