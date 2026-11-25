// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLEVENT_H_
#define _METAL_MTLEVENT_H_

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLSharedEvent;
@class MTLSharedEventListener;

/**
 * A counter command buffers of one device signal and wait on (-[MTLCommandBuffer encodeSignalEvent:value:] and
 * -encodeWaitForEvent:value:). Its value starts at 0 and only goes up; a wait on a value that has already been
 * reached holds nothing up.
 */
@protocol MTLEvent <NSObject>

/** The device that made the event; nil for a shared event, which is not tied to one device. */
@property(nullable, readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;

@end

typedef void (^MTLSharedEventNotificationBlock)(id<MTLSharedEvent> sharedEvent, uint64_t value);

/**
 * Names a shared event, so that -[MTLDevice newSharedEventWithHandle:] can make another object for it.
 *
 * A handle only works inside the process that made it: encoding one (with any coder) raises an exception.
 */
MTL_EXPORT
@interface MTLSharedEventHandle : NSObject <NSSecureCoding>

@property(nullable, readonly) NSString* label;

@end

/**
 * An event whose value the host can read, raise and wait on as well. The value only goes up: setting a lower
 * value, or signaling one from a command buffer, leaves it unchanged.
 */
@protocol MTLSharedEvent <MTLEvent>

/**
 * Calls `block` on the listener's queue once the value has reached `value` (also if it already has), with this
 * event and `value`.
 */
- (void)notifyListener: (MTLSharedEventListener*)listener
               atValue: (uint64_t)value
                 block: (MTLSharedEventNotificationBlock)block;

- (MTLSharedEventHandle*)newSharedEventHandle;

/** Returns whether the value reached `value` within `milliseconds`. */
- (BOOL)waitUntilSignaledValue: (uint64_t)value
                     timeoutMS: (uint64_t)milliseconds;

@property uint64_t signaledValue;

@end

/**
 * The queue a shared event notifies on.
 */
MTL_EXPORT
@interface MTLSharedEventListener : NSObject

+ (MTLSharedEventListener*)sharedListener;

/** A listener with a serial queue of its own. */
- (instancetype)init;

- (instancetype)initWithDispatchQueue: (dispatch_queue_t)dispatchQueue;

@property(nonnull, readonly) dispatch_queue_t dispatchQueue;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLEVENT_H_
