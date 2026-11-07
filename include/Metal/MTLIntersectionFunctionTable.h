// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLINTERSECTIONFUNCTIONTABLE_H_
#define _METAL_MTLINTERSECTIONFUNCTIONTABLE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

/**
 * Names the intersection function a geometry uses.
 *
 * Declared with no properties on purpose. Neither metal-cpp's generated header
 * nor the iOS 13.0 SDK's public headers carry this class, so there is no
 * reference on this machine that says what its properties are called, and a
 * guess would be a wrong answer wearing the right shape. The class symbol is
 * still declared because dyld fails on the whole binary without it, and a caller
 * that sets a property now gets an unrecognised selector naming the gap, which
 * is the truth, instead of a value this would have invented.
 */
MTL_EXPORT
@interface MTLIntersectionFunctionDescriptor : NSObject <NSCopying>
@end

/**
 * Says how big an intersection function table is.
 *
 * functionCount is stored and returned unchanged. The table itself is not
 * provided: indium has no ray tracing and no shader binding table, so
 * -[MTLDevice newIntersectionFunctionTableWithDescriptor:] is not declared.
 * functionCount therefore defaults to 0, which is also the truth - an unbacked
 * table holds no functions - rather than a plausible number a caller would then
 * size its ray query buffers against.
 *
 * The descriptor's other properties (sceneIndexType, functionDescriptors,
 * category) are not declared: their enumerators are in no reference available
 * here, for the same reason as MTLIntersectionFunctionDescriptor above.
 */
MTL_EXPORT
@interface MTLIntersectionFunctionTableDescriptor : NSObject <NSCopying>

+ (MTLIntersectionFunctionTableDescriptor*)intersectionFunctionTableDescriptor;

@property(nonatomic) NSUInteger functionCount;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLINTERSECTIONFUNCTIONTABLE_H_
