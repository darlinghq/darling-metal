// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLArgumentInternal.h>
#import <Metal/MTLAttributeInfo.h>
#import <Metal/stubs.h>

#if DARLING_METAL_ENABLED

// MTLDataTypeNone for anything but a scalar, vector or matrix type name. A packed vector has the
// data type of the vector; its size and alignment are reported separately.
static MTLDataType dataTypeForName(const std::string& name)
{
	static const std::string packed = "packed_";
	if (name.compare(0, packed.size(), packed) == 0) {
		std::string vector = name.substr(packed.size());
		bool isVector = !vector.empty() && vector.back() >= '2' && vector.back() <= '4' && vector.find('x') == std::string::npos;
		return isVector ? static_cast<MTLDataType>(MTLAttributeInfo::dataTypeFromName(vector)) : MTLDataTypeNone;
	}
	return static_cast<MTLDataType>(MTLAttributeInfo::dataTypeFromName(name));
}

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
@synthesize dataType = _dataType;

- (instancetype)initWithInfo: (const Indium::ArgumentMemberInfo&)info
{
	self = [super init];
	if (self != nil) {
		_name = [[NSString alloc] initWithUTF8String: info.name.c_str()];
		_offset = info.offset;
		// Indium keeps a member's type name but not its array length or nested layout, so an array
		// member reports its element type and a nested struct reports None.
		_dataType = dataTypeForName(info.typeName);
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

// The layout of a buffer's pointee, or nil when Indium has no members for it
static MTLStructType* structTypeForArgument(const Indium::ArgumentInfo& info)
{
	if (info.members.empty()) {
		return nil;
	}
	NSMutableArray<MTLStructMember*>* members = [NSMutableArray arrayWithCapacity: info.members.size()];
	for (const auto& memberInfo: info.members) {
		MTLStructMember* member = [[MTLStructMember alloc] initWithInfo: memberInfo];
		[members addObject: member];
		[member release];
	}
	return [[[MTLStructType alloc] initWithMembers: members] autorelease];
}

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
			if (options & MTLPipelineOptionBufferTypeInfo) {
				_bufferStructType = [structTypeForArgument(info) retain];
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

@interface MTLBindingInternal : NSObject <MTLBinding> {
	NSString* _name;
	MTLBindingType _type;
	MTLBindingAccess _access;
	NSUInteger _index;
}
- (instancetype)initWithInfo: (const Indium::ArgumentInfo&)info type: (MTLBindingType)type access: (MTLBindingAccess)access;
@end

@implementation MTLBindingInternal

@synthesize name = _name;
@synthesize type = _type;
@synthesize access = _access;
@synthesize index = _index;

- (instancetype)initWithInfo: (const Indium::ArgumentInfo&)info type: (MTLBindingType)type access: (MTLBindingAccess)access
{
	self = [super init];
	if (self != nil) {
		_name = [[NSString alloc] initWithUTF8String: info.name.c_str()];
		_type = type;
		_access = access;
		_index = info.index;
	}
	return self;
}

- (void)dealloc
{
	[_name release];
	[super dealloc];
}

// as for -[MTLArgument isActive]: Indium reports declared arguments, not which ones are used
- (BOOL)isUsed
{
	return YES;
}

// every binding Indium reports is a parameter of the function
- (BOOL)isArgument
{
	return YES;
}

@end

@interface MTLBufferBindingInternal : MTLBindingInternal <MTLBufferBinding>
- (instancetype)initWithInfo: (const Indium::ArgumentInfo&)info options: (MTLPipelineOption)options;
@end

@implementation MTLBufferBindingInternal

@synthesize bufferAlignment = _bufferAlignment;
@synthesize bufferDataSize = _bufferDataSize;
@synthesize bufferDataType = _bufferDataType;
@synthesize bufferStructType = _bufferStructType;

- (instancetype)initWithInfo: (const Indium::ArgumentInfo&)info options: (MTLPipelineOption)options
{
	// Indium does not report a buffer's address space or access qualifier, so a constant or
	// read-only buffer is reported as read-write too.
	self = [super initWithInfo: info type: MTLBindingTypeBuffer access: MTLBindingAccessReadWrite];
	if (self != nil) {
		_bufferAlignment = info.alignment;
		_bufferDataSize = info.size;
		_bufferDataType = info.members.empty() ? dataTypeForName(info.typeName) : MTLDataTypeStruct;
		// the layout of the pointee is only reported when it was asked for
		if (options & MTLPipelineOptionBufferTypeInfo) {
			_bufferStructType = [structTypeForArgument(info) retain];
		}
	}
	return self;
}

- (void)dealloc
{
	[_bufferStructType release];
	[super dealloc];
}

// Indium does not describe the buffer's pointer type
- (MTLPointerType*)bufferPointerType
{
	return nil;
}

@end

// A texture argument as its MSL type describes it, e.g. "texture2d<float, read>"
struct TextureDescription {
	MTLTextureType type;
	BOOL depth;
	MTLDataType dataType;
	MTLBindingAccess access;
};

static bool describeTexture(const std::string& typeName, TextureDescription& description)
{
	auto open = typeName.find('<');
	auto comma = typeName.find(',', open);
	auto close = typeName.find('>', comma);
	if (open == std::string::npos || comma == std::string::npos || close == std::string::npos) {
		return false;
	}

	std::string className = typeName.substr(0, open);
	description.depth = className.compare(0, 5, "depth") == 0;
	if (description.depth) {
		className.replace(0, 5, "texture");
	}
	static const struct { const char* name; MTLTextureType type; } classes[] = {
		{ "texture1d", MTLTextureType1D },
		{ "texture1d_array", MTLTextureType1DArray },
		{ "texture2d", MTLTextureType2D },
		{ "texture2d_array", MTLTextureType2DArray },
		{ "texture2d_ms", MTLTextureType2DMultisample },
		{ "texture2d_ms_array", MTLTextureType2DMultisampleArray },
		{ "texturecube", MTLTextureTypeCube },
		{ "texturecube_array", MTLTextureTypeCubeArray },
		{ "texture3d", MTLTextureType3D },
		{ "texture_buffer", MTLTextureTypeTextureBuffer },
	};
	bool found = false;
	for (const auto& entry: classes) {
		if (className == entry.name) {
			description.type = entry.type;
			found = true;
			break;
		}
	}

	auto sampleStart = typeName.find_first_not_of(" \t", open + 1);
	auto sampleEnd = typeName.find_last_not_of(" \t", comma - 1);
	auto accessStart = typeName.find_first_not_of(" \t", comma + 1);
	auto accessEnd = typeName.find_last_not_of(" \t", close - 1);
	if (!found || sampleStart >= comma || accessStart >= close) {
		return false;
	}
	description.dataType = dataTypeForName(typeName.substr(sampleStart, sampleEnd + 1 - sampleStart));

	std::string access = typeName.substr(accessStart, accessEnd + 1 - accessStart);
	if (access.compare(0, 8, "access::") == 0) {
		access.erase(0, 8);
	}
	if (access == "sample" || access == "read") {
		description.access = MTLBindingAccessReadOnly;
	} else if (access == "write") {
		description.access = MTLBindingAccessWriteOnly;
	} else if (access == "read_write") {
		description.access = MTLBindingAccessReadWrite;
	} else {
		return false;
	}
	return true;
}

@interface MTLTextureBindingInternal : MTLBindingInternal <MTLTextureBinding>
- (instancetype)initWithInfo: (const Indium::ArgumentInfo&)info description: (const TextureDescription&)description;
@end

@implementation MTLTextureBindingInternal

@synthesize textureType = _textureType;
@synthesize textureDataType = _textureDataType;
@synthesize depthTexture = _depthTexture;

- (instancetype)initWithInfo: (const Indium::ArgumentInfo&)info description: (const TextureDescription&)description
{
	self = [super initWithInfo: info type: MTLBindingTypeTexture access: description.access];
	if (self != nil) {
		_textureType = description.type;
		_textureDataType = description.dataType;
		_depthTexture = description.depth;
	}
	return self;
}

// Indium reports each texture argument as one binding; arrays of textures are not described
- (NSUInteger)arrayLength
{
	return 1;
}

@end

static id<MTLBinding> bindingForArgument(const Indium::ArgumentInfo& info, MTLPipelineOption options)
{
	switch (info.kind) {
		case Indium::ArgumentKind::Texture: {
			TextureDescription description;
			// a type name describeTexture can't parse: report the texture without its details
			if (describeTexture(info.typeName, description)) {
				return [[[MTLTextureBindingInternal alloc] initWithInfo: info description: description] autorelease];
			}
			return [[[MTLBindingInternal alloc] initWithInfo: info type: MTLBindingTypeTexture access: MTLBindingAccessReadOnly] autorelease];
		}
		case Indium::ArgumentKind::Sampler:
			return [[[MTLBindingInternal alloc] initWithInfo: info type: MTLBindingTypeSampler access: MTLBindingAccessReadOnly] autorelease];
		case Indium::ArgumentKind::Buffer:
		default:
			return [[[MTLBufferBindingInternal alloc] initWithInfo: info options: options] autorelease];
	}
}

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

// The same arguments as argumentsForFunction, in declaration order, as bindings
static NSArray<id<MTLBinding>>* bindingsForFunction(const std::shared_ptr<Indium::Function>& function, MTLPipelineOption options)
{
	NSMutableArray<id<MTLBinding>>* result = [NSMutableArray array];

	if (!function || !(options & (MTLPipelineOptionBindingInfo | MTLPipelineOptionBufferTypeInfo))) {
		return result;
	}

	for (const auto& info: function->argumentInfo()) {
		if (info.kind != Indium::ArgumentKind::VertexInput) {
			[result addObject: bindingForArgument(info, options)];
		}
	}

	return result;
}

@implementation MTLComputePipelineReflection

@synthesize bindings = _bindings;
@synthesize arguments = _arguments;

- (instancetype)initWithFunction: (std::shared_ptr<Indium::Function>)function
                         options: (MTLPipelineOption)options
{
	self = [super init];
	if (self != nil) {
		_bindings = [bindingsForFunction(function, options) copy];
		_arguments = [argumentsForFunction(function, options) copy];
	}
	return self;
}

- (void)dealloc
{
	[_bindings release];
	[_arguments release];
	[super dealloc];
}

@end

@implementation MTLRenderPipelineReflection

@synthesize vertexBindings = _vertexBindings;
@synthesize fragmentBindings = _fragmentBindings;
@synthesize vertexArguments = _vertexArguments;
@synthesize fragmentArguments = _fragmentArguments;

- (instancetype)initWithVertexFunction: (std::shared_ptr<Indium::Function>)vertexFunction
                      fragmentFunction: (std::shared_ptr<Indium::Function>)fragmentFunction
                               options: (MTLPipelineOption)options
{
	self = [super init];
	if (self != nil) {
		_vertexBindings = [bindingsForFunction(vertexFunction, options) copy];
		_fragmentBindings = [bindingsForFunction(fragmentFunction, options) copy];
		_vertexArguments = [argumentsForFunction(vertexFunction, options) copy];
		_fragmentArguments = [argumentsForFunction(fragmentFunction, options) copy];
	}
	return self;
}

- (void)dealloc
{
	[_vertexBindings release];
	[_fragmentBindings release];
	[_vertexArguments release];
	[_fragmentArguments release];
	[super dealloc];
}

@end

#else

@implementation MTLStructMember
@dynamic name;
@dynamic offset;
@dynamic dataType;
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
@dynamic bindings;
@dynamic arguments;
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLRenderPipelineReflection
@dynamic vertexBindings;
@dynamic fragmentBindings;
@dynamic vertexArguments;
@dynamic fragmentArguments;
MTL_UNSUPPORTED_CLASS
@end

#endif
