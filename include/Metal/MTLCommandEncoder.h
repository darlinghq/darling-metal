// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;


// How a command uses a resource the application says it uses (-useResource:usage:).
typedef NS_OPTIONS(NSUInteger, MTLResourceUsage) {
	MTLResourceUsageRead = 1 << 0,
	MTLResourceUsageWrite = 1 << 1,
	MTLResourceUsageSample = 1 << 2,
};

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
