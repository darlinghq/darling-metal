// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLAccelerationStructureGeometryDescriptor.h>

@implementation MTLAccelerationStructureGeometryDescriptor

- (id)copyWithZone: (NSZone*)zone
{
	return [[MTLAccelerationStructureGeometryDescriptor allocWithZone: zone] init];
}

@end

// Every subclass below is a bag of stored values with an independent copy, so
// the two are written out per class rather than generated: a macro that walked
// the property list would need either a runtime property walk or a hand-kept
// list of names, and either would be a second place to forget one. Each -copy
// names every property its class declares, so a property added to a header
// without a line here fails to compile at the -copyWithZone: that omits it only
// if the compiler is told to warn, which is why each class re-declares its
// properties as @synthesize: a missing @synthesize is a warning, not an error,
// so the copy is the place that is checked by the compiler reading it.

@implementation MTLAccelerationStructureTriangleGeometryDescriptor

@synthesize vertexBuffer = _vertexBuffer;
@synthesize vertexBufferOffset = _vertexBufferOffset;
@synthesize vertexStride = _vertexStride;
@synthesize vertexFormat = _vertexFormat;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexBufferOffset = _indexBufferOffset;
@synthesize indexType = _indexType;
@synthesize triangleCount = _triangleCount;
@synthesize transformationMatrixBuffer = _transformationMatrixBuffer;
@synthesize transformationMatrixBufferOffset = _transformationMatrixBufferOffset;
@synthesize transformationMatrixLayout = _transformationMatrixLayout;

