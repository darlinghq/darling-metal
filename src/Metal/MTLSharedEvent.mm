// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLEventInternal.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/stubs.h>

#if __LP64__


@implementation MTLSharedEventListener

- (instancetype)init
{
	// QUIRK: a listener made with -init, and the shared listener, notify on a serial queue of their own that is
	// labelled "MTLSharedEventListener", not on the main queue (each listener gets a queue of its own). Not
	// documented. Evidence: black-box observation on macOS 27.0.1 arm64 (tier 2), reproduced by the test below.
	// Without it a notification would wait for a main run loop an application may not run.
	// Test: the section "the default queues of listeners" of test/guest/events_fences.m.
	dispatch_queue_t queue = dispatch_queue_create("MTLSharedEventListener", DISPATCH_QUEUE_SERIAL);
	self = [self initWithDispatchQueue: queue];
	dispatch_release(queue);
	return self;
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

#endif // __LP64__

@implementation MTLSharedEventHandle

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::SharedEventHandle> _handle;
}

// The label is nil, as for a handle on macOS 27.0.1 (observed with the public API).
@synthesize label = _label;

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)initWithHandle: (std::shared_ptr<Indium::SharedEventHandle>)handle
{
	self = [super init];
	if (self != nil) {
		_handle = handle;
	}
	return self;
}

- (std::shared_ptr<Indium::SharedEventHandle>)indiumHandle
{
	return _handle;
}

// A handle names an event inside this process, so it cannot travel to another one. macOS accepts only an
// NSXPCCoder here and raises for any other coder; passing a handle through XPC is not supported, so every
// coder is refused.
- (void)encodeWithCoder: (NSCoder*)coder
{
	[NSException raise: NSInvalidArgumentException format: @"MTLSharedEventHandle cannot be encoded: it is only valid in the process that made it"];
}

- (instancetype)initWithCoder: (NSCoder*)coder
{
	[self release];
	return nil;
}

- (void)dealloc
{
	[_label release];
	[super dealloc];
}

#else

@dynamic label;

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)encodeWithCoder: (NSCoder*)coder
{
}

- (instancetype)initWithCoder: (NSCoder*)coder
{
	[self release];
	return nil;
}

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLSharedEventInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::SharedEvent> _event;
}

@synthesize label = _label;

// What Indium calls when the value is reached, which is on its event loop thread: the notification block is
// passed on to the listener's queue. It holds what it needs until it has been called.
struct MTLSharedEventNotification {
	MTLSharedEventNotificationBlock block;
	id<MTLSharedEvent> event;
	dispatch_queue_t queue;
	uint64_t value;

	MTLSharedEventNotification(MTLSharedEventNotificationBlock theBlock, id<MTLSharedEvent> theEvent, dispatch_queue_t theQueue, uint64_t theValue):
		block([theBlock copy]),
		event([theEvent retain]),
		queue(theQueue),
		value(theValue)
		{
			dispatch_retain(queue);
		};

	MTLSharedEventNotification(const MTLSharedEventNotification& other):
		block([other.block copy]),
		event([other.event retain]),
		queue(other.queue),
		value(other.value)
		{
			dispatch_retain(queue);
		};

	MTLSharedEventNotification& operator=(const MTLSharedEventNotification&) = delete;

	~MTLSharedEventNotification() {
		[block release];
		[event release];
		dispatch_release(queue);
	};

	void operator()() const {
		// the block copies what it captures, so the notification itself can go away
		id<MTLSharedEvent> theEvent = event;
		MTLSharedEventNotificationBlock theBlock = block;
		uint64_t theValue = value;
		dispatch_async(queue, ^{
			theBlock(theEvent, theValue);
		});
	};
};

- (instancetype)initWithEvent: (std::shared_ptr<Indium::SharedEvent>)event
{
	self = [super init];
	if (self != nil) {
		_event = event;
	}
	return self;
}

// A shared event can be used across devices, so it has none, as Apple's MTLEvent.h says and as on macOS 27.
- (id<MTLDevice>)device
{
	return nil;
}

- (std::shared_ptr<Indium::SharedEvent>)indiumSharedEvent
{
	return _event;
}

- (void)dealloc
{
	[_label release];
	[super dealloc];
}

- (uint64_t)signaledValue
{
	return _event->signaledValue();
}

- (void)setSignaledValue: (uint64_t)value
{
	_event->setSignaledValue(value);
}

- (void)notifyListener: (MTLSharedEventListener*)listener
               atValue: (uint64_t)value
                 block: (MTLSharedEventNotificationBlock)block
{
	if (!listener) {
		listener = [MTLSharedEventListener sharedListener];
	}
	// the block gets the value it was registered for, however far the event has gone since
	_event->notify(value, MTLSharedEventNotification(block, self, listener.dispatchQueue, value));
}

- (MTLSharedEventHandle*)newSharedEventHandle
{
	return [[MTLSharedEventHandle alloc] initWithHandle: _event->newSharedEventHandle()];
}

- (BOOL)waitUntilSignaledValue: (uint64_t)value
                     timeoutMS: (uint64_t)milliseconds
{
	return _event->waitUntilSignaledValue(value, milliseconds);
}

#else

@dynamic device;
@dynamic label;
@dynamic signaledValue;

MTL_UNSUPPORTED_CLASS

#endif

@end
