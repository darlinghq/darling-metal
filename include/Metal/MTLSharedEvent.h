// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLSHAREDEVENT_H_
#define _METAL_MTLSHAREDEVENT_H_

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

/**
 * The queue a shared event notifies on.
 *
 * This holds nothing but a dispatch queue and hands that same queue back, so
 * nothing here is invented. No notification will ever arrive, and that is worth
 * stating plainly: signalling needs MTLSharedEvent, whose -notifyListener:...
 * would have to raise a semaphore or signal a fence on the host, and neither
 * MTLSharedEvent nor MTLSharedEventHandle is provided. -[MTLDevice newSharedEvent]
 * is therefore not declared, so a caller that wants one is told so at the call
 * rather than receiving an event that never fires and never says why.
 */
MTL_EXPORT
@interface MTLSharedEventListener : NSObject

+ (MTLSharedEventListener*)sharedListener;

- (instancetype)initWithDispatchQueue: (dispatch_queue_t)dispatchQueue;

@property(nonnull, readonly) dispatch_queue_t dispatchQueue;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLSHAREDEVENT_H_
