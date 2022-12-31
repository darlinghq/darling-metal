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

#ifndef _METAL_STUBS_H_
#define _METAL_STUBS_H_

// this is mainly used for the 32-bit build.
// in the 32-bit build, Metal builds and links, but any attempt to use it fails.
// this is the correct behavior according to the official framework.
#define MTL_UNSUPPORTED_CLASS \
	- (NSMethodSignature*)methodSignatureForSelector: (SEL)selector \
	{ \
		return [NSMethodSignature signatureWithObjCTypes: "v@:"]; \
	} \
	- (void)forwardInvocation: (NSInvocation*)invocation \
	{ \
		NSLog(@"Method invocation in unsupported class %@ in %@", NSStringFromSelector(invocation.selector), self.class); \
		abort(); \
	}

#if !__OBJC2__ || !DARLING_METAL_ENABLED
	// shut Clang up about unimplemented methods and properties
	#pragma clang diagnostic ignored "-Wobjc-property-implementation"
	#pragma clang diagnostic ignored "-Wprotocol"
	#pragma clang diagnostic ignored "-Wincomplete-implementation"
	#pragma clang diagnostic ignored "-Wobjc-protocol-property-synthesis"

	#undef DARLING_METAL_ENABLED
#endif

#endif // _METAL_STUBS_H_
