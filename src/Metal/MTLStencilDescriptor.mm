// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLStencilDescriptor.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <Metal/stubs.h>

@implementation MTLStencilDescriptor

#if DARLING_METAL_ENABLED

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return MTLStubSignature(aSelector);
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

#endif

@end
