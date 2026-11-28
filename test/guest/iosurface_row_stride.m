// SPDX-FileCopyrightText: 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0
//
// A texture made from an IOSurface plane shows the plane's rows at the surface's own row stride
// (IOSurfaceGetBytesPerRow, which may exceed width * bytes per pixel), through every access
// path: getBytes and replaceRegion (whole and partial regions, tight and padded caller strides),
// and blits between the texture and buffers or other textures. Checked for surfaces whose
// stride is the tight row, or aligned up to 16, 64 and 256 bytes, with odd widths, for BGRA8 and
// RGBA16Float and for both planes of a 420v surface. Every pixel of every row is compared, and
// the padding bytes of the surface must stay as they were. Prints SKIP without a Metal device.
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>
#include <stdio.h>
#include <string.h>

static int g_failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL %d: %s\n", __LINE__, #cond); g_failures++; } } while (0)
#define CHECKF(cond, ...) do { if (!(cond)) { printf("FAIL %d: %s: ", __LINE__, #cond); printf(__VA_ARGS__); printf("\n"); g_failures++; } } while (0)

static id<MTLDevice> g_device;
static id<MTLCommandQueue> g_queue;

static uint8_t patternByte(unsigned seed, size_t x, size_t y, size_t b)
{
	return (uint8_t)(seed * 37 + x * 7 + y * 31 + b * 3 + 1);
}

static void fillPattern(uint8_t* base, size_t stride, size_t w, size_t h, size_t bpp, unsigned seed)
{
	for (size_t y = 0; y < h; y++)
		for (size_t x = 0; x < w; x++)
			for (size_t b = 0; b < bpp; b++)
				base[y * stride + x * bpp + b] = patternByte(seed, x, y, b);
}

// Number of pixels (not bytes) of mismatch of a region against the pattern; `stride` is that of `data`.
static size_t mismatches(const uint8_t* data, size_t stride, size_t x0, size_t y0, size_t w, size_t h, size_t bpp, unsigned seed,
	size_t patternX, size_t patternY)
{
	size_t bad = 0;
	for (size_t y = 0; y < h; y++)
		for (size_t x = 0; x < w; x++)
			for (size_t b = 0; b < bpp; b++)
				if (data[y * stride + x * bpp + b] != patternByte(seed, patternX + x, patternY + y, b)) {
					if (bad == 0)
						printf("  first bad pixel (%zu,%zu) byte %zu: %02x, expected %02x\n", x, y, b, data[y * stride + x * bpp + b], patternByte(seed, patternX + x, patternY + y, b));
					bad++;
					break;
				}
	(void)x0; (void)y0;
	return bad;
}

static IOSurfaceRef makeSurface(size_t w, size_t h, size_t bpp, size_t stride)
{
	NSDictionary* props = @{
		(id)kIOSurfaceWidth: @(w), (id)kIOSurfaceHeight: @(h),
		(id)kIOSurfaceBytesPerElement: @(bpp), (id)kIOSurfaceBytesPerRow: @(stride),
	};
	return IOSurfaceCreate((CFDictionaryRef)props);
}

static id<MTLTexture> makeTexture(IOSurfaceRef surface, MTLPixelFormat format, size_t w, size_t h, size_t plane)
{
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:w height:h mipmapped:NO];
	d.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;
	d.storageMode = MTLStorageModeShared;
	return [g_device newTextureWithDescriptor:d iosurface:surface plane:plane];
}

static void waitFor(id<MTLCommandBuffer> cb)
{
	[cb commit];
	[cb waitUntilCompleted];
	CHECK(cb.status == MTLCommandBufferStatusCompleted);
}

