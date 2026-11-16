// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBUFFER_H_
#define _METAL_MTLBUFFER_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLResource.h>
#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@class MTLTextureDescriptor;
@protocol MTLTexture;

@protocol MTLBuffer <MTLResource>

@property(readonly) NSUInteger length;
@property(readonly) uint64_t gpuAddress;

- (void*)contents;

- (void)didModifyRange: (NSRange)range;

// A texture whose rows are the rows of this buffer from `offset` on, `bytesPerRow` apart: what is written to
// the buffer is seen by the texture and the other way round. nil when the texture cannot be made that way: it
// has to be a 2D texture with one level, one slice and one sample in an uncompressed format, with the storage
// mode of the buffer, and `bytesPerRow` has to be a multiple of
// -[MTLDevice minimumLinearTextureAlignmentForPixelFormat:].
- (nullable id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor
                                              offset: (NSUInteger)offset
                                         bytesPerRow: (NSUInteger)bytesPerRow;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLBUFFER_H_
