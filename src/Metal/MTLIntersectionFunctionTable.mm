// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLIntersectionFunctionTable.h>

#if __LP64__


@implementation MTLIntersectionFunctionDescriptor

- (id)copyWithZone: (NSZone*)zone
{
	return [[MTLIntersectionFunctionDescriptor allocWithZone: zone] init];
}

@end

@implementation MTLIntersectionFunctionTableDescriptor

@synthesize functionCount = _functionCount;

+ (MTLIntersectionFunctionTableDescriptor*)intersectionFunctionTableDescriptor
{
	return [[[self alloc] init] autorelease];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLIntersectionFunctionTableDescriptor* copy =
		[[MTLIntersectionFunctionTableDescriptor allocWithZone: zone] init];

	copy.functionCount = _functionCount;

	return copy;
}

@end

#endif // __LP64__
