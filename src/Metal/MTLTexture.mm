// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>
#import <Metal/MTLPixelFormatInternal.h>
#import <Metal/MTLTypesInternal.h>

@implementation MTLTextureInternal {
#if DARLING_METAL_ENABLED
	// Set when the texture holds a copy of its IOSurface plane.
	MTLIOSurfaceCopy* _iosurfaceCopy;
#endif
}

#if DARLING_METAL_ENABLED

@synthesize texture = _texture;

const std::shared_ptr<Indium::Texture>& MTLTextureGetIndium(id<MTLTexture> object)
{
	static const std::shared_ptr<Indium::Texture> none;
	static const Class internalClass = [MTLTextureInternal class];

	if (!MTLObjectIsInstanceOf(object, internalClass)) {
		return none;
	}
	return ((MTLTextureInternal*)object)->_texture;
}

void MTLIOSurfaceWriteSetNote(MTLIOSurfaceWriteSet& set, id<MTLTexture> texture)
{
	static const Class internalClass = [MTLTextureInternal class];

	if (!MTLObjectIsInstanceOf(texture, internalClass)) {
		return;
	}
	MTLTextureInternal* internal = (MTLTextureInternal*)texture;
	if (internal->_iosurface != NULL) {
		set.add(internal->_iosurface, internal->_iosurfaceCopy != nullptr);
	}
}

@synthesize device = _device;
@synthesize resourceOptions = _resourceOptions;
@synthesize label = _label;
@synthesize iosurface = _iosurface;
@synthesize iosurfacePlane = _iosurfacePlane;
@synthesize backingBuffer = _backingBuffer;
@synthesize owningHeap = _owningHeap;

- (instancetype)initWithTexture: (std::shared_ptr<Indium::Texture>)texture
                         device: (id<MTLDevice>)device
                resourceOptions: (MTLResourceOptions)options
{
	return [self initWithTexture: texture device: device resourceOptions: options iosurface: NULL plane: 0 copy: nullptr];
}

- (instancetype)initWithTexture: (std::shared_ptr<Indium::Texture>)texture
                         device: (id<MTLDevice>)device
                resourceOptions: (MTLResourceOptions)options
                      iosurface: (IOSurfaceRef)iosurface
                          plane: (NSUInteger)plane
                           copy: (MTLIOSurfaceCopy*)copy
{
	self = [super init];
	if (self != nil) {
		_texture = texture;
		_device = [device retain];
		_resourceOptions = options;
		if (iosurface != NULL) {
			_iosurface = (IOSurfaceRef)CFRetain(iosurface);
			_iosurfacePlane = plane;
			_iosurfaceCopy = copy;
		}
	}
	return self;
}

- (void)dealloc
{
	// The copy refers to the surface, and the Indium texture may hold the surface's memory;
	// drop both before the surface.
	MTLIOSurfaceCopyDestroy(_iosurfaceCopy);
	_texture.reset();
	if (_iosurface != NULL) {
		CFRelease(_iosurface);
	}
	[(id)_backingBuffer release];
	// the Indium texture gives its range back to the heap, which has to be alive for that
	[(id)_owningHeap release];
	[_device release];
	[_label release];
	[super dealloc];
}

//
// properties
//

- (id<MTLHeap>)heap
{
	return _owningHeap;
}

- (NSUInteger)heapOffset
{
	return _texture->heapOffset();
}

- (NSUInteger)allocatedSize
{
	return _texture->allocatedSize();
}

- (void)makeAliasable
{
	_texture->makeAliasable();
}

- (BOOL)isAliasable
{
	return _texture->isAliasable();
}

- (MTLPurgeableState)setPurgeableState: (MTLPurgeableState)state
{
	// QUIRK: every call returns NonVolatile and no state is ever applied (Volatile and Empty included), so the
	// resource is never purgeable, although the documentation describes returning the previous state. Evidence:
	// black-box observation on macOS 27.0.1 (Apple silicon), buffers and textures of every storage mode (tier 2).
	// Test: test/guest/resource_api.m
	return MTLPurgeableStateNonVolatile;
}

- (id<MTLBuffer>)buffer
{
	return _backingBuffer;
}

- (NSUInteger)bufferOffset
{
	return _texture->bufferOffset();
}

