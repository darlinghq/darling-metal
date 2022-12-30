/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _METAL_MTLRENDERPIPELINE_H_
#define _METAL_MTLRENDERPIPELINE_H_

#import <Metal/MTLDefines.h>
#import <Foundation/Foundation.h>
#import <Metal/MTLPipeline.h>
#import <Metal/MTLPixelFormat.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLFunction;
@protocol MTLBinaryArchive;
@protocol MTLDynamicLibrary;
@protocol MTLDevice;
@class MTLVertexDescriptor;
@class MTLRenderPipelineColorAttachmentDescriptorArray;
@class MTLLinkedFunctions;
@class MTLRenderPipelineColorAttachmentDescriptor;

typedef NS_ENUM(NSUInteger, MTLPrimitiveTopologyClass) {
	MTLPrimitiveTopologyClassUnspecified = 0,
	MTLPrimitiveTopologyClassPoint = 1,
	MTLPrimitiveTopologyClassLine = 2,
	MTLPrimitiveTopologyClassTriangle = 3,
};

typedef NS_ENUM(NSUInteger, MTLWinding) {
	MTLWindingClockwise = 0,
	MTLWindingCounterClockwise = 1,
};

typedef NS_ENUM(NSUInteger, MTLTessellationFactorFormat) {
	MTLTessellationFactorFormatHalf = 0,
};

typedef NS_ENUM(NSUInteger, MTLTessellationControlPointIndexType) {
	MTLTessellationControlPointIndexTypeNone = 0,
	MTLTessellationControlPointIndexTypeUInt16 = 1,
	MTLTessellationControlPointIndexTypeUInt32 = 2,
};

typedef NS_ENUM(NSUInteger, MTLTessellationFactorStepFunction) {
	MTLTessellationFactorStepFunctionConstant = 0,
	MTLTessellationFactorStepFunctionPerPatch = 1,
	MTLTessellationFactorStepFunctionPerInstance = 2,
	MTLTessellationFactorStepFunctionPerPatchAndPerInstance = 3,
};

typedef NS_ENUM(NSUInteger, MTLTessellationPartitionMode) {
	MTLTessellationPartitionModePow2 = 0,
	MTLTessellationPartitionModeInteger = 1,
	MTLTessellationPartitionModeFractionalOdd = 2,
	MTLTessellationPartitionModeFractionalEven = 3,
};

typedef NS_ENUM(NSUInteger, MTLColorWriteMask) {
	MTLColorWriteMaskNone = 0,
	MTLColorWriteMaskAlpha = 1,
	MTLColorWriteMaskBlue = 2,
	MTLColorWriteMaskGreen = 4,
	MTLColorWriteMaskRed = 8,
	MTLColorWriteMaskAll = 15,
};

typedef NS_ENUM(NSUInteger, MTLBlendOperation) {
	MTLBlendOperationAdd = 0,
	MTLBlendOperationSubtract = 1,
	MTLBlendOperationReverseSubtract = 2,
	MTLBlendOperationMin = 3,
	MTLBlendOperationMax = 4,
};

typedef NS_ENUM(NSUInteger, MTLBlendFactor) {
	MTLBlendFactorZero = 0,
	MTLBlendFactorOne = 1,
	MTLBlendFactorSourceColor = 2,
	MTLBlendFactorOneMinusSourceColor = 3,
	MTLBlendFactorSourceAlpha = 4,
	MTLBlendFactorOneMinusSourceAlpha = 5,
	MTLBlendFactorDestinationColor = 6,
	MTLBlendFactorOneMinusDestinationColor = 7,
	MTLBlendFactorDestinationAlpha = 8,
	MTLBlendFactorOneMinusDestinationAlpha = 9,
	MTLBlendFactorSourceAlphaSaturated = 10,
	MTLBlendFactorBlendColor = 11,
	MTLBlendFactorOneMinusBlendColor = 12,
	MTLBlendFactorBlendAlpha = 13,
	MTLBlendFactorOneMinusBlendAlpha = 14,
	MTLBlendFactorSource1Color = 15,
	MTLBlendFactorOneMinusSource1Color = 16,
	MTLBlendFactorSource1Alpha = 17,
	MTLBlendFactorOneMinusSource1Alpha = 18,
};

MTL_EXPORT
@interface MTLRenderPipelineColorAttachmentDescriptor : NSObject <NSCopying>

