// Copyright (C) 2026 Lubos Dolezel
// MTLSamplerDescriptor's documented defaults, and a sampler made from a default descriptor and bound with
// -setFragmentSamplerState:atIndex: reads the texture like any other sampler.
//
// The documented default of compareFunction is MTLCompareFunctionNever, which means the sampler does not compare;
// a default of Always turns every sampler into a comparison sampler, and ordinary sample() calls on a color texture
// then return a meaningless value (white here). No Mac GPU was available to observe a Mac; the expectations follow
// the Metal documentation. Exits 77 when there is no Metal device (the descriptor checks run first).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <float.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kSize = 8 };

static uint32_t pixels[kSize * kSize];

int main(void) {
	@autoreleasepool {
		MTLSamplerDescriptor* d = [[MTLSamplerDescriptor alloc] init];
		CHECK(d.minFilter == MTLSamplerMinMagFilterNearest);
		CHECK(d.magFilter == MTLSamplerMinMagFilterNearest);
		CHECK(d.mipFilter == MTLSamplerMipFilterNotMipmapped);
		CHECK(d.sAddressMode == MTLSamplerAddressModeClampToEdge);
		CHECK(d.tAddressMode == MTLSamplerAddressModeClampToEdge);
		CHECK(d.rAddressMode == MTLSamplerAddressModeClampToEdge);
		CHECK(d.maxAnisotropy == 1);
		CHECK(d.normalizedCoordinates == YES);
		CHECK(d.lodMinClamp == 0);
		CHECK(d.lodMaxClamp == FLT_MAX);
		CHECK(d.borderColor == MTLSamplerBorderColorTransparentBlack);
		CHECK(d.compareFunction == MTLCompareFunctionNever);
		CHECK(d.supportArgumentBuffers == NO);

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf(failures ? "FAILED: %d\n" : "OK (descriptors only, no Metal device)\n", failures);
			return failures != 0 ? 1 : 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
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
		id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor: d];

		MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
		td.usage = MTLTextureUsageShaderRead;
		id<MTLTexture> source = [device newTextureWithDescriptor: td];
		uint32_t texels[kSize * kSize];
		for (int i = 0; i < kSize * kSize; i++) texels[i] = 0xFF0000FFu;   // opaque red (R in the low byte)
		[source replaceRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0 withBytes: texels bytesPerRow: kSize * 4];

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
		[e setFragmentTexture: source atIndex: 0];
		[e setFragmentSamplerState: sampler atIndex: 0];
		[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
		[e endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		[target getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
		CHECK(pixels[kSize * kSize / 2 + kSize / 2] == 0xFF0000FFu);
		CHECK(pixels[0] == 0xFF0000FFu);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
