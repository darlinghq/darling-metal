// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCAPTUREMANAGER_H_
#define _METAL_MTLCAPTUREMANAGER_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

typedef NS_ENUM(NSInteger, MTLCaptureDestination) {
	MTLCaptureDestinationDeveloperTools = 1,
	MTLCaptureDestinationGPUTraceDocument = 2,
};

typedef NS_ENUM(NSInteger, MTLCaptureError) {
	MTLCaptureErrorNotSupported = 1,
	MTLCaptureErrorAlreadyCapturing = 2,
	MTLCaptureErrorInvalidDescriptor = 3,
};

MTL_EXTERN NSErrorDomain const MTLCaptureErrorDomain;

/**
 * Says what to capture and where to put it.
 *
 * A stored value is returned unchanged, so the descriptor itself is honest.
 * What consumes it is not: there is no capture engine, no trace format writer
 * and nowhere to deliver a GPU trace document, so
 * -[MTLCaptureManager startCaptureWithDescriptor:error:] answers NO with a
 * specific error rather than reporting a capture that never began.
 */
MTL_EXPORT
@interface MTLCaptureDescriptor : NSObject <NSCopying>

@property(nullable, nonatomic, retain) id captureObject;
@property(nonatomic) MTLCaptureDestination destination;
@property(nullable, nonatomic, copy) NSURL* outputURL;

@end

MTL_EXPORT
@interface MTLCaptureManager : NSObject

+ (MTLCaptureManager*)sharedCaptureManager;

@property(readonly) BOOL isCapturing;

- (BOOL)startCaptureWithDescriptor: (MTLCaptureDescriptor*)descriptor error: (NSError**)error;
- (void)stopCapture;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCAPTUREMANAGER_H_
