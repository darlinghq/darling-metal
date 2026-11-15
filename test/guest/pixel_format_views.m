// Copyright (C) 2026 Lubos Dolezel
// Pixel formats with no one-to-one Vulkan equivalent and views of a texture as another format:
// A8Unorm (a shader reads (0, 0, 0, a); no shader writes or rendering), the stencil views X32_Stencil8
// and X24_Stencil8 of the combined depth/stencil formats, and views of the same texel size, which need
// MTLTextureUsagePixelFormatView on the texture (RGBA8Unorm as RGBA8Unorm_sRGB decodes sRGB).
// The behaviour is the one the Metal documentation states for these formats and views. No Metal GPU was
// available to observe a Mac, so the expected values are from the documentation, not from a probe.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <math.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;
static id<MTLComputePipelineState> readPipeline;

static id<MTLTexture> make(MTLPixelFormat format, MTLTextureUsage usage) {
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: format width: 2 height: 2 mipmapped: NO];
	d.usage = usage;
	d.storageMode = MTLStorageModeManaged;
	return [device newTextureWithDescriptor: d];
}

// texel (0, 0) as the shader sees it
static void readTexel(id<MTLTexture> texture, float out[4]) {
	id<MTLBuffer> buffer = [device newBufferWithLength: 16 options: MTLResourceStorageModeShared];
	memset([buffer contents], 0xEE, 16);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
	[encoder setComputePipelineState: readPipeline];
	[encoder setTexture: texture atIndex: 0];
	[encoder setBuffer: buffer offset: 0 atIndex: 0];
	[encoder dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(1, 1, 1)];
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	memcpy(out, [buffer contents], 16);
	[buffer release];
}

static BOOL near(float a, float b) { return fabsf(a - b) < 0.003f; }

int main(void) {
	@autoreleasepool {
		device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		queue = [device newCommandQueue];
		NSError* error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"kernel void readTexel(texture2d<float> tex [[texture(0)]], device float4* out [[buffer(0)]]) {\n"
			"	out[0] = tex.read(uint2(0, 0));\n}\n" options: nil error: &error];
		CHECK(library != nil);
		id<MTLFunction> function = [library newFunctionWithName: @"readTexel"];
		readPipeline = [device newComputePipelineStateWithFunction: function error: &error];
		CHECK(readPipeline != nil);
		if (readPipeline == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		// --- A8Unorm
		id<MTLTexture> a8 = make(MTLPixelFormatA8Unorm, MTLTextureUsageShaderRead);
		CHECK(a8 != nil);
		const uint8_t bytes[4] = { 0x40, 0x80, 0xC0, 0xFF };
		[a8 replaceRegion: MTLRegionMake2D(0, 0, 2, 2) mipmapLevel: 0 withBytes: bytes bytesPerRow: 2];
		uint8_t back[4] = { 0 };
		[a8 getBytes: back bytesPerRow: 2 fromRegion: MTLRegionMake2D(0, 0, 2, 2) mipmapLevel: 0];
		CHECK(memcmp(back, bytes, 4) == 0);
		float texel[4];
		readTexel(a8, texel);
		CHECK(texel[0] == 0 && texel[1] == 0 && texel[2] == 0 && near(texel[3], 0x40 / 255.0f));
		CHECK(make(MTLPixelFormatA8Unorm, MTLTextureUsageShaderWrite) == nil);
		CHECK(make(MTLPixelFormatA8Unorm, MTLTextureUsageRenderTarget) == nil);

		id<MTLTexture> r8 = make(MTLPixelFormatR8Unorm, MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView);
		[r8 replaceRegion: MTLRegionMake2D(0, 0, 2, 2) mipmapLevel: 0 withBytes: bytes bytesPerRow: 2];
		id<MTLTexture> asA8 = [r8 newTextureViewWithPixelFormat: MTLPixelFormatA8Unorm];
		CHECK(asA8 != nil);
		readTexel(asA8, texel);
		CHECK(texel[0] == 0 && near(texel[3], 0x40 / 255.0f));
		readTexel(r8, texel);
		CHECK(near(texel[0], 0x40 / 255.0f) && texel[1] == 0 && texel[2] == 0 && texel[3] == 1);

		// --- stencil views
		id<MTLTexture> combined = make(MTLPixelFormatDepth32Float_Stencil8,
			MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView);
		CHECK(combined != nil);
		id<MTLTexture> stencil = [combined newTextureViewWithPixelFormat: MTLPixelFormatX32_Stencil8];
		CHECK(stencil != nil);
		CHECK(stencil.pixelFormat == MTLPixelFormatX32_Stencil8);
		CHECK([combined newTextureViewWithPixelFormat: MTLPixelFormatX24_Stencil8] == nil);
		CHECK([combined newTextureViewWithPixelFormat: MTLPixelFormatR32Uint] == nil);
		id<MTLTexture> depthOnly = make(MTLPixelFormatDepth32Float, MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView);
		CHECK([depthOnly newTextureViewWithPixelFormat: MTLPixelFormatX32_Stencil8] == nil);

		// --- same-size views
		const uint8_t texels[16] = { 128, 64, 255, 200, 128, 64, 255, 200, 128, 64, 255, 200, 128, 64, 255, 200 };
		id<MTLTexture> plain = make(MTLPixelFormatRGBA8Unorm, MTLTextureUsageShaderRead);
		CHECK([plain newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm_sRGB] == nil);
		CHECK([plain newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm] != nil);

		id<MTLTexture> viewable = make(MTLPixelFormatRGBA8Unorm, MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView);
		[viewable replaceRegion: MTLRegionMake2D(0, 0, 2, 2) mipmapLevel: 0 withBytes: texels bytesPerRow: 8];
		readTexel(viewable, texel);
		CHECK(near(texel[0], 128 / 255.0f) && near(texel[3], 200 / 255.0f));
		id<MTLTexture> srgb = [viewable newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm_sRGB];
		CHECK(srgb != nil);
		readTexel(srgb, texel);
		// IEC 61966-2-1 decode of 128/255 and 64/255; alpha is not decoded
		CHECK(near(texel[0], 0.2158605f) && near(texel[1], 0.0513270f) && near(texel[2], 1.0f) && near(texel[3], 200 / 255.0f));
		id<MTLTexture> bgra = [viewable newTextureViewWithPixelFormat: MTLPixelFormatBGRA8Unorm];
		CHECK(bgra != nil);
		readTexel(bgra, texel);
		CHECK(near(texel[0], 1.0f) && near(texel[2], 128 / 255.0f));
		CHECK([viewable newTextureViewWithPixelFormat: MTLPixelFormatR32Uint] != nil);
		CHECK([viewable newTextureViewWithPixelFormat: MTLPixelFormatR8Unorm] == nil);
		CHECK([viewable newTextureViewWithPixelFormat: MTLPixelFormatRGBA16Float] == nil);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
