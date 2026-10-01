// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLLinkedFunctions.h>

#if __LP64__


@implementation MTLLinkedFunctions

@synthesize functions = _functions;
@synthesize privateFunctions = _privateFunctions;
@synthesize groups = _groups;
@synthesize binaryFunctions = _binaryFunctions;

- (void)dealloc
{
	[_functions release];
	[_privateFunctions release];
	[_groups release];
	[(id)_binaryFunctions release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLLinkedFunctions* copy = [[MTLLinkedFunctions allocWithZone: zone] init];

	copy.functions = _functions;
	copy.privateFunctions = _privateFunctions;
	copy.groups = _groups;
	copy.binaryFunctions = _binaryFunctions;

	return copy;
}

@end

#endif // __LP64__
