// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLFunctionConstantValues.h>
#import <Metal/stubs.h>

@implementation MTLFunctionConstantValues

// Function constants are specialization constants: they only mean anything once a function is
// compiled against them, and neither MTLLibrary nor Indium can do that yet. Collecting the values
// here would produce a pipeline silently built from the shader's defaults, so refuse instead.
MTL_UNSUPPORTED_CLASS

@end
