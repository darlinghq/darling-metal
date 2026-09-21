// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METALKIT_MTKMODEL_H_
#define _METALKIT_MTKMODEL_H_

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@class MDLAsset;
@class MDLMesh;
@class MDLVertexDescriptor;

MTL_EXPORT
@interface MTKMeshBufferAllocator : NSObject

- (instancetype)initWithDevice: (id<MTLDevice>)device;

@end

MTL_EXPORT
@interface MTKMesh : NSObject

- (instancetype)initWithMesh: (MDLMesh*)mesh
                      device: (id<MTLDevice>)device
                       error: (NSError**)error;

+ (NSArray<MTKMesh*>*)newMeshesFromAsset: (MDLAsset*)asset
                                  device: (id<MTLDevice>)device
                            sourceMeshes: (NSArray<MDLMesh*>**)sourceMeshes
                                   error: (NSError**)error;

@end

MTL_EXPORT MTL_EXTERN MDLVertexDescriptor* MTKModelIOVertexDescriptorFromMetal(MTLVertexDescriptor* metalDescriptor);

#endif // _METALKIT_MTKMODEL_H_