- (NSUInteger)bufferBytesPerRow
{
	return _texture->bufferBytesPerRow();
}

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
	return static_cast<MTLTextureUsage>(_texture->usage());
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
	MTLTextureInternal* view = [[MTLTextureInternal alloc] initWithTexture: tex device: _device resourceOptions: _resourceOptions];
	view.owningHeap = _owningHeap;
	return view;
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
	MTLTextureInternal* view = [[MTLTextureInternal alloc] initWithTexture: tex device: _device resourceOptions: _resourceOptions];
	view.owningHeap = _owningHeap;
	return view;
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
	MTLTextureInternal* view = [[MTLTextureInternal alloc] initWithTexture: tex device: _device resourceOptions: _resourceOptions];
	view.owningHeap = _owningHeap;
	return view;
}

// Indium states a precondition it cannot meet by throwing, and these selectors
// return void, so there is nowhere for the failure to go but out as an
// exception. That is also what the framework itself does: uploading into a
// texture whose storage mode has no host-visible destination is a programming
// error, and Metal raises rather than silently discarding the bytes. Let it
// escape the C++ layer rather than terminating the process with it, and carry
// Indium's message.
static void raiseIndiumFailure(const std::exception& e) {
	@throw [NSException exceptionWithName: NSInvalidArgumentException
	                               reason: [NSString stringWithUTF8String: e.what()]
	                             userInfo: nil];
}

- (void)replaceRegion: (MTLRegion)region
          mipmapLevel: (NSUInteger)level
            withBytes: (const void*)pixelBytes
            bytesPerRow: (NSUInteger)bytesPerRow
{
	if (_iosurfaceCopy != nullptr) {
		MTLIOSurfaceCopyBeforeTextureAccess(_iosurfaceCopy);
	}
	try {
		_texture->replaceRegion(MTLRegionToIndium(region), level, pixelBytes, bytesPerRow);
	} catch (const std::exception& e) {
		raiseIndiumFailure(e);
	}
	if (_iosurfaceCopy != nullptr) {
		MTLIOSurfaceCopyGPUMayHaveWritten();
	}
}

- (void)replaceRegion: (MTLRegion)region
          mipmapLevel: (NSUInteger)level
                slice: (NSUInteger)slice
            withBytes: (const void*)pixelBytes
            bytesPerRow: (NSUInteger)bytesPerRow
          bytesPerImage: (NSUInteger)bytesPerImage
{
	if (_iosurfaceCopy != nullptr) {
		MTLIOSurfaceCopyBeforeTextureAccess(_iosurfaceCopy);
	}
	try {
		_texture->replaceRegion(MTLRegionToIndium(region), level, slice, pixelBytes, bytesPerRow, bytesPerImage);
	} catch (const std::exception& e) {
		raiseIndiumFailure(e);
	}
	if (_iosurfaceCopy != nullptr) {
		MTLIOSurfaceCopyGPUMayHaveWritten();
	}
}

// Indium states a precondition it cannot meet by throwing, and this selector
// returns void, so there is nowhere for the failure to go but out as an
// exception. That is also what the framework itself does: reading a texture
// whose storage mode has no host-visible contents is a programming error, and
// Metal raises rather than returning a sentinel. Let it escape the C++ layer
// rather than terminating the process with it, and carry Indium's message.

- (void)getBytes: (void*)pixelBytes
     bytesPerRow: (NSUInteger)bytesPerRow
      fromRegion: (MTLRegion)region
     mipmapLevel: (NSUInteger)level
{
	if (_iosurfaceCopy != nullptr) {
		MTLIOSurfaceCopyBeforeTextureAccess(_iosurfaceCopy);
	}
	try {
		_texture->getBytes(MTLRegionToIndium(region), level, pixelBytes, bytesPerRow);
	} catch (const std::exception& e) {
		raiseIndiumFailure(e);
	}
}

- (void)getBytes: (void*)pixelBytes
     bytesPerRow: (NSUInteger)bytesPerRow
   bytesPerImage: (NSUInteger)bytesPerImage
      fromRegion: (MTLRegion)region
     mipmapLevel: (NSUInteger)level
           slice: (NSUInteger)slice
{
	if (_iosurfaceCopy != nullptr) {
		MTLIOSurfaceCopyBeforeTextureAccess(_iosurfaceCopy);
	}
	try {
		_texture->getBytes(MTLRegionToIndium(region), level, slice, pixelBytes, bytesPerRow, bytesPerImage);
	} catch (const std::exception& e) {
		raiseIndiumFailure(e);
	}
}

#else

@dynamic backingBuffer;
@dynamic buffer;
@dynamic bufferOffset;
@dynamic bufferBytesPerRow;
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
@dynamic iosurface;
@dynamic iosurfacePlane;

MTL_UNSUPPORTED_CLASS

#endif

@end
