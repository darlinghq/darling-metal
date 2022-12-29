/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _METALKIT_MTKVIEW_H_
#define _METALKIT_MTKVIEW_H_

#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

@class MTKView;

@protocol MTKViewDelegate

- (void)         mtkView: (MTKView*)view
  drawableSizeWillChange: (CGSize)size;

- (void)drawInMTKView: (MTKView*)view;

@end

MTL_EXPORT
@interface MTKView : NSView <NSCoding, CALayerDelegate>

#if __OBJC2__
@property(nonatomic, weak, nullable) id<MTKViewDelegate> delegate;
#else
@property(nonatomic, assign, nullable) id<MTKViewDelegate> delegate;
#endif

@property(nonatomic, retain, nullable) id<MTLDevice> device;
@property(readonly) id<MTLDevice> preferredDevice;
@property(nonatomic) MTLPixelFormat colorPixelFormat;
@property(nonatomic) CGColorSpaceRef colorspace;
@property(nonatomic) BOOL framebufferOnly;
@property(nonatomic) CGSize drawableSize;
@property(nonatomic, readonly) CGSize preferredDrawableSize;
@property(nonatomic) BOOL autoResizeDrawable;
@property(nonatomic) MTLClearColor clearColor;
@property(nonatomic) MTLPixelFormat depthStencilPixelFormat;
@property(nonatomic) MTLTextureUsage depthStencilAttachmentTextureUsage;
@property(nonatomic) double clearDepth;
@property(nonatomic) uint32_t clearStencil;
@property(nonatomic) NSUInteger sampleCount;
@property(nonatomic) MTLTextureUsage multisampleColorAttachmentTextureUsage;
@property(nonatomic, readonly, nullable) MTLRenderPassDescriptor* currentRenderPassDescriptor;
@property(nonatomic, readonly, nullable) id<CAMetalDrawable> currentDrawable;
@property(nonatomic, readonly, nullable) id<MTLTexture> depthStencilTexture;
@property(nonatomic, readonly, nullable) id<MTLTexture> multisampleColorTexture;
@property(nonatomic) NSInteger preferredFramesPerSecond;
@property(nonatomic, getter=isPaused) BOOL paused;
@property(nonatomic) BOOL enableSetNeedsDisplay;
@property(nonatomic) BOOL presentsWithTransaction;
@property(nonatomic) MTLStorageMode depthStencilStorageMode;

- (instancetype)initWithFrame: (NSRect)frame
                       device: (id<MTLDevice>)device;
- (void)draw;
- (void)releaseDrawables;

@end

#endif // _METALKIT_MTKVIEW_H_
