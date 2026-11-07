// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLVertexDescriptorInternal.h>
#import <Metal/stubs.h>

#if DARLING_METAL_ENABLED

@implementation MTLVertexBufferLayoutDescriptor

@synthesize stride = _stride;
@synthesize stepFunction = _stepFunction;
@synthesize stepRate = _stepRate;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_stride = 0;
		_stepFunction = MTLVertexStepFunctionPerVertex;
		_stepRate = 1;
	}
	return self;
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLVertexBufferLayoutDescriptor* copy = [[[self class] allocWithZone: zone] init];
	copy.stride = _stride;
	copy.stepFunction = _stepFunction;
	copy.stepRate = _stepRate;
	return copy;
}

@end

@implementation MTLVertexAttributeDescriptor

@synthesize format = _format;
@synthesize offset = _offset;
@synthesize bufferIndex = _bufferIndex;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_format = MTLVertexFormatInvalid;
		_offset = 0;
		_bufferIndex = 0;
	}
	return self;
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLVertexAttributeDescriptor* copy = [[[self class] allocWithZone: zone] init];
	copy.format = _format;
	copy.offset = _offset;
	copy.bufferIndex = _bufferIndex;
	return copy;
}

@end

// Both arrays hand out an item for any index, created with the default values on first access,
// so that `descriptor.layouts[0].stride = 16` configures the descriptor.

@interface MTLVertexBufferLayoutDescriptorArray ()
- (instancetype)initWithItems: (NSDictionary<NSNumber*, MTLVertexBufferLayoutDescriptor*>*)items;
- (NSDictionary<NSNumber*, MTLVertexBufferLayoutDescriptor*>*)items;
@end

@implementation MTLVertexBufferLayoutDescriptorArray {
	NSMutableDictionary<NSNumber*, MTLVertexBufferLayoutDescriptor*>* _items;
}

- (instancetype)init
{
	return [self initWithItems: nil];
}

- (instancetype)initWithItems: (NSDictionary<NSNumber*, MTLVertexBufferLayoutDescriptor*>*)items
{
	self = [super init];
	if (self != nil) {
		_items = [NSMutableDictionary new];
		for (NSNumber* index in items) {
			MTLVertexBufferLayoutDescriptor* item = [items[index] copy];
			_items[index] = item;
			[item release];
		}
	}
	return self;
}

- (void)dealloc
{
	[_items release];
	[super dealloc];
}

- (NSDictionary<NSNumber*, MTLVertexBufferLayoutDescriptor*>*)items
{
	return _items;
}

- (MTLVertexBufferLayoutDescriptor*)objectAtIndexedSubscript: (NSUInteger)index
{
	MTLVertexBufferLayoutDescriptor* item = _items[@(index)];
	if (item == nil) {
		item = [MTLVertexBufferLayoutDescriptor new];
		_items[@(index)] = item;
		[item release];
	}
	return item;
}

- (void)setObject: (MTLVertexBufferLayoutDescriptor*)bufferDesc atIndexedSubscript: (NSUInteger)index
{
	if (bufferDesc == nil) {
		[_items removeObjectForKey: @(index)];
	} else {
		MTLVertexBufferLayoutDescriptor* item = [bufferDesc copy];
		_items[@(index)] = item;
		[item release];
	}
}

@end

@interface MTLVertexAttributeDescriptorArray ()
- (instancetype)initWithItems: (NSDictionary<NSNumber*, MTLVertexAttributeDescriptor*>*)items;
- (NSDictionary<NSNumber*, MTLVertexAttributeDescriptor*>*)items;
@end

@implementation MTLVertexAttributeDescriptorArray {
	NSMutableDictionary<NSNumber*, MTLVertexAttributeDescriptor*>* _items;
}

- (instancetype)init
{
	return [self initWithItems: nil];
}

- (instancetype)initWithItems: (NSDictionary<NSNumber*, MTLVertexAttributeDescriptor*>*)items
{
	self = [super init];
	if (self != nil) {
		_items = [NSMutableDictionary new];
		for (NSNumber* index in items) {
			MTLVertexAttributeDescriptor* item = [items[index] copy];
			_items[index] = item;
			[item release];
		}
	}
	return self;
}

