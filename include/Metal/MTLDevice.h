// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLDEVICE_H_
#define _METAL_MTLDEVICE_H_

#import <Foundation/Foundation.h>
#import <IOSurface/IOSurfaceRef.h>

#import <Metal/MTLResource.h>
#import <Metal/MTLPixelFormat.h>
#import <Metal/MTLTypes.h>
#import <Metal/MTLDefines.h>
#import <Metal/MTLEvent.h>
#import <Metal/MTLFence.h>
#import <Metal/MTLCounters.h>

METAL_DECLARATIONS_BEGIN

// What a resource takes in a heap: its size, and the alignment of the offset it is placed at.
typedef struct MTLSizeAndAlign {
	NSUInteger size;
	NSUInteger align;
} MTLSizeAndAlign;

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
@protocol MTLHeap;
@class MTLHeapDescriptor;
@protocol MTLCounterSet;
@protocol MTLCounterSampleBuffer;
@class MTLCounterSampleBufferDescriptor;
@protocol MTLBinaryArchive;
@class MTLBinaryArchiveDescriptor;
@protocol MTLResidencySet;
@class MTLResidencySetDescriptor;

@class MTLCompileOptions;
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
	MTLPipelineOptionBindingInfo = MTLPipelineOptionArgumentInfo,
	MTLPipelineOptionBufferTypeInfo = 1 << 1,
	MTLPipelineOptionFailOnBinaryArchiveMiss = 1 << 2,
};

typedef NS_ENUM(NSUInteger, MTLDeviceLocation) {
	MTLDeviceLocationBuiltIn = 0,
	MTLDeviceLocationSlot = 1,
	MTLDeviceLocationExternal = 2,
	MTLDeviceLocationUnspecified = NSUIntegerMax,
};

typedef __autoreleasing MTLComputePipelineReflection* MTLAutoreleasedComputePipelineReflection;
typedef __autoreleasing MTLRenderPipelineReflection* MTLAutoreleasedRenderPipelineReflection;

typedef void (^MTLNewComputePipelineStateCompletionHandler)(id<MTLComputePipelineState> computePipelineState, NSError* error);
typedef void (^MTLNewComputePipelineStateWithReflectionCompletionHandler)(id<MTLComputePipelineState> computePipelineState, MTLComputePipelineReflection* reflection, NSError* error);
typedef void (^MTLNewRenderPipelineStateCompletionHandler)(id<MTLRenderPipelineState> renderPipelineState, NSError* error);
typedef void (^MTLNewRenderPipelineStateWithReflectionCompletionHandler)(id<MTLRenderPipelineState> renderPipelineState, MTLRenderPipelineReflection* reflection, NSError* error);

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

typedef NS_ENUM(NSUInteger, MTLArgumentBuffersTier) {
	MTLArgumentBuffersTier1 = 0,
	MTLArgumentBuffersTier2 = 1,
};

typedef NS_ENUM(NSUInteger, MTLReadWriteTextureTier) {
	MTLReadWriteTextureTierNone = 0,
	MTLReadWriteTextureTier1 = 1,
	MTLReadWriteTextureTier2 = 2,
};

typedef uint64_t MTLTimestamp;

// The points in a pass at which a device can take a counter sample.
typedef NS_ENUM(NSUInteger, MTLCounterSamplingPoint) {
	MTLCounterSamplingPointAtStageBoundary = 0,
	MTLCounterSamplingPointAtDrawBoundary = 1,
	MTLCounterSamplingPointAtDispatchBoundary = 2,
	MTLCounterSamplingPointAtTileDispatchBoundary = 3,
	MTLCounterSamplingPointAtBlitBoundary = 4,
};

@protocol MTLDevice <NSObject>

@property(readonly, nonnull) NSString* name;
@property(readonly) uint64_t registryID;
@property(readonly, getter=isLowPower) BOOL lowPower;
@property(readonly, getter=isHeadless) BOOL headless;
@property(readonly, getter=isRemovable) BOOL removable;
@property(readonly) BOOL hasUnifiedMemory;
@property(readonly) uint64_t recommendedMaxWorkingSetSize;
// The bytes of memory currently allocated for the device's buffers, textures and heaps.
@property(readonly) NSUInteger currentAllocatedSize;
@property(readonly) NSUInteger maxBufferLength;
@property(readonly) MTLSize maxThreadsPerThreadgroup;
@property(readonly) NSUInteger maxThreadgroupMemoryLength;
@property(readonly, getter=isDepth24Stencil8PixelFormatSupported) BOOL depth24Stencil8PixelFormatSupported;
@property(readonly) MTLReadWriteTextureTier readWriteTextureSupport;

