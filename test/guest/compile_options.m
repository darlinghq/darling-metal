// Copyright (C) 2026 Lubos Dolezel
// MTLCompileOptions: public properties, defaults that agree across macOS versions, NSCopying.
// Runs on Darling and on macOS (the checks below are the macOS-observed behaviour).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void) {
	@autoreleasepool {
		MTLCompileOptions* o = [[MTLCompileOptions alloc] init];
		CHECK(o != nil);
		CHECK([o conformsToProtocol: @protocol(NSCopying)]);
		CHECK(o.fastMathEnabled == YES);
		CHECK(o.preprocessorMacros == nil);
		CHECK(o.mathMode == MTLMathModeFast);

		o.fastMathEnabled = NO;
		CHECK(o.fastMathEnabled == NO);
		CHECK(o.mathMode == MTLMathModeSafe);
		o.fastMathEnabled = YES;
		CHECK(o.mathMode == MTLMathModeFast);
		o.mathMode = MTLMathModeRelaxed;
		CHECK(o.fastMathEnabled == NO);
		o.mathMode = MTLMathModeSafe;
		CHECK(o.fastMathEnabled == NO);
		o.mathMode = MTLMathModeFast;
		CHECK(o.fastMathEnabled == YES);

		o.languageVersion = MTLLanguageVersion2_0;
		CHECK(o.languageVersion == MTLLanguageVersion2_0);
		CHECK(o.languageVersion == (2 << 16));

		o.preprocessorMacros = @{@"A": @1, @"B": @"x"};
		CHECK(o.preprocessorMacros.count == 2);
		o.mathFloatingPointFunctions = MTLMathFloatingPointFunctionsPrecise;
		o.libraryType = MTLLibraryTypeDynamic;
		o.installName = @"@rpath/x.metallib";
		o.preserveInvariance = YES;
		o.optimizationLevel = MTLLibraryOptimizationLevelSize;
		o.compileSymbolVisibility = MTLCompileSymbolVisibilityHidden;
		o.allowReferencingUndefinedSymbols = YES;
		o.maxTotalThreadsPerThreadgroup = 128;

		MTLCompileOptions* c = [o copy];
		CHECK(c != nil && c != o);
		CHECK(c.mathMode == MTLMathModeFast);
		CHECK(c.languageVersion == MTLLanguageVersion2_0);
		CHECK(c.preprocessorMacros.count == 2);
		CHECK([c.preprocessorMacros[@"A"] isEqual: @1]);
		CHECK(c.mathFloatingPointFunctions == MTLMathFloatingPointFunctionsPrecise);
		CHECK(c.libraryType == MTLLibraryTypeDynamic);
		CHECK([c.installName isEqualToString: @"@rpath/x.metallib"]);
		CHECK(c.preserveInvariance == YES);
		CHECK(c.optimizationLevel == MTLLibraryOptimizationLevelSize);
		CHECK(c.compileSymbolVisibility == MTLCompileSymbolVisibilityHidden);
		CHECK(c.allowReferencingUndefinedSymbols == YES);
		CHECK(c.maxTotalThreadsPerThreadgroup == 128);

		// the macros dictionary is copied on set, not retained as given
		NSMutableDictionary* m = [@{@"K": @1} mutableCopy];
		o.preprocessorMacros = m;
		[m setObject: @2 forKey: @"L"];
		CHECK(o.preprocessorMacros.count == 1);

		// a copy is independent of the original
		c.mathMode = MTLMathModeSafe;
		CHECK(o.mathMode == MTLMathModeFast);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
