// Copyright (C) 2026 Lubos Dolezel
// -[MTLCommandBuffer parallelRenderCommandEncoderWithDescriptor:] and MTLParallelRenderCommandEncoder: the encoders
// of one pass can be used in any order and from several threads; their commands run in the order the encoders were
// made, each starting with the default state, in one pass whose load action applies once. Every check compares what a
// serial pass with one encoder makes with what the parallel pass makes. The expectations follow the documented
// contract and what macOS 27.0.1 (Apple silicon) does (checked by compiling this file there).
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kSize = 8 };

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;
static id<MTLRenderPipelineState> plain;      // writes red
static id<MTLRenderPipelineState> blendColor; // writes the blend color in the red channel

static uint32_t rgba(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	return r | (g << 8) | (b << 16) | ((uint32_t)a << 24);
}

static id<MTLTexture> newTarget(void) {
	MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
	td.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	td.storageMode = MTLStorageModeShared;
	return [device newTextureWithDescriptor: td];
}

static MTLRenderPassDescriptor* passFor(id<MTLTexture> target, MTLStoreAction store) {
	MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
	rp.colorAttachments[0].texture = target;
	rp.colorAttachments[0].loadAction = MTLLoadActionClear;
	rp.colorAttachments[0].storeAction = store;
	rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 1, 1);
	return rp;
}