// One plane of one surface: all the access paths.
static void checkPlane(IOSurfaceRef surface, size_t plane, MTLPixelFormat format, size_t w, size_t h, size_t bpp, const char* what)
{
	size_t stride = IOSurfaceGetPlaneCount(surface) ? IOSurfaceGetBytesPerRowOfPlane(surface, plane) : IOSurfaceGetBytesPerRow(surface);
	uint8_t* base = IOSurfaceGetPlaneCount(surface) ? IOSurfaceGetBaseAddressOfPlane(surface, plane) : IOSurfaceGetBaseAddress(surface);
	char tag[160];
	snprintf(tag, sizeof(tag), "%s plane %zu %zux%zu bpp %zu stride %zu", what, plane, w, h, bpp, stride);

	IOSurfaceLock(surface, 0, NULL);
	memset(base, 0xEE, stride * h);
	fillPattern(base, stride, w, h, bpp, 1);
	IOSurfaceUnlock(surface, 0, NULL);

	id<MTLTexture> tex = makeTexture(surface, format, w, h, plane);
	if (tex == nil) {
		printf("FAIL %s: no texture\n", tag);
		g_failures++;
		return;
	}

	// getBytes of the whole texture, into a tight and into a padded destination.
	size_t tight = w * bpp, padded = tight + 36 * bpp;
	uint8_t* out = malloc(padded * h + 64);
	memset(out, 0xAB, padded * h + 64);
	[tex getBytes:out bytesPerRow:tight fromRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0];
	size_t bad = mismatches(out, tight, 0, 0, w, h, bpp, 1, 0, 0);
	CHECKF(bad == 0, "%s: getBytes tight, %zu bad pixels", tag, bad);
	memset(out, 0xAB, padded * h);
	[tex getBytes:out bytesPerRow:padded fromRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0];
	bad = mismatches(out, padded, 0, 0, w, h, bpp, 1, 0, 0);
	CHECKF(bad == 0, "%s: getBytes padded, %zu bad pixels", tag, bad);
	// a partial region, away from the origin
	if (w > 2 && h > 2) {
		size_t rw = w - 2, rh = h - 2;
		memset(out, 0xAB, padded * h);
		[tex getBytes:out bytesPerRow:padded fromRegion:MTLRegionMake2D(1, 1, rw, rh) mipmapLevel:0];
		bad = mismatches(out, padded, 0, 0, rw, rh, bpp, 1, 1, 1);
		CHECKF(bad == 0, "%s: getBytes partial, %zu bad pixels", tag, bad);
	}
	// single pixels of the last row
	{
		uint8_t px[16];
		[tex getBytes:px bytesPerRow:bpp fromRegion:MTLRegionMake2D(w - 1, h - 1, 1, 1) mipmapLevel:0];
		CHECKF(mismatches(px, bpp, 0, 0, 1, 1, bpp, 1, w - 1, h - 1) == 0, "%s: last pixel", tag);
	}

	// replaceRegion of the whole texture, from a tight and from a padded source; the surface
	// then holds the rows at its own stride and its padding is untouched.
	for (int variant = 0; variant < 2; variant++) {
		size_t srcStride = variant ? padded : tight;
		unsigned seed = 2 + variant;
		IOSurfaceLock(surface, 0, NULL);
		memset(base, 0xEE, stride * h);
		IOSurfaceUnlock(surface, 0, NULL);
		memset(out, 0, padded * h);
		fillPattern(out, srcStride, w, h, bpp, seed);
		[tex replaceRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0 withBytes:out bytesPerRow:srcStride];
		IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
		bad = mismatches(base, stride, 0, 0, w, h, bpp, seed, 0, 0);
		CHECKF(bad == 0, "%s: replaceRegion %s source, %zu bad pixels in the surface", tag, variant ? "padded" : "tight", bad);
		for (size_t y = 0; y < h; y++)
			for (size_t i = w * bpp; i < stride; i++)
				if (base[y * stride + i] != 0xEE) {
					printf("FAIL %s: replaceRegion wrote padding (row %zu byte %zu)\n", tag, y, i);
					g_failures++;
					y = h;
					break;
				}
		IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
	}
	// a partial replaceRegion leaves everything else alone
	if (w > 2 && h > 2) {
		IOSurfaceLock(surface, 0, NULL);
		fillPattern(base, stride, w, h, bpp, 5);
		IOSurfaceUnlock(surface, 0, NULL);
		size_t rw = w - 2, rh = h - 2;
		fillPattern(out, padded, rw, rh, bpp, 6);
		[tex replaceRegion:MTLRegionMake2D(1, 1, rw, rh) mipmapLevel:0 withBytes:out bytesPerRow:padded];
		IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
		size_t badIn = mismatches(base + stride + bpp, stride, 0, 0, rw, rh, bpp, 6, 0, 0);
		CHECKF(badIn == 0, "%s: partial replaceRegion, %zu bad pixels", tag, badIn);
		size_t badOut = 0;
		for (size_t y = 0; y < h; y++)
			for (size_t x = 0; x < w; x++) {
				if (x >= 1 && x < 1 + rw && y >= 1 && y < 1 + rh)
					continue;
				for (size_t b = 0; b < bpp; b++)
					if (base[y * stride + x * bpp + b] != patternByte(5, x, y, b)) {
						badOut++;
						break;
					}
			}
		CHECKF(badOut == 0, "%s: partial replaceRegion changed %zu pixels outside the region", tag, badOut);
		IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
	}

	// Blits. The surface holds pattern 7.
	IOSurfaceLock(surface, 0, NULL);
	memset(base, 0xEE, stride * h);
	fillPattern(base, stride, w, h, bpp, 7);
	IOSurfaceUnlock(surface, 0, NULL);

	// texture -> buffer at a padded stride, and at an offset
	{
		size_t bufStride = padded;
		size_t offset = 16 * bpp;
		id<MTLBuffer> buf = [g_device newBufferWithLength:offset + bufStride * h + 64 options:MTLResourceStorageModeShared];
		memset(buf.contents, 0xAB, buf.length);
		id<MTLCommandBuffer> cb = [g_queue commandBuffer];
		id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
		[blit copyFromTexture:tex sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(w, h, 1)
		             toBuffer:buf destinationOffset:offset destinationBytesPerRow:bufStride destinationBytesPerImage:bufStride * h];
		[blit endEncoding];
		waitFor(cb);
		bad = mismatches((uint8_t*)buf.contents + offset, bufStride, 0, 0, w, h, bpp, 7, 0, 0);
		CHECKF(bad == 0, "%s: blit texture to buffer, %zu bad pixels", tag, bad);
	}
	// buffer -> texture at a padded stride; the surface then has the rows at its own stride
	{
		size_t bufStride = padded;
		size_t offset = 16 * bpp;
		id<MTLBuffer> buf = [g_device newBufferWithLength:offset + bufStride * h + 64 options:MTLResourceStorageModeShared];
		memset(buf.contents, 0, buf.length);
		fillPattern((uint8_t*)buf.contents + offset, bufStride, w, h, bpp, 8);
		id<MTLCommandBuffer> cb = [g_queue commandBuffer];
		id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
		[blit copyFromBuffer:buf sourceOffset:offset sourceBytesPerRow:bufStride sourceBytesPerImage:bufStride * h
		          sourceSize:MTLSizeMake(w, h, 1) toTexture:tex destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];
		[blit endEncoding];
		waitFor(cb);
		IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
		bad = mismatches(base, stride, 0, 0, w, h, bpp, 8, 0, 0);
		CHECKF(bad == 0, "%s: blit buffer to texture, %zu bad pixels in the surface", tag, bad);
		IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
	}
	// texture -> an ordinary texture, and back from another one
	{
		MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:w height:h mipmapped:NO];
		d.storageMode = MTLStorageModeShared;
		d.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
		id<MTLTexture> plain = [g_device newTextureWithDescriptor:d];
		IOSurfaceLock(surface, 0, NULL);
		fillPattern(base, stride, w, h, bpp, 9);
		IOSurfaceUnlock(surface, 0, NULL);
		id<MTLCommandBuffer> cb = [g_queue commandBuffer];
		id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
		[blit copyFromTexture:tex toTexture:plain];
		[blit endEncoding];
		waitFor(cb);
		memset(out, 0, padded * h);
		[plain getBytes:out bytesPerRow:tight fromRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0];
		bad = mismatches(out, tight, 0, 0, w, h, bpp, 9, 0, 0);
		CHECKF(bad == 0, "%s: blit texture to texture, %zu bad pixels", tag, bad);

		fillPattern(out, tight, w, h, bpp, 10);
		[plain replaceRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0 withBytes:out bytesPerRow:tight];
		cb = [g_queue commandBuffer];
		blit = [cb blitCommandEncoder];
		[blit copyFromTexture:plain toTexture:tex];
		[blit endEncoding];
		waitFor(cb);
		IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL);
		bad = mismatches(base, stride, 0, 0, w, h, bpp, 10, 0, 0);
		CHECKF(bad == 0, "%s: blit texture from texture, %zu bad pixels in the surface", tag, bad);
		IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
	}
	free(out);
}

