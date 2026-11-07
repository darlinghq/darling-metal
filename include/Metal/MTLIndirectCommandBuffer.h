// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLINDIRECTCOMMANDBUFFER_H_
#define _METAL_MTLINDIRECTCOMMANDBUFFER_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

typedef NS_OPTIONS(NSUInteger, MTLIndirectCommandType) {
	MTLIndirectCommandTypeDraw = 1,
	MTLIndirectCommandTypeDrawIndexed = 1 << 1,
	MTLIndirectCommandTypeDrawPatches = 1 << 2,
	MTLIndirectCommandTypeDrawIndexedPatches = 1 << 3,
	MTLIndirectCommandTypeConcurrentDispatch = 1 << 5,
	MTLIndirectCommandTypeConcurrentDispatchThreads = 1 << 6,
	MTLIndirectCommandTypeDrawMeshThreadgroups = 1 << 7,
	MTLIndirectCommandTypeDrawMeshThreads = 1 << 8,
};

/**
 * Describes an indirect command buffer to allocate.
 *
 * A stored value is returned unchanged. The buffer is not provided: indium has
 * no indirect command buffer, no indirect command encoder and nowhere to put
 * the encoded commands, so
 * -[MTLDevice newIndirectCommandBufferWithDescriptor:] is not declared.
 */
MTL_EXPORT
@interface MTLIndirectCommandBufferDescriptor : NSObject <NSCopying>

@property(nonatomic) BOOL inheritPipelineState;
@property(nonatomic) BOOL inheritBuffers;
@property(nonatomic) NSUInteger maxVertexBufferBindCount;
@property(nonatomic) NSUInteger maxFragmentBufferBindCount;
@property(nonatomic) NSUInteger maxKernelBufferBindCount;
@property(nonatomic) MTLIndirectCommandType commandTypes;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLINDIRECTCOMMANDBUFFER_H_
