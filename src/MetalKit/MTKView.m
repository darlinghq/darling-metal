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

#import <MetalKit/MTKView.h>
#import <Metal/stubs.h>
#import <Foundation/NSObjectInternal.h>

@implementation MTKView

#if __OBJC2__

{
	id<MTKViewDelegate> _delegate;
	NSInteger _preferredFramesPerSecond;
	BOOL _paused;
	BOOL _enableSetNeedsDisplay;
	id<CAMetalDrawable> _currentDrawable;
	NSTimer* _frameTimer;
}

//
// properties
//

@synthesize autoResizeDrawable = _autoResizeDrawable;
@synthesize clearColor = _clearColor;
@synthesize depthStencilPixelFormat = _depthStencilPixelFormat;
@synthesize depthStencilAttachmentTextureUsage = _depthStencilAttachmentTextureUsage;
@synthesize depthStencilStorageMode = _depthStencilStorageMode;
@synthesize clearDepth = _clearDepth;
@synthesize clearStencil = _clearStencil;
@synthesize sampleCount = _sampleCount;
@synthesize multisampleColorAttachmentTextureUsage = _multisampleColorAttachmentTextureUsage;
@synthesize preferredFramesPerSecond = _preferredFramesPerSecond;
@synthesize paused = _paused;
@synthesize enableSetNeedsDisplay = _enableSetNeedsDisplay;

- (id<MTKViewDelegate>)delegate
{
	return objc_loadWeak(&_delegate);
}

- (void)setDelegate: (id<MTKViewDelegate>)delegate
{
	objc_storeWeak(&_delegate, delegate);
}

- (id<MTLDevice>)device
{
	return ((CAMetalLayer*)_layer).device;
}

- (void)setDevice: (id<MTLDevice>)device
{
	((CAMetalLayer*)_layer).device = device;
}

- (id<MTLDevice>)preferredDevice
{
	return ((CAMetalLayer*)_layer).preferredDevice;
}

- (MTLPixelFormat)colorPixelFormat
{
	return ((CAMetalLayer*)_layer).pixelFormat;
}

- (void)setColorPixelFormat: (MTLPixelFormat)colorPixelFormat
{
	((CAMetalLayer*)_layer).pixelFormat = colorPixelFormat;
}

- (CGColorSpaceRef)colorspace
{
	return ((CAMetalLayer*)_layer).colorspace;
}

- (void)setColorspace: (CGColorSpaceRef)colorspace
{
	((CAMetalLayer*)_layer).colorspace = colorspace;
}

- (BOOL)framebufferOnly
{
	return ((CAMetalLayer*)_layer).framebufferOnly;
}

- (void)setFramebufferOnly: (BOOL)framebufferOnly
{
	((CAMetalLayer*)_layer).framebufferOnly = framebufferOnly;
}

- (CGSize)drawableSize
{
	return ((CAMetalLayer*)_layer).drawableSize;
}

- (void)setDrawableSize: (CGSize)drawableSize
{
	((CAMetalLayer*)_layer).drawableSize = drawableSize;
	[_delegate mtkView: self drawableSizeWillChange: drawableSize];
}

- (CGSize)preferredDrawableSize
{
	// TODO: multiply by contentsScale
	return self.bounds.size;
}

- (MTLRenderPassDescriptor*)currentRenderPassDescriptor
{
	id<MTLDevice> device = self.device;

	if (!device) {
		return nil;
	}

	id<CAMetalDrawable> drawable = self.currentDrawable;

	if (!drawable) {
		return nil;
	}

	MTLRenderPassDescriptor* desc = [MTLRenderPassDescriptor renderPassDescriptor];

	desc.colorAttachments[0].texture = drawable.texture;
	desc.colorAttachments[0].clearColor = _clearColor;
	desc.colorAttachments[0].loadAction = MTLLoadActionClear;
	desc.colorAttachments[0].storeAction = MTLStoreActionStore;

	return desc;
}

- (id<CAMetalDrawable>)currentDrawable
{
	if (!_currentDrawable) {
		_currentDrawable = [[(CAMetalLayer*)_layer nextDrawable] retain];
	}
	return _currentDrawable;
}

- (id<MTLTexture>)depthStencilTexture
{
	// TODO
	return nil;
}

- (id<MTLTexture>)multisampleColorTexture
{
	// TODO
	return nil;
}

// use the synthesized `preferredFramesPerSecond` getter

- (void)setPreferredFramesPerSecond: (NSInteger)preferredFramesPerSecond
{
	if (preferredFramesPerSecond > 60) {
		preferredFramesPerSecond = 60;
	}

	if (preferredFramesPerSecond < 1) {
		preferredFramesPerSecond = 1;
	}

	if (preferredFramesPerSecond == _preferredFramesPerSecond) {
		return;
	}

	_preferredFramesPerSecond = preferredFramesPerSecond;

	[self _resetTimer];
}

// use the synthesized `paused` getter

- (void)setPaused: (BOOL)paused
{
	if (paused == _paused) {
		return;
	}

	_paused = paused;

	[self _resetTimer];
}

