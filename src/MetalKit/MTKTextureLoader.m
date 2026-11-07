// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <MetalKit/MTKTextureLoader.h>
#import <ImageIO/ImageIO.h>
#import <Metal/stubs.h>

const MTKTextureLoaderError MTKTextureLoaderErrorDomain = @"MTKTextureLoaderErrorDomain";
const MTKTextureLoaderError MTKTextureLoaderErrorKey = @"MTKTextureLoaderErrorKey";

const MTKTextureLoaderOption MTKTextureLoaderOptionAllocateMipmaps = @"MTKTextureLoaderOptionAllocateMipmaps";
const MTKTextureLoaderOption MTKTextureLoaderOptionGenerateMipmaps = @"MTKTextureLoaderOptionGenerateMipmaps";
const MTKTextureLoaderOption MTKTextureLoaderOptionSRGB = @"MTKTextureLoaderOptionSRGB";
const MTKTextureLoaderOption MTKTextureLoaderOptionTextureUsage = @"MTKTextureLoaderOptionTextureUsage";
const MTKTextureLoaderOption MTKTextureLoaderOptionTextureCPUCacheMode = @"MTKTextureLoaderOptionTextureCPUCacheMode";
const MTKTextureLoaderOption MTKTextureLoaderOptionTextureStorageMode = @"MTKTextureLoaderOptionTextureStorageMode";
const MTKTextureLoaderOption MTKTextureLoaderOptionCubeLayout = @"MTKTextureLoaderOptionCubeLayout";
const MTKTextureLoaderOption MTKTextureLoaderOptionOrigin = @"MTKTextureLoaderOptionOrigin";

const MTKTextureLoaderOrigin MTKTextureLoaderOriginTopLeft = @"MTKTextureLoaderOriginTopLeft";
const MTKTextureLoaderOrigin MTKTextureLoaderOriginBottomLeft = @"MTKTextureLoaderOriginBottomLeft";
const MTKTextureLoaderOrigin MTKTextureLoaderOriginFlippedVertically = @"MTKTextureLoaderOriginFlippedVertically";

#if DARLING_METAL_ENABLED

static NSString* const kImageResourceExtensions[] = {
	@"png", @"jpg", @"jpeg", @"tiff", @"tif", @"bmp", @"gif",
};

static id MTKTextureLoaderFail(NSError** error, NSString* format, ...) {
	va_list args;
	va_start(args, format);
	NSString* description = [[[NSString alloc] initWithFormat: format arguments: args] autorelease];
	va_end(args);

	if (error) {
		*error = [NSError errorWithDomain: MTKTextureLoaderErrorDomain
		                             code: 0
		                         userInfo: @{
			NSLocalizedDescriptionKey: description,
			MTKTextureLoaderErrorKey: description,
		}];
	}
	return nil;
}

// Used for options we cannot honour at all. Returning an unmipmapped or differently laid out
// texture would look like a successful load, so refuse loudly instead.
static void MTKTextureLoaderUnsupported(NSString* what) __attribute__((noreturn));

static void MTKTextureLoaderUnsupported(NSString* what) {
	NSLog(@"MTKTextureLoader: %@ is not supported in Darling", what);
	abort();
}

#endif

@implementation MTKTextureLoader

#if DARLING_METAL_ENABLED

@synthesize device = _device;

- (instancetype)initWithDevice: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_device = [device retain];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[super dealloc];
}

