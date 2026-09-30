// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLACCELERATIONSTRUCTUREDESCRIPTOR_H_
#define _METAL_MTLACCELERATIONSTRUCTUREDESCRIPTOR_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLAccelerationStructure.h>
#import <Metal/MTLAccelerationStructureGeometryDescriptor.h>
#import <Metal/MTLBuffer.h>
#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

typedef NS_ENUM(NSUInteger, MTLAccelerationStructureInstanceDescriptorType) {
	MTLAccelerationStructureInstanceDescriptorTypeDefault = 0,
	MTLAccelerationStructureInstanceDescriptorTypeUserID = 1,
	MTLAccelerationStructureInstanceDescriptorTypeMotion = 2,
	MTLAccelerationStructureInstanceDescriptorTypeIndirect = 3,
	MTLAccelerationStructureInstanceDescriptorTypeIndirectMotion = 4,
};

/**
 * Describes a bottom-level acceleration structure to build over some geometry.
 *
 * Every property is stored and returned unchanged, so the descriptor is honest
 * as a value. Building is not: indium has no ray tracing, so
 * -[MTLDevice newAccelerationStructureWithDescriptor:error:] is not declared and
 * a caller that assembles this is told at the call rather than handed a
 * structure that traces nothing.
 */
MTL_EXPORT
@interface MTLPrimitiveAccelerationStructureDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, retain) NSArray<MTLAccelerationStructureGeometryDescriptor*>* geometryDescriptors;
@property(nonatomic) NSUInteger motionKeyframeCount;
@property(nonatomic) float motionStartTime;
@property(nonatomic) MTLMotionBorderMode motionStartBorderMode;
@property(nonatomic) float motionEndTime;
@property(nonatomic) MTLMotionBorderMode motionEndBorderMode;
@property(nullable, nonatomic, copy) NSString* label;

@end

/**
 * Describes a top-level acceleration structure to build over instances.
 *
 * As above: stored and returned unchanged, and not buildable.
 */
MTL_EXPORT
@interface MTLInstanceAccelerationStructureDescriptor : NSObject <NSCopying>

@property(nonatomic) MTLAccelerationStructureInstanceDescriptorType instanceDescriptorType;
@property(nonatomic) NSUInteger instanceDescriptorStride;
@property(nonatomic) MTLMatrixLayout instanceTransformationMatrixLayout;
@property(nonatomic) NSUInteger instanceCount;
@property(nullable, nonatomic, retain) NSArray* instancedAccelerationStructures;
@property(nullable, nonatomic, retain) id<MTLBuffer> instanceDescriptorBuffer;
@property(nonatomic) NSUInteger instanceDescriptorBufferOffset;
@property(nonatomic) MTLTransformType motionTransformType;
@property(nonatomic) NSUInteger motionTransformStride;
@property(nonatomic) NSUInteger motionTransformCount;
@property(nullable, nonatomic, retain) id<MTLBuffer> motionTransformBuffer;
@property(nonatomic) NSUInteger motionTransformBufferOffset;
@property(nullable, nonatomic, copy) NSString* label;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLACCELERATIONSTRUCTUREDESCRIPTOR_H_