@property(nonatomic) MTLPixelFormat pixelFormat;
@property(nonatomic) MTLColorWriteMask writeMask;
@property(nonatomic, getter=isBlendingEnabled) BOOL blendingEnabled;
@property(nonatomic) MTLBlendOperation alphaBlendOperation;
@property(nonatomic) MTLBlendOperation rgbBlendOperation;
@property(nonatomic) MTLBlendFactor destinationAlphaBlendFactor;
@property(nonatomic) MTLBlendFactor destinationRGBBlendFactor;
@property(nonatomic) MTLBlendFactor sourceAlphaBlendFactor;
@property(nonatomic) MTLBlendFactor sourceRGBBlendFactor;

@end

MTL_EXPORT
@interface MTLRenderPipelineColorAttachmentDescriptorArray : NSObject

- (MTLRenderPipelineColorAttachmentDescriptor*)objectAtIndexedSubscript:(NSUInteger)attachmentIndex;
-    (void)setObject: (MTLRenderPipelineColorAttachmentDescriptor*)attachment 
  atIndexedSubscript: (NSUInteger)attachmentIndex;

@end

MTL_EXPORT
@interface MTLRenderPipelineDescriptor : NSObject <NSCopying>

@property(nullable, readwrite, nonatomic, strong) id<MTLFunction> vertexFunction;
@property(nullable, readwrite, nonatomic, strong) id<MTLFunction> fragmentFunction;
@property(readwrite, nonatomic) NSUInteger maxVertexCallStackDepth;
@property(readwrite, nonatomic) NSUInteger maxFragmentCallStackDepth;
@property(nullable, copy, nonatomic) MTLVertexDescriptor* vertexDescriptor;
@property(readonly) MTLPipelineBufferDescriptorArray* vertexBuffers;
@property(readonly) MTLPipelineBufferDescriptorArray* fragmentBuffers;
@property(readonly) MTLRenderPipelineColorAttachmentDescriptorArray* colorAttachments;
@property(nonatomic) MTLPixelFormat depthAttachmentPixelFormat;
@property(nonatomic) MTLPixelFormat stencilAttachmentPixelFormat;
@property(readwrite, nonatomic) NSUInteger sampleCount;
@property(readwrite, nonatomic, getter=isAlphaToCoverageEnabled) BOOL alphaToCoverageEnabled;
@property(readwrite, nonatomic, getter=isAlphaToOneEnabled) BOOL alphaToOneEnabled;
@property(readwrite, nonatomic, getter=isRasterizationEnabled) BOOL rasterizationEnabled;
@property(readwrite, nonatomic) MTLPrimitiveTopologyClass inputPrimitiveTopology;
@property(readwrite, nonatomic) NSUInteger rasterSampleCount;
@property(readwrite, nonatomic) NSUInteger maxTessellationFactor;
@property(readwrite, nonatomic, getter=isTessellationFactorScaleEnabled) BOOL tessellationFactorScaleEnabled;
@property(readwrite, nonatomic) MTLTessellationFactorFormat tessellationFactorFormat;
@property(readwrite, nonatomic) MTLTessellationControlPointIndexType tessellationControlPointIndexType;
@property(readwrite, nonatomic) MTLTessellationFactorStepFunction tessellationFactorStepFunction;
@property(readwrite, nonatomic) MTLWinding tessellationOutputWindingOrder;
@property(readwrite, nonatomic) MTLTessellationPartitionMode tessellationPartitionMode;
@property(readwrite, nonatomic) BOOL supportIndirectCommandBuffers;
@property(readwrite, nonatomic) NSUInteger maxVertexAmplificationCount;
@property(readwrite, nonatomic) BOOL supportAddingVertexBinaryFunctions;
@property(readwrite, nonatomic) BOOL supportAddingFragmentBinaryFunctions;
@property(readwrite, nullable, nonatomic, copy) NSArray<id<MTLBinaryArchive>>* binaryArchives;
@property(copy, nonatomic) MTLLinkedFunctions* vertexLinkedFunctions;
@property(copy, nonatomic) MTLLinkedFunctions* fragmentLinkedFunctions;
@property(readwrite, nonnull, nonatomic, copy) NSArray<id<MTLDynamicLibrary>>* fragmentPreloadedLibraries;
@property(readwrite, nonnull, nonatomic, copy) NSArray<id<MTLDynamicLibrary>>* vertexPreloadedLibraries;
@property(nullable, copy, nonatomic) NSString* label;

- (void)reset;

@end

@protocol MTLRenderPipelineState <NSObject>

@property(readonly) id<MTLDevice> device;
@property(readonly) NSString* label;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRENDERPIPELINE_H_
