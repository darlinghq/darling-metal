// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLDEPTHSTENCILDESCRIPTOR_H_
#define _METAL_MTLDEPTHSTENCILDESCRIPTOR_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;

typedef NS_ENUM(NSUInteger, MTLCompareFunction) {
	MTLCompareFunctionNever = 0,
	MTLCompareFunctionLess = 1,
	MTLCompareFunctionEqual = 2,
	MTLCompareFunctionLessEqual = 3,
	MTLCompareFunctionGreater = 4,
	MTLCompareFunctionNotEqual = 5,
	MTLCompareFunctionGreaterEqual = 6,
	MTLCompareFunctionAlways = 7,
};

MTL_EXPORT
@interface MTLDepthStencilDescriptor : NSObject

@property(nullable, copy, nonatomic) NSString* label;
@property(nonatomic, getter=isDepthWriteEnabled) BOOL depthWriteEnabled;
@property(nonatomic) MTLCompareFunction depthCompareFunction;

@end

MTL_EXPORT
@protocol MTLDepthStencilState <NSObject>

@property(readonly) id<MTLDevice> device;
@property(nullable, copy, nonatomic) NSString* label;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLDEPTHSTENCILDESCRIPTOR_H_
