// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLSharedEvent.h>

@implementation MTLSharedEventListener

- (instancetype)init
{
	// A listener with no queue has nothing to dispatch onto, and the property is
	// nonnull, so the default is the main queue rather than NULL: a NULL here
	// would read back as a real queue that happens to be NULL.
	return [self initWithDispatchQueue: dispatch_get_main_queue()];
}

- (instancetype)initWithDispatchQueue: (dispatch_queue_t)dispatchQueue
{
	self = [super init];
	if (self != nil) {
		_dispatchQueue = dispatchQueue;
		dispatch_retain(_dispatchQueue);
	}
	return self;
}

+ (MTLSharedEventListener*)sharedListener
{
	static MTLSharedEventListener* shared = nil;
	static dispatch_once_t once;

	dispatch_once(&once, ^{
		shared = [[MTLSharedEventListener alloc] init];
	});

	return shared;
}

- (void)dealloc
{
	if (_dispatchQueue) {
		dispatch_release(_dispatchQueue);
	}
	[super dealloc];
}

@end
