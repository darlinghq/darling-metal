// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBINARYARCHIVE_H_
#define _METAL_MTLBINARYARCHIVE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

/**
 * Points at a .metallib on disk to open a binary archive from.
 *
 * A stored URL is returned unchanged. The archive itself is not provided:
 * indium's BinaryArchive is an empty placeholder struct with no members, and
 * -[MTLDevice newBinaryArchiveWithDescriptor:error:] is therefore not declared,
 * so a caller reaches an unrecognised selector rather than an archive that
 * loads nothing and reports an empty pipeline list.
 */
MTL_EXPORT
@interface MTLBinaryArchiveDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, copy) NSURL* url;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLBINARYARCHIVE_H_
