// Copyright (C) 2026 Lubos Dolezel
// Visibility results: -[MTLRenderCommandEncoder setVisibilityResultMode:offset:] counts the samples of the draws
// after it into the 8-byte slot of MTLRenderPassDescriptor.visibilityResultBuffer at the offset, once the command
// buffer has completed. Counting stores the number of samples that passed the depth test, were not discarded and
// were inside the scissor rectangle; Boolean stores 1 if any passed. The first call of an encoder that names a slot
// clears it, later spans at the slot of the same encoder add (Counting) or set it to 1 (Boolean, when a sample
// passed); Disabled and slots no call names leave the buffer alone; a new encoder replaces what the buffer held.
// The target is 16x16 pixels and every rectangle has pixel-aligned edges, so a w x h rectangle covers w * h samples.
// The expected values were also observed on macOS 27.0.1 (arm64); the test runs there as well.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kSize = 16 };
static const uint64_t kUntouched = 0xABABABABABABABABull;

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;
static id<MTLRenderPipelineState> red, discarding;
static id<MTLDepthStencilState> always, less, noTest;
static id<MTLTexture> color, depth;

// a pixel-aligned rectangle (x0, y0)-(x1, y1) of the target at depth z; two triangles that never overlap
static void quad(id<MTLRenderCommandEncoder> e, int x0, int y0, int x1, int y1, float z) {
	float r[5] = { x0 / 8.0f - 1, 1 - y0 / 8.0f, x1 / 8.0f - 1, 1 - y1 / 8.0f, z };
	[e setVertexBytes: r length: sizeof r atIndex: 0];
	[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 6];
}

static MTLRenderPassDescriptor* pass(id<MTLBuffer> results, BOOL loadDepth) {
	MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
	rp.colorAttachments[0].texture = color;
	rp.colorAttachments[0].loadAction = MTLLoadActionClear;
	rp.colorAttachments[0].storeAction = MTLStoreActionStore;
	rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
	rp.depthAttachment.texture = depth;
	rp.depthAttachment.loadAction = loadDepth ? MTLLoadActionLoad : MTLLoadActionClear;
	rp.depthAttachment.storeAction = MTLStoreActionStore;
	rp.depthAttachment.clearDepth = 1.0;
	rp.visibilityResultBuffer = results;
	return rp;
}

static id<MTLRenderCommandEncoder> begin(id<MTLCommandBuffer> cb, id<MTLBuffer> results, BOOL loadDepth) {
	id<MTLRenderCommandEncoder> e = [cb renderCommandEncoderWithDescriptor: pass(results, loadDepth)];
	[e setRenderPipelineState: red];
	[e setDepthStencilState: always];
	return e;
}

static id<MTLBuffer> newBuf(size_t n, uint8_t fill) {
	id<MTLBuffer> b = [device newBufferWithLength: n options: MTLResourceStorageModeShared];
	memset([b contents], fill, n);
	return b;
}

static uint64_t slot(id<MTLBuffer> b, int i) {
	uint64_t v;
	memcpy(&v, (const char*)[b contents] + i * 8, 8);
	return v;
}

static void finish(id<MTLCommandBuffer> cb) {
	[cb commit];
	[cb waitUntilCompleted];
}

