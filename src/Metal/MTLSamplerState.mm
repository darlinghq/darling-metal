// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLSamplerStateInternal.h>
#import <Metal/stubs.h>

@implementation MTLSamplerStateInternal

#if DARLING_METAL_ENABLED

@synthesize device = _device;
@synthesize label = _label;
@synthesize state = _state;

- (instancetype)initWithState: (std::shared_ptr<Indium::SamplerState>)state
                       device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_state = state;
		_device = [device retain];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[super dealloc];
}

#else

@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
