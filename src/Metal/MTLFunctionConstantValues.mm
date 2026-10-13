// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLFunctionConstantValues.h>

// Sizes follow the Metal Shading Language's scalar and vector types; a 3-component vector occupies
// the size of a 4-component one. Matrices and every non-value type are not valid constant types.
static NSUInteger MTLFunctionConstantTypeSize(MTLDataType type)
{
	switch (type) {
		case MTLDataTypeChar: case MTLDataTypeUChar: case MTLDataTypeBool:
			return 1;
		case MTLDataTypeChar2: case MTLDataTypeUChar2: case MTLDataTypeBool2:
		case MTLDataTypeShort: case MTLDataTypeUShort: case MTLDataTypeHalf: case MTLDataTypeBFloat:
			return 2;
		case MTLDataTypeChar3: case MTLDataTypeChar4: case MTLDataTypeUChar3: case MTLDataTypeUChar4:
		case MTLDataTypeBool3: case MTLDataTypeBool4:
		case MTLDataTypeShort2: case MTLDataTypeUShort2: case MTLDataTypeHalf2: case MTLDataTypeBFloat2:
		case MTLDataTypeInt: case MTLDataTypeUInt: case MTLDataTypeFloat:
			return 4;
		case MTLDataTypeShort3: case MTLDataTypeShort4: case MTLDataTypeUShort3: case MTLDataTypeUShort4:
		case MTLDataTypeHalf3: case MTLDataTypeHalf4: case MTLDataTypeBFloat3: case MTLDataTypeBFloat4:
		case MTLDataTypeInt2: case MTLDataTypeUInt2: case MTLDataTypeFloat2:
		case MTLDataTypeLong: case MTLDataTypeULong:
			return 8;
		case MTLDataTypeInt3: case MTLDataTypeInt4: case MTLDataTypeUInt3: case MTLDataTypeUInt4:
		case MTLDataTypeFloat3: case MTLDataTypeFloat4:
		case MTLDataTypeLong2: case MTLDataTypeULong2:
			return 16;
		case MTLDataTypeLong3: case MTLDataTypeLong4: case MTLDataTypeULong3: case MTLDataTypeULong4:
			return 32;
		default:
			return 0;
	}
}

static void MTLFunctionConstantFail(NSString* reason)
{
	[NSException raise: NSInvalidArgumentException format: @"%@", reason];
}

static NSUInteger MTLFunctionConstantCheckedSize(const void* value, MTLDataType type, const char* selector)
{
	NSUInteger size = MTLFunctionConstantTypeSize(type);
	if (size == 0) {
		MTLFunctionConstantFail([NSString stringWithFormat: @"-[MTLFunctionConstantValues %s]: MTLDataType %lu is not a scalar or vector type", selector, (unsigned long)type]);
	}
	if (value == NULL) {
		MTLFunctionConstantFail([NSString stringWithFormat: @"-[MTLFunctionConstantValues %s]: value must not be NULL", selector]);
	}
	return size;
}

// Each entry is {@"type": NSNumber, @"data": NSData} so a copy only has to copy the two dictionaries.
static NSDictionary* MTLFunctionConstantEntry(const void* value, MTLDataType type, NSUInteger size)
{
	return @{ @"type": @(type), @"data": [NSData dataWithBytes: value length: size] };
}

@implementation MTLFunctionConstantValues

- (id)init
{
	if ((self = [super init])) {
		_byIndex = [[NSMutableDictionary alloc] init];
		_byName = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_byIndex release];
	[_byName release];
	[super dealloc];
}

- (void)setConstantValue: (const void*)value type: (MTLDataType)type atIndex: (NSUInteger)index
{
	NSUInteger size = MTLFunctionConstantCheckedSize(value, type, "setConstantValue:type:atIndex:");
	_byIndex[@(index)] = MTLFunctionConstantEntry(value, type, size);
}

- (void)setConstantValue: (const void*)value type: (MTLDataType)type withName: (NSString*)name
{
	NSUInteger size = MTLFunctionConstantCheckedSize(value, type, "setConstantValue:type:withName:");
	if (name == nil) {
		MTLFunctionConstantFail(@"-[MTLFunctionConstantValues setConstantValue:type:withName:]: name must not be nil");
	}
	NSString* key = [name copy];
	_byName[key] = MTLFunctionConstantEntry(value, type, size);
	[key release];
}

- (void)setConstantValues: (const void*)values type: (MTLDataType)type withRange: (NSRange)range
{
	NSUInteger size = MTLFunctionConstantCheckedSize(values, type, "setConstantValues:type:withRange:");
	if (range.location > NSUIntegerMax - range.length) {
		MTLFunctionConstantFail(@"-[MTLFunctionConstantValues setConstantValues:type:withRange:]: range overflows");
	}
	for (NSUInteger i = 0; i < range.length; i++) {
		_byIndex[@(range.location + i)] = MTLFunctionConstantEntry((const char*)values + i * size, type, size);
	}
}

- (void)reset
{
	[_byIndex removeAllObjects];
	[_byName removeAllObjects];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLFunctionConstantValues* copy = [[[self class] allocWithZone: zone] init];

	[copy->_byIndex addEntriesFromDictionary: _byIndex];
	[copy->_byName addEntriesFromDictionary: _byName];

	return copy;
}

@end
