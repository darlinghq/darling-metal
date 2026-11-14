// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLMSLREFLECTION_H_
#define _METAL_MTLMSLREFLECTION_H_

#import <Foundation/Foundation.h>

#if DARLING_METAL_ENABLED
#include <indium/library.hpp>

/**
 * Reads mslc's reflection document into the values indium's SPIR-V library
 * entry point takes.
 *
 * indium deliberately knows nothing about any producer's format, so the reader
 * lives here rather than in indium. Returns NO and fills `error` with the reason
 * on anything it cannot use: a document mslc could have described and this
 * cannot turn into bindings is a stop, not a reason to guess, because guessing a
 * binding kind is how a texture ends up bound as a buffer.
 */
extern bool MTLReadMSLReflection(const char* document, size_t length,
	Indium::LibraryReflection& outReflection, NSString*& outError);

#endif // DARLING_METAL_ENABLED

#endif // _METAL_MTLMSLREFLECTION_H_