// use the synthesized `enableSetNeedsDisplay` getter

- (void)setEnableSetNeedsDisplay: (BOOL)enableSetNeedsDisplay
{
	if (enableSetNeedsDisplay == _enableSetNeedsDisplay) {
		return;
	}

	_enableSetNeedsDisplay = enableSetNeedsDisplay;

	[self _resetTimer];
}

- (BOOL)presentsWithTransaction
{
	return ((CAMetalLayer*)_layer).presentsWithTransaction;
}

- (void)setPresentsWithTransaction: (BOOL)presentsWithTransaction
{
	((CAMetalLayer*)_layer).presentsWithTransaction = presentsWithTransaction;
}

//
// methods
//

- (void)_initCommon
{
	_autoResizeDrawable = YES;
	_clearColor = MTLClearColorMake(0, 0, 0, 1);
	_depthStencilPixelFormat = MTLPixelFormatInvalid;
	_depthStencilAttachmentTextureUsage = MTLTextureUsageRenderTarget;
	_depthStencilStorageMode = MTLStorageModeShared; // TODO: check what the actual default is
	_clearDepth = 1;
	_clearStencil = 0;
	_sampleCount = 1;
	_multisampleColorAttachmentTextureUsage = MTLTextureUsageRenderTarget;
	_preferredFramesPerSecond = 60;
	_paused = NO;
	_enableSetNeedsDisplay = NO;

	[self _resetTimer];
}

- (instancetype)initWithCoder: (NSCoder*)decoder
{
	self.wantsLayer = YES;
	// TODO: check if MTKView has any coding stuff of its own
	self = [super initWithCoder: decoder];
	if (self != nil) {
		[self _initCommon];
	}
	return self;
}

- (instancetype)initWithFrame: (NSRect)frame
{
	self.wantsLayer = YES;
	self = [super initWithFrame: frame];
	if (self != nil) {
		[self _initCommon];
	}
	return self;
}

- (instancetype)initWithFrame: (NSRect)frame
                       device: (id<MTLDevice>)device
{
	self.wantsLayer = YES;
	self = [super initWithFrame: frame];
	if (self != nil) {
		self.device = device;
		[self _initCommon];
	}
	return self;
}

- (void)dealloc
{
	objc_storeWeak(&_delegate, nil);
	[_currentDrawable release];
	[_frameTimer invalidate];
	[_frameTimer release];
	[super dealloc];
}

- (CALayer*)makeBackingLayer
{
	return [CAMetalLayer layer];
}

- (void)draw
{
	[_currentDrawable release];
	_currentDrawable = [[(CAMetalLayer*)_layer nextDrawable] retain];

	if ([self methodForSelector: @selector(drawRect:)] != [MTKView instanceMethodForSelector: @selector(drawRect:)]) {
		// a subclass has overridden this method; invoke it.
		[self drawRect: self.bounds];
	} else {
		// `drawRect:` has not been overridden; invoke the delegate's method.
		[_delegate drawInMTKView: self];
	}

	[_currentDrawable release];
	_currentDrawable = nil;
}

- (void)releaseDrawables
{
	// TODO
	// we don't need this yet since we don't have depth, stencil, or multisample textures
}

- (void)_resetTimer
{
	[_frameTimer invalidate];
	[_frameTimer release];

	if (_paused) {
		return;
	}

	_NSWeakRef* weakSelf = [[[_NSWeakRef alloc] initWithObject: self] autorelease];

	_frameTimer = [[NSTimer scheduledTimerWithTimeInterval: 1.0 / _preferredFramesPerSecond
	                                               repeats: YES
	                                                 block: ^(NSTimer* timer) {
		MTKView* me = weakSelf.object;
		[me draw];
	}] retain];
}

// FIXME: this is a lazy (and probably half-assed) implementation.
//        currently, subclassing an MTKView and implementing `drawRect:`
//        will result in the method always being invoked after `setNeedsDisplay:`,
//        regardless of whether or not `enableSetNeedsDisplay` is set.
//
//        we need to check what the official behavior regarding this method
//        is with subclasses: we need to check whether `drawRect:` is always
//        invoked from `setNeedsDisplay:` or if setting `enableSetNeedsDisplay`
//        to NO will prevent the subclass' `drawRect:` from being invoked due
//        to `setNeedsDisplay`.
//
//        the reason i didn't go ahead and do what sounds like the right behavior
//        right now is because that would requiring overridding various display-related
//        methods, not just `setNeedsDisplay`.
- (void)drawRect: (NSRect)rect
{
	// if we're not paused, we only redraw when the timer fires.
	// if we're not supposed to respond to setNeedsDisplay, we only redraw via manual calls of `draw`.
	if (!_paused || !_enableSetNeedsDisplay) {
		return;
	}
	[self draw];
}

- (void)setFrame: (NSRect)frame
{
	[super setFrame: frame];

	if (_autoResizeDrawable) {
		self.drawableSize = _frame.size;
	}
}

- (void)setBounds: (NSRect)bounds
{
	[super setBounds: bounds];

	if (_autoResizeDrawable) {
		self.drawableSize = _bounds.size;
	}
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
