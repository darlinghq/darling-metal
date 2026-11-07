// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLCaptureManager.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

#if __LP64__


MTL_EXTERN NSErrorDomain const MTLCaptureErrorDomain = @"MTLCaptureErrorDomain";

@implementation MTLCaptureDescriptor

@synthesize captureObject = _captureObject;
@synthesize destination = _destination;
@synthesize outputURL = _outputURL;

- (void)dealloc
{
	[_captureObject release];
	[_outputURL release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLCaptureDescriptor* copy = [[MTLCaptureDescriptor allocWithZone: zone] init];

	copy.captureObject = _captureObject;
	copy.destination = _destination;
	copy.outputURL = _outputURL;

	return copy;
}

@end

@implementation MTLCaptureManager

@synthesize isCapturing = _isCapturing;

+ (MTLCaptureManager*)sharedCaptureManager
{
	static MTLCaptureManager* shared = nil;
	static dispatch_once_t once;

	dispatch_once(&once, ^{
		shared = [[MTLCaptureManager alloc] init];
	});

	return shared;
}

- (BOOL)startCaptureWithDescriptor: (MTLCaptureDescriptor*)descriptor error: (NSError**)error
{
	// Capturing is refused rather than accepted and ignored. This method
	// previously had no signature at all and went through a void-signature
	// forwardInvocation, so the BOOL a caller read was whatever happened to be
	// in the return register: a caller that checked it could act on "capture
	// started" for a capture that never began. A descriptor that reports its
	// own values honestly is not much use if the thing that consumes it
	// answers arbitrarily, so the refusal is explicit.
	if (error) {
		*error = [NSError errorWithDomain: MTLCaptureErrorDomain
		                             code: MTLCaptureErrorNotSupported
		                         userInfo: [NSDictionary dictionaryWithObject:
			@"Metal capture is not implemented: there is no capture engine and no "
			@"trace format writer, so no capture can produce output."
		                             forKey: NSLocalizedDescriptionKey]];
	}

	return NO;
}

- (void)stopCapture
{
	// Nothing is ever capturing, so there is nothing to stop. Reporting that
	// would be an invention.
	NSLog(@"MTLCaptureManager: -stopCapture called, but no capture is running "
		@"because -startCaptureWithDescriptor:error: always refuses.");
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end

#endif // __LP64__