- (BOOL)supportsFamily: (MTLGPUFamily)gpuFamily;
- (BOOL)supportsFeatureSet: (MTLFeatureSet)featureSet;
- (BOOL)supportsTextureSampleCount: (NSUInteger)sampleCount;

/* Whether R32Float, RG32Float and RGBA32Float textures can be sampled with linear filtering. */
@property(readonly) BOOL supports32BitFloatFiltering;

/* Whether the block-compressed BC1 to BC7 texture formats can be sampled. */
@property(readonly) BOOL supportsBCTextureCompression;

/* Always NO: Vulkan has no interpolate-at-offset/sample/centroid operations to lower the
 * shader's pull-model calls onto. */
@property(readonly) BOOL supportsPullModelInterpolation;

/* Always NO: Vulkan has no equivalent of a shader-programmable sample position table. */
@property(readonly, getter=areProgrammableSamplePositionsSupported) BOOL programmableSamplePositionsSupported;

/* Always NO: raster order groups need fragment ordering that indium does not provide. */
@property(readonly, getter=areRasterOrderGroupsSupported) BOOL rasterOrderGroupsSupported;

/* Where the GPU sits, from the kind of Vulkan device: integrated is built in, discrete is in a
 * slot, anything else (virtual, software) is unspecified. */
@property(readonly) MTLDeviceLocation location;

/* For a built-in GPU 0 when it is the low-power one and 1 otherwise; 0 for other locations. */
@property(readonly) NSUInteger locationNumber;

/* 0: Apple specifies 0 for built-in GPUs, and Vulkan reports no link rate for the others. */
@property(readonly) uint64_t maxTransferRate;

/* The counter sets the device can sample: only the timestamp set, and none where the device cannot sample timestamps. */
@property(readonly, nullable) NSArray<id<MTLCounterSet>>* counterSets;

/* Reports Tier 1 argument buffers support (baseline tier). indium does not
 * implement Tier 2 argument buffers. */
- (MTLArgumentBuffersTier)argumentBuffersSupport;

/* Also NO for want of an implementation rather than for want of hardware.
 * Barycentric coordinates are a fragment-shader interpolation decoration, and
 * Vulkan has no equivalent, so there is nothing for indium to lower a shader's
 * use of them onto. A caller told YES would emit a shader whose output no
 * longer means what it says. */
- (BOOL)supportsShaderBarycentricCoordinates;

/* NO: indium has no variable rasterization rate to give a rate map to, so
 * there are no rate maps to make. */
- (BOOL)supportsRasterizationRateMapWithLayerCount: (NSUInteger)layerCount;

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

/* The asynchronous variants create the pipeline state on another thread and call the handler exactly once, on a thread of
 * their own (not the caller's), with either the state or an error. */
- (void)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction
                          completionHandler: (MTLNewComputePipelineStateCompletionHandler)completionHandler;

- (void)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction
                                    options: (MTLPipelineOption)options
                          completionHandler: (MTLNewComputePipelineStateWithReflectionCompletionHandler)completionHandler;

- (void)newComputePipelineStateWithDescriptor: (MTLComputePipelineDescriptor*)descriptor
                                      options: (MTLPipelineOption)options
                            completionHandler: (MTLNewComputePipelineStateWithReflectionCompletionHandler)completionHandler;

- (void)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                           completionHandler: (MTLNewRenderPipelineStateCompletionHandler)completionHandler;

- (void)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                     options: (MTLPipelineOption)options
                           completionHandler: (MTLNewRenderPipelineStateWithReflectionCompletionHandler)completionHandler;

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor;

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor
                                 iosurface: (IOSurfaceRef)iosurface
                                     plane: (NSUInteger)plane;

- (id<MTLSamplerState>)newSamplerStateWithDescriptor: (MTLSamplerDescriptor*)descriptor;

