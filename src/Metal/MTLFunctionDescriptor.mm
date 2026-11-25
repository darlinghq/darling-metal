// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLFunctionDescriptor.h>
#import <Metal/MTLFunctionConstantValues.h>

#if __LP64__


@implementation MTLFunctionDescriptor

@synthesize name = _name;
@synthesize specializedName = _specializedName;
@synthesize constantValues = _constantValues;
@synthesize options = _options;
@synthesize binaryArchives = _binaryArchives;

+ (MTLFunctionDescriptor*)functionDescriptor
{
	return [[[self alloc] init] autorelease];
}

- (void)dealloc
{
	[_name release];
	[_specializedName release];
	[_constantValues release];
	[_binaryArchives release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLFunctionDescriptor* copy = [[[self class] allocWithZone: zone] init];

	copy.name = _name;
	copy.specializedName = _specializedName;
	copy.constantValues = _constantValues;
	copy.options = _options;
	copy.binaryArchives = _binaryArchives;

	return copy;
}

@end

#endif // __LP64__
