// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLLibraryInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>

MTL_EXTERN NSErrorDomain const MTLLibraryErrorDomain = @"MTLLibraryErrorDomain";

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
