// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLArgumentInternal.h>
#import <Metal/stubs.h>

#if DARLING_METAL_ENABLED

@interface MTLStructMember ()
- (instancetype)initWithInfo: (const Indium::ArgumentMemberInfo&)info;
@end

@interface MTLStructType ()
- (instancetype)initWithMembers: (NSArray<MTLStructMember*>*)members;
@end

@interface MTLArgument ()
- (instancetype)initWithInfo: (const Indium::ArgumentInfo&)info options: (MTLPipelineOption)options;
@end

@implementation MTLStructMember

@synthesize name = _name;
@synthesize offset = _offset;

- (instancetype)initWithInfo: (const Indium::ArgumentMemberInfo&)info
{
	self = [super init];
	if (self != nil) {
		_name = [[NSString alloc] initWithUTF8String: info.name.c_str()];
		_offset = info.offset;
	}
	return self;
}

- (void)dealloc
{
	[_name release];
	[super dealloc];
}

@end

@implementation MTLStructType

@synthesize members = _members;

- (instancetype)initWithMembers: (NSArray<MTLStructMember*>*)members
{
	self = [super init];
	if (self != nil) {
		_members = [members copy];
	}
	return self;
}

- (void)dealloc
{
	[_members release];
	[super dealloc];
}

- (MTLStructMember*)memberByName: (NSString*)name
{
	for (MTLStructMember* member in _members) {
		if ([member.name isEqualToString: name]) {
			return member;
		}
	}
	return nil;
}

@end

static MTLArgumentType argumentTypeForKind(Indium::ArgumentKind kind)
{
	switch (kind) {
		case Indium::ArgumentKind::Texture:
			return MTLArgumentTypeTexture;
		case Indium::ArgumentKind::Sampler:
			return MTLArgumentTypeSampler;
		case Indium::ArgumentKind::Buffer:
		default:
			return MTLArgumentTypeBuffer;
	}
}

@implementation MTLArgument

@synthesize name = _name;
@synthesize type = _type;
@synthesize index = _index;
@synthesize bufferAlignment = _bufferAlignment;
@synthesize bufferDataSize = _bufferDataSize;
@synthesize bufferStructType = _bufferStructType;

- (instancetype)initWithInfo: (const Indium::ArgumentInfo&)info options: (MTLPipelineOption)options
{
	self = [super init];
	if (self != nil) {
		_name = [[NSString alloc] initWithUTF8String: info.name.c_str()];
		_type = argumentTypeForKind(info.kind);
		_index = info.index;
		if (_type == MTLArgumentTypeBuffer) {
			_bufferAlignment = info.alignment;
			_bufferDataSize = info.size;

			// the layout of the pointee is only reported when it was asked for
			if ((options & MTLPipelineOptionBufferTypeInfo) && !info.members.empty()) {
				NSMutableArray<MTLStructMember*>* members = [NSMutableArray arrayWithCapacity: info.members.size()];
				for (const auto& memberInfo: info.members) {
					MTLStructMember* member = [[MTLStructMember alloc] initWithInfo: memberInfo];
					[members addObject: member];
					[member release];
				}
				_bufferStructType = [[MTLStructType alloc] initWithMembers: members];
			}
		}
	}
	return self;
}

- (void)dealloc
{
	[_name release];
	[_bufferStructType release];
	[super dealloc];
}

// Indium does not track which declared arguments a function actually uses, so every
// declared argument is reported as active.
- (BOOL)isActive
{
	return YES;
}

@end

// Arguments are only reported when the pipeline was created with MTLPipelineOptionArgumentInfo
// or MTLPipelineOptionBufferTypeInfo; otherwise the reflection lists none.
static NSArray<MTLArgument*>* argumentsForFunction(const std::shared_ptr<Indium::Function>& function, MTLPipelineOption options)
{
	NSMutableArray<MTLArgument*>* result = [NSMutableArray array];

	if (!function || !(options & (MTLPipelineOptionArgumentInfo | MTLPipelineOptionBufferTypeInfo))) {
		return result;
	}

	for (const auto& info: function->argumentInfo()) {
		// vertex inputs are not arguments: MTLFunction reports them as attributes
		if (info.kind == Indium::ArgumentKind::VertexInput) {
			continue;
		}
		MTLArgument* argument = [[MTLArgument alloc] initWithInfo: info options: options];
		[result addObject: argument];
		[argument release];
	}

	return result;
}

@implementation MTLComputePipelineReflection

@synthesize arguments = _arguments;

- (instancetype)initWithFunction: (std::shared_ptr<Indium::Function>)function
                         options: (MTLPipelineOption)options
{
	self = [super init];
	if (self != nil) {
		_arguments = [argumentsForFunction(function, options) copy];
	}
	return self;
}

- (void)dealloc
{
	[_arguments release];
	[super dealloc];
}

@end

@implementation MTLRenderPipelineReflection

@synthesize vertexArguments = _vertexArguments;
@synthesize fragmentArguments = _fragmentArguments;

- (instancetype)initWithVertexFunction: (std::shared_ptr<Indium::Function>)vertexFunction
                      fragmentFunction: (std::shared_ptr<Indium::Function>)fragmentFunction
                               options: (MTLPipelineOption)options
{
	self = [super init];
	if (self != nil) {
		_vertexArguments = [argumentsForFunction(vertexFunction, options) copy];
		_fragmentArguments = [argumentsForFunction(fragmentFunction, options) copy];
	}
	return self;
}

- (void)dealloc
{
	[_vertexArguments release];
	[_fragmentArguments release];
	[super dealloc];
}

@end

#else

@implementation MTLStructMember
@dynamic name;
@dynamic offset;
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLStructType
@dynamic members;
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLArgument
@dynamic name;
@dynamic type;
@dynamic index;
@dynamic active;
@dynamic bufferAlignment;
@dynamic bufferDataSize;
@dynamic bufferStructType;
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLComputePipelineReflection
@dynamic arguments;
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLRenderPipelineReflection
@dynamic vertexArguments;
@dynamic fragmentArguments;
MTL_UNSUPPORTED_CLASS
@end

#endif
