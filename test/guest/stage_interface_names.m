// Copyright (C) 2026 Lubos Dolezel
// A vertex function and a fragment function made in separate libraries are paired at pipeline creation by the names
// of their [[user(name)]] varyings, not by the position of the fields: the fragment function reads only some of the
// vertex function's outputs, in another order, and still gets the values the vertex function wrote under those names.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdlib.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLLibrary> compile(id<MTLDevice> device, NSString* source) {
	NSError* error = nil;
	id<MTLLibrary> library = [device newLibraryWithSource: source options: nil error: &error];
	if (library == nil) {
		printf("compile error: %s\n", [[error description] UTF8String]);
	}
	return library;
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
		// the vertex function writes five varyings, each a distinct constant
		id<MTLLibrary> vertexLibrary = compile(device,
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"struct VertexOut {\n"
			"	float4 position [[position]];\n"
			"	float4 first [[user(FIRST)]];\n"
			"	float4 second [[user(SECOND)]];\n"
			"	float third [[user(THIRD)]];\n"
			"	float4 fourth [[user(FOURTH)]];\n"
			"};\n"
			"vertex VertexOut vertexMain(uint vid [[vertex_id]]) {\n"
			"	VertexOut o;\n"
			"	float x = (vid == 1) ? 3.0 : -1.0;\n"
			"	float y = (vid == 2) ? 3.0 : -1.0;\n"
			"	o.position = float4(x, y, 0.5, 1.0);\n"
			"	o.first = float4(0.1, 0.1, 0.1, 0.1);\n"
			"	o.second = float4(0.2, 0.4, 0.6, 0.8);\n"
			"	o.third = 0.3;\n"
			"	o.fourth = float4(1.0, 0.0, 0.5, 1.0);\n"
			"	return o;\n}\n");
		// the fragment function takes only two of them, in the vertex function order but without the first and third
		id<MTLLibrary> fragmentLibrary = compile(device,
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"struct FragmentIn {\n"
			"	float4 second [[user(SECOND)]];\n"
			"	float4 fourth [[user(FOURTH)]];\n"
			"};\n"
			"fragment float4 fragmentMain(FragmentIn in [[stage_in]]) {\n"
			"	return float4(in.second.xyz, in.fourth.y + 0.25);\n}\n");
		CHECK(vertexLibrary != nil && fragmentLibrary != nil);
		if (vertexLibrary == nil || fragmentLibrary == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
		pd.vertexFunction = [vertexLibrary newFunctionWithName: @"vertexMain"];
		pd.fragmentFunction = [fragmentLibrary newFunctionWithName: @"fragmentMain"];
		pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
		NSError* error = nil;
		id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor: pd error: &error];
		CHECK(pipeline != nil);
		if (pipeline == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 4 height: 4 mipmapped: NO];
		td.usage = MTLTextureUsageRenderTarget;
		id<MTLTexture> target = [device newTextureWithDescriptor: td];
		MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
		rp.colorAttachments[0].texture = target;
		rp.colorAttachments[0].loadAction = MTLLoadActionClear;
		rp.colorAttachments[0].storeAction = MTLStoreActionStore;
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLRenderCommandEncoder> encoder = [commands renderCommandEncoderWithDescriptor: rp];
		[encoder setRenderPipelineState: pipeline];
		[encoder drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
		[encoder endEncoding];
		[commands commit];
		[commands waitUntilCompleted];

		uint8_t px[4 * 4 * 4];
		[target getBytes: px bytesPerRow: 16 fromRegion: MTLRegionMake2D(0, 0, 4, 4) mipmapLevel: 0];
		const uint8_t* p = px + (2 * 4 + 2) * 4;
		// second.xyz = (0.2, 0.4, 0.6), fourth.y + 0.25 = 0.25
		CHECK(abs(p[0] - 51) <= 2 && abs(p[1] - 102) <= 2 && abs(p[2] - 153) <= 2 && abs(p[3] - 64) <= 2);
		if (failures) {
			printf("pixel %d %d %d %d\n", p[0], p[1], p[2], p[3]);
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures ? 1 : 0;
}
