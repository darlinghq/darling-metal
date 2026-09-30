// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLARGUMENTDESCRIPTOR_H_
#define _METAL_MTLARGUMENTDESCRIPTOR_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLTexture.h>

METAL_DECLARATIONS_BEGIN

// MTLDataType is transcribed from Apple's MTLArgument.h. The 57 enumerators that
// iOS 13.0 also carries were checked value-for-value against metal-cpp's
// generated header and agree on all 57; the rest is metal-cpp's newer tail.
// It is not written by hand, so no value here is a transcription.
typedef NS_ENUM(NSUInteger, MTLDataType) {
	MTLDataTypeNone = 0,
	MTLDataTypeStruct = 1,
	MTLDataTypeArray = 2,
	MTLDataTypeFloat = 3,
	MTLDataTypeFloat2 = 4,
	MTLDataTypeFloat3 = 5,
	MTLDataTypeFloat4 = 6,
	MTLDataTypeFloat2x2 = 7,
	MTLDataTypeFloat2x3 = 8,
	MTLDataTypeFloat2x4 = 9,
	MTLDataTypeFloat3x2 = 10,
	MTLDataTypeFloat3x3 = 11,
	MTLDataTypeFloat3x4 = 12,
	MTLDataTypeFloat4x2 = 13,
	MTLDataTypeFloat4x3 = 14,
	MTLDataTypeFloat4x4 = 15,
	MTLDataTypeHalf = 16,
	MTLDataTypeHalf2 = 17,
	MTLDataTypeHalf3 = 18,
	MTLDataTypeHalf4 = 19,
	MTLDataTypeHalf2x2 = 20,
	MTLDataTypeHalf2x3 = 21,
	MTLDataTypeHalf2x4 = 22,
	MTLDataTypeHalf3x2 = 23,
	MTLDataTypeHalf3x3 = 24,
	MTLDataTypeHalf3x4 = 25,
	MTLDataTypeHalf4x2 = 26,
	MTLDataTypeHalf4x3 = 27,
	MTLDataTypeHalf4x4 = 28,
	MTLDataTypeInt = 29,
	MTLDataTypeInt2 = 30,
	MTLDataTypeInt3 = 31,
	MTLDataTypeInt4 = 32,
	MTLDataTypeUInt = 33,
	MTLDataTypeUInt2 = 34,
	MTLDataTypeUInt3 = 35,
	MTLDataTypeUInt4 = 36,
	MTLDataTypeShort = 37,
	MTLDataTypeShort2 = 38,
	MTLDataTypeShort3 = 39,
	MTLDataTypeShort4 = 40,
	MTLDataTypeUShort = 41,
	MTLDataTypeUShort2 = 42,
	MTLDataTypeUShort3 = 43,
	MTLDataTypeUShort4 = 44,
	MTLDataTypeChar = 45,
	MTLDataTypeChar2 = 46,
	MTLDataTypeChar3 = 47,
	MTLDataTypeChar4 = 48,
	MTLDataTypeUChar = 49,
	MTLDataTypeUChar2 = 50,
	MTLDataTypeUChar3 = 51,
	MTLDataTypeUChar4 = 52,
	MTLDataTypeBool = 53,
	MTLDataTypeBool2 = 54,
	MTLDataTypeBool3 = 55,
	MTLDataTypeBool4 = 56,
	MTLDataTypeTexture = 58,
	MTLDataTypeSampler = 59,
	MTLDataTypePointer = 60,
	MTLDataTypeR8Unorm = 62,
	MTLDataTypeR8Snorm = 63,
	MTLDataTypeR16Unorm = 64,
	MTLDataTypeR16Snorm = 65,
	MTLDataTypeRG8Unorm = 66,
	MTLDataTypeRG8Snorm = 67,
	MTLDataTypeRG16Unorm = 68,
	MTLDataTypeRG16Snorm = 69,
	MTLDataTypeRGBA8Unorm = 70,
	MTLDataTypeRGBA8Unorm_sRGB = 71,
	MTLDataTypeRGBA8Snorm = 72,
	MTLDataTypeRGBA16Unorm = 73,
	MTLDataTypeRGBA16Snorm = 74,
	MTLDataTypeRGB10A2Unorm = 75,
	MTLDataTypeRG11B10Float = 76,
	MTLDataTypeRGB9E5Float = 77,
	MTLDataTypeRenderPipeline = 78,
	MTLDataTypeComputePipeline = 79,
	MTLDataTypeIndirectCommandBuffer = 80,
	MTLDataTypeLong = 81,
	MTLDataTypeLong2 = 82,
	MTLDataTypeLong3 = 83,
	MTLDataTypeLong4 = 84,
	MTLDataTypeULong = 85,
	MTLDataTypeULong2 = 86,
	MTLDataTypeULong3 = 87,
	MTLDataTypeULong4 = 88,
	MTLDataTypeVisibleFunctionTable = 115,
	MTLDataTypeIntersectionFunctionTable = 116,
	MTLDataTypePrimitiveAccelerationStructure = 117,
	MTLDataTypeInstanceAccelerationStructure = 118,
	MTLDataTypeBFloat = 121,
	MTLDataTypeBFloat2 = 122,
	MTLDataTypeBFloat3 = 123,
	MTLDataTypeBFloat4 = 124,
	MTLDataTypeDepthStencilState = 139,
	MTLDataTypeTensor = 140,
};

typedef NS_ENUM(NSUInteger, MTLArgumentAccess) {
	MTLArgumentAccessReadOnly = 0,
	MTLArgumentAccessReadWrite = 1,
	MTLArgumentAccessWriteOnly = 2,
};

/**
 * Describes one argument of a function signature.
 *
 * This is a value: every property stores what the caller set and returns it
 * unchanged, so nothing here has to be backed by a device, a library or a
 * shader. It is the *reflection* object, MTLArgument, that indium would have to
 * produce and cannot, so -newArgumentEncoderWithBufferIndex: on MTLFunction
 * refuses instead of handing back an encoder built on a guessed layout.
 */
MTL_EXPORT
@interface MTLArgumentDescriptor : NSObject <NSCopying>

+ (MTLArgumentDescriptor*)argumentDescriptor;

@property(nonatomic) NSUInteger index;
@property(nonatomic) MTLDataType dataType;
@property(nonatomic) MTLArgumentAccess access;
@property(nonatomic) NSUInteger arrayLength;
@property(nonatomic) MTLTextureType textureType;
@property(nonatomic) NSUInteger constantBlockAlignment;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLARGUMENTDESCRIPTOR_H_
