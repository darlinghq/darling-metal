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

#ifndef _METAL_MTLLIBRARYINTERNAL_H_
#define _METAL_MTLLIBRARYINTERNAL_H_

#import <Metal/MTLLibrary.h>

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

#endif // _METAL_MTLLIBRARYINTERNAL_H_
