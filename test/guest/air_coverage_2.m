// Copyright (C) 2026 Lubos Dolezel
// Compute kernels from a precompiled library (air_coverage_2_metallib.h, source air_coverage_2.metal) that use
// features of the Metal Shading Language the AIR translation has to cover: gather() of a 2D texture, the size and
// level count queries, read() of a multisample texture, and the simdgroup functions (reductions, prefix sums,
// broadcasts, shuffles and ballots). The results are compared with what the specification defines, independent of
// the width of a simdgroup, so the same numbers come out on macOS. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>

#include "air_coverage_2_metallib.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;
static id<MTLLibrary> library;

static id<MTLComputePipelineState> pipeline(NSString* name) {
	NSError* error = nil;
	id<MTLFunction> function = [library newFunctionWithName: name];
	CHECK(function != nil);
	if (function == nil) {
		return nil;
	}
	id<MTLComputePipelineState> pso = [device newComputePipelineStateWithFunction: function error: &error];
	CHECK(pso != nil);
	return pso;
}

// Runs a kernel with the buffers bound from index 0 and the textures from index 0.
static void run(NSString* name, NSArray<id<MTLBuffer>>* buffers, NSArray<id<MTLTexture>>* textures, MTLSize groups, MTLSize size, BOOL byThreads) {
	id<MTLComputePipelineState> pso = pipeline(name);
	if (pso == nil) {
		return;
	}
	id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
	id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
	[encoder setComputePipelineState: pso];
	for (NSUInteger i = 0; i < buffers.count; i++) {
		[encoder setBuffer: buffers[i] offset: 0 atIndex: i];
	}
	for (NSUInteger i = 0; i < textures.count; i++) {
		[encoder setTexture: textures[i] atIndex: i];
	}
	if (byThreads) {
		[encoder dispatchThreads: groups threadsPerThreadgroup: size];
	} else {
		[encoder dispatchThreadgroups: groups threadsPerThreadgroup: size];
	}
	[encoder endEncoding];
	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];
	CHECK(commandBuffer.status == MTLCommandBufferStatusCompleted);
}

static id<MTLBuffer> buffer(NSUInteger length) {
	return [device newBufferWithLength: length options: MTLResourceStorageModeShared];
}

static float texelValue(int x, int y, int channel) {
	return 100 * channel + 10 * y + x;
}

static int clampTo(int v, int size) {
	return v < 0 ? 0 : (v > size - 1 ? size - 1 : v);
}

static void testGather(void) {
	enum { N = 4 };
	MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA32Float width: N height: N mipmapped: NO];
	descriptor.storageMode = MTLStorageModeManaged;
	id<MTLTexture> t = [device newTextureWithDescriptor: descriptor];
	float texels[N * N * 4];
	for (int y = 0; y < N; y++) {
		for (int x = 0; x < N; x++) {
			for (int c = 0; c < 4; c++) {
				texels[(y * N + x) * 4 + c] = texelValue(x, y, c);
			}
		}
	}
	[t replaceRegion: MTLRegionMake2D(0, 0, N, N) mipmapLevel: 0 withBytes: texels bytesPerRow: N * 16];
	uint32_t size[2] = { N, N };
	id<MTLBuffer> sizeBuffer = [device newBufferWithBytes: size length: sizeof(size) options: MTLResourceStorageModeShared];

	// the footprint is (i0, j1), (i1, j1), (i1, j0), (i0, j0), clamped to the texture; the offset moves it
	NSArray* kernels = @[@"gather_2d", @"gather_2d_offset"];
	for (int k = 0; k < 2; k++) {
		id<MTLBuffer> out = buffer(N * N * 16);
		run(kernels[k], @[out, sizeBuffer], @[t], MTLSizeMake(N, N, 1), MTLSizeMake(1, 1, 1), YES);
		const float* got = [out contents];
		int component = k == 0 ? 1 : 0, offsetX = k == 0 ? 0 : 1;
		BOOL ok = YES;
		for (int y = 0; y < N; y++) {
			for (int x = 0; x < N; x++) {
				int i0 = clampTo(x + offsetX, N), i1 = clampTo(x + offsetX + 1, N), j0 = clampTo(y, N), j1 = clampTo(y + 1, N);
				const float* p = got + (y * N + x) * 4;
				ok = ok && p[0] == texelValue(i0, j1, component) && p[1] == texelValue(i1, j1, component)
					&& p[2] == texelValue(i1, j0, component) && p[3] == texelValue(i0, j0, component);
			}
		}
		CHECK(ok);
	}
}

