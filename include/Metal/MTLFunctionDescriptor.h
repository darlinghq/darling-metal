// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLFUNCTIONDESCRIPTOR_H_
#define _METAL_MTLFUNCTIONDESCRIPTOR_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLFunctionConstantValues.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLBinaryArchive;

typedef NS_OPTIONS(NSUInteger, MTLFunctionOptions) {
	MTLFunctionOptionNone = 0,
	MTLFunctionOptionCompileToBinary = 1 << 0,
};

/**
 * What -[MTLLibrary newFunctionWithDescriptor:error:] makes: the function `name` of the library, specialized with
 * `constantValues` when they are set, and called `specializedName` instead of `name` when that is set.
 * The function reports `options`, which change nothing else. `binaryArchives` are kept but not searched: functions are
 * always compiled.
 */
MTL_EXPORT
@interface MTLFunctionDescriptor : NSObject <NSCopying>

+ (MTLFunctionDescriptor*)functionDescriptor;

@property(nullable, copy, nonatomic) NSString* name;
@property(nullable, copy, nonatomic) NSString* specializedName;
@property(nullable, copy, nonatomic) MTLFunctionConstantValues* constantValues;
@property(nonatomic) MTLFunctionOptions options;
@property(nullable, copy, nonatomic) NSArray<id<MTLBinaryArchive>>* binaryArchives;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLFUNCTIONDESCRIPTOR_H_
