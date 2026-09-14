// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Foundation/Foundation.h>

@interface MPSKernel : NSObject <NSCopying>
@end

@implementation MPSKernel
- (id)copyWithZone:(NSZone *)zone {
    return [self retain];
}
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
