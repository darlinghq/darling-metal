// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_STUBS_H_
#define _METAL_STUBS_H_

// this is mainly used for the 32-bit build.
// in the 32-bit build, Metal builds and links, but any attempt to use it fails.
// this is the correct behavior according to the official framework.
// only the selectors the class does not really have get a fabricated signature: answering "v@:" for
// an inherited method that does exist would mislead anyone introspecting it to build an invocation.
#define MTL_UNSUPPORTED_CLASS \
	- (NSMethodSignature*)methodSignatureForSelector: (SEL)selector \
	{ \
		NSMethodSignature* signature = [super methodSignatureForSelector: selector]; \
		return signature ?: [NSMethodSignature signatureWithObjCTypes: "v@:"]; \
	} \
	- (void)forwardInvocation: (NSInvocation*)invocation \
	{ \
		NSLog(@"Method invocation in unsupported class %@ in %@", NSStringFromSelector(invocation.selector), self.class); \
		abort(); \
	} \
	+ (NSMethodSignature*)methodSignatureForSelector: (SEL)selector \
	{ \
		NSMethodSignature* signature = [super methodSignatureForSelector: selector]; \
		return signature ?: [NSMethodSignature signatureWithObjCTypes: "v@:"]; \
	} \
	+ (void)forwardInvocation: (NSInvocation*)invocation \
	{ \
		NSLog(@"Method invocation in unsupported class %@ in %@", NSStringFromSelector(invocation.selector), self); \
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
