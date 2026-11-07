// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLDEVICE_H_
#define _METAL_MTLDEVICE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLResource.h>
#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLComputePipelineState;
@protocol MTLFunction;
@protocol MTLCommandQueue;
@protocol MTLDevice;
@protocol MTLBuffer;
@protocol MTLLibrary;
@protocol MTLRenderPipelineState;
@protocol MTLTexture;
@protocol MTLDepthStencilState;
@protocol MTLSamplerState;

@class MTLComputePipelineDescriptor;
@class MTLComputePipelineReflection;
@class MTLRenderPipelineReflection;
@class MTLDepthStencilDescriptor;
@class MTLRenderPipelineDescriptor;
@class MTLSamplerDescriptor;
@class MTLTextureDescriptor;

typedef NS_OPTIONS(NSUInteger, MTLPipelineOption) {
	MTLPipelineOptionNone = 0,
	MTLPipelineOptionArgumentInfo = 1 << 0,
	MTLPipelineOptionBufferTypeInfo = 1 << 1,
	MTLPipelineOptionFailOnBinaryArchiveMiss = 1 << 2,
};

typedef __autoreleasing MTLComputePipelineReflection* MTLAutoreleasedComputePipelineReflection;
typedef __autoreleasing MTLRenderPipelineReflection* MTLAutoreleasedRenderPipelineReflection;

typedef NSString* MTLDeviceNotificationName;
typedef void (^MTLDeviceNotificationHandler)(id<MTLDevice> device, MTLDeviceNotificationName notifyName);

MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasAddedNotification;
MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceRemovalRequestedNotification;
MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasRemovedNotification;

MTL_EXPORT id<MTLDevice> MTLCreateSystemDefaultDevice(void);
MTL_EXPORT NSArray<id<MTLDevice>>* MTLCopyAllDevices(void);
MTL_EXPORT NSArray<id<MTLDevice>>* MTLCopyAllDevicesWithObserver(id<NSObject>* observer, MTLDeviceNotificationHandler handler);
MTL_EXPORT void MTLRemoveDeviceObserver(id<NSObject> observer);

typedef NS_ENUM(NSUInteger, MTLFeatureSet) {
	MTLFeatureSet_iOS_GPUFamily1_v1 = 0,
	MTLFeatureSet_iOS_GPUFamily2_v1 = 1,
	MTLFeatureSet_iOS_GPUFamily1_v2 = 2,
	MTLFeatureSet_iOS_GPUFamily2_v2 = 3,
	MTLFeatureSet_iOS_GPUFamily3_v1 = 4,
	MTLFeatureSet_iOS_GPUFamily1_v3 = 5,
	MTLFeatureSet_iOS_GPUFamily2_v3 = 6,
	MTLFeatureSet_iOS_GPUFamily3_v2 = 7,
	MTLFeatureSet_iOS_GPUFamily1_v4 = 8,
	MTLFeatureSet_iOS_GPUFamily2_v4 = 9,
	MTLFeatureSet_iOS_GPUFamily3_v3 = 10,
	MTLFeatureSet_iOS_GPUFamily4_v1 = 11,
	MTLFeatureSet_iOS_GPUFamily1_v5 = 12,
	MTLFeatureSet_iOS_GPUFamily2_v5 = 13,
	MTLFeatureSet_iOS_GPUFamily3_v4 = 14,
	MTLFeatureSet_iOS_GPUFamily4_v2 = 15,
	MTLFeatureSet_iOS_GPUFamily5_v1 = 16,

	MTLFeatureSet_macOS_GPUFamily1_v1 = 10000,
	MTLFeatureSet_OSX_GPUFamily1_v1 = MTLFeatureSet_macOS_GPUFamily1_v1,
	MTLFeatureSet_macOS_GPUFamily1_v2 = 10001,
	MTLFeatureSet_OSX_GPUFamily1_v2 = MTLFeatureSet_macOS_GPUFamily1_v2,
	MTLFeatureSet_macOS_ReadWriteTextureTier2 = 10002,
	MTLFeatureSet_OSX_ReadWriteTextureTier2 = MTLFeatureSet_macOS_ReadWriteTextureTier2,
	MTLFeatureSet_macOS_GPUFamily1_v3 = 10003,
	MTLFeatureSet_macOS_GPUFamily1_v4 = 10004,
	MTLFeatureSet_macOS_GPUFamily2_v1 = 10005,

	MTLFeatureSet_tvOS_GPUFamily1_v1 = 30000,
	MTLFeatureSet_TVOS_GPUFamily1_v1 = MTLFeatureSet_tvOS_GPUFamily1_v1,
	MTLFeatureSet_tvOS_GPUFamily1_v2 = 30001,
	MTLFeatureSet_tvOS_GPUFamily1_v3 = 30002,
	MTLFeatureSet_tvOS_GPUFamily2_v1 = 30003,
	MTLFeatureSet_tvOS_GPUFamily1_v4 = 30004,
	MTLFeatureSet_tvOS_GPUFamily2_v2 = 30005,
};

