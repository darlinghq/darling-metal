// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLCompileOptions.h>
#import <Metal/stubs.h>

@implementation MTLCompileOptions

#if DARLING_METAL_ENABLED

@synthesize preprocessorMacros = _preprocessorMacros;
@synthesize mathMode = _mathMode;
@synthesize mathFloatingPointFunctions = _mathFloatingPointFunctions;
@synthesize languageVersion = _languageVersion;
@synthesize libraryType = _libraryType;
@synthesize installName = _installName;
@synthesize preserveInvariance = _preserveInvariance;
@synthesize optimizationLevel = _optimizationLevel;
@synthesize compileSymbolVisibility = _compileSymbolVisibility;
@synthesize allowReferencingUndefinedSymbols = _allowReferencingUndefinedSymbols;
@synthesize maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
@synthesize enableLogging = _enableLogging;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		// Black-box observation (macOS 26.7.3 and 10.14.4): a new object has fast math on and no
		// macros. The default language version is the OS's own newest-at-the-time value (4.0 on
		// 26, 1.1 on 10.14); the oldest of those is used so that source written for an older
		// macOS keeps its meaning.
		_mathMode = MTLMathModeFast;
		_languageVersion = MTLLanguageVersion1_1;
	}
	return self;
}

- (void)dealloc
{
	[_preprocessorMacros release];
	[_installName release];
	[super dealloc];
}

- (BOOL)fastMathEnabled
{
	return _mathMode == MTLMathModeFast;
}

- (void)setFastMathEnabled: (BOOL)enabled
{
	_mathMode = enabled ? MTLMathModeFast : MTLMathModeSafe;
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLCompileOptions* copy = [[[self class] allocWithZone: zone] init];

	copy.preprocessorMacros = _preprocessorMacros;
	copy.mathMode = _mathMode;
	copy.mathFloatingPointFunctions = _mathFloatingPointFunctions;
	copy.languageVersion = _languageVersion;
	copy.libraryType = _libraryType;
	copy.installName = _installName;
	copy.preserveInvariance = _preserveInvariance;
	copy.optimizationLevel = _optimizationLevel;
	copy.compileSymbolVisibility = _compileSymbolVisibility;
	copy.allowReferencingUndefinedSymbols = _allowReferencingUndefinedSymbols;
	copy.maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
	copy.enableLogging = _enableLogging;

	return copy;
}

#else

@dynamic preprocessorMacros;
@dynamic fastMathEnabled;
@dynamic mathMode;
@dynamic mathFloatingPointFunctions;
@dynamic languageVersion;
@dynamic libraryType;
@dynamic installName;
@dynamic preserveInvariance;
@dynamic optimizationLevel;
@dynamic compileSymbolVisibility;
@dynamic allowReferencingUndefinedSymbols;
@dynamic maxTotalThreadsPerThreadgroup;
@dynamic enableLogging;

MTL_UNSUPPORTED_CLASS

#endif

@end
