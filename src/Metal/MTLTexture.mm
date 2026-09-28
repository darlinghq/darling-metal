// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>
#import <Metal/MTLPixelFormatInternal.h>
#import <Metal/MTLTypesInternal.h>

@implementation MTLTextureInternal

#if DARLING_METAL_ENABLED

@synthesize texture = _texture;
@synthesize device = _device;
@synthesize resourceOptions = _resourceOptions;
@synthesize label = _label;

- (instancetype)initWithTexture: (std::shared_ptr<Indium::Texture>)texture
                         device: (id<MTLDevice>)device
                resourceOptions: (MTLResourceOptions)options
{
	self = [super init];
	if (self != nil) {
		_texture = texture;
		_device = [device retain];
		_resourceOptions = options;
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[super dealloc];
}

//
// properties
//

- (MTLCPUCacheMode)cpuCacheMode
{
	return static_cast<MTLCPUCacheMode>((self.resourceOptions >> MTLResourceCPUCacheModeShift) & 0x0f);
}

- (MTLStorageMode)storageMode
{
	return static_cast<MTLStorageMode>((self.resourceOptions >> MTLResourceStorageModeShift) & 0x0f);
}

- (MTLHazardTrackingMode)hazardTrackingMode
{
	return static_cast<MTLHazardTrackingMode>((self.resourceOptions >> MTLResourceHazardTrackingModeShift) & 0x0f);
}

- (MTLTextureType)textureType
{
	return static_cast<MTLTextureType>(_texture->textureType());
}

- (MTLPixelFormat)pixelFormat
{
	return static_cast<MTLPixelFormat>(_texture->pixelFormat());
}

- (NSUInteger)width
{
	return _texture->width();
}

- (NSUInteger)height
{
	return _texture->height();
}

- (NSUInteger)depth
{
	return _texture->depth();
}

- (NSUInteger)mipmapLevelCount
{
	return _texture->mipmapLevelCount();
}

- (NSUInteger)arrayLength
{
	return _texture->arrayLength();
}

- (NSUInteger)sampleCount
{
	return _texture->sampleCount();
}

- (BOOL)isFramebufferOnly
{
	return _texture->framebufferOnly();
}

- (MTLTextureUsage)usage
{
	// TODO
	return MTLTextureUsageUnknown;
}

- (BOOL)allowGPUOptimizedContents
{
	return _texture->allowGPUOptimizedContents();
}

- (BOOL)isShareable
{
	return _texture->shareable();
}

- (MTLTextureSwizzleChannels)swizzle
{
	return MTLTextureSwizzleChannelsFromIndium(_texture->swizzle());
}

//
// methods
//

- (id<MTLTexture>)newTextureViewWithPixelFormat: (MTLPixelFormat)pixelFormat
{
	auto tex = _texture->newTextureView(static_cast<Indium::PixelFormat>(pixelFormat));
	if (!tex) {
		return nil;
	}
	return [[MTLTextureInternal alloc] initWithTexture: tex device: _device resourceOptions: _resourceOptions];
}

- (id<MTLTexture>)newTextureViewWithPixelFormat: (MTLPixelFormat)pixelFormat
                                    textureType: (MTLTextureType)textureType
                                         levels: (NSRange)levelRange
                                         slices: (NSRange)sliceRange
{
	auto tex = _texture->newTextureView(static_cast<Indium::PixelFormat>(pixelFormat), static_cast<Indium::TextureType>(textureType), NSRangeToIndium(levelRange), NSRangeToIndium(sliceRange));
	if (!tex) {
		return nil;
	}
	return [[MTLTextureInternal alloc] initWithTexture: tex device: _device resourceOptions: _resourceOptions];
}

- (id<MTLTexture>)newTextureViewWithPixelFormat: (MTLPixelFormat)pixelFormat
                                    textureType: (MTLTextureType)textureType
                                         levels: (NSRange)levelRange
                                         slices: (NSRange)sliceRange
                                        swizzle: (MTLTextureSwizzleChannels)swizzle
{
	auto tex = _texture->newTextureView(static_cast<Indium::PixelFormat>(pixelFormat), static_cast<Indium::TextureType>(textureType), NSRangeToIndium(levelRange), NSRangeToIndium(sliceRange), MTLTextureSwizzleChannelsToIndium(swizzle));
	if (!tex) {
		return nil;
	}
	return [[MTLTextureInternal alloc] initWithTexture: tex device: _device resourceOptions: _resourceOptions];
}

- (void)replaceRegion: (MTLRegion)region
          mipmapLevel: (NSUInteger)level
            withBytes: (const void*)pixelBytes
          bytesPerRow: (NSUInteger)bytesPerRow
{
	_texture->replaceRegion(MTLRegionToIndium(region), level, pixelBytes, bytesPerRow);
}

- (void)replaceRegion: (MTLRegion)region
          mipmapLevel: (NSUInteger)level
                slice: (NSUInteger)slice
            withBytes: (const void*)pixelBytes
          bytesPerRow: (NSUInteger)bytesPerRow
        bytesPerImage: (NSUInteger)bytesPerImage
{
	_texture->replaceRegion(MTLRegionToIndium(region), level, slice, pixelBytes, bytesPerRow, bytesPerImage);
}

// Indium states a precondition it cannot meet by throwing, and this selector
// returns void, so there is nowhere for the failure to go but out as an
// exception. That is also what the framework itself does: reading a texture
// whose storage mode has no host-visible contents is a programming error, and
// Metal raises rather than returning a sentinel. Let it escape the C++ layer
// rather than terminating the process with it, and carry Indium's message.
static void raiseIndiumFailure(const std::exception& e) {
	@throw [NSException exceptionWithName: NSInvalidArgumentException
	                               reason: [NSString stringWithUTF8String: e.what()]
	                             userInfo: nil];
}

- (void)getBytes: (void*)pixelBytes
     bytesPerRow: (NSUInteger)bytesPerRow
      fromRegion: (MTLRegion)region
     mipmapLevel: (NSUInteger)level
{
	(void)pixelBytes; (void)bytesPerRow; (void)region; (void)level;
	NSLog(@"STUB: -[MTLTexture getBytes:bytesPerRow:fromRegion:mipmapLevel:]");
}

- (void)getBytes: (void*)pixelBytes
     bytesPerRow: (NSUInteger)bytesPerRow
   bytesPerImage: (NSUInteger)bytesPerImage
      fromRegion: (MTLRegion)region
     mipmapLevel: (NSUInteger)level
           slice: (NSUInteger)slice
{
	(void)pixelBytes; (void)bytesPerRow; (void)bytesPerImage; (void)region; (void)level; (void)slice;
	NSLog(@"STUB: -[MTLTexture getBytes:bytesPerRow:bytesPerImage:fromRegion:mipmapLevel:slice:]");
}

#else

@dynamic textureType;
@dynamic pixelFormat;
@dynamic width;
@dynamic height;
@dynamic depth;
@dynamic mipmapLevelCount;
@dynamic arrayLength;
@dynamic sampleCount;
@dynamic framebufferOnly;
@dynamic usage;
@dynamic allowGPUOptimizedContents;
@dynamic shareable;
@dynamic swizzle;

MTL_UNSUPPORTED_CLASS

#endif

@end
