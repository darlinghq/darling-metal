// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// Framebuffer fetch from a library compiled from source: a fragment function whose parameter is
// [[color(n)]] reads the value that color attachment n of the render pass holds at the fragment's
// position, which is what the pass cleared it to and then what the earlier draws wrote (MSL
// specification, "Fragment Function Input Attributes", color attachment inputs).
// Drawn on the device and read back:
//  - a function that reads color(0) and writes its inverse, once and twice in one pass;
//  - color(1) read in a pass of two attachments and written to attachment 0;
//  - a draw of another function between two of them;
//  - an integer attachment.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static NSString* const kSource =
	@"#include <metal_stdlib>\nusing namespace metal;\n"
	"vertex float4 fullscreen(uint vid [[vertex_id]]) {\n"
	"	float2 corner = float2((vid << 1) & 2, vid & 2);\n"
	"	return float4(corner * 2.0 - 1.0, 0.0, 1.0);\n"
	"}\n"
	"fragment float4 invert(float4 c [[color(0)]]) {\n"
	"	return float4(1.0 - c.rgb, c.a);\n"
	"}\n"
	"struct CopyOut { float4 target [[color(0)]]; };\n"
	"fragment CopyOut copyFrom1(float4 source [[color(1)]]) {\n"
	"	CopyOut out;\n"
	"	out.target = source;\n"
	"	return out;\n"
	"}\n"
	"fragment float4 constantColor() { return float4(0.25, 0.5, 0.75, 1.0); }\n"
	"fragment uint4 addOne(uint4 c [[color(0)]]) { return c + uint4(1); }\n";

static const NSUInteger kSize = 8;

static id<MTLTexture> makeTarget(id<MTLDevice> device, MTLPixelFormat format) {
	MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: format width: kSize height: kSize mipmapped: NO];
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	return [device newTextureWithDescriptor: descriptor];
}

static id<MTLRenderPipelineState> makePipeline(id<MTLDevice> device, id<MTLLibrary> library, NSString* fragment, NSArray<NSNumber*>* formats) {
	MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor new] autorelease];
	descriptor.vertexFunction = [[library newFunctionWithName: @"fullscreen"] autorelease];
	descriptor.fragmentFunction = [[library newFunctionWithName: fragment] autorelease];
	for (NSUInteger i = 0; i < formats.count; i++) {
		descriptor.colorAttachments[i].pixelFormat = (MTLPixelFormat)formats[i].unsignedIntegerValue;
	}
	NSError* error = nil;
	id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor: descriptor error: &error];
	if (pipeline == nil) {
		printf("pipeline %s: %s\n", fragment.UTF8String, error.localizedDescription.UTF8String);
	}
	return [pipeline autorelease];
}

static void setAttachment(MTLRenderPassDescriptor* pass, NSUInteger index, id<MTLTexture> texture, MTLLoadAction load, MTLClearColor clear) {
	pass.colorAttachments[index].texture = texture;
	pass.colorAttachments[index].loadAction = load;
	pass.colorAttachments[index].storeAction = MTLStoreActionStore;
	pass.colorAttachments[index].clearColor = clear;
}

