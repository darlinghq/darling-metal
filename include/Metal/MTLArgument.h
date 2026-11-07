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

@interface MTLStructMember : NSObject

@property(readonly) NSString* name;
@property(readonly) NSUInteger offset;

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

@interface MTLComputePipelineReflection : NSObject

@property(readonly) NSArray<MTLArgument*>* arguments;

@end

@interface MTLRenderPipelineReflection : NSObject

@property(readonly) NSArray<MTLArgument*>* vertexArguments;
@property(readonly) NSArray<MTLArgument*>* fragmentArguments;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLARGUMENT_H_
