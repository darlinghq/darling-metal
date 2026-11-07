// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLSAMPLERSTATE_H_
#define _METAL_MTLSAMPLERSTATE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;

MTL_EXPORT
@protocol MTLSamplerState <NSObject>

@property(readonly) id<MTLDevice> device;
@property(nullable, copy, nonatomic) NSString* label;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLSAMPLERSTATE_H_
