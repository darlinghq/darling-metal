// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOMPILEOPTIONS_H_
#define _METAL_MTLCOMPILEOPTIONS_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>
#import <Metal/MTLLibrary.h>

METAL_DECLARATIONS_BEGIN

typedef NS_ENUM(NSUInteger, MTLLanguageVersion) {
	MTLLanguageVersion1_0 = (1 << 16),
	MTLLanguageVersion1_1 = (1 << 16) + 1,
	MTLLanguageVersion1_2 = (1 << 16) + 2,
	MTLLanguageVersion2_0 = (2 << 16),
	MTLLanguageVersion2_1 = (2 << 16) + 1,
	MTLLanguageVersion2_2 = (2 << 16) + 2,
	MTLLanguageVersion2_3 = (2 << 16) + 3,
	MTLLanguageVersion2_4 = (2 << 16) + 4,
	MTLLanguageVersion3_0 = (3 << 16) + 0,
	MTLLanguageVersion3_1 = (3 << 16) + 1,
	MTLLanguageVersion3_2 = (3 << 16) + 2,
	MTLLanguageVersion4_0 = (4 << 16) + 0,
};

typedef NS_ENUM(NSInteger, MTLLibraryOptimizationLevel) {
	MTLLibraryOptimizationLevelDefault = 0,
	MTLLibraryOptimizationLevelSize = 1,
};

typedef NS_ENUM(NSInteger, MTLCompileSymbolVisibility) {
	MTLCompileSymbolVisibilityDefault = 0,
	MTLCompileSymbolVisibilityHidden = 1,
};

typedef NS_ENUM(NSInteger, MTLMathMode) {
	MTLMathModeSafe = 0,
	MTLMathModeRelaxed = 1,
	MTLMathModeFast = 2,
};

typedef NS_ENUM(NSInteger, MTLMathFloatingPointFunctions) {
	MTLMathFloatingPointFunctionsFast = 0,
	MTLMathFloatingPointFunctionsPrecise = 1,
};

/**
 * Options for compiling Metal Shading Language source. The options are plain
 * values; they are stored and copied, and are consumed by whatever compiles
 * the source.
 */
MTL_EXPORT
@interface MTLCompileOptions : NSObject <NSCopying>

@property(nullable, readwrite, copy, nonatomic) NSDictionary<NSString*, NSObject*>* preprocessorMacros;
/* A view of mathMode: YES means MTLMathModeFast, NO means MTLMathModeSafe. */
@property(readwrite, nonatomic) BOOL fastMathEnabled;
@property(readwrite, nonatomic) MTLMathMode mathMode;
@property(nonatomic) MTLMathFloatingPointFunctions mathFloatingPointFunctions;
@property(readwrite, nonatomic) MTLLanguageVersion languageVersion;
@property(readwrite, nonatomic) MTLLibraryType libraryType;
@property(readwrite, nullable, copy, nonatomic) NSString* installName;
@property(readwrite, nonatomic) BOOL preserveInvariance;
@property(readwrite, nonatomic) MTLLibraryOptimizationLevel optimizationLevel;
@property(readwrite, nonatomic) MTLCompileSymbolVisibility compileSymbolVisibility;
@property(readwrite, nonatomic) BOOL allowReferencingUndefinedSymbols;
@property(readwrite, nonatomic) NSUInteger maxTotalThreadsPerThreadgroup;
@property(readwrite, nonatomic) BOOL enableLogging;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOMPILEOPTIONS_H_
