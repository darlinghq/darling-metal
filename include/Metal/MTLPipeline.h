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

#ifndef _METAL_MTLPIPELINE_H_
#define _METAL_MTLPIPELINE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@class MTLPipelineBufferDescriptor;
@class MTLPipelineBufferDescriptorArray;

typedef NS_ENUM(NSUInteger, MTLMutability) {
	MTLMutabilityDefault = 0,
	MTLMutabilityMutable = 1,
	MTLMutabilityImmutable = 2,
};

MTL_EXPORT
@interface MTLPipelineBufferDescriptor : NSObject <NSCopying>

@property(readwrite, nonatomic, assign) MTLMutability mutability;

@end

MTL_EXPORT
@interface MTLPipelineBufferDescriptorArray : NSObject

- (MTLPipelineBufferDescriptor*)objectAtIndexedSubscript: (NSUInteger)index;

-    (void)setObject: (MTLPipelineBufferDescriptor*)buffer
  atIndexedSubscript: (NSUInteger)index;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLPIPELINE_H_
