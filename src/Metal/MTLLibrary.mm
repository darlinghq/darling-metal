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

#import <Metal/MTLLibraryInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>

@implementation MTLFunctionInternal

#if DARLING_METAL_ENABLED

@synthesize function = _function;
@synthesize device = _device;
@synthesize functionType = _functionType;
@synthesize name = _name;
@synthesize options = _options;
@synthesize patchType = _patchType;
@synthesize patchControlPointCount = _patchControlPointCount;
@synthesize vertexAttributes = _vertexAttributes;
@synthesize stageInputAttributes = _stageInputAttributes;
@synthesize functionConstantsDictionary = _functionConstantsDictionary;
@synthesize label = _label;

- (instancetype)initWithFunction: (std::shared_ptr<Indium::Function>)function
                          device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_function = function;
		_device = [device retain];

		// cache the name
		_name = [NSString stringWithUTF8String: _function->name().c_str()];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_name release];
	[_vertexAttributes release];
	[_stageInputAttributes release];
	[_functionConstantsDictionary release];
	[_label release];
	[super dealloc];
}

- (id<MTLArgumentEncoder>)newArgumentEncoderWithBufferIndex: (NSUInteger)bufferIndex
{
	return [self newArgumentEncoderWithBufferIndex: bufferIndex reflection: nil];
}

- (id<MTLArgumentEncoder>)newArgumentEncoderWithBufferIndex: (NSUInteger)bufferIndex
                                                 reflection: (MTLAutoreleasedArgument*)reflection
{
	// TODO
	return nil;
}

#else

@dynamic device;
@dynamic functionType;
@dynamic name;
@dynamic options;
@dynamic patchType;
@dynamic patchControlPointCount;
@dynamic vertexAttributes;
@dynamic stageInputAttributes;
@dynamic functionConstantsDictionary;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLLibraryInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::Library> _library;
}

@synthesize installName = _installName;
@synthesize type = _type;
@synthesize functionNames = _functionNames;
@synthesize device = _device;
@synthesize label = _label;

- (instancetype)initWithLibrary: (std::shared_ptr<Indium::Library>)library
                         device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_library = library;

		// TODO: dynamic libraries
		_installName = nil;
		_type = MTLLibraryTypeExecutable;

		// TODO: function names. this requires a change in Indium.
		_functionNames = nil;

		_device = [device retain];
	}
	return self;
}

- (void)dealloc
{
	[_installName release];
	[_functionNames release];
	[_device release];
	[_label release];
	[super dealloc];
}

- (id<MTLFunction>)newFunctionWithName: (NSString*)functionName
{
	auto func = _library->newFunction(functionName.UTF8String);
	if (!func) {
		return nil;
	}
	return [[MTLFunctionInternal alloc] initWithFunction: func device: _device];
}

#else

@dynamic installName;
@dynamic type;
@dynamic functionNames;
@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
