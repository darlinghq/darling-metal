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

#ifndef _METAL_MTLCOMPUTEPIPELINE_H_
#define _METAL_MTLCOMPUTEPIPELINE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLTypes.h>
#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLFunctionHandle;
@protocol MTLComputePipelineState;
@protocol MTLFunction;
@protocol MTLVisibleFunctionTable;
@protocol MTLIntersectionFunctionTable;
@protocol MTLDynamicLibrary;
@protocol MTLBinaryArchive;

@class MTLVisibleFunctionTableDescriptor;
@class MTLIntersectionFunctionTableDescriptor;
@class MTLStageInputOutputDescriptor;
@class MTLPipelineBufferDescriptorArray;
@class MTLLinkedFunctions;

MTL_EXPORT
@interface MTLComputePipelineDescriptor : NSObject <NSCopying>

@property(readwrite, nullable, nonatomic, strong) id<MTLFunction> computeFunction;
@property(readwrite, nonatomic) BOOL threadGroupSizeIsMultipleOfThreadExecutionWidth;
@property(readwrite, nonatomic) NSUInteger maxTotalThreadsPerThreadgroup;
@property(readwrite, nonatomic) NSUInteger maxCallStackDepth;
@property(readwrite, nullable, copy, nonatomic) MTLStageInputOutputDescriptor* stageInputDescriptor;
@property(readonly) MTLPipelineBufferDescriptorArray* buffers;
@property(readwrite, nonatomic) BOOL supportIndirectCommandBuffers;
@property(readwrite, nonnull, nonatomic, copy) NSArray<id<MTLDynamicLibrary>>* preloadedLibraries;
@property(readwrite, nullable, nonatomic, copy) NSArray<id<MTLDynamicLibrary>>* insertLibraries;
@property(readwrite, nullable, copy, nonatomic) MTLLinkedFunctions* linkedFunctions;
@property(readwrite, nonatomic) BOOL supportAddingBinaryFunctions;
@property(readwrite, nullable, nonatomic, copy) NSArray<id<MTLBinaryArchive>>* binaryArchives;
@property(nullable, copy, atomic) NSString* label;

- (void)reset;

@end

@protocol MTLComputePipelineState <NSObject>

@property(readonly) NSUInteger maxTotalThreadsPerThreadgroup;
@property(readonly) NSUInteger threadExecutionWidth;
@property(readonly) NSUInteger staticThreadgroupMemoryLength;
@property(readonly) id<MTLDevice> device;
@property(readonly) BOOL supportIndirectCommandBuffers;
@property(readonly) NSString* label;

- (NSUInteger)imageblockMemoryLengthForDimensions: (MTLSize)imageblockDimensions;

- (id<MTLFunctionHandle>)functionHandleWithFunction: (id<MTLFunction>)function;

- (id<MTLComputePipelineState>)newComputePipelineStateWithAdditionalBinaryFunctions: (NSArray<id<MTLFunction>>*)functions 
                                                                              error: (NSError**)error;

- (id<MTLVisibleFunctionTable>)newVisibleFunctionTableWithDescriptor: (MTLVisibleFunctionTableDescriptor*)descriptor;

- (id<MTLIntersectionFunctionTable>)newIntersectionFunctionTableWithDescriptor: (MTLIntersectionFunctionTableDescriptor*)descriptor;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOMPUTEPIPELINE_H_
