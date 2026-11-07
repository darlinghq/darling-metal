// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLLIBRARY_H_
#define _METAL_MTLLIBRARY_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLLibrary;
@protocol MTLFunction;
@protocol MTLDevice;
@protocol MTLArgumentEncoder;

@class MTLVertexAttribute;
@class MTLAttribute;
@class MTLFunctionConstant;
@class MTLArgument;

typedef __autoreleasing MTLArgument* MTLAutoreleasedArgument;

typedef NS_ENUM(NSUInteger, MTLFunctionType) {
	MTLFunctionTypeVertex = 1,
	MTLFunctionTypeFragment = 2,
	MTLFunctionTypeKernel = 3,
	MTLFunctionTypeVisible = 5,
	MTLFunctionTypeIntersection = 6,
	MTLFunctionTypeMesh = 7,
	MTLFunctionTypeObject = 8,
};

typedef NS_OPTIONS(NSUInteger, MTLFunctionOptions) {
	MTLFunctionOptionNone = 0,
	MTLFunctionOptionCompileToBinary = 1 << 0,
};

typedef NS_ENUM(NSUInteger, MTLPatchType) {
	MTLPatchTypeNone = 0,
	MTLPatchTypeTriangle = 1,
	MTLPatchTypeQuad = 2,
};

typedef NS_ENUM(NSUInteger, MTLLibraryType) {
	MTLLibraryTypeExecutable = 0,
	MTLLibraryTypeDynamic = 1,
};

MTL_EXPORT MTL_EXTERN NSErrorDomain const MTLLibraryErrorDomain;

typedef NS_ENUM(NSUInteger, MTLLibraryError) {
	MTLLibraryErrorUnsupported = 1,
	MTLLibraryErrorInternal = 2,
	MTLLibraryErrorCompileFailure = 3,
	MTLLibraryErrorCompileWarning = 4,
	MTLLibraryErrorFunctionNotFound = 5,
	MTLLibraryErrorFileNotFound = 6,
};

@protocol MTLFunction <NSObject>

@property(readonly) id<MTLDevice> device;
@property(readonly) MTLFunctionType functionType;
@property(readonly) NSString* name;
@property(readonly) MTLFunctionOptions options;
@property(readonly) MTLPatchType patchType;
@property(readonly) NSInteger patchControlPointCount;
@property(readonly) NSArray<MTLVertexAttribute*>* vertexAttributes;
@property(readonly) NSArray<MTLAttribute*>* stageInputAttributes;
@property(readonly) NSDictionary<NSString*, MTLFunctionConstant*>* functionConstantsDictionary;
@property(nullable, copy, nonatomic) NSString* label;

- (id<MTLArgumentEncoder>)newArgumentEncoderWithBufferIndex: (NSUInteger)bufferIndex;

- (id<MTLArgumentEncoder>)newArgumentEncoderWithBufferIndex: (NSUInteger)bufferIndex
                                                 reflection: (MTLAutoreleasedArgument*)reflection;

@end

@protocol MTLLibrary <NSObject>

@property(readonly) NSString* installName;
@property(readonly) MTLLibraryType type;
@property(readonly) NSArray<NSString*>* functionNames;
@property(readonly) id<MTLDevice> device;
@property(nullable, copy, nonatomic) NSString* label;

- (id<MTLFunction>)newFunctionWithName: (NSString*)functionName;

// TODO: other methods

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLLIBRARY_H_
