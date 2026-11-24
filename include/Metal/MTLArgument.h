// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLARGUMENT_H_
#define _METAL_MTLARGUMENT_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLArgumentDescriptor.h>

METAL_DECLARATIONS_BEGIN

typedef NS_ENUM(NSUInteger, MTLArgumentType) {
	MTLArgumentTypeBuffer = 0,
	MTLArgumentTypeThreadgroupMemory = 1,
	MTLArgumentTypeTexture = 2,
	MTLArgumentTypeSampler = 3,
	MTLArgumentTypeImageblockData = 16,
	MTLArgumentTypeImageblock = 17,
	MTLArgumentTypeVisibleFunctionTable = 24,
	MTLArgumentTypePrimitiveAccelerationStructure = 25,
	MTLArgumentTypeInstanceAccelerationStructure = 26,
	MTLArgumentTypeIntersectionFunctionTable = 27,
};

typedef NS_ENUM(NSInteger, MTLBindingType) {
	MTLBindingTypeBuffer = 0,
	MTLBindingTypeThreadgroupMemory = 1,
	MTLBindingTypeTexture = 2,
	MTLBindingTypeSampler = 3,
	MTLBindingTypeImageblockData = 16,
	MTLBindingTypeImageblock = 17,
	MTLBindingTypeVisibleFunctionTable = 24,
	MTLBindingTypePrimitiveAccelerationStructure = 25,
	MTLBindingTypeInstanceAccelerationStructure = 26,
	MTLBindingTypeIntersectionFunctionTable = 27,
	MTLBindingTypeObjectPayload = 34,
	MTLBindingTypeTensor = 37,
};

@class MTLPointerType;

@interface MTLStructMember : NSObject

@property(readonly) NSString* name;
@property(readonly) NSUInteger offset;
@property(readonly) MTLDataType dataType;

@end

@interface MTLStructType : NSObject

@property(readonly) NSArray<MTLStructMember*>* members;

- (MTLStructMember*)memberByName: (NSString*)name;

@end

@interface MTLArgument : NSObject

@property(readonly) NSString* name;
@property(readonly) MTLArgumentType type;
@property(readonly) NSUInteger index;
@property(readonly, getter=isActive) BOOL active;
@property(readonly) NSUInteger bufferAlignment;
@property(readonly) NSUInteger bufferDataSize;
@property(readonly) MTLStructType* bufferStructType;

@end

@protocol MTLBinding <NSObject>

@property(readonly, nonnull) NSString* name;
@property(readonly) MTLBindingType type;
@property(readonly) MTLBindingAccess access;
@property(readonly) NSUInteger index;
@property(readonly, getter=isUsed) BOOL used;
@property(readonly, getter=isArgument) BOOL argument;

@end

@protocol MTLBufferBinding <MTLBinding>

@property(readonly) NSUInteger bufferAlignment;
@property(readonly) NSUInteger bufferDataSize;
@property(readonly) MTLDataType bufferDataType;
@property(readonly, nullable) MTLStructType* bufferStructType;
@property(readonly, nullable) MTLPointerType* bufferPointerType;

@end

@protocol MTLTextureBinding <MTLBinding>

@property(readonly) MTLTextureType textureType;
@property(readonly) MTLDataType textureDataType;
@property(readonly, getter=isDepthTexture) BOOL depthTexture;
@property(readonly) NSUInteger arrayLength;

@end

@interface MTLComputePipelineReflection : NSObject

@property(readonly, nonnull) NSArray<id<MTLBinding>>* bindings;
@property(readonly) NSArray<MTLArgument*>* arguments;

@end

@interface MTLRenderPipelineReflection : NSObject

@property(readonly, nonnull) NSArray<id<MTLBinding>>* vertexBindings;
@property(readonly, nonnull) NSArray<id<MTLBinding>>* fragmentBindings;
@property(readonly) NSArray<MTLArgument*>* vertexArguments;
@property(readonly) NSArray<MTLArgument*>* fragmentArguments;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLARGUMENT_H_
