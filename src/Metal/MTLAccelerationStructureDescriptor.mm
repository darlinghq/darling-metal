// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLAccelerationStructureDescriptor.h>

@implementation MTLPrimitiveAccelerationStructureDescriptor

@synthesize geometryDescriptors = _geometryDescriptors;
@synthesize motionKeyframeCount = _motionKeyframeCount;
@synthesize motionStartTime = _motionStartTime;
@synthesize motionStartBorderMode = _motionStartBorderMode;
@synthesize motionEndTime = _motionEndTime;
@synthesize motionEndBorderMode = _motionEndBorderMode;
@synthesize label = _label;

- (void)dealloc
{
	[_geometryDescriptors release];
	[_label release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLPrimitiveAccelerationStructureDescriptor* copy =
		[[MTLPrimitiveAccelerationStructureDescriptor allocWithZone: zone] init];

	copy.geometryDescriptors = _geometryDescriptors;
	copy.motionKeyframeCount = _motionKeyframeCount;
	copy.motionStartTime = _motionStartTime;
	copy.motionStartBorderMode = _motionStartBorderMode;
	copy.motionEndTime = _motionEndTime;
	copy.motionEndBorderMode = _motionEndBorderMode;
	copy.label = _label;

	return copy;
}

@end

@implementation MTLInstanceAccelerationStructureDescriptor

@synthesize instanceDescriptorType = _instanceDescriptorType;
@synthesize instanceDescriptorStride = _instanceDescriptorStride;
@synthesize instanceTransformationMatrixLayout = _instanceTransformationMatrixLayout;
@synthesize instanceCount = _instanceCount;
@synthesize instancedAccelerationStructures = _instancedAccelerationStructures;
@synthesize instanceDescriptorBuffer = _instanceDescriptorBuffer;
@synthesize instanceDescriptorBufferOffset = _instanceDescriptorBufferOffset;
@synthesize motionTransformType = _motionTransformType;
@synthesize motionTransformStride = _motionTransformStride;
@synthesize motionTransformCount = _motionTransformCount;
@synthesize motionTransformBuffer = _motionTransformBuffer;
@synthesize motionTransformBufferOffset = _motionTransformBufferOffset;
@synthesize label = _label;

- (void)dealloc
{
	[_instancedAccelerationStructures release];
	[_instanceDescriptorBuffer release];
	[_motionTransformBuffer release];
	[_label release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLInstanceAccelerationStructureDescriptor* copy =
		[[MTLInstanceAccelerationStructureDescriptor allocWithZone: zone] init];

	copy.instanceDescriptorType = _instanceDescriptorType;
	copy.instanceDescriptorStride = _instanceDescriptorStride;
	copy.instanceTransformationMatrixLayout = _instanceTransformationMatrixLayout;
	copy.instanceCount = _instanceCount;
	copy.instancedAccelerationStructures = _instancedAccelerationStructures;
	copy.instanceDescriptorBuffer = _instanceDescriptorBuffer;
	copy.instanceDescriptorBufferOffset = _instanceDescriptorBufferOffset;
	copy.motionTransformType = _motionTransformType;
	copy.motionTransformStride = _motionTransformStride;
	copy.motionTransformCount = _motionTransformCount;
	copy.motionTransformBuffer = _motionTransformBuffer;
	copy.motionTransformBufferOffset = _motionTransformBufferOffset;
	copy.label = _label;

	return copy;
}

@end
