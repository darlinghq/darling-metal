// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLRESIDENCYSETINTERNAL_H_
#define _METAL_MTLRESIDENCYSETINTERNAL_H_

#import <Metal/MTLResidencySet.h>
#import <Metal/MTLDevice.h>

METAL_DECLARATIONS_BEGIN

@interface MTLResidencySetInternal : NSObject <MTLResidencySet>

- (instancetype)initWithDevice: (id<MTLDevice>)device
                         label: (NSString*)label
               initialCapacity: (NSUInteger)initialCapacity;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRESIDENCYSETINTERNAL_H_
