// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLLibraryInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>
#import <Metal/MTLIndiumErrors.h>
#include <cstring>

MTL_EXTERN NSErrorDomain const MTLLibraryErrorDomain = @"MTLLibraryErrorDomain";

@interface MTLFunctionConstant ()
- (instancetype)initWithName: (NSString*)name type: (MTLDataType)type index: (NSUInteger)index;
@end

@implementation MTLFunctionConstant

@synthesize name = _name;
@synthesize type = _type;
@synthesize index = _index;

- (instancetype)initWithName: (NSString*)name type: (MTLDataType)type index: (NSUInteger)index
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
		_type = type;
		_index = index;
	}
	return self;
}

- (void)dealloc
{
	[_name release];
	[super dealloc];
}

- (BOOL)required
{
	return YES;
}

@end

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
		_name = [[NSString alloc] initWithUTF8String: _function->name().c_str()];
		// Indium's FunctionType values are Metal's
		_functionType = static_cast<MTLFunctionType>(_function->functionType());

		NSMutableDictionary<NSString*, MTLFunctionConstant*>* constants = [NSMutableDictionary dictionary];
		for (const auto& constant: _function->functionConstants()) {
			MTLDataType type = MTLDataTypeNone;
			switch (constant.type) {
				case Indium::FunctionConstantType::Bool: type = MTLDataTypeBool; break;
				case Indium::FunctionConstantType::Int: type = MTLDataTypeInt; break;
				case Indium::FunctionConstantType::UInt: type = MTLDataTypeUInt; break;
				case Indium::FunctionConstantType::Float: type = MTLDataTypeFloat; break;
			}
			NSString* constantName = [NSString stringWithUTF8String: constant.name.c_str()];
			MTLFunctionConstant* object = [[MTLFunctionConstant alloc] initWithName: constantName type: type index: constant.index];
			constants[constantName] = object;
			[object release];
		}
		_functionConstantsDictionary = [constants copy];
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
	// An argument encoder is a writer: it lays arguments out in a buffer at
	// offsets and alignments the shader dictates. indium's BindingDescriptor
	// carries an argument index and a kind and nothing else - no data type, no
	// size, no alignment, no name, and an internalIndex that is a Vulkan
	// descriptor binding rather than a Metal buffer index - so any offset this
	// produced would be invented, and the shader would read the wrong bytes.
	//
	// MTLArgumentDescriptor is implemented because it only holds what the caller
	// sets. This is not, because it would have to hold an answer.
	//
	// nil is what Apple declares for this method when there is no encoder to
	// give, so a caller that checks keeps working; the log is what makes the
	// absence visible instead of leaving the caller to wonder.
	NSLog(@"MTLFunction: -newArgumentEncoderWithBufferIndex:%lu returns nil. indium does not "
		@"expose the buffer layout an argument encoder needs (its BindingDescriptor has no "
		@"dataType, size or alignment, and its internalIndex is a Vulkan descriptor binding, not "
		@"a Metal buffer index). Reading arguments through setArgumentBuffer:offset: is not "
		@"available either for the same reason.",
		(unsigned long)bufferIndex);

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
	if (!functionName) {
		return nil;
	}
	// this selector has no error out-parameter: a function Indium cannot create is nil
	auto func = MTLCallIndium(nullptr, MTLLibraryErrorFunctionNotFound, [&]() {
		return _library->newFunction(functionName.UTF8String);
	});
	if (!func) {
		return nil;
	}
	return [[MTLFunctionInternal alloc] initWithFunction: func device: _device];
}

- (id<MTLFunction>)newFunctionWithName: (NSString*)functionName
                        constantValues: (MTLFunctionConstantValues*)constantValues
                                 error: (NSError**)error
{
	if (error) {
		*error = nil;
	}
	if (!functionName) {
		MTLSetError(error, MTLLibraryErrorFunctionNotFound, @"No function name");
		return nil;
	}

	// the function's own constants say which of the values apply to it
	auto plain = MTLCallIndium(error, MTLLibraryErrorFunctionNotFound, [&]() {
		return _library->newFunction(functionName.UTF8String);
	});
	if (!plain) {
		if (error && !*error) {
			MTLSetError(error, MTLLibraryErrorFunctionNotFound, [NSString stringWithFormat: @"Function '%@' was not found in the library", functionName]);
		}
		return nil;
	}

	Indium::FunctionConstantValues values;
	NSDictionary* byIndex = [constantValues constantsByIndex];
	NSDictionary* byName = [constantValues constantsByName];
	for (const auto& constant: plain->functionConstants()) {
		NSString* constantName = [NSString stringWithUTF8String: constant.name.c_str()];
		// a value set by index takes precedence over one set by name
		NSDictionary* entry = byIndex[@(constant.index)] ?: byName[constantName];
		if (entry == nil) {
			continue;
		}

		MTLDataType type = static_cast<MTLDataType>([entry[@"type"] unsignedIntegerValue]);
		NSData* data = entry[@"data"];
		uint32_t bits = 0;
		Indium::FunctionConstantType expected = constant.type;
		bool matches = false;
		switch (expected) {
			case Indium::FunctionConstantType::Bool:
				matches = type == MTLDataTypeBool && data.length == 1;
				bits = matches && *static_cast<const uint8_t*>(data.bytes) != 0 ? 1 : 0;
				break;
			case Indium::FunctionConstantType::Int:
				matches = type == MTLDataTypeInt && data.length == 4;
				break;
			case Indium::FunctionConstantType::UInt:
				matches = type == MTLDataTypeUInt && data.length == 4;
				break;
			case Indium::FunctionConstantType::Float:
				matches = type == MTLDataTypeFloat && data.length == 4;
				break;
		}
		if (!matches) {
			MTLSetError(error, MTLLibraryErrorCompileFailure, [NSString stringWithFormat: @"The value for function constant '%@' (index %lu) does not have the constant's type", constantName, (unsigned long)constant.index]);
			return nil;
		}
		if (expected != Indium::FunctionConstantType::Bool) {
			memcpy(&bits, data.bytes, sizeof(bits));
		}
		values.setValue(constant.index, expected, bits);
	}

	std::string message;
	auto func = MTLCallIndium(error, MTLLibraryErrorCompileFailure, [&]() {
		return _library->newFunction(functionName.UTF8String, values, &message);
	});
	if (!func) {
		if (error && !*error) {
			MTLSetError(error, MTLLibraryErrorCompileFailure, [NSString stringWithUTF8String: message.c_str()]);
		}
		return nil;
	}
	return [[MTLFunctionInternal alloc] initWithFunction: func device: _device];
}

- (void)newFunctionWithName: (NSString*)functionName
             constantValues: (MTLFunctionConstantValues*)constantValues
          completionHandler: (void (^)(id<MTLFunction> function, NSError* error))completionHandler
{
	NSError* error = nil;
	id<MTLFunction> function = [self newFunctionWithName: functionName constantValues: constantValues error: &error];
	void (^handler)(id<MTLFunction>, NSError*) = [completionHandler copy];
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
		handler(function, error);
		[function release];
		[handler release];
	});
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
