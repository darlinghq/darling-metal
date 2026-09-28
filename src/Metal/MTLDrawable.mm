// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLDrawableInternal.h>
#import <Metal/stubs.h>

@implementation MTLDrawableInternal

#if DARLING_METAL_ENABLED

@synthesize drawable = _drawable;

- (instancetype)initWithDrawable: (std::shared_ptr<Indium::Drawable>)drawable
{
	self = [super init];
	if (self != nil) {
		_drawable = drawable;
	}
	return self;
}

- (NSUInteger)drawableID
{
	NSLog(@"STUB: drawableID");
	return 0;
}

- (CFTimeInterval)presentedTime
{
	NSLog(@"STUB: presentedTime");
	return 0;
}

- (void)present
{
	_drawable->present();
}

- (void)presentAfterMinimumDuration: (CFTimeInterval)duration
{
	// This wrapper has no clock of its own: -present hands the drawable to whichever
	// layer produced it, and that layer decides when the frame is shown. So a minimum
	// duration cannot be scheduled here. Present anyway (that is what the call asks
	// for) and say once that the hint was dropped rather than pretending to honour it.
	static int warned;
	if (duration > 0 && !__sync_lock_test_and_set(&warned, 1)) {
		NSLog(@"MTLDrawable: presentAfterMinimumDuration: %.6f cannot be scheduled; the layer presents on its own tick",
		      duration);
	}
	[self present];
}

- (void)presentAtTime: (CFTimeInterval)presentationTime
{
	// There is no timed queue anywhere in this path, so every target time is a hint
	// this wrapper cannot honour; the layer's tick decides when the frame goes out.
	static int warned;
	if (!__sync_lock_test_and_set(&warned, 1)) {
		NSLog(@"MTLDrawable: presentAtTime: %.6f cannot be scheduled; the layer presents on its own tick",
		      presentationTime);
	}
	[self present];
}

- (void)addPresentedHandler: (MTLDrawablePresentedHandler)block
{
	// There is no presentation-completion callback to attach the block to on this
	// wrapper: Indium::Drawable::present() returns void and the layer that owns the
	// drawable reports completion on its own. Dropping the block silently would leave
	// the caller waiting forever for a callback that can never run, so raise instead.
	@throw [NSException exceptionWithName: NSInvalidArgumentException
	                               reason: @"addPresentedHandler: is not supported on a bare MTLDrawable; "
	                                       @"use the drawable of a CAMetalLayer, which reports presentation"
	                             userInfo: nil];
}

#else

@dynamic drawableID;
@dynamic presentedTime;

MTL_UNSUPPORTED_CLASS

#endif

@end
