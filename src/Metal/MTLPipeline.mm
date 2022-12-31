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

#import <Metal/MTLPipelineInternal.h>
#import <Metal/stubs.h>

@implementation MTLPipelineBufferDescriptor

#if DARLING_METAL_ENABLED

- (instancetype)init
{
	return [self initWithMutability: MTLMutabilityDefault];
}

- (instancetype)initWithMutability: (MTLMutability)mutability
{
	self = [super init];
	if (self != nil) {
		_mutability = mutability;
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[MTLPipelineBufferDescriptor alloc] initWithMutability: _mutability];
}

#else

@dynamic mutability;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLPipelineBufferDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::PipelineBufferDescriptor)asIndiumDescriptor
{
	return Indium::PipelineBufferDescriptor {
		static_cast<Indium::Mutability>(_mutability),
	};
}

#endif

@end

@implementation MTLPipelineBufferDescriptorArray

#if DARLING_METAL_ENABLED

{
	NSMutableDictionary<NSNumber*, MTLPipelineBufferDescriptor*>* _dict;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_dict = [NSMutableDictionary new];
	}
	return self;
}

- (instancetype)initWithDictionary: (NSDictionary<NSNumber*, MTLPipelineBufferDescriptor*>*)dictionary
{
	self = [super init];
	if (self != nil) {
		_dict = [dictionary mutableCopy];
	}
	return self;
}

- (void)dealloc
{
	[_dict release];
	[super dealloc];
}

- (MTLPipelineBufferDescriptor*)objectAtIndexedSubscript: (NSUInteger)index
{
	if (!_dict[@(index)]) {
		_dict[@(index)] = [[MTLPipelineBufferDescriptor new] autorelease];
	}
	return [[_dict[@(index)] retain] autorelease];
}

-    (void)setObject: (MTLPipelineBufferDescriptor*)desc
  atIndexedSubscript: (NSUInteger)index
{
	_dict[@(index)] = desc;
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLPipelineBufferDescriptorArray (Internal)

#if DARLING_METAL_ENABLED

- (id)copyWithZone: (NSZone*)zone
{
	return [[MTLPipelineBufferDescriptorArray alloc] initWithDictionary: _dict];
}

- (std::unordered_map<size_t, Indium::PipelineBufferDescriptor>)asIndiumDescriptors
{
	std::unordered_map<size_t, Indium::PipelineBufferDescriptor> result;

	for (NSNumber* index in _dict) {
		result[[index unsignedIntegerValue]] = [_dict[index] asIndiumDescriptor];
	}

	return result;
}

#endif

@end
