// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLLINKEDFUNCTIONS_H_
#define _METAL_MTLLINKEDFUNCTIONS_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

@protocol MTLFunction;
@protocol MTLBinaryFunction;

/**
 * Names the functions a pipeline is built from, and in what groups.
 *
 * Four stored arrays and a dictionary, each returned unchanged, so the object is
 * honest as a value. Linking is not performed: indium's LinkedFunctions is an
 * empty placeholder struct, and the group names have no counterpart in Vulkan
 * at all, so a group dictionary this accepted could not be turned into
 * anything. A pipeline descriptor that names linked functions therefore fails
 * later, at the pipeline, with whatever indium reports.
 */

METAL_DECLARATIONS_BEGIN

MTL_EXPORT
@interface MTLLinkedFunctions : NSObject <NSCopying>

@property(nullable, nonatomic, retain) NSArray<id<MTLFunction>>* functions;
@property(nullable, nonatomic, retain) NSArray* privateFunctions;
@property(nullable, nonatomic, retain) NSDictionary<NSString*, NSArray<id<MTLFunction>>*>* groups;
@property(nullable, nonatomic, retain) NSArray<id<MTLBinaryFunction>>* binaryFunctions;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLLINKEDFUNCTIONS_H_
