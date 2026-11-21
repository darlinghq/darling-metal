// Copyright (C) 2026 Lubos Dolezel
// Block-compressed textures created with the usage flags an application gives every texture
// (ShaderRead | RenderTarget | PixelFormatView): the texture is made, filled with -replaceRegion: and
// sampled by a shader like one created with ShaderRead only.
//
// QUIRK test: Metal's documentation lists the compressed formats as not renderable but does not say that
// creating one with MTLTextureUsageRenderTarget fails; this framework makes the texture and leaves the
// render-target use out. No Mac GPU was available to observe a Mac (the expectation is an inference).
// Exits 77 when there is no Metal device or the device cannot sample BC formats.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kSize = 16 };

static uint32_t pixels[kSize * kSize];

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil || !device.supportsBCTextureCompression) {
			printf("SKIP: no Metal device with BC texture compression\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];

		// creation with each usage combination, for the formats applications upload
		const MTLPixelFormat formats[] = { MTLPixelFormatBC1_RGBA, MTLPixelFormatBC3_RGBA, MTLPixelFormatBC7_RGBAUnorm };
		const MTLTextureUsage usages[] = {
			MTLTextureUsageShaderRead,
			MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsagePixelFormatView,
			MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget,
		};
		for (size_t f = 0; f < sizeof(formats) / sizeof(*formats); f++) {
			for (size_t u = 0; u < sizeof(usages) / sizeof(*usages); u++) {
				MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: formats[f] width: 64 height: 64 mipmapped: NO];
				td.usage = usages[u];
				id<MTLTexture> texture = [device newTextureWithDescriptor: td];
				if (texture == nil) {
					printf("no texture: format %d usage %d\n", (int)formats[f], (int)usages[u]);
				}
				CHECK(texture != nil);
			}
		}

		// a BC3 texture made with the blanket usage is sampled correctly: one solid red block everywhere
		NSError* error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"struct Vertex { float4 position [[position]]; float2 uv; };\n"
			"vertex Vertex fullVertex(uint vid [[vertex_id]]) {\n"
			"	Vertex o;\n"
			"	float x = (vid == 1) ? 3.0 : -1.0;\n"
			"	float y = (vid == 2) ? 3.0 : -1.0;\n"
			"	o.position = float4(x, y, 0.5, 1.0);\n	o.uv = float2((x + 1.0) * 0.5, (1.0 - y) * 0.5);\n	return o;\n}\n"
			"fragment float4 sampleFragment(Vertex in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler s [[sampler(0)]]) {\n"
			"	return tex.sample(s, in.uv);\n}\n" options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
		pd.vertexFunction = [library newFunctionWithName: @"fullVertex"];
		pd.fragmentFunction = [library newFunctionWithName: @"sampleFragment"];
		pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
		id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor: pd error: nil];
		CHECK(pso != nil);
		MTLSamplerDescriptor* sd = [[MTLSamplerDescriptor alloc] init];
		id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor: sd];

		MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBC3_RGBA width: 16 height: 16 mipmapped: NO];
		td.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsagePixelFormatView;
		id<MTLTexture> bc3 = [device newTextureWithDescriptor: td];
		CHECK(bc3 != nil);
		// BC3 block: 8 bytes of alpha (both end points 255, all indices 0) and 8 bytes of color
		// (end points 0xF800 = red twice, all indices 0)
		uint8_t block[16] = { 255, 255, 0, 0, 0, 0, 0, 0, 0x00, 0xF8, 0x00, 0xF8, 0, 0, 0, 0 };
		uint8_t data[16 * 16];
		for (int i = 0; i < 16; i++) memcpy(data + i * 16, block, 16);
		[bc3 replaceRegion: MTLRegionMake2D(0, 0, 16, 16) mipmapLevel: 0 withBytes: data bytesPerRow: 4 * 16];

		MTLTextureDescriptor* rd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
		rd.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
		rd.storageMode = MTLStorageModeManaged;
		id<MTLTexture> target = [device newTextureWithDescriptor: rd];
		MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
		rp.colorAttachments[0].texture = target;
		rp.colorAttachments[0].loadAction = MTLLoadActionClear;
		rp.colorAttachments[0].storeAction = MTLStoreActionStore;
		rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 1, 1);
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLRenderCommandEncoder> e = [commands renderCommandEncoderWithDescriptor: rp];
		[e setRenderPipelineState: pso];
		[e setFragmentTexture: bc3 atIndex: 0];
		[e setFragmentSamplerState: sampler atIndex: 0];
		[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
		[e endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		[target getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
				CHECK(pixels[kSize * kSize / 2 + kSize / 2] == 0xFF0000FFu);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
