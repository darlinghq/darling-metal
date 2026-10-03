// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_STUBS_H_
#define _METAL_STUBS_H_

#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>
#import <objc/runtime.h>
#include <string.h>

// A stub that answers "v@:" declares a return of void and exactly two arguments:
// self and _cmd. Foundation builds the NSInvocation from that signature, so a
// caller passing any argument at all -- any selector containing a colon -- gets
// NSForwardSignatureError raised before forwardInvocation: is ever reached, and
// the process dies on a selector the framework never claimed to be missing.
//
// The arity is knowable even when the types are not: a selector has one
// argument per colon in its name. The return is declared as an object because a
// getter is the common case and a fabricated void truncates the return register,
// which is worse than declaring a type the stub never actually produces.
static inline NSMethodSignature* MTLStubSignature(SEL selector) {
	const char* name = sel_getName(selector);
	char types[64];
	size_t colons = 0;
	size_t at;

	for (const char* p = name; p != NULL && *p != '\0'; p++) {
		if (*p == ':') {
			colons++;
		}
	}

	// "@@:" is return-object, self, _cmd. One "@" per colon follows. A selector
	// cannot have more arguments than this buffer holds.
	if (colons > (sizeof(types) / 2) - 4) {
		colons = (sizeof(types) / 2) - 4;
	}

	memcpy(types, "@@:", 4);

	for (at = 0; at < colons; at++) {
		types[3 + at] = '@';
	}

	types[3 + colons] = '\0';

	return [NSMethodSignature signatureWithObjCTypes: types];
}

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