int main(void)
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		g_device = MTLCreateSystemDefaultDevice();
		if (g_device == nil) {
			printf("SKIP: no Metal device\n");
			printf("PASS\n");
			return 0;
		}
		g_queue = [g_device newCommandQueue];

		static const size_t widths[] = { 1, 3, 5, 7, 16, 17, 30, 33, 63, 64, 65, 100 };
		static const size_t aligns[] = { 0, 16, 64, 256 }; // 0: the tight row, as far as the system allows
		for (size_t wi = 0; wi < sizeof(widths) / sizeof(widths[0]); wi++) {
			for (size_t ai = 0; ai < sizeof(aligns) / sizeof(aligns[0]); ai++) {
				size_t w = widths[wi], h = 5;
				// BGRA8
				size_t row = w * 4;
				size_t stride = aligns[ai] ? (row + aligns[ai] - 1) / aligns[ai] * aligns[ai] : row;
				IOSurfaceRef s = makeSurface(w, h, 4, stride);
				if (s == NULL) {
					printf("FAIL: IOSurfaceCreate %zux%zu stride %zu\n", w, h, stride);
					g_failures++;
				} else {
					checkPlane(s, 0, MTLPixelFormatBGRA8Unorm, w, h, 4, "BGRA8");
					CFRelease(s);
				}
				// RGBA16Float
				row = w * 8;
				stride = aligns[ai] ? (row + aligns[ai] - 1) / aligns[ai] * aligns[ai] : row;
				s = makeSurface(w, h, 8, stride);
				if (s != NULL) {
					checkPlane(s, 0, MTLPixelFormatRGBA16Float, w, h, 8, "RGBA16Float");
					CFRelease(s);
				}
			}
		}

		// The IOSurface alignment of kIOSurfaceBytesPerRow, as the documentation tells callers to use it.
		for (size_t w = 1; w < 40; w += 6) {
			size_t stride = IOSurfaceAlignProperty(kIOSurfaceBytesPerRow, w * 4);
			IOSurfaceRef s = makeSurface(w, 6, 4, stride);
			CHECK(s != NULL);
			if (s) {
				checkPlane(s, 0, MTLPixelFormatBGRA8Unorm, w, 6, 4, "aligned property");
				CFRelease(s);
			}
		}

		// Both planes of a 420v pixel buffer.
		static const size_t pbWidths[] = { 8, 18, 34, 66, 130 };
		for (size_t i = 0; i < sizeof(pbWidths) / sizeof(pbWidths[0]); i++) {
			size_t w = pbWidths[i], h = 6;
			NSDictionary* attrs = @{ (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
			CVPixelBufferRef pb = NULL;
			if (CVPixelBufferCreate(NULL, w, h, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, (CFDictionaryRef)attrs, &pb) != kCVReturnSuccess || pb == NULL) {
				printf("FAIL: 420v pixel buffer %zux%zu\n", w, h);
				g_failures++;
				continue;
			}
			IOSurfaceRef s = CVPixelBufferGetIOSurface(pb);
			CHECK(s != NULL && IOSurfaceGetPlaneCount(s) == 2);
			if (s != NULL && IOSurfaceGetPlaneCount(s) == 2) {
				checkPlane(s, 0, MTLPixelFormatR8Unorm, w, h, 1, "420v");
				checkPlane(s, 1, MTLPixelFormatRG8Unorm, w / 2, h / 2, 2, "420v");
			}
			CVPixelBufferRelease(pb);
		}
	}
	if (g_failures == 0)
		printf("PASS\n");
	else
		printf("FAILED (%d)\n", g_failures);
	return g_failures ? 1 : 0;
}
