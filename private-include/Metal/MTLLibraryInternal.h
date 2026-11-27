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

// What identifies the function's code in a binary archive: a digest of its library's contents, its name and
// the values of its function constants
@property(readonly) NSData* archiveKey;

// set by -[MTLLibrary newFunctionWithDescriptor:error:] from the descriptor
- (void)setName: (NSString*)name;
- (void)setOptions: (MTLFunctionOptions)options;

- (instancetype)initWithFunction: (std::shared_ptr<Indium::Function>)function
                          device: (id<MTLDevice>)device
                      archiveKey: (NSData*)archiveKey;
#endif

@end

@interface MTLLibraryInternal : NSObject <MTLLibrary>

#if DARLING_METAL_ENABLED
// `contents` are the bytes Indium made the library from: a metallib, or the SPIR-V compiled from source
- (instancetype)initWithLibrary: (std::shared_ptr<Indium::Library>)library
                         device: (id<MTLDevice>)device
                       contents: (const void*)contents
                         length: (size_t)length;

// functions of the library that cannot be made, by name, with the reason each one is refused for
- (void)setUnusableFunctions: (NSDictionary<NSString*, NSString*>*)reasons;
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
