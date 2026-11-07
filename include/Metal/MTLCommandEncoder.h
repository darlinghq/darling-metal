// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;

typedef NS_OPTIONS(NSUInteger, MTLBarrierScope) {
	MTLBarrierScopeBuffers = 1 << 0,
	MTLBarrierScopeTextures = 1 << 1,
	MTLBarrierScopeRenderTargets = 1 << 2,
};

@protocol MTLCommandEncoder <NSObject>

@property(readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;

- (void)endEncoding;

@end

METAL_DECLARATIONS_END
