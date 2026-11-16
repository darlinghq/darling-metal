// Copyright (C) 2026 Lubos Dolezel
// MTLPixelFormatA8Unorm textures written by a kernel and rendered to. The format has only an alpha channel: a
// kernel writing float4(r, g, b, a) stores a, a render target clears to the alpha of the clear colour, stores the
// alpha a fragment returns, blends the alpha with the alpha blend factors, and the colour write mask has an effect
// through its alpha bit only. A shader reads the texture back as (0, 0, 0, a).
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <math.h>
#include <stdlib.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kWidth = 8, kHeight = 2 };

static uint8_t bytes[kWidth * kHeight];
static id<MTLDevice> device;
static id<MTLCommandQueue> queue;

static BOOL within(uint8_t value, int expected) { return abs((int)value - expected) <= 1; }

static BOOL allWithin(const uint8_t* bytes, int expected) {
	for (int i = 0; i < kWidth * kHeight; i++) {
		if (!within(bytes[i], expected)) {
			return NO;
		}
	}
	return YES;
}

static id<MTLTexture> make(MTLTextureUsage usage) {
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatA8Unorm width: kWidth height: kHeight mipmapped: NO];
	d.usage = usage;
	d.storageMode = MTLStorageModeManaged;
	return [device newTextureWithDescriptor: d];
}

// the texels as a blit copy into a shared buffer delivers them (a managed texture needs no synchronisation that way)
static void readBack(id<MTLTexture> texture, uint8_t* out) {
	id<MTLBuffer> buffer = [device newBufferWithLength: kWidth * kHeight options: MTLResourceStorageModeShared];
	memset([buffer contents], 0xEE, kWidth * kHeight);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
	[blit copyFromTexture: texture sourceSlice: 0 sourceLevel: 0 sourceOrigin: MTLOriginMake(0, 0, 0) sourceSize: MTLSizeMake(kWidth, kHeight, 1)
		toBuffer: buffer destinationOffset: 0 destinationBytesPerRow: kWidth destinationBytesPerImage: kWidth * kHeight];
	[blit endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	memcpy(out, [buffer contents], kWidth * kHeight);
	[buffer release];
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
			"	o.position = float4(x, y, 0.5, 1.0);\n	return o;\n}\n"
			"fragment float4 colorFragment() { return float4(0.9, 0.8, 0.7, 0.5); }\n"
			"kernel void writeTexel(texture2d<float, access::write> tex [[texture(0)]], uint2 gid [[thread_position_in_grid]]) {\n"
			"	tex.write(float4(0.9, 0.8, 0.7, float(gid.x + 1) / 8.0), gid);\n}\n"
			"kernel void readTexel(texture2d<float> tex [[texture(0)]], device float4* out [[buffer(0)]]) {\n"
			"	out[0] = tex.read(uint2(1, 0));\n}\n" options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		id<MTLTexture> writable = make(MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead);
		id<MTLTexture> target = make(MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead);
		CHECK(writable != nil);
		CHECK(target != nil);
		if (writable == nil || target == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		// --- a kernel writes the alpha
		id<MTLComputePipelineState> writeKernel = [device newComputePipelineStateWithFunction: [library newFunctionWithName: @"writeTexel"] error: &error];
		CHECK(writeKernel != nil);
		{
			uint8_t zeros[kWidth * kHeight] = { 0 };
			[writable replaceRegion: MTLRegionMake2D(0, 0, kWidth, kHeight) mipmapLevel: 0 withBytes: zeros bytesPerRow: kWidth];
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
			[encoder setComputePipelineState: writeKernel];
			[encoder setTexture: writable atIndex: 0];
			[encoder dispatchThreads: MTLSizeMake(kWidth, kHeight, 1) threadsPerThreadgroup: MTLSizeMake(1, 1, 1)];
			[encoder endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			readBack(writable, bytes);
			BOOL all = YES;
			for (int y = 0; y < kHeight; y++) {
				for (int x = 0; x < kWidth; x++) {
					all = all && within(bytes[y * kWidth + x], (int)((x + 1) * 255 / 8.0 + 0.5));
				}
			}
			CHECK(all);
		}

		// --- what was written reads back as (0, 0, 0, a)
		{
			id<MTLComputePipelineState> readKernel = [device newComputePipelineStateWithFunction: [library newFunctionWithName: @"readTexel"] error: &error];
			id<MTLBuffer> out = [device newBufferWithLength: 16 options: MTLResourceStorageModeShared];
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
			[encoder setComputePipelineState: readKernel];
			[encoder setTexture: writable atIndex: 0];
			[encoder setBuffer: out offset: 0 atIndex: 0];
			[encoder dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(1, 1, 1)];
			[encoder endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			const float* texel = [out contents];
			CHECK(texel[0] == 0 && texel[1] == 0 && texel[2] == 0 && fabsf(texel[3] - 2 / 8.0f) < 0.005f);
			[out release];
		}

		// --- a render pass draws into it
		id<MTLRenderPipelineState> (^pipeline)(MTLColorWriteMask, BOOL) = ^id<MTLRenderPipelineState>(MTLColorWriteMask mask, BOOL blend) {
			MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
			pd.vertexFunction = [library newFunctionWithName: @"fullVertex"];
			pd.fragmentFunction = [library newFunctionWithName: @"colorFragment"];
			pd.colorAttachments[0].pixelFormat = MTLPixelFormatA8Unorm;
			pd.colorAttachments[0].writeMask = mask;
			if (blend) {
				pd.colorAttachments[0].blendingEnabled = YES;
				pd.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
				pd.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
				pd.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
				pd.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
			}
			return [device newRenderPipelineStateWithDescriptor: pd error: nil];
		};
		// clears to `clearAlpha` and draws with `state` (nil draws nothing)
		void (^run)(float, id<MTLRenderPipelineState>) = ^(float clearAlpha, id<MTLRenderPipelineState> state) {
			MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
			rp.colorAttachments[0].texture = target;
			rp.colorAttachments[0].loadAction = MTLLoadActionClear;
			rp.colorAttachments[0].storeAction = MTLStoreActionStore;
			rp.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, clearAlpha);
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLRenderCommandEncoder> encoder = [commands renderCommandEncoderWithDescriptor: rp];
			if (state != nil) {
				[encoder setRenderPipelineState: state];
				[encoder drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
			}
			[encoder endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			readBack(target, bytes);
		};
		id<MTLRenderPipelineState> plain = pipeline(MTLColorWriteMaskAll, NO);
		id<MTLRenderPipelineState> blended = pipeline(MTLColorWriteMaskAll, YES);
		id<MTLRenderPipelineState> noAlpha = pipeline(MTLColorWriteMaskRed | MTLColorWriteMaskGreen | MTLColorWriteMaskBlue, NO);
		id<MTLRenderPipelineState> onlyAlpha = pipeline(MTLColorWriteMaskAlpha, NO);
		CHECK(plain != nil && blended != nil && noAlpha != nil && onlyAlpha != nil);

		run(0.25f, nil);
		CHECK(allWithin(bytes, 64));
		run(0.25f, plain);
		CHECK(allWithin(bytes, 128));
		run(0.25f, blended);
		CHECK(allWithin(bytes, 191));
		run(0.25f, noAlpha);
		CHECK(allWithin(bytes, 64));
		run(0.25f, onlyAlpha);
		CHECK(allWithin(bytes, 128));
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures ? 1 : 0;
}