- (id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor: (MTLDepthStencilDescriptor*)descriptor;

- (id<MTLCommandQueue>)newCommandQueue;

- (id<MTLEvent>)newEvent;
- (id<MTLSharedEvent>)newSharedEvent;

/* The event the handle names, as an object of its own that shares the value; nil for a handle of another device. */
- (nullable id<MTLSharedEvent>)newSharedEventWithHandle: (MTLSharedEventHandle*)sharedEventHandle;
- (id<MTLFence>)newFence;

- (id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                             options: (MTLResourceOptions)options;

// The row alignment, in bytes, of a texture made from a buffer in `format`: its bytesPerRow is a multiple of it.
- (NSUInteger)minimumLinearTextureAlignmentForPixelFormat: (MTLPixelFormat)format;

// A heap of device memory to make buffers and textures from. nil for a descriptor with a size of 0, a sparse heap, a heap
// with a storage mode other than shared and private, or a size the device cannot allocate.
- (nullable id<MTLHeap>)newHeapWithDescriptor: (MTLHeapDescriptor*)descriptor;

// What a buffer or texture takes in a heap on this device, and the alignment of the offset it must be placed at in a
// placement heap. These are the device's own requirements; the sizes include its rounding, and are what a heap counts
// (usedSize) and what the resource reports as its allocatedSize.
- (MTLSizeAndAlign)heapBufferSizeAndAlignWithLength: (NSUInteger)length
                                            options: (MTLResourceOptions)options;
- (MTLSizeAndAlign)heapTextureSizeAndAlignWithDescriptor: (MTLTextureDescriptor*)desc;

// The host and device clocks sampled together, in nanoseconds. Where the driver cannot correlate the two, both are
// the host's monotonic clock.
- (void)sampleTimestamps: (MTLTimestamp*)cpuTimestamp
            gpuTimestamp: (MTLTimestamp*)gpuTimestamp;

// Whether a sample can be taken at `samplingPoint`: stage, dispatch and blit boundaries where the device samples
// timestamps; never draw or tile dispatch boundaries.
- (BOOL)supportsCounterSampling: (MTLCounterSamplingPoint)samplingPoint;

// Allocates a sample buffer for the descriptor's counter set. Returns nil and sets MTLCounterErrorDomain's
// MTLCounterSampleBufferErrorInvalid if the counter set is not one of -counterSets or the sample count is not
// in 1...4096.
- (nullable id<MTLCounterSampleBuffer>)newCounterSampleBufferWithDescriptor: (MTLCounterSampleBufferDescriptor*)descriptor
                                                                      error: (NSError**)error;

- (id<MTLBuffer>)newBufferWithBytes: (const void*)pointer
                             length: (NSUInteger)length
                            options: (MTLResourceOptions)options;

// A buffer over memory the application owns: contents is `pointer` itself, with no copy, and what the CPU and the GPU write
// to it is seen by both. `pointer` and `length` need not be aligned, and `options` must use the shared or the managed storage mode.
// `deallocator`, if not nil, is called with the pointer and length once the buffer has been released and the GPU is done
// with it, on an unspecified thread, and the memory must stay valid until then. nil (and no deallocator call) for a null
// pointer, a length of 0 or another storage mode. If the device cannot import the memory, the buffer has memory of its own
// that is copied from `pointer` when a command buffer is committed and back when one completes, and a warning is printed
// to stderr once.
- (nullable id<MTLBuffer>)newBufferWithBytesNoCopy: (void*)pointer
                                            length: (NSUInteger)length
                                           options: (MTLResourceOptions)options
                                       deallocator: (void (^ _Nullable)(void* pointer, NSUInteger length))deallocator;

- (id<MTLLibrary>)newDefaultLibrary;

- (id<MTLLibrary>)newDefaultLibraryWithBundle: (NSBundle*)bundle
                                        error: (NSError**)error;

- (id<MTLLibrary>)newLibraryWithURL: (NSURL*)url
                              error: (NSError**)error;

- (id<MTLLibrary>)newLibraryWithData: (dispatch_data_t)data
                               error: (NSError**)error;

- (nullable id<MTLLibrary>)newLibraryWithSource: (NSString*)source
                                        options: (nullable MTLCompileOptions*)options
                                          error: (NSError**)error;

- (nullable id<MTLBinaryArchive>)newBinaryArchiveWithDescriptor: (MTLBinaryArchiveDescriptor*)descriptor
                                                          error: (NSError**)error;

- (nullable id<MTLResidencySet>)newResidencySetWithDescriptor: (MTLResidencySetDescriptor*)descriptor
                                                        error: (NSError**)error;

// TODO: other methods and properties

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLDEVICE_H_
