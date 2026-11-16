// Copyright (C) 2026 Lubos Dolezel
// -setTriangleFillMode: and -setDepthClipMode: apply to the draws that follow: MTLTriangleFillModeLines draws the
// outline of a triangle, MTLDepthClipModeClamp draws a triangle that lies beyond the far plane (depth is clamped
// to the viewport range), both persist across a pipeline state change and a new encoder starts with Fill and
// Clip. The expectations follow the documented meaning of the two modes; no Mac GPU was available to observe a Mac.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kSize = 16 };

static uint32_t pixels[kSize * kSize];

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
		NSError* error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"struct Vertex { float4 position [[position]]; };\n"
			"vertex Vertex smallVertex(uint vid [[vertex_id]]) {\n"
			"	Vertex o;\n"
			"	float x = (vid == 0) ? -0.75 : ((vid == 1) ? 0.75 : 0.0);\n"
			"	float y = (vid == 2) ? 0.75 : -0.75;\n"
			"	o.position = float4(x, y, 0.5, 1.0);\n	return o;\n}\n"
			"vertex Vertex farVertex(uint vid [[vertex_id]]) {\n"
			"	Vertex o;\n"
			"	float x = (vid == 1) ? 3.0 : -1.0;\n"
			"	float y = (vid == 2) ? 3.0 : -1.0;\n"
			"	o.position = float4(x, y, 2.0, 1.0);\n	return o;\n}\n"
			"fragment float4 redFragment() { return float4(1.0, 0.0, 0.0, 1.0); }\n" options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		id<MTLRenderPipelineState> (^pipeline)(NSString*) = ^id<MTLRenderPipelineState>(NSString* vertex) {
			MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
			pd.vertexFunction = [library newFunctionWithName: vertex];
			pd.fragmentFunction = [library newFunctionWithName: @"redFragment"];
			pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
			return [device newRenderPipelineStateWithDescriptor: pd error: nil];
		};
		id<MTLRenderPipelineState> small = pipeline(@"smallVertex");
		id<MTLRenderPipelineState> far = pipeline(@"farVertex");
		MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
		td.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
		td.storageMode = MTLStorageModeManaged;
		id<MTLTexture> target = [device newTextureWithDescriptor: td];

		// runs the draws in `body` on a cleared target; returns the number of red pixels and leaves the pixels in `pixels`
		int (^run)(void (^)(id<MTLRenderCommandEncoder>)) = ^int(void (^body)(id<MTLRenderCommandEncoder>)) {
			MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
			rp.colorAttachments[0].texture = target;
			rp.colorAttachments[0].loadAction = MTLLoadActionClear;
			rp.colorAttachments[0].storeAction = MTLStoreActionStore;
			rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLRenderCommandEncoder> encoder = [commands renderCommandEncoderWithDescriptor: rp];
			body(encoder);
			[encoder endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			[target getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
			int red = 0;
			for (int i = 0; i < kSize * kSize; i++) if (pixels[i] == 0xFF0000FFu) red++;
			return red;
		};
		void (^draw)(id<MTLRenderCommandEncoder>) = ^(id<MTLRenderCommandEncoder> e) {
			[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
		};

		int filled = run(^(id<MTLRenderCommandEncoder> e) { [e setRenderPipelineState: small]; draw(e); });
		CHECK(filled > kSize * kSize / 4 && pixels[(kSize / 2 - 1) * kSize + kSize / 2] == 0xFF0000FFu);

		int outline = run(^(id<MTLRenderCommandEncoder> e) {
			[e setRenderPipelineState: small];
			[e setTriangleFillMode: MTLTriangleFillModeLines];
			draw(e);
		});
		CHECK(outline > 0 && outline < filled / 2);
		CHECK(pixels[(kSize / 2 - 1) * kSize + kSize / 2] != 0xFF0000FFu);

		// the mode set before the pipeline state, and kept across a change of pipeline state
		int before = run(^(id<MTLRenderCommandEncoder> e) {
			[e setTriangleFillMode: MTLTriangleFillModeLines];
			[e setRenderPipelineState: far];
			[e setRenderPipelineState: small];
			draw(e);
		});
		CHECK(before == outline);

		// a new encoder starts with Fill
		CHECK(run(^(id<MTLRenderCommandEncoder> e) { [e setRenderPipelineState: small]; draw(e); }) == filled);

		// depth clip
		CHECK(run(^(id<MTLRenderCommandEncoder> e) { [e setRenderPipelineState: far]; draw(e); }) == 0);
		CHECK(run(^(id<MTLRenderCommandEncoder> e) {
			[e setRenderPipelineState: far];
			[e setDepthClipMode: MTLDepthClipModeClamp];
			draw(e);
		}) == kSize * kSize);
		CHECK(run(^(id<MTLRenderCommandEncoder> e) {
			[e setRenderPipelineState: far];
			[e setDepthClipMode: MTLDepthClipModeClamp];
			[e setDepthClipMode: MTLDepthClipModeClip];
			draw(e);
		}) == 0);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
