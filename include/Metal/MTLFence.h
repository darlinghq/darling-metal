// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLFENCE_H_
#define _METAL_MTLFENCE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;

/**
 * Orders work between encoders: the commands an encoder updates the fence after (-updateFence:) are done before
 * the commands another encoder waits for the fence before (-waitForFence:).
 */
@protocol MTLFence <NSObject>

@property(nullable, readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLFENCE_H_
