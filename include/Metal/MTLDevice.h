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

@class MTLComputePipelineDescriptor;
@class MTLAutoreleasedComputePipelineReflection;
@class MTLRenderPipelineDescriptor;
@class MTLTextureDescriptor;

typedef NS_OPTIONS(NSUInteger, MTLPipelineOption) {
	MTLPipelineOptionNone = 0,
	MTLPipelineOptionArgumentInfo = 1 << 0,
	MTLPipelineOptionBufferTypeInfo = 1 << 1,
	MTLPipelineOptionFailOnBinaryArchiveMiss = 1 << 2,
};

typedef NSString* MTLDeviceNotificationName;
typedef void (^MTLDeviceNotificationHandler)(id<MTLDevice> device, MTLDeviceNotificationName notifyName);

MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasAddedNotification;
MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceRemovalRequestedNotification;
MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasRemovedNotification;

MTL_EXPORT id<MTLDevice> MTLCreateSystemDefaultDevice(void);
MTL_EXPORT NSArray<id<MTLDevice>>* MTLCopyAllDevices(void);
MTL_EXPORT NSArray<id<MTLDevice>>* MTLCopyAllDevicesWithObserver(id<NSObject>* observer, MTLDeviceNotificationHandler handler);
MTL_EXPORT void MTLRemoveDeviceObserver(id<NSObject> observer);

@protocol MTLDevice <NSObject>

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

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor;

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
