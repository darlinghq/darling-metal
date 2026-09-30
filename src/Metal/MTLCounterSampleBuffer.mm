// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLCounterSampleBuffer.h>

@implementation MTLCounterSampleBufferDescriptor

@synthesize label = _label;
@synthesize counterSet = _counterSet;
@synthesize storageMode = _storageMode;
@synthesize sampleCount = _sampleCount;

- (void)dealloc
{
	[_label release];
	[(id)_counterSet release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLCounterSampleBufferDescriptor* copy =
		[[MTLCounterSampleBufferDescriptor allocWithZone: zone] init];

	copy.label = _label;
	copy.counterSet = _counterSet;
	copy.storageMode = _storageMode;
	copy.sampleCount = _sampleCount;

	return copy;
}

@end
