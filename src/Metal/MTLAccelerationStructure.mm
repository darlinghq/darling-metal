// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLAccelerationStructure.h>

#if __LP64__


@implementation MTLMotionKeyframeData

@synthesize buffer = _buffer;
@synthesize offset = _offset;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_buffer = nil;
		_offset = 0;
	}
	return self;
}

- (void)dealloc
{
	[_buffer release];
	[super dealloc];
}

- (void*)data
{
	id<MTLBuffer> buffer = _buffer;

	if (buffer == nil) {
		return NULL;
	}

	// A private buffer has no host-visible contents, and -[MTLBuffer contents]
	// says so by returning NULL. The keyframe bytes are then genuinely not
	// reachable from here, which is a fact about the buffer rather than about
	// this class, so NULL is the answer.
	char* contents = (char*)[buffer contents];

	if (contents == NULL) {
		return NULL;
	}

	return contents + _offset;
}

@end

#endif // __LP64__
