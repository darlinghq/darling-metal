// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLACCELERATIONSTRUCTURE_H_
#define _METAL_MTLACCELERATIONSTRUCTURE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLBuffer.h>
#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

typedef NS_ENUM(NSInteger, MTLMatrixLayout) {
	MTLMatrixLayoutColumnMajor = 0,
	MTLMatrixLayoutRowMajor = 1,
};

typedef NS_ENUM(uint32_t, MTLMotionBorderMode) {
	MTLMotionBorderModeClamp = 0,
	MTLMotionBorderModeVanish = 1,
};

typedef NS_ENUM(NSInteger, MTLTransformType) {
	MTLTransformTypePackedFloat4x3 = 0,
	MTLTransformTypeComponent = 1,
};

/**
 * One instant of a motion blur transform, pointing into a buffer the caller
 * filled.
 *
 * -data is the caller's own bytes: the buffer and the offset are stored as
 * given, and -data is that offset into the buffer's host-visible contents. It
 * is NULL for a private buffer, because such a buffer genuinely has no
 * host-visible contents, and that NULL is the truth rather than a stand-in.
 *
 * Building an acceleration structure out of these is not provided: indium has no
 * ray tracing at all.
 */
MTL_EXPORT
@interface MTLMotionKeyframeData : NSObject

- (instancetype)init;

@property(nullable, nonatomic, retain) id<MTLBuffer> buffer;
@property(nonatomic) NSUInteger offset;

@property(readonly) void* data;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLACCELERATIONSTRUCTURE_H_
