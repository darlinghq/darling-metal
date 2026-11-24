// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBINARYARCHIVEINTERNAL_H_
#define _METAL_MTLBINARYARCHIVEINTERNAL_H_

#import <Metal/MTLBinaryArchive.h>
#import <Metal/MTLLibrary.h>

@interface MTLBinaryArchiveInternal : NSObject <MTLBinaryArchive>

#if DARLING_METAL_ENABLED
// An empty archive when `url` is nil, else the archive serialized to `url`. Returns nil, with an
// MTLBinaryArchiveErrorInvalidFile error, when that file cannot be read as an archive.
- (instancetype)initWithDevice: (id<MTLDevice>)device
                           url: (NSURL*)url
                         error: (NSError**)error;
#endif

@end

#if DARLING_METAL_ENABLED
// Whether a pipeline of `functions` may be created with MTLPipelineOptionFailOnBinaryArchiveMiss: when
// `archives` is empty, or each function is in one of them. Otherwise sets `error` and returns NO.
BOOL MTLBinaryArchivesContainFunctions(NSArray<id<MTLBinaryArchive>>* archives, NSArray<id<MTLFunction>>* functions, NSError** error);
#endif

#endif // _METAL_MTLBINARYARCHIVEINTERNAL_H_