- (void)dealloc
{
	[_vertexBuffer release];
	[_indexBuffer release];
	[_transformationMatrixBuffer release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLAccelerationStructureTriangleGeometryDescriptor* copy =
		[[MTLAccelerationStructureTriangleGeometryDescriptor allocWithZone: zone] init];

	copy.vertexBuffer = _vertexBuffer;
	copy.vertexBufferOffset = _vertexBufferOffset;
	copy.vertexStride = _vertexStride;
	copy.vertexFormat = _vertexFormat;
	copy.indexBuffer = _indexBuffer;
	copy.indexBufferOffset = _indexBufferOffset;
	copy.indexType = _indexType;
	copy.triangleCount = _triangleCount;
	copy.transformationMatrixBuffer = _transformationMatrixBuffer;
	copy.transformationMatrixBufferOffset = _transformationMatrixBufferOffset;
	copy.transformationMatrixLayout = _transformationMatrixLayout;

	return copy;
}

@end

@implementation MTLAccelerationStructureBoundingBoxGeometryDescriptor

@synthesize boundingBoxBuffer = _boundingBoxBuffer;
@synthesize boundingBoxBufferOffset = _boundingBoxBufferOffset;
@synthesize boundingBoxStride = _boundingBoxStride;
@synthesize boundingBoxCount = _boundingBoxCount;

- (void)dealloc
{
	[_boundingBoxBuffer release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLAccelerationStructureBoundingBoxGeometryDescriptor* copy =
		[[MTLAccelerationStructureBoundingBoxGeometryDescriptor allocWithZone: zone] init];

	copy.boundingBoxBuffer = _boundingBoxBuffer;
	copy.boundingBoxBufferOffset = _boundingBoxBufferOffset;
	copy.boundingBoxStride = _boundingBoxStride;
	copy.boundingBoxCount = _boundingBoxCount;

	return copy;
}

@end

@implementation MTLAccelerationStructureMotionTriangleGeometryDescriptor

@synthesize vertexBuffers = _vertexBuffers;
@synthesize vertexStride = _vertexStride;
@synthesize vertexFormat = _vertexFormat;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexBufferOffset = _indexBufferOffset;
@synthesize indexType = _indexType;
@synthesize triangleCount = _triangleCount;
@synthesize transformationMatrixBuffer = _transformationMatrixBuffer;
@synthesize transformationMatrixBufferOffset = _transformationMatrixBufferOffset;
@synthesize transformationMatrixLayout = _transformationMatrixLayout;

- (void)dealloc
{
	[_vertexBuffers release];
	[_indexBuffer release];
	[_transformationMatrixBuffer release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLAccelerationStructureMotionTriangleGeometryDescriptor* copy =
		[[MTLAccelerationStructureMotionTriangleGeometryDescriptor allocWithZone: zone] init];

	copy.vertexBuffers = _vertexBuffers;
	copy.vertexStride = _vertexStride;
	copy.vertexFormat = _vertexFormat;
	copy.indexBuffer = _indexBuffer;
	copy.indexBufferOffset = _indexBufferOffset;
	copy.indexType = _indexType;
	copy.triangleCount = _triangleCount;
	copy.transformationMatrixBuffer = _transformationMatrixBuffer;
	copy.transformationMatrixBufferOffset = _transformationMatrixBufferOffset;
	copy.transformationMatrixLayout = _transformationMatrixLayout;

	return copy;
}

@end

@implementation MTLAccelerationStructureMotionBoundingBoxGeometryDescriptor

@synthesize boundingBoxBuffers = _boundingBoxBuffers;
@synthesize boundingBoxStride = _boundingBoxStride;
@synthesize boundingBoxCount = _boundingBoxCount;

- (void)dealloc
{
	[_boundingBoxBuffers release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLAccelerationStructureMotionBoundingBoxGeometryDescriptor* copy =
		[[MTLAccelerationStructureMotionBoundingBoxGeometryDescriptor allocWithZone: zone] init];

	copy.boundingBoxBuffers = _boundingBoxBuffers;
	copy.boundingBoxStride = _boundingBoxStride;
	copy.boundingBoxCount = _boundingBoxCount;

	return copy;
}

@end

@implementation MTLAccelerationStructureCurveGeometryDescriptor

@synthesize controlPointBuffer = _controlPointBuffer;
@synthesize controlPointBufferOffset = _controlPointBufferOffset;
@synthesize controlPointStride = _controlPointStride;
@synthesize controlPointFormat = _controlPointFormat;
@synthesize controlPointCount = _controlPointCount;
@synthesize radiusBuffer = _radiusBuffer;
@synthesize radiusBufferOffset = _radiusBufferOffset;
@synthesize radiusStride = _radiusStride;
@synthesize radiusFormat = _radiusFormat;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexBufferOffset = _indexBufferOffset;
@synthesize indexType = _indexType;
@synthesize segmentCount = _segmentCount;
@synthesize segmentControlPointCount = _segmentControlPointCount;
@synthesize curveType = _curveType;
@synthesize curveBasis = _curveBasis;
@synthesize curveEndCaps = _curveEndCaps;

- (void)dealloc
{
	[_controlPointBuffer release];
	[_radiusBuffer release];
	[_indexBuffer release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLAccelerationStructureCurveGeometryDescriptor* copy =
		[[MTLAccelerationStructureCurveGeometryDescriptor allocWithZone: zone] init];

	copy.controlPointBuffer = _controlPointBuffer;
	copy.controlPointBufferOffset = _controlPointBufferOffset;
	copy.controlPointStride = _controlPointStride;
	copy.controlPointFormat = _controlPointFormat;
	copy.controlPointCount = _controlPointCount;
	copy.radiusBuffer = _radiusBuffer;
	copy.radiusBufferOffset = _radiusBufferOffset;
	copy.radiusStride = _radiusStride;
	copy.radiusFormat = _radiusFormat;
	copy.indexBuffer = _indexBuffer;
	copy.indexBufferOffset = _indexBufferOffset;
	copy.indexType = _indexType;
	copy.segmentCount = _segmentCount;
	copy.segmentControlPointCount = _segmentControlPointCount;
	copy.curveType = _curveType;
	copy.curveBasis = _curveBasis;
	copy.curveEndCaps = _curveEndCaps;

	return copy;
}

@end

@implementation MTLAccelerationStructureMotionCurveGeometryDescriptor

@synthesize controlPointBuffers = _controlPointBuffers;
@synthesize controlPointStride = _controlPointStride;
@synthesize controlPointFormat = _controlPointFormat;
@synthesize controlPointCount = _controlPointCount;
@synthesize radiusBuffers = _radiusBuffers;
@synthesize radiusStride = _radiusStride;
@synthesize radiusFormat = _radiusFormat;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexBufferOffset = _indexBufferOffset;
@synthesize indexType = _indexType;
@synthesize segmentCount = _segmentCount;
@synthesize segmentControlPointCount = _segmentControlPointCount;
@synthesize curveType = _curveType;
@synthesize curveBasis = _curveBasis;
@synthesize curveEndCaps = _curveEndCaps;

- (void)dealloc
{
	[_controlPointBuffers release];
	[_radiusBuffers release];
	[_indexBuffer release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLAccelerationStructureMotionCurveGeometryDescriptor* copy =
		[[MTLAccelerationStructureMotionCurveGeometryDescriptor allocWithZone: zone] init];

	copy.controlPointBuffers = _controlPointBuffers;
	copy.controlPointStride = _controlPointStride;
	copy.controlPointFormat = _controlPointFormat;
	copy.controlPointCount = _controlPointCount;
	copy.radiusBuffers = _radiusBuffers;
	copy.radiusStride = _radiusStride;
	copy.radiusFormat = _radiusFormat;
	copy.indexBuffer = _indexBuffer;
	copy.indexBufferOffset = _indexBufferOffset;
	copy.indexType = _indexType;
	copy.segmentCount = _segmentCount;
	copy.segmentControlPointCount = _segmentControlPointCount;
	copy.curveType = _curveType;
	copy.curveBasis = _curveBasis;
	copy.curveEndCaps = _curveEndCaps;

	return copy;
}

@end
