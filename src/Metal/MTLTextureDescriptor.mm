// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLTextureDescriptorInternal.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/stubs.h>

@implementation MTLTextureDescriptor

#if DARLING_METAL_ENABLED

@synthesize textureType = _textureType;
@synthesize pixelFormat = _pixelFormat;
@synthesize width = _width;
@synthesize height = _height;
@synthesize depth = _depth;
@synthesize mipmapLevelCount = _mipmapLevelCount;
@synthesize sampleCount = _sampleCount;
@synthesize arrayLength = _arrayLength;
@synthesize cpuCacheMode = _cpuCacheMode;
@synthesize storageMode = _storageMode;
@synthesize hazardTrackingMode = _hazardTrackingMode;
@synthesize allowGPUOptimizedContents = _allowGPUOptimizedContents;
@synthesize usage = _usage;
@synthesize swizzle = _swizzle;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		// these defaults mirror Indium::TextureDescriptor, which mirrors the official framework
		_textureType = MTLTextureType2D;
		_pixelFormat = MTLPixelFormatRGBA8Unorm;
		_width = 1;
		_height = 1;
		_depth = 1;
		_mipmapLevelCount = 1;
		_sampleCount = 1;
		_arrayLength = 1;
		_cpuCacheMode = MTLCPUCacheModeDefaultCache;
		_storageMode = MTLStorageModeManaged;
		_hazardTrackingMode = MTLHazardTrackingModeDefault;
		_allowGPUOptimizedContents = YES;
		_usage = MTLTextureUsageShaderRead;
		_swizzle = MTLTextureSwizzleChannelsDefault;
	}
	return self;
}

+ (MTLTextureDescriptor*)texture2DDescriptorWithPixelFormat: (MTLPixelFormat)pixelFormat
                                                      width: (NSUInteger)width
                                                     height: (NSUInteger)height
                                                  mipmapped: (BOOL)mipmapped
{
	MTLTextureDescriptor* descriptor = [[MTLTextureDescriptor new] autorelease];
	descriptor.textureType = MTLTextureType2D;
	descriptor.pixelFormat = pixelFormat;
	descriptor.width = width;
	descriptor.height = height;
	// Indium owns the mipmap level count formula, so take it from there rather than repeating it
	descriptor.mipmapLevelCount = Indium::TextureDescriptor::texture2DDescriptor(static_cast<Indium::PixelFormat>(pixelFormat), width, height, mipmapped).mipmapLevelCount;
	return descriptor;
}

+ (MTLTextureDescriptor*)textureCubeDescriptorWithPixelFormat: (MTLPixelFormat)pixelFormat
                                                         size: (NSUInteger)size
                                                    mipmapped: (BOOL)mipmapped
{
	MTLTextureDescriptor* descriptor = [[MTLTextureDescriptor new] autorelease];
	descriptor.textureType = MTLTextureTypeCube;
	descriptor.pixelFormat = pixelFormat;
	descriptor.width = size;
	descriptor.height = size;
	descriptor.mipmapLevelCount = Indium::TextureDescriptor::textureCubeDescriptor(static_cast<Indium::PixelFormat>(pixelFormat), size, mipmapped).mipmapLevelCount;
	return descriptor;
}

// the three mode properties are the stored ones; `resourceOptions` is the packed view of them
- (MTLResourceOptions)resourceOptions
{
	return (_cpuCacheMode << MTLResourceCPUCacheModeShift) |
	       (_storageMode << MTLResourceStorageModeShift) |
	       (_hazardTrackingMode << MTLResourceHazardTrackingModeShift);
}

- (void)setResourceOptions: (MTLResourceOptions)resourceOptions
{
	_cpuCacheMode = static_cast<MTLCPUCacheMode>((resourceOptions >> MTLResourceCPUCacheModeShift) & 0x0f);
	_storageMode = static_cast<MTLStorageMode>((resourceOptions >> MTLResourceStorageModeShift) & 0x0f);
	_hazardTrackingMode = static_cast<MTLHazardTrackingMode>((resourceOptions >> MTLResourceHazardTrackingModeShift) & 0x0f);
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLTextureDescriptor* copy = [MTLTextureDescriptor new];
	copy.textureType = _textureType;
	copy.pixelFormat = _pixelFormat;
	copy.width = _width;
	copy.height = _height;
	copy.depth = _depth;
	copy.mipmapLevelCount = _mipmapLevelCount;
	copy.sampleCount = _sampleCount;
	copy.arrayLength = _arrayLength;
	copy.cpuCacheMode = _cpuCacheMode;
	copy.storageMode = _storageMode;
	copy.hazardTrackingMode = _hazardTrackingMode;
	copy.allowGPUOptimizedContents = _allowGPUOptimizedContents;
	copy.usage = _usage;
	copy.swizzle = _swizzle;
	return copy;
}

- (Indium::TextureDescriptor)asIndiumDescriptor
{
	Indium::TextureDescriptor descriptor {};
	descriptor.textureType = static_cast<Indium::TextureType>(_textureType);
	descriptor.pixelFormat = static_cast<Indium::PixelFormat>(_pixelFormat);
	descriptor.width = _width;
	descriptor.height = _height;
	descriptor.depth = _depth;
	descriptor.mipmapLevelCount = _mipmapLevelCount;
	descriptor.sampleCount = _sampleCount;
	descriptor.arrayLength = _arrayLength;
	descriptor.resourceOptions = static_cast<Indium::ResourceOptions>(self.resourceOptions);
	descriptor.allowGPUOptimizedContents = _allowGPUOptimizedContents;
	descriptor.usage = static_cast<Indium::TextureUsage>(_usage);
	descriptor.swizzle = MTLTextureSwizzleChannelsToIndium(_swizzle);
	return descriptor;
}

#else

@dynamic textureType;
@dynamic pixelFormat;
@dynamic width;
@dynamic height;
@dynamic depth;
@dynamic mipmapLevelCount;
@dynamic sampleCount;
@dynamic arrayLength;
@dynamic resourceOptions;
@dynamic cpuCacheMode;
@dynamic storageMode;
@dynamic hazardTrackingMode;
@dynamic allowGPUOptimizedContents;
@dynamic usage;
@dynamic swizzle;

MTL_UNSUPPORTED_CLASS

#endif

@end
