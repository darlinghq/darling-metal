// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLCommandBuffer.h>

@implementation MTLCommandBufferDescriptor

@synthesize logState = _logState;
@synthesize retainedReferences = _retainedReferences;
@synthesize errorOptions = _errorOptions;

- (void)dealloc
{
	[(id)_logState release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLCommandBufferDescriptor* copy = [[MTLCommandBufferDescriptor allocWithZone: zone] init];

	copy.logState = _logState;
	copy.retainedReferences = _retainedReferences;
	copy.errorOptions = _errorOptions;

	return copy;
}

@end
