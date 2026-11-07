// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Foundation/Foundation.h>
#import <Metal/stubs.h>

@interface MPSKernel : NSObject <NSCopying>
@end

@implementation MPSKernel
- (id)copyWithZone:(NSZone *)zone {
    return [self retain];
}
@end

@interface MPSImageGaussianBlur : MPSKernel
@end

// No image kernel here has an implementation, and a blur that quietly leaves its destination
// texture untouched is indistinguishable from a working one, so refuse any use of it.
@implementation MPSImageGaussianBlur
MTL_UNSUPPORTED_CLASS
@end

@interface MPSImage : NSObject
@end

@implementation MPSImage
@end

@interface MPSMatrix : NSObject
@end

@implementation MPSMatrix
@end

@interface MPSGraph : NSObject
+ (instancetype)graph;
@end

@implementation MPSGraph
+ (instancetype)graph {
    return [[[self alloc] init] autorelease];
}
@end

BOOL MPSSupportsMTLDevice(id device) {
    return NO;
}
