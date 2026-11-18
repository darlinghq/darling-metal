// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBLITPASS_H_
#define _METAL_MTLBLITPASS_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLCounters.h>
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>

METAL_DECLARATIONS_BEGIN

MTL_EXPORT
@interface MTLBlitPassSampleBufferAttachmentDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, retain) id<MTLCounterSampleBuffer> sampleBuffer;
// MTLCounterDontSample (the default) takes no sample
@property(nonatomic) NSUInteger startOfEncoderSampleIndex;
@property(nonatomic) NSUInteger endOfEncoderSampleIndex;

@end

MTL_EXPORT
@interface MTLBlitPassSampleBufferAttachmentDescriptorArray : NSObject

- (MTLBlitPassSampleBufferAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)attachmentIndex;

-    (void)setObject: (nullable MTLBlitPassSampleBufferAttachmentDescriptor*)attachment
  atIndexedSubscript: (NSUInteger)attachmentIndex;

@end

MTL_EXPORT
@interface MTLBlitPassDescriptor : NSObject <NSCopying>

+ (MTLBlitPassDescriptor*)blitPassDescriptor;

@property(readonly) MTLBlitPassSampleBufferAttachmentDescriptorArray* sampleBufferAttachments;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLBLITPASS_H_
