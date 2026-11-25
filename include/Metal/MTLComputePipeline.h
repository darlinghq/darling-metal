// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

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
@property(readwrite, nonatomic) MTLSize requiredThreadsPerThreadgroup;
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
@property(readonly) MTLSize requiredThreadsPerThreadgroup;
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