typedef NS_ENUM(NSInteger, MTLGPUFamily) {
	MTLGPUFamilyApple1 = 1001,
	MTLGPUFamilyApple2 = 1002,
	MTLGPUFamilyApple3 = 1003,
	MTLGPUFamilyApple4 = 1004,
	MTLGPUFamilyApple5 = 1005,
	MTLGPUFamilyApple6 = 1006,
	MTLGPUFamilyApple7 = 1007,
	MTLGPUFamilyApple8 = 1008,
	MTLGPUFamilyApple9 = 1009,
	MTLGPUFamilyApple10 = 1010,
	MTLGPUFamilyApple11 = 1011,

	MTLGPUFamilyMac1 = 2001,
	MTLGPUFamilyMac2 = 2002,

	MTLGPUFamilyCommon1 = 3001,
	MTLGPUFamilyCommon2 = 3002,
	MTLGPUFamilyCommon3 = 3003,

	MTLGPUFamilyMacCatalyst1 = 4001,
	MTLGPUFamilyMacCatalyst2 = 4002,

	MTLGPUFamilyMetal3 = 5001,
	MTLGPUFamilyMetal4 = 5002,
};

typedef NS_ENUM(NSUInteger, MTLReadWriteTextureTier) {
	MTLReadWriteTextureTierNone = 0,
	MTLReadWriteTextureTier1 = 1,
	MTLReadWriteTextureTier2 = 2,
};

@protocol MTLDevice <NSObject>

@property(readonly, nonnull) NSString* name;
@property(readonly) uint64_t registryID;
@property(readonly, getter=isLowPower) BOOL lowPower;
@property(readonly, getter=isHeadless) BOOL headless;
@property(readonly, getter=isRemovable) BOOL removable;
@property(readonly) BOOL hasUnifiedMemory;
@property(readonly) uint64_t recommendedMaxWorkingSetSize;
@property(readonly) NSUInteger maxBufferLength;
@property(readonly, getter=isDepth24Stencil8PixelFormatSupported) BOOL depth24Stencil8PixelFormatSupported;
@property(readonly) MTLReadWriteTextureTier readWriteTextureSupport;

- (BOOL)supportsFamily: (MTLGPUFamily)gpuFamily;
- (BOOL)supportsFeatureSet: (MTLFeatureSet)featureSet;
- (BOOL)supportsTextureSampleCount: (NSUInteger)sampleCount;

- (id<MTLCommandQueue>)newCommandQueueWithMaxCommandBufferCount: (NSUInteger)maxCommandBufferCount;

- (id<MTLComputePipelineState>)newComputePipelineStateWithDescriptor: (MTLComputePipelineDescriptor*)descriptor
                                                             options: (MTLPipelineOption)options
                                                          reflection: (MTLAutoreleasedComputePipelineReflection*)reflection
                                                               error: (NSError**)error;

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction 
                                                             error: (NSError**)error;

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction 
                                                           options: (MTLPipelineOption)options 
                                                        reflection: (MTLAutoreleasedComputePipelineReflection*)reflection 
                                                             error: (NSError**)error;

- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                                             error: (NSError**)error;
- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                                           options: (MTLPipelineOption)options
                                                        reflection: (MTLAutoreleasedRenderPipelineReflection*)reflection
                                                             error: (NSError**)error;

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor;

- (id<MTLSamplerState>)newSamplerStateWithDescriptor: (MTLSamplerDescriptor*)descriptor;

- (id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor: (MTLDepthStencilDescriptor*)descriptor;

- (id<MTLCommandQueue>)newCommandQueue;

- (id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                             options: (MTLResourceOptions)options;

- (id<MTLBuffer>)newBufferWithBytes: (const void*)pointer
                             length: (NSUInteger)length
                            options: (MTLResourceOptions)options;

- (id<MTLLibrary>)newDefaultLibrary;

- (id<MTLLibrary>)newDefaultLibraryWithBundle: (NSBundle*)bundle
                                        error: (NSError**)error;

- (id<MTLLibrary>)newLibraryWithURL: (NSURL*)url
                              error: (NSError**)error;

- (id<MTLLibrary>)newLibraryWithData: (dispatch_data_t)data
                               error: (NSError**)error;

// TODO: other methods and properties

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLDEVICE_H_
