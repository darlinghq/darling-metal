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

#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>
#import <Metal/MTLPixelFormatInternal.h>
#import <Metal/MTLTypesInternal.h>

@implementation MTLTextureInternal

#if __OBJC2__

@synthesize texture = _texture;
@synthesize device = _device;
@synthesize resourceOptions = _resourceOptions;

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

- (void)getBytes: (void*)pixelBytes
     bytesPerRow: (NSUInteger)bytesPerRow
      fromRegion: (MTLRegion)region
     mipmapLevel: (NSUInteger)level
{
	NSLog(@"STUB: getBytes:bytesPerRow:fromRegion:mipmapLevel:");
	abort();
}

- (void)getBytes: (void*)pixelBytes
     bytesPerRow: (NSUInteger)bytesPerRow
   bytesPerImage: (NSUInteger)bytesPerImage
      fromRegion: (MTLRegion)region
     mipmapLevel: (NSUInteger)level
           slice: (NSUInteger)slice
{
	NSLog(@"STUB: getBytes:bytesPerRow:bytesPerImage:fromRegion:mipmapLevel:slice:");
	abort();
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