// runs `body` on a new command buffer for a new target cleared to blue and returns its pixels
static void run(uint32_t* pixels, MTLStoreAction store, void (^body)(id<MTLCommandBuffer>, MTLRenderPassDescriptor*)) {
	id<MTLTexture> target = newTarget();
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	body(commands, passFor(target, store));
	[commands commit];
	[commands waitUntilCompleted];
	[target getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
	[target release];
}

static int allEqual(const uint32_t* pixels, uint32_t value) {
	for (int i = 0; i < kSize * kSize; i++) if (pixels[i] != value) return 0;
	return 1;
}

static void drawAll(id<MTLRenderCommandEncoder> e, id<MTLRenderPipelineState> state) {
	[e setRenderPipelineState: state];
	[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
}

static void drawWithBlendColor(id<MTLRenderCommandEncoder> e, float value) {
	[e setBlendColorRed: value green: value blue: value alpha: 1];
	drawAll(e, blendColor);
}

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
			"struct Vertex { float4 position [[position]]; };\n"
			"vertex Vertex fullVertex(uint vid [[vertex_id]]) {\n"
			"	Vertex o;\n"
			"	float x = (vid == 1) ? 3.0 : -1.0;\n"
			"	float y = (vid == 2) ? 3.0 : -1.0;\n"
			"	o.position = float4(x, y, 0.0, 1.0);\n	return o;\n}\n"
			"fragment float4 redFragment() { return float4(1.0, 0.0, 0.0, 1.0); }\n" options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
		pd.vertexFunction = [library newFunctionWithName: @"fullVertex"];
		pd.fragmentFunction = [library newFunctionWithName: @"redFragment"];
		pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
		plain = [device newRenderPipelineStateWithDescriptor: pd error: nil];
		pd.colorAttachments[0].blendingEnabled = YES;
		pd.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorBlendColor;
		pd.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorZero;
		pd.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorBlendColor;
		pd.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorZero;
		blendColor = [device newRenderPipelineStateWithDescriptor: pd error: nil];
		CHECK(plain != nil && blendColor != nil);

		uint32_t pixels[kSize * kSize], expected[kSize * kSize];

		// --- a parallel pass without encoders is a pass: the load action ran, nothing was drawn
		run(pixels, MTLStoreActionStore, ^(id<MTLCommandBuffer> commands, MTLRenderPassDescriptor* rp) {
			id<MTLParallelRenderCommandEncoder> pass = [commands parallelRenderCommandEncoderWithDescriptor: rp];
			CHECK(pass != nil);
			CHECK(pass.device == device);
			[pass endEncoding];
		});
		CHECK(allEqual(pixels, rgba(0, 0, 255, 255)));

		// --- one encoder: the same as a serial pass
		run(expected, MTLStoreActionStore, ^(id<MTLCommandBuffer> commands, MTLRenderPassDescriptor* rp) {
			id<MTLRenderCommandEncoder> e = [commands renderCommandEncoderWithDescriptor: rp];
			drawAll(e, plain);
			[e endEncoding];
		});
		run(pixels, MTLStoreActionStore, ^(id<MTLCommandBuffer> commands, MTLRenderPassDescriptor* rp) {
			id<MTLParallelRenderCommandEncoder> pass = [commands parallelRenderCommandEncoderWithDescriptor: rp];
			id<MTLRenderCommandEncoder> e = [pass renderCommandEncoder];
			drawAll(e, plain);
			[e endEncoding];
			[pass endEncoding];
		});
		CHECK(allEqual(expected, rgba(255, 0, 0, 255)) && memcmp(pixels, expected, sizeof pixels) == 0);

		// --- commands run in the order the encoders were made, not the order they were used or ended in
		run(pixels, MTLStoreActionStore, ^(id<MTLCommandBuffer> commands, MTLRenderPassDescriptor* rp) {
			id<MTLParallelRenderCommandEncoder> pass = [commands parallelRenderCommandEncoderWithDescriptor: rp];
			id<MTLRenderCommandEncoder> first = [pass renderCommandEncoder];
			id<MTLRenderCommandEncoder> second = [pass renderCommandEncoder];
			drawWithBlendColor(second, 0.6f);
			[second endEncoding];
			drawWithBlendColor(first, 0.2f);
			[first endEncoding];
			[pass endEncoding];
		});
		CHECK(allEqual(pixels, rgba(153, 0, 0, 255)));

		// --- an encoder starts from the default state, not from what the one before it left
		run(pixels, MTLStoreActionStore, ^(id<MTLCommandBuffer> commands, MTLRenderPassDescriptor* rp) {
			id<MTLParallelRenderCommandEncoder> pass = [commands parallelRenderCommandEncoderWithDescriptor: rp];
			id<MTLRenderCommandEncoder> first = [pass renderCommandEncoder];
			[first setScissorRect: (MTLScissorRect){ 0, 0, kSize / 2, kSize }];
			drawWithBlendColor(first, 0.5f);
			[first endEncoding];
			id<MTLRenderCommandEncoder> second = [pass renderCommandEncoder];
			drawAll(second, blendColor);
			[second endEncoding];
			[pass endEncoding];
		});
		CHECK(allEqual(pixels, rgba(0, 0, 0, 0)));

		// --- the encoders can be used from threads at the same time
		enum { kCount = 8 };
		run(expected, MTLStoreActionStore, ^(id<MTLCommandBuffer> commands, MTLRenderPassDescriptor* rp) {
			id<MTLRenderCommandEncoder> e = [commands renderCommandEncoderWithDescriptor: rp];
			for (int i = 0; i < kCount; i++) {
				[e setScissorRect: (MTLScissorRect){ (NSUInteger)i, 0, 1, kSize }];
				drawWithBlendColor(e, (float)(i + 1) / 10);
				[e setScissorRect: (MTLScissorRect){ 0, 0, kSize, kSize }];
			}
			[e endEncoding];
		});
		run(pixels, MTLStoreActionStore, ^(id<MTLCommandBuffer> commands, MTLRenderPassDescriptor* rp) {
			id<MTLParallelRenderCommandEncoder> pass = [commands parallelRenderCommandEncoderWithDescriptor: rp];
			NSMutableArray* encoders = [NSMutableArray array];
			for (int i = 0; i < kCount; i++) [encoders addObject: [pass renderCommandEncoder]];
			dispatch_apply(kCount, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t k) {
				size_t i = kCount - 1 - k;
				id<MTLRenderCommandEncoder> e = encoders[i];
				[e setScissorRect: (MTLScissorRect){ i, 0, 1, kSize }];
				drawWithBlendColor(e, (float)(i + 1) / 10);
				[e endEncoding];
			});
			[pass endEncoding];
		});
		CHECK(memcmp(pixels, expected, sizeof pixels) == 0 && pixels[1] == rgba(51, 0, 0, 255) && pixels[kCount - 1] == rgba(204, 0, 0, 255));

		// --- the store action of an attachment whose action is Unknown is the one set on the parallel encoder
		run(pixels, MTLStoreActionUnknown, ^(id<MTLCommandBuffer> commands, MTLRenderPassDescriptor* rp) {
			id<MTLParallelRenderCommandEncoder> pass = [commands parallelRenderCommandEncoderWithDescriptor: rp];
			[pass setColorStoreAction: MTLStoreActionStore atIndex: 0];
			id<MTLRenderCommandEncoder> e = [pass renderCommandEncoder];
			drawAll(e, plain);
			[e endEncoding];
			[pass endEncoding];
		});
		CHECK(allEqual(pixels, rgba(255, 0, 0, 255)));
	}
	if (failures) {
		printf("FAILED (%d)\n", failures);
		return 1;
	}
	printf("ALL PASSED\n");
	return 0;
}
