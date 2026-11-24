// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLBINARYARCHIVE_H_
#define _METAL_MTLBINARYARCHIVE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@class MTLComputePipelineDescriptor;
@class MTLRenderPipelineDescriptor;

MTL_EXTERN NSErrorDomain const MTLBinaryArchiveDomain;

typedef NS_ENUM(NSUInteger, MTLBinaryArchiveError) {
	MTLBinaryArchiveErrorNone = 0,
	MTLBinaryArchiveErrorInvalidFile = 1,
	MTLBinaryArchiveErrorUnexpectedElement = 2,
	MTLBinaryArchiveErrorCompilationFailure = 3,
	MTLBinaryArchiveErrorInternalError = 4,
};

/**
 * The file a binary archive is opened from, or nil for a new, empty archive.
 */
MTL_EXPORT
@interface MTLBinaryArchiveDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, copy) NSURL* url;

@end

/**
 * The functions of pipeline descriptors, so that a pipeline made with
 * MTLPipelineOptionFailOnBinaryArchiveMiss can be checked against them.
 *
 * Indium compiles a pipeline when it is created, so an archive holds no GPU
 * code: it records which functions were added to it, by their content, and a
 * pipeline found in one is compiled like any other.
 */
@protocol MTLBinaryArchive <NSObject>

@property(nullable, copy, atomic) NSString* label;
@property(readonly) id<MTLDevice> device;

- (BOOL)addComputePipelineFunctionsWithDescriptor: (MTLComputePipelineDescriptor*)descriptor
                                            error: (NSError**)error;

- (BOOL)addRenderPipelineFunctionsWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                           error: (NSError**)error;

- (BOOL)serializeToURL: (NSURL*)url
                 error: (NSError**)error;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLBINARYARCHIVE_H_