- (id<MTLTexture>)newTextureWithCGImage: (CGImageRef)cgImage
                                options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                                  error: (NSError**)error
{
	if (!cgImage) {
		return MTKTextureLoaderFail(error, @"no image was given");
	}

	for (MTKTextureLoaderOption key in @[
		MTKTextureLoaderOptionAllocateMipmaps,
		MTKTextureLoaderOptionGenerateMipmaps,
		MTKTextureLoaderOptionSRGB,
		MTKTextureLoaderOptionTextureUsage,
		MTKTextureLoaderOptionTextureCPUCacheMode,
		MTKTextureLoaderOptionTextureStorageMode,
	]) {
		id value = options[key];
		if (value != nil && ![value isKindOfClass: [NSNumber class]]) {
			return MTKTextureLoaderFail(error, @"%@ must be an NSNumber, not a %@", key, [value class]);
		}
	}

	if ([options[MTKTextureLoaderOptionGenerateMipmaps] boolValue] || [options[MTKTextureLoaderOptionAllocateMipmaps] boolValue]) {
		// generating mipmaps needs a blit command encoder, which Metal does not expose yet
		MTKTextureLoaderUnsupported(@"mipmap generation");
	}

	if (options[MTKTextureLoaderOptionCubeLayout] != nil) {
		MTKTextureLoaderUnsupported(@"cube textures");
	}

	BOOL flipVertically = NO;
	MTKTextureLoaderOrigin origin = options[MTKTextureLoaderOptionOrigin];
	if (origin != nil) {
		if (![origin isKindOfClass: [NSString class]]) {
			return MTKTextureLoaderFail(error, @"%@ must be an NSString, not a %@", MTKTextureLoaderOptionOrigin, [origin class]);
		}
		if ([origin isEqualToString: MTKTextureLoaderOriginBottomLeft] || [origin isEqualToString: MTKTextureLoaderOriginFlippedVertically]) {
			flipVertically = YES;
		} else if (![origin isEqualToString: MTKTextureLoaderOriginTopLeft]) {
			return MTKTextureLoaderFail(error, @"unknown texture origin \"%@\"", origin);
		}
	}

	size_t width = CGImageGetWidth(cgImage);
	size_t height = CGImageGetHeight(cgImage);

	if (width == 0 || height == 0) {
		return MTKTextureLoaderFail(error, @"the image is empty (%zux%zu)", width, height);
	}

	// BGRA premultiplied is the only 32-bit layout Onyx2D renders into natively, so ask for exactly
	// that and hand the bytes to Metal as BGRA8Unorm. note that this means every texture loaded
	// here has premultiplied alpha, whatever the source file used.
	//
	// Onyx2D does no color management either: the bytes it writes are the decoder's own samples,
	// and those are gamma encoded for the formats anyone loads textures from. so default to an
	// sRGB pixel format and let MTKTextureLoaderOptionSRGB opt out.
	BOOL srgb = YES;
	NSNumber* srgbOption = options[MTKTextureLoaderOptionSRGB];
	if (srgbOption != nil) {
		srgb = srgbOption.boolValue;
	}

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(colorSpace);

	if (!context) {
		return MTKTextureLoaderFail(error, @"could not create a %zux%zu BGRA bitmap for the image", width, height);
	}

	if (flipVertically) {
		CGContextTranslateCTM(context, 0, height);
		CGContextScaleCTM(context, 1, -1);
	}
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);

	const void* pixels = CGBitmapContextGetData(context);
	size_t bytesPerRow = CGBitmapContextGetBytesPerRow(context);

	if (!pixels) {
		CGContextRelease(context);
		return MTKTextureLoaderFail(error, @"the bitmap for the image has no backing store");
	}

	MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: (srgb ? MTLPixelFormatBGRA8Unorm_sRGB : MTLPixelFormatBGRA8Unorm)
	                                                                                      width: width
	                                                                                     height: height
	                                                                                  mipmapped: NO];

	// Indium enables every usage flag on the images it creates and ignores the descriptor's usage,
	// so this only records what the caller asked for; it neither grants nor withholds anything
	NSNumber* usage = options[MTKTextureLoaderOptionTextureUsage];
	if (usage != nil) {
		descriptor.usage = usage.unsignedIntegerValue;
	}

	NSNumber* cpuCacheMode = options[MTKTextureLoaderOptionTextureCPUCacheMode];
	if (cpuCacheMode != nil) {
		descriptor.cpuCacheMode = cpuCacheMode.unsignedIntegerValue;
	}

	NSNumber* storageMode = options[MTKTextureLoaderOptionTextureStorageMode];
	if (storageMode != nil) {
		if (storageMode.unsignedIntegerValue == MTLStorageModePrivate) {
			// uploading into private storage needs a staging buffer and a blit command encoder
			MTKTextureLoaderUnsupported(@"private storage mode");
		}
		descriptor.storageMode = storageMode.unsignedIntegerValue;
	}

	id<MTLTexture> texture = [_device newTextureWithDescriptor: descriptor];
	if (!texture) {
		CGContextRelease(context);
		return MTKTextureLoaderFail(error, @"the device could not allocate a %zux%zu texture", width, height);
	}

	[texture replaceRegion: MTLRegionMake2D(0, 0, width, height)
	           mipmapLevel: 0
	             withBytes: pixels
	           bytesPerRow: bytesPerRow];

	CGContextRelease(context);

	return texture;
}