static void testSizes(void) {
	MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 8 height: 4 mipmapped: YES];
	id<MTLTexture> t = [device newTextureWithDescriptor: descriptor];
	id<MTLBuffer> out = buffer(4 * 4);
	run(@"size_2d", @[out], @[t], MTLSizeMake(1, 1, 1), MTLSizeMake(1, 1, 1), NO);
	const uint32_t* got = [out contents];
	CHECK(got[0] == 8 && got[1] == 4 && got[2] == 4 && got[3] == 4);
}

static void testMultisample(void) {
	enum { N = 4, SAMPLES = 4 };
	if (![device supportsTextureSampleCount: SAMPLES]) {
		printf("skipping the multisample checks: no 4x sampling\n");
		return;
	}
	MTLTextureDescriptor* descriptor = [[MTLTextureDescriptor alloc] init];
	descriptor.textureType = MTLTextureType2DMultisample;
	descriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
	descriptor.width = N;
	descriptor.height = N;
	descriptor.sampleCount = SAMPLES;
	descriptor.storageMode = MTLStorageModePrivate;
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	id<MTLTexture> t = [device newTextureWithDescriptor: descriptor];
	MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = t;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	pass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1);
	id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
	[[commandBuffer renderCommandEncoderWithDescriptor: pass] endEncoding];
	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];

	uint32_t samples = SAMPLES;
	id<MTLBuffer> countBuffer = [device newBufferWithBytes: &samples length: sizeof(samples) options: MTLResourceStorageModeShared];
	id<MTLBuffer> out = buffer(N * N * SAMPLES * 16);
	run(@"ms_read", @[out, countBuffer], @[t], MTLSizeMake(N, N, 1), MTLSizeMake(1, 1, 1), YES);
	const float* got = [out contents];
	BOOL ok = YES;
	for (int i = 0; i < N * N * SAMPLES; i++) {
		ok = ok && got[i * 4] == 1.0f && got[i * 4 + 1] == 0.0f && got[i * 4 + 2] == 0.0f && got[i * 4 + 3] == 1.0f;
	}
	CHECK(ok);

	id<MTLBuffer> sizes = buffer(3 * 4);
	run(@"ms_sizes", @[sizes], @[t], MTLSizeMake(1, 1, 1), MTLSizeMake(1, 1, 1), NO);
	const uint32_t* s = [sizes contents];
	CHECK(s[0] == N && s[1] == N && s[2] == SAMPLES);
}

static void testSimdgroup(void) {
	enum { THREADS = 64 };
	id<MTLBuffer> out = buffer(THREADS * 8 * 4);
	run(@"simd_ops", @[out], @[], MTLSizeMake(1, 1, 1), MTLSizeMake(THREADS, 1, 1), NO);
	const uint32_t* got = [out contents];
	uint32_t width = got[1];
	CHECK(width >= 4 && width <= 128 && THREADS % width == 0);
	if (width < 4 || width > 128 || THREADS % width != 0) {
		return;
	}
	uint32_t oddMask = 0;
	for (uint32_t lane = 0; lane < width && lane < 32; lane++) {
		oddMask |= (lane & 1) ? 1u << lane : 0;
	}
	BOOL ok = YES;
	for (uint32_t t = 0; t < THREADS; t++) {
		uint32_t first = t - t % width, lane = t % width, sum = 0, prefix = 0;
		for (uint32_t i = first; i < first + width; i++) {
			sum += i;
			prefix += i < t ? i : 0;
		}
		const uint32_t* p = got + t * 8;
		ok = ok && p[0] == lane && p[1] == width && p[2] == sum && p[3] == first + width - 1 && p[4] == prefix
			&& p[5] == first && p[6] == first + (lane + 1) % width && p[7] == oddMask;
	}
	CHECK(ok);
}

int main(void) {
	@autoreleasepool {
		device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("no Metal device\n");
			return 77;
		}
		queue = [device newCommandQueue];
		NSError* error = nil;
		dispatch_data_t data = dispatch_data_create(air_coverage_2_metallib, sizeof(air_coverage_2_metallib), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
		library = [device newLibraryWithData: data error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAIL\n");
			return 1;
		}
		testGather();
		testSizes();
		testMultisample();
		testSimdgroup();
		printf(failures ? "FAIL (%d)\n" : "ALL PASSED\n", failures);
	}
	return failures ? 1 : 0;
}
