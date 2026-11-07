// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLINDIUMERRORS_H_
#define _METAL_MTLINDIUMERRORS_H_

#import <Foundation/Foundation.h>
#import <Metal/MTLLibrary.h>

#include <exception>
#include <utility>

// Indium reports failures by throwing C++ exceptions. A Metal method that has an NSError**
// out-parameter must report them through it, and one that has none must not let a C++
// exception unwind through Objective-C callers. These helpers do both.

static inline NSError* MTLErrorWithCode(NSInteger code, NSString* description)
{
	NSDictionary* userInfo = description ? @{ NSLocalizedDescriptionKey: description } : nil;
	return [NSError errorWithDomain: MTLLibraryErrorDomain code: code userInfo: userInfo];
}

static inline void MTLSetError(NSError** error, NSInteger code, NSString* description)
{
	if (error) {
		*error = MTLErrorWithCode(code, description);
	}
}

// Runs `body`. If it throws, stores an error with `code` and Indium's message in `error` and
// returns a value-initialized result (nullptr for Indium's shared_ptr results).
template<typename Body>
static inline auto MTLCallIndium(NSError** error, NSInteger code, Body&& body) -> decltype(body())
{
	try {
		return std::forward<Body>(body)();
	} catch (const std::exception& e) {
		MTLSetError(error, code, [NSString stringWithUTF8String: e.what()]);
	} catch (...) {
		MTLSetError(error, code, nil);
	}
	return decltype(body()) {};
}

#endif // _METAL_MTLINDIUMERRORS_H_
