// Copyright (C) 2026 Lubos Dolezel
// The texture a view was made from, and where the view starts in it: parentTexture is the texture the view was
// made from (a view of a view gives the view, not the texture at the root), parentRelativeLevel and
// parentRelativeSlice are the first level and slice of the ranges the view was made with (0 for a view made with
// only a pixel format), and a texture that is not a view has no parent and 0 for both. A view keeps its parent.
// Also the API ANGLE's Metal backend compiles against: MTLColorWriteMask is a set of options, MTLCoordinate2D and
// MTLCoordinate2DMake() are declared, and a device answers whether it has rasterization rate maps.
// The behaviour is the one the Metal documentation states. No Metal GPU was available to observe a Mac, so the
// expected values are from the documentation, not from a probe.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}

		MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 64 height: 64 mipmapped: YES];
		d.textureType = MTLTextureType2DArray;
		d.arrayLength = 4;
		d.usage = MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView;
		id<MTLTexture> texture = [device newTextureWithDescriptor: d];
		CHECK(texture != nil);
		CHECK(texture.parentTexture == nil);
		CHECK(texture.parentRelativeLevel == 0);
		CHECK(texture.parentRelativeSlice == 0);

		id<MTLTexture> formatView = [texture newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm_sRGB];
		CHECK(formatView.parentTexture == texture);
		CHECK(formatView.parentRelativeLevel == 0);
		CHECK(formatView.parentRelativeSlice == 0);

		id<MTLTexture> rangeView = [texture newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm textureType: MTLTextureType2DArray
		                                                          levels: NSMakeRange(2, 3) slices: NSMakeRange(1, 2)];
		CHECK(rangeView.parentTexture == texture);
		CHECK(rangeView.parentRelativeLevel == 2);
		CHECK(rangeView.parentRelativeSlice == 1);
		CHECK(rangeView.mipmapLevelCount == 3);
		CHECK(rangeView.arrayLength == 2);

		id<MTLTexture> viewOfView = [rangeView newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm textureType: MTLTextureType2D
		                                                             levels: NSMakeRange(1, 1) slices: NSMakeRange(1, 1)];
		CHECK(viewOfView.parentTexture == rangeView);
		CHECK(viewOfView.parentRelativeLevel == 1);
		CHECK(viewOfView.parentRelativeSlice == 1);

		MTLTextureSwizzleChannels bgra = MTLTextureSwizzleChannelsMake(MTLTextureSwizzleBlue, MTLTextureSwizzleGreen, MTLTextureSwizzleRed, MTLTextureSwizzleAlpha);
		id<MTLTexture> swizzleView = [texture newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm textureType: MTLTextureType2DArray
		                                                            levels: NSMakeRange(1, 2) slices: NSMakeRange(3, 1) swizzle: bgra];
		CHECK(swizzleView.parentTexture == texture);
		CHECK(swizzleView.parentRelativeLevel == 1);
		CHECK(swizzleView.parentRelativeSlice == 3);

		// the view keeps its parent
		NSUInteger before = [texture retainCount];
		[formatView release];
		CHECK([texture retainCount] == before - 1);
		[texture release];
		CHECK(rangeView.parentTexture != nil && rangeView.parentTexture.mipmapLevelCount == 7);
		[viewOfView release];
		[swizzleView release];
		[rangeView release];

		MTLColorWriteMask mask = MTLColorWriteMaskRed | MTLColorWriteMaskAlpha;
		mask &= ~MTLColorWriteMaskAlpha;
		CHECK(mask == MTLColorWriteMaskRed);
		MTLCoordinate2D coordinate = MTLCoordinate2DMake(1.5f, 2.5f);
		CHECK(coordinate.x == 1.5f && coordinate.y == 2.5f);
		(void) [device supportsRasterizationRateMapWithLayerCount: 1];
	}
	printf(failures ? "FAILED\n" : "PASS\n");
	return failures != 0;
}