- (void)dealloc
{
	[_items release];
	[super dealloc];
}

- (NSDictionary<NSNumber*, MTLVertexAttributeDescriptor*>*)items
{
	return _items;
}

- (MTLVertexAttributeDescriptor*)objectAtIndexedSubscript: (NSUInteger)index
{
	MTLVertexAttributeDescriptor* item = _items[@(index)];
	if (item == nil) {
		item = [MTLVertexAttributeDescriptor new];
		_items[@(index)] = item;
		[item release];
	}
	return item;
}

- (void)setObject: (MTLVertexAttributeDescriptor*)attributeDesc atIndexedSubscript: (NSUInteger)index
{
	if (attributeDesc == nil) {
		[_items removeObjectForKey: @(index)];
	} else {
		MTLVertexAttributeDescriptor* item = [attributeDesc copy];
		_items[@(index)] = item;
		[item release];
	}
}

@end

@implementation MTLVertexDescriptor

@synthesize layouts = _layouts;
@synthesize attributes = _attributes;

+ (MTLVertexDescriptor*)vertexDescriptor
{
	return [[self new] autorelease];
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_layouts = [MTLVertexBufferLayoutDescriptorArray new];
		_attributes = [MTLVertexAttributeDescriptorArray new];
	}
	return self;
}

- (void)dealloc
{
	[_layouts release];
	[_attributes release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLVertexDescriptor* copy = [[[self class] allocWithZone: zone] init];
	[copy->_layouts release];
	copy->_layouts = [[MTLVertexBufferLayoutDescriptorArray alloc] initWithItems: [_layouts items]];
	[copy->_attributes release];
	copy->_attributes = [[MTLVertexAttributeDescriptorArray alloc] initWithItems: [_attributes items]];
	return copy;
}

- (void)reset
{
	// items a caller kept from before the reset stay valid but no longer belong to this
	// descriptor; later accesses create fresh items with the default values
	[_layouts release];
	_layouts = [MTLVertexBufferLayoutDescriptorArray new];
	[_attributes release];
	_attributes = [MTLVertexAttributeDescriptorArray new];
}

@end

@implementation MTLVertexDescriptor (Internal)

- (Indium::VertexDescriptor)asIndiumDescriptor
{
	Indium::VertexDescriptor result;

	NSDictionary<NSNumber*, MTLVertexBufferLayoutDescriptor*>* layouts = [_layouts items];
	for (NSNumber* index in layouts) {
		MTLVertexBufferLayoutDescriptor* layout = layouts[index];
		result.layouts[index.unsignedIntegerValue] = Indium::VertexBufferLayoutDescriptor {
			layout.stride,
			static_cast<Indium::VertexStepFunction>(layout.stepFunction),
			layout.stepRate,
		};
	}

	// an attribute left at MTLVertexFormatInvalid is not part of the layout
	NSDictionary<NSNumber*, MTLVertexAttributeDescriptor*>* attributes = [_attributes items];
	for (NSNumber* index in attributes) {
		MTLVertexAttributeDescriptor* attribute = attributes[index];
		if (attribute.format == MTLVertexFormatInvalid) {
			continue;
		}
		result.attributes[index.unsignedIntegerValue] = Indium::VertexAttributeDescriptor {
			static_cast<Indium::VertexFormat>(attribute.format),
			attribute.offset,
			attribute.bufferIndex,
		};
	}

	return result;
}

@end

#else

@implementation MTLVertexBufferLayoutDescriptor
@dynamic stride;
@dynamic stepFunction;
@dynamic stepRate;
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLVertexBufferLayoutDescriptorArray
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLVertexAttributeDescriptor
@dynamic format;
@dynamic offset;
@dynamic bufferIndex;
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLVertexAttributeDescriptorArray
MTL_UNSUPPORTED_CLASS
@end

@implementation MTLVertexDescriptor
@dynamic layouts;
@dynamic attributes;
MTL_UNSUPPORTED_CLASS
@end

#endif