- (id<MTLTexture>)newTextureWithImageSource: (CGImageSourceRef)source
                                    options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                                      error: (NSError**)error
{
	if (!source) {
		return MTKTextureLoaderFail(error, @"the image data could not be read");
	}

	if (CGImageSourceGetCount(source) == 0) {
		return MTKTextureLoaderFail(error, @"the image data contains no images");
	}

	CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);

	if (!image) {
		return MTKTextureLoaderFail(error, @"the image could not be decoded");
	}

	id<MTLTexture> texture = [self newTextureWithCGImage: image options: options error: error];
	CGImageRelease(image);
	return texture;
}

- (id<MTLTexture>)newTextureWithContentsOfURL: (NSURL*)URL
                                      options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                                        error: (NSError**)error
{
	if (!URL) {
		return MTKTextureLoaderFail(error, @"no URL was given");
	}

	CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)URL, NULL);
	id<MTLTexture> texture = [self newTextureWithImageSource: source options: options error: error];
	if (source) {
		CFRelease(source);
	}
	return texture;
}

- (id<MTLTexture>)newTextureWithData: (NSData*)data
                             options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                               error: (NSError**)error
{
	if (!data) {
		return MTKTextureLoaderFail(error, @"no data was given");
	}

	CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data, NULL);
	id<MTLTexture> texture = [self newTextureWithImageSource: source options: options error: error];
	if (source) {
		CFRelease(source);
	}
	return texture;
}

- (id<MTLTexture>)newTextureWithName: (NSString*)name
                         scaleFactor: (CGFloat)scaleFactor
                              bundle: (NSBundle*)bundle
                             options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                               error: (NSError**)error
{
	if (!name) {
		return MTKTextureLoaderFail(error, @"no texture name was given");
	}

	NSBundle* searchBundle = bundle ?: [NSBundle mainBundle];

	NSMutableArray<NSString*>* candidates = [NSMutableArray array];
	if (scaleFactor > 1.0) {
		[candidates addObject: [NSString stringWithFormat: @"%@@%lux", name, (unsigned long)lround(scaleFactor)]];
	}
	[candidates addObject: name];

	for (NSString* candidate in candidates) {
		for (size_t i = 0; i < sizeof(kImageResourceExtensions) / sizeof(*kImageResourceExtensions); ++i) {
			NSURL* url = [searchBundle URLForResource: candidate withExtension: kImageResourceExtensions[i]];
			if (url != nil) {
				return [self newTextureWithContentsOfURL: url options: options error: error];
			}
		}
	}

	// the official framework reads these out of a compiled asset catalog, which Darling has no
	// reader for; a caller that ships loose image files still works via the search above
	return MTKTextureLoaderFail(error, @"no image resource named \"%@\" in %@ (asset catalogs are not supported)", name, searchBundle.bundlePath);
}

- (id<MTLTexture>)newTextureWithMDLTexture: (MDLTexture*)texture
                                   options: (NSDictionary<MTKTextureLoaderOption, id>*)options
                                     error: (NSError**)error
{
	// MDLTexture holds no real pixel data in Darling: ModelIO is a set of forwarding stubs
	MTKTextureLoaderUnsupported(@"loading textures from ModelIO");
}

#else

@dynamic device;

MTL_UNSUPPORTED_CLASS

#endif

@end