static void draw(id<MTLCommandQueue> queue, MTLRenderPassDescriptor* pass, NSArray<id<MTLRenderPipelineState>>* pipelines) {
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLRenderCommandEncoder> encoder = [commands renderCommandEncoderWithDescriptor: pass];
	for (id<MTLRenderPipelineState> pipeline in pipelines) {
		[encoder setRenderPipelineState: pipeline];
		[encoder drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
	}
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
}

static uint32_t texel(id<MTLTexture> texture, NSUInteger x, NSUInteger y) {
	uint32_t pixels[kSize * kSize];
	[texture getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
	return pixels[y * kSize + x];
}

static BOOL near(uint32_t got, int r, int g, int b, int a) {
	int want[4] = { r, g, b, a };
	for (int channel = 0; channel < 4; channel++) {
		int have = (got >> (8 * channel)) & 0xff;
		if (abs(have - want[channel]) > 1) {
			return NO;
		}
	}
	return YES;
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		NSError* error = nil;
		id<MTLLibrary> library = [[device newLibraryWithSource: kSource options: nil error: &error] autorelease];
		CHECK(library != nil);
		if (library == nil) {
			printf("library: %s\nFAILED: %d\n", error.localizedDescription.UTF8String, failures + 1);
			return 1;
		}
		id<MTLCommandQueue> queue = [[device newCommandQueue] autorelease];
		NSNumber* rgba8 = @(MTLPixelFormatRGBA8Unorm);

		id<MTLRenderPipelineState> invert = makePipeline(device, library, @"invert", @[ rgba8 ]);
		CHECK(invert != nil);
		if (invert == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		{
			id<MTLTexture> target = [makeTarget(device, MTLPixelFormatRGBA8Unorm) autorelease];
			MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
			setAttachment(pass, 0, target, MTLLoadActionClear, MTLClearColorMake(0.2, 0.4, 0.6, 0.8));
			draw(queue, pass, @[ invert ]);
			uint32_t got = texel(target, 3, 4);
			CHECK(near(got, 204, 153, 102, 204));
			if (!near(got, 204, 153, 102, 204)) printf("  one inversion: %08x\n", got);

			target = [makeTarget(device, MTLPixelFormatRGBA8Unorm) autorelease];
			setAttachment(pass, 0, target, MTLLoadActionClear, MTLClearColorMake(0.2, 0.4, 0.6, 0.8));
			draw(queue, pass, @[ invert, invert ]);
			got = texel(target, 5, 2);
			CHECK(near(got, 51, 102, 153, 204));
			if (!near(got, 51, 102, 153, 204)) printf("  two inversions: %08x\n", got);
		}

		{
			id<MTLRenderPipelineState> constant = makePipeline(device, library, @"constantColor", @[ rgba8 ]);
			id<MTLTexture> target = [makeTarget(device, MTLPixelFormatRGBA8Unorm) autorelease];
			MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
			setAttachment(pass, 0, target, MTLLoadActionClear, MTLClearColorMake(0, 0, 0, 0));
			draw(queue, pass, @[ constant, invert ]);
			uint32_t got = texel(target, 6, 6);
			CHECK(near(got, 191, 128, 64, 255));
			if (!near(got, 191, 128, 64, 255)) printf("  constant then inversion: %08x\n", got);
		}

		{
			id<MTLRenderPipelineState> copy = makePipeline(device, library, @"copyFrom1", @[ rgba8, rgba8 ]);
			id<MTLTexture> destination = [makeTarget(device, MTLPixelFormatRGBA8Unorm) autorelease];
			id<MTLTexture> source = [makeTarget(device, MTLPixelFormatRGBA8Unorm) autorelease];
			MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
			setAttachment(pass, 0, destination, MTLLoadActionClear, MTLClearColorMake(0, 0, 0, 1));
			setAttachment(pass, 1, source, MTLLoadActionClear, MTLClearColorMake(0.25, 0.5, 0.75, 1));
			draw(queue, pass, @[ copy ]);
			uint32_t got = texel(destination, 2, 2);
			CHECK(near(got, 64, 128, 191, 255));
			if (!near(got, 64, 128, 191, 255)) printf("  color(1): %08x\n", got);
		}

		{
			id<MTLRenderPipelineState> addOne = makePipeline(device, library, @"addOne", @[ @(MTLPixelFormatRGBA8Uint) ]);
			id<MTLTexture> target = [makeTarget(device, MTLPixelFormatRGBA8Uint) autorelease];
			uint32_t start[kSize * kSize];
			for (NSUInteger i = 0; i < kSize * kSize; i++) start[i] = 0x04030201u;
			[target replaceRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0 withBytes: start bytesPerRow: kSize * 4];
			MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
			setAttachment(pass, 0, target, MTLLoadActionLoad, MTLClearColorMake(0, 0, 0, 0));
			draw(queue, pass, @[ addOne, addOne ]);
			uint32_t got = texel(target, 3, 3);
			CHECK(got == 0x06050403u);
			if (got != 0x06050403u) printf("  integer: %08x\n", got);
		}

		printf(failures ? "FAILED: %d\n" : "PASSED\n", failures);
	}
	return failures ? 1 : 0;
}