// one encoder in one command buffer
static void run(id<MTLBuffer> results, void (^body)(id<MTLRenderCommandEncoder>)) {
	id<MTLCommandBuffer> cb = [queue commandBuffer];
	id<MTLRenderCommandEncoder> e = begin(cb, results, NO);
	body(e);
	[e endEncoding];
	finish(cb);
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
		id<MTLLibrary> lib = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"struct Vertex { float4 position [[position]]; };\n"
			"struct Quad { float x0; float y0; float x1; float y1; float z; };\n"
			"vertex Vertex quadVertex(uint vid [[vertex_id]], constant Quad& q [[buffer(0)]]) {\n"
			"	Vertex o;\n"
			"	float x = (vid == 1 || vid == 3 || vid == 4) ? q.x1 : q.x0;\n"
			"	float y = (vid == 2 || vid == 4 || vid == 5) ? q.y1 : q.y0;\n"
			"	o.position = float4(x, y, q.z, 1.0);\n	return o;\n}\n"
			"fragment float4 redFragment() { return float4(1.0, 0.0, 0.0, 1.0); }\n"
			"fragment float4 discardFragment(Vertex in [[stage_in]]) {\n"
			"	if (in.position.x < 4.0) { discard_fragment(); }\n"
			"	return float4(0.0, 1.0, 0.0, 1.0);\n}\n" options: nil error: &error];
		CHECK(lib != nil);
		if (lib == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		id<MTLRenderPipelineState> (^pipeline)(NSString*) = ^id<MTLRenderPipelineState>(NSString* fragment) {
			MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
			pd.vertexFunction = [lib newFunctionWithName: @"quadVertex"];
			pd.fragmentFunction = [lib newFunctionWithName: fragment];
			pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
			pd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
			return [device newRenderPipelineStateWithDescriptor: pd error: nil];
		};
		red = pipeline(@"redFragment");
		discarding = pipeline(@"discardFragment");
		MTLDepthStencilDescriptor* dd = [[MTLDepthStencilDescriptor alloc] init];
		dd.depthCompareFunction = MTLCompareFunctionAlways;
		dd.depthWriteEnabled = YES;
		always = [device newDepthStencilStateWithDescriptor: dd];
		dd.depthCompareFunction = MTLCompareFunctionLess;
		less = [device newDepthStencilStateWithDescriptor: dd];
		noTest = [device newDepthStencilStateWithDescriptor: [[MTLDepthStencilDescriptor alloc] init]];
		MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
		td.usage = MTLTextureUsageRenderTarget;
		td.storageMode = MTLStorageModePrivate;
		color = [device newTextureWithDescriptor: td];
		td.pixelFormat = MTLPixelFormatDepth32Float;
		depth = [device newTextureWithDescriptor: td];
		CHECK(red != nil && discarding != nil && color != nil && depth != nil);

		id<MTLBuffer> b;

		// Counting
		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 8];
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		CHECK(slot(b, 1) == 128);
		CHECK(slot(b, 0) == kUntouched && slot(b, 2) == kUntouched && slot(b, 3) == kUntouched);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 256);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setDepthStencilState: less];
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 4, 0, 12, 16, 0.75f);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 8];
			quad(e, 0, 0, 8, 16, 0.75f);
		});
		CHECK(slot(b, 0) == 64);
		CHECK(slot(b, 1) == 0);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setRenderPipelineState: discarding];
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 4, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 8];
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 0 && slot(b, 1) == 64);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setScissorRect: (MTLScissorRect){ 0, 0, 4, 16 }];
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 64);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			quad(e, 0, 0, 16, 16, 0.25f);
			[e setDepthStencilState: noTest];
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 16, 16, 0.75f);
		});
		CHECK(slot(b, 0) == 256);

		// the depth stored by an earlier pass decides
		b = newBuf(64, 0xAB);
		{
			id<MTLCommandBuffer> cb = [queue commandBuffer];
			id<MTLRenderCommandEncoder> first = begin(cb, b, NO);
			quad(first, 0, 0, 16, 16, 0.5f);
			[first endEncoding];
			id<MTLRenderCommandEncoder> second = begin(cb, b, YES);
			[second setDepthStencilState: less];
			[second setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(second, 0, 0, 16, 16, 0.25f);
			[second setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 8];
			quad(second, 0, 0, 16, 16, 0.75f);
			[second endEncoding];
			finish(cb);
		}
		CHECK(slot(b, 0) == 256 && slot(b, 1) == 0);

		// Boolean
		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 8];
			[e setDepthStencilState: less];
			quad(e, 0, 0, 8, 16, 0.75f);
		});
		CHECK(slot(b, 0) == 1);
		CHECK(slot(b, 1) == 0);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 8];
			quad(e, 0, 0, 8, 16, 0.25f);
			[e setDepthStencilState: less];
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 8];
			quad(e, 0, 0, 8, 16, 0.75f);
		});
		CHECK(slot(b, 0) == 1);
		CHECK(slot(b, 1) == 1);

		// one slot used again within an encoder
		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeDisabled offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 4, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 192);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 8];
			quad(e, 0, 0, 4, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 2, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 160 && slot(b, 1) == 64);

		// mixing the two modes on one slot: a boolean span that passes sets the slot to 1 (it does not add), a
		// counting span adds
		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 0];
			quad(e, 0, 0, 4, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 1);
		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 4, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 65);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
		});
		CHECK(slot(b, 0) == 128);

		// what is written and what is not
		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 16];
			[e setVisibilityResultMode: MTLVisibilityResultModeBoolean offset: 24];
		});
		CHECK(slot(b, 2) == 0 && slot(b, 3) == 0 && slot(b, 0) == kUntouched && slot(b, 1) == kUntouched);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			[e setVisibilityResultMode: MTLVisibilityResultModeDisabled offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 0);

		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			quad(e, 0, 0, 8, 16, 0.5f);
			[e setVisibilityResultMode: MTLVisibilityResultModeDisabled offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		{
			BOOL all = YES;
			for (int i = 0; i < 8; i++) all = all && slot(b, i) == kUntouched;
			CHECK(all);
		}

		// a new encoder replaces what the buffer held instead of adding to it
		b = newBuf(64, 0);
		uint64_t thousand = 1000;
		memcpy([b contents], &thousand, 8);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 128);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 4, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 64);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		CHECK(slot(b, 0) == 64);

		// two encoders of one command buffer: the second replaces the slots it names only
		b = newBuf(64, 0xAB);
		{
			id<MTLCommandBuffer> cb = [queue commandBuffer];
			id<MTLRenderCommandEncoder> first = begin(cb, b, NO);
			[first setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(first, 0, 0, 8, 16, 0.5f);
			[first setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 8];
			quad(first, 0, 0, 8, 16, 0.5f);
			[first endEncoding];
			id<MTLRenderCommandEncoder> second = begin(cb, b, NO);
			[second setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 8];
			quad(second, 0, 0, 2, 16, 0.5f);
			[second endEncoding];
			finish(cb);
		}
		CHECK(slot(b, 0) == 128 && slot(b, 1) == 32);

		// written when the command buffer executes
		b = newBuf(64, 0xAB);
		{
			id<MTLCommandBuffer> cb = [queue commandBuffer];
			id<MTLRenderCommandEncoder> e = begin(cb, b, NO);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e endEncoding];
			CHECK(slot(b, 0) == kUntouched);
			finish(cb);
		}
		CHECK(slot(b, 0) == 128);

		// many spans: one slot each, and a long chain on one slot
		{
			enum { kCount = 600 };
			b = newBuf(kCount * 8, 0xAB);
			run(b, ^(id<MTLRenderCommandEncoder> e) {
				for (int i = 0; i < kCount; i++) {
					[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: i * 8];
					quad(e, i % 16, 0, i % 16 + 1, 1 + i % 16, 0.5f);
				}
			});
			BOOL all = YES;
			for (int i = 0; i < kCount; i++) all = all && slot(b, i) == (uint64_t)(1 + i % 16);
			CHECK(all);
			b = newBuf(64, 0xAB);
			run(b, ^(id<MTLRenderCommandEncoder> e) {
				for (int i = 0; i < kCount; i++) {
					[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 0];
					quad(e, 0, 0, 1, 1, 0.5f);
				}
			});
			CHECK(slot(b, 0) == kCount);
		}

		// a private visibility result buffer is written too (the GPU writes it; it is copied out to look at it)
		{
			id<MTLBuffer> priv = [device newBufferWithLength: 64 options: MTLResourceStorageModePrivate];
			id<MTLBuffer> shared = newBuf(64, 0xAB);
			id<MTLCommandBuffer> cb = [queue commandBuffer];
			id<MTLRenderCommandEncoder> e = begin(cb, priv, NO);
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 8];
			quad(e, 0, 0, 8, 16, 0.5f);
			[e endEncoding];
			id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
			[blit copyFromBuffer: priv sourceOffset: 0 toBuffer: shared destinationOffset: 0 size: 64];
			[blit endEncoding];
			finish(cb);
			CHECK(slot(shared, 1) == 128);
		}

		// test_quirk_unaligned_visibility_offset: QUIRK, see MTLRenderCommandEncoder's setVisibilityResultMode
		// (indium): an offset that is not a multiple of 8 is used rounded down to one, as macOS 27 does
		b = newBuf(64, 0xAB);
		run(b, ^(id<MTLRenderCommandEncoder> e) {
			[e setVisibilityResultMode: MTLVisibilityResultModeCounting offset: 12];
			quad(e, 0, 0, 8, 16, 0.5f);
		});
		CHECK(slot(b, 1) == 128 && slot(b, 0) == kUntouched && slot(b, 2) == kUntouched);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
