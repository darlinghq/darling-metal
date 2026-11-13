// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLLIBRARYINTERNAL_H_
#define _METAL_MTLLIBRARYINTERNAL_H_

#import <Metal/MTLLibrary.h>
#import <Metal/MTLFunctionConstantValues.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

@interface MTLFunctionInternal : NSObject <MTLFunction>

#if DARLING_METAL_ENABLED
@property(readonly) std::shared_ptr<Indium::Function> function;

- (instancetype)initWithFunction: (std::shared_ptr<Indium::Function>)function
                          device: (id<MTLDevice>)device;
#endif

@end

@interface MTLLibraryInternal : NSObject <MTLLibrary>

#if DARLING_METAL_ENABLED
- (instancetype)initWithLibrary: (std::shared_ptr<Indium::Library>)library
                         device: (id<MTLDevice>)device;
#endif

@end

/* What -[MTLFunctionConstantValues setConstantValue:...] recorded, for the library to apply. */
@interface MTLFunctionConstantValues (Internal)

/* @{ NSNumber index: @{ @"type": NSNumber(MTLDataType), @"data": NSData } } */
- (NSDictionary*)constantsByIndex;
/* The same, keyed by name. */
- (NSDictionary*)constantsByName;

@end

#endif // _METAL_MTLLIBRARYINTERNAL_H_
