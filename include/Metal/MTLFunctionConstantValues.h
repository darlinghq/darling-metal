// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLFUNCTIONCONSTANTVALUES_H_
#define _METAL_MTLFUNCTIONCONSTANTVALUES_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLArgumentDescriptor.h>

METAL_DECLARATIONS_BEGIN

/**
 * Records the values for a library's function constants, keyed by constant index or by name.
 *
 * Setting a value copies the bytes at that moment; the size is derived from the MTLDataType, which
 * must be a scalar or vector type. A NULL value (even with a zero-length range), a nil name or any
 * other type raises NSInvalidArgumentException. The size of 3-component vectors (assumed equal to the
 * 4-component size) is not confirmed from a primary source.
 *
 * Nothing consumes these values yet: MTLLibrary has no -newFunctionWithName:constantValues:error:
 * because mslc cannot compile [[function_constant]], so declaring it would mean ignoring the values.
 */
MTL_EXPORT
@interface MTLFunctionConstantValues : NSObject <NSCopying> {
	// Declared here, not in the .mm: the i386 slice of the FAT build uses the fragile ABI.
	NSMutableDictionary* _byIndex;
	NSMutableDictionary* _byName;
}

- (void)setConstantValue: (const void*)value type: (MTLDataType)type atIndex: (NSUInteger)index;
- (void)setConstantValue: (const void*)value type: (MTLDataType)type withName: (NSString*)name;
// `value` points at range.length consecutive values; they go to range.location, range.location + 1, ...
- (void)setConstantValues: (const void*)values type: (MTLDataType)type withRange: (NSRange)range;
- (void)reset;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLFUNCTIONCONSTANTVALUES_H_
