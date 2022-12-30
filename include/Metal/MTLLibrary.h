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
