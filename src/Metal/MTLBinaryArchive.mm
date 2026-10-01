// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLBinaryArchive.h>

#if __LP64__


@implementation MTLBinaryArchiveDescriptor

@synthesize url = _url;

- (id)copyWithZone: (NSZone*)zone
{
	MTLBinaryArchiveDescriptor* copy = [[MTLBinaryArchiveDescriptor allocWithZone: zone] init];

	copy.url = _url;

	return copy;
}

@end

#endif // __LP64__
