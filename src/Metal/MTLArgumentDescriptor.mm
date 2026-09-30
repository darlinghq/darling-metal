// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLArgumentDescriptor.h>

@implementation MTLArgumentDescriptor

+ (MTLArgumentDescriptor*)argumentDescriptor
{
	return [[[self alloc] init] autorelease];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLArgumentDescriptor* copy = [[MTLArgumentDescriptor allocWithZone: zone] init];

	copy.index = _index;
	copy.dataType = _dataType;
	copy.access = _access;
	copy.arrayLength = _arrayLength;
	copy.textureType = _textureType;
	copy.constantBlockAlignment = _constantBlockAlignment;

	return copy;
}

@end
