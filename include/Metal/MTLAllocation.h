// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLALLOCATION_H_
#define _METAL_MTLALLOCATION_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

/**
 * Device memory that can be put in a residency set: a buffer, a texture or a heap.
 */
@protocol MTLAllocation <NSObject>

@property(readonly) NSUInteger allocatedSize;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLALLOCATION_H_
