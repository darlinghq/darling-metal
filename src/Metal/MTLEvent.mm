// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLEventInternal.h>
#import <Metal/stubs.h>

@implementation MTLEventInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::Event> _event;
}

@synthesize device = _device;
@synthesize label = _label;

- (instancetype)initWithEvent: (std::shared_ptr<Indium::Event>)event
                       device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_event = event;
		_device = [device retain];
	}
	return self;
}

- (std::shared_ptr<Indium::Event>)indiumEvent
{
	return _event;
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

#if DARLING_METAL_ENABLED
std::shared_ptr<Indium::Event> MTLEventGetIndium(id<MTLEvent> object)
{
	static const Class eventClass = [MTLEventInternal class];
	static const Class sharedClass = [MTLSharedEventInternal class];

	if (MTLObjectIsInstanceOf(object, eventClass)) {
		return [(MTLEventInternal*)object indiumEvent];
	}
	if (MTLObjectIsInstanceOf(object, sharedClass)) {
		return [(MTLSharedEventInternal*)object indiumSharedEvent];
	}
	return nullptr;
}
#endif
