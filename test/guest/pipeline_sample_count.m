// Copyright (C) 2026 Lubos Dolezel
// MTLRenderPipelineDescriptor.sampleCount is the older name of rasterSampleCount (both default to 1 and set the
// number of samples per pixel the pipeline rasterizes), so a pipeline described with either one has to match
// a multisample attachment.
//
// Documented contract (the Metal framework reference): sampleCount is deprecated in favour of rasterSampleCount
// and is aliased to it. The draw checks the whole target: a pipeline whose sample count differs from its
// attachment's is undefined in Vulkan, and some drivers then rasterize only part of the target.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kSize = 16 };

static uint32_t pixels[kSize * kSize];

int main(void) {
	@autoreleasepool {
		// descriptor level, no device needed
		MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
		CHECK(pd.sampleCount == 1 && pd.rasterSampleCount == 1);
		pd.sampleCount = 4;
		CHECK(pd.rasterSampleCount == 4);
		pd.rasterSampleCount = 2;
		CHECK(pd.sampleCount == 2);
		MTLRenderPipelineDescriptor* copy = [pd copy];
		CHECK(copy.sampleCount == 2 && copy.rasterSampleCount == 2);

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf(failures ? "FAILED: %d\n" : "SKIP: no Metal device\n", failures);
			return failures ? 1 : 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
		id<MTLLibrary> library = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"struct Vertex { float4 position [[position]]; };\n"
			"vertex Vertex fullVertex(uint vid [[vertex_id]]) {\n"
			"	Vertex o;\n"
			"	float x = (vid == 1) ? 3.0 : -1.0;\n"
			"	float y = (vid == 2) ? 3.0 : -1.0;\n"
			"	o.position = float4(x, y, 0.5, 1.0);\n	return o;\n}\n"
			"fragment float4 redFragment() { return float4(1.0, 0.0, 0.0, 1.0); }\n" options: nil error: nil];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		for (int viaRaster = 0; viaRaster < 2; viaRaster++) {
			for (NSUInteger samples = 2; samples <= 8; samples *= 2) {
				if (![device supportsTextureSampleCount: samples])
					continue;
				MTLRenderPipelineDescriptor* d = [[MTLRenderPipelineDescriptor alloc] init];
				d.vertexFunction = [library newFunctionWithName: @"fullVertex"];
				d.fragmentFunction = [library newFunctionWithName: @"redFragment"];
				d.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
				if (viaRaster)
					d.rasterSampleCount = samples;
				else
					d.sampleCount = samples;
				id<MTLRenderPipelineState> state = [device newRenderPipelineStateWithDescriptor: d error: nil];
				CHECK(state != nil);

				MTLTextureDescriptor* md = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
				md.textureType = MTLTextureType2DMultisample;
				md.sampleCount = samples;
				md.usage = MTLTextureUsageRenderTarget;
				md.storageMode = MTLStorageModePrivate;
				id<MTLTexture> multisample = [device newTextureWithDescriptor: md];
				MTLTextureDescriptor* rd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
				rd.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
				rd.storageMode = MTLStorageModeManaged;
				id<MTLTexture> resolved = [device newTextureWithDescriptor: rd];
				CHECK(multisample != nil && resolved != nil);
				if (state == nil || multisample == nil || resolved == nil)
					continue;

				MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
				rp.colorAttachments[0].texture = multisample;
				rp.colorAttachments[0].resolveTexture = resolved;
				rp.colorAttachments[0].loadAction = MTLLoadActionClear;
				rp.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
				rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 1, 1);
				id<MTLCommandBuffer> commands = [queue commandBuffer];
				id<MTLRenderCommandEncoder> e = [commands renderCommandEncoderWithDescriptor: rp];
				[e setRenderPipelineState: state];
				[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
				[e endEncoding];
				[commands commit];
				[commands waitUntilCompleted];
				[resolved getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
				int bad = 0;
				for (int i = 0; i < kSize * kSize; i++)
					bad += pixels[i] != 0xFF0000FFu;
				if (bad)
					printf("%s=%lu: %d of %d pixels are not red\n", viaRaster ? "rasterSampleCount" : "sampleCount", (unsigned long)samples, bad, kSize * kSize);
				CHECK(bad == 0);
			}
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
