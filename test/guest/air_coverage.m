// Copyright (C) 2026 Lubos Dolezel
// Compute kernels from a precompiled library (air_coverage_metallib.h) that use features of the Metal Shading
// Language the AIR translation has to cover: write() on write and read_write textures (several dimensions and
// component types) and read() of read-only textures, threadgroup memory with threadgroup_barrier(), and the atomic
// functions on device and threadgroup memory. The results do not depend on the order the threads run in, so the
// same numbers come out on macOS. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>

#include "air_coverage_metallib.h"

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

static id<MTLBuffer> bufferOf(const uint32_t* words, NSUInteger count) {
	return [device newBufferWithBytes: words length: count * 4 options: MTLResourceStorageModeShared];
}

// Runs a kernel over `groups` threadgroups of `size` threads with the buffers bound from index 0.
static void run(NSString* name, NSArray<id<MTLBuffer>>* buffers, NSArray<id<MTLTexture>>* textures, MTLSize groups, MTLSize size) {
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
	[encoder dispatchThreadgroups: groups threadsPerThreadgroup: size];
	[encoder endEncoding];
	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];
	CHECK(commandBuffer.status == MTLCommandBufferStatusCompleted);
}

static id<MTLTexture> texture2D(MTLPixelFormat format, NSUInteger width, NSUInteger height, MTLTextureUsage usage) {
	MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: format width: width height: height mipmapped: NO];
	descriptor.usage = usage;
	descriptor.storageMode = MTLStorageModeManaged;
	return [device newTextureWithDescriptor: descriptor];
}

static void upload(id<MTLTexture> texture, const void* bytes, NSUInteger bytesPerRow) {
	[texture replaceRegion: MTLRegionMake2D(0, 0, texture.width, texture.height) mipmapLevel: 0 withBytes: bytes bytesPerRow: bytesPerRow];
}

static void download(id<MTLTexture> texture, void* bytes, NSUInteger bytesPerRow) {
	[texture getBytes: bytes bytesPerRow: bytesPerRow fromRegion: MTLRegionMake2D(0, 0, texture.width, texture.height) mipmapLevel: 0];
}

static void testTextures(void) {
	enum { W = 8, H = 4 };
	MTLTextureUsage rw = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
	MTLSize grid = MTLSizeMake(W, H, 1), one = MTLSizeMake(1, 1, 1);

	// write(float4) to a write texture
	{
		id<MTLTexture> t = texture2D(MTLPixelFormatRGBA32Float, W, H, rw);
		float zeros[W * H * 4] = { 0 };
		upload(t, zeros, W * 16);
		run(@"write_2d", @[], @[t], grid, one);
		float got[W * H * 4];
		download(t, got, W * 16);
		BOOL ok = YES;
		for (int y = 0; y < H; y++) {
			for (int x = 0; x < W; x++) {
				float* p = got + (y * W + x) * 4;
				ok = ok && p[0] == x && p[1] == y && p[2] == x + y && p[3] == 1.0f;
			}
		}
		CHECK(ok);
	}

	// write(uint4) and write(int4)
	{
		id<MTLTexture> t = texture2D(MTLPixelFormatRGBA32Uint, W, H, rw);
		run(@"write_2d_uint", @[], @[t], grid, one);
		uint32_t got[W * H * 4];
		download(t, got, W * 16);
		BOOL ok = YES;
		for (int y = 0; y < H; y++) {
			for (int x = 0; x < W; x++) {
				uint32_t* p = got + (y * W + x) * 4;
				ok = ok && p[0] == x && p[1] == y && p[2] == x * 10 + y && p[3] == 7;
			}
		}
		CHECK(ok);
		t = texture2D(MTLPixelFormatRGBA32Sint, W, H, rw);
		run(@"write_2d_int", @[], @[t], grid, one);
		int32_t igot[W * H * 4];
		download(t, igot, W * 16);
		ok = YES;
		for (int y = 0; y < H; y++) {
			for (int x = 0; x < W; x++) {
				int32_t* p = igot + (y * W + x) * 4;
				ok = ok && p[0] == -x && p[1] == y && p[2] == -3 && p[3] == 5;
			}
		}
		CHECK(ok);
	}

	// read() then write() of a read_write texture
	{
		id<MTLTexture> t = texture2D(MTLPixelFormatRGBA32Float, W, H, rw);
		float start[W * H * 4];
		for (int i = 0; i < W * H; i++) {
			start[i * 4] = i; start[i * 4 + 1] = 2 * i; start[i * 4 + 2] = 0.5f; start[i * 4 + 3] = 1;
		}
		upload(t, start, W * 16);
		run(@"read_write_2d", @[], @[t], grid, one);
		float got[W * H * 4];
		download(t, got, W * 16);
		BOOL ok = YES;
		for (int i = 0; i < W * H; i++) {
			ok = ok && got[i * 4] == i * 2 + 1 && got[i * 4 + 1] == 4 * i && got[i * 4 + 2] == 1.0f && got[i * 4 + 3] == 2.0f;
		}
		CHECK(ok);
	}

	// read() of a read-only texture, write() to another
	{
		id<MTLTexture> in = texture2D(MTLPixelFormatRGBA32Float, W, H, MTLTextureUsageShaderRead);
		id<MTLTexture> out = texture2D(MTLPixelFormatRGBA32Float, W, H, rw);
		float src[W * H * 4];
		for (int i = 0; i < W * H; i++) {
			src[i * 4] = i; src[i * 4 + 1] = i + 1; src[i * 4 + 2] = i + 2; src[i * 4 + 3] = i + 3;
		}
		upload(in, src, W * 16);
		run(@"copy_read_to_write", @[], @[in, out], grid, one);
		float got[W * H * 4];
		download(out, got, W * 16);
		BOOL ok = YES;
		for (int i = 0; i < W * H; i++) {
			// the kernel writes the texel with its components reversed
			ok = ok && got[i * 4] == i + 3 && got[i * 4 + 1] == i + 2 && got[i * 4 + 2] == i + 1 && got[i * 4 + 3] == i;
		}
		CHECK(ok);
	}
}

static void testThreadgroup(void) {
	enum { Groups = 5, Size = 64 };
	uint32_t input[Groups * Size], reversed[Groups * Size], sums[Groups] = { 0 };
	for (int i = 0; i < Groups * Size; i++) {
		input[i] = i * 7 + 3;
	}
	for (int g = 0; g < Groups; g++) {
		for (int l = 0; l < Size; l++) {
			reversed[g * Size + l] = input[g * Size + Size - 1 - l];
			sums[g] += input[g * Size + l];
		}
	}

	id<MTLBuffer> in = bufferOf(input, Groups * Size);
	id<MTLBuffer> out = [device newBufferWithLength: Groups * Size * 4 options: MTLResourceStorageModeShared];
	memset([out contents], 0xA5, Groups * Size * 4);
	run(@"reverse_tile", @[in, out], @[], MTLSizeMake(Groups, 1, 1), MTLSizeMake(Size, 1, 1));
	CHECK(memcmp([out contents], reversed, sizeof(reversed)) == 0);

	id<MTLBuffer> sumOut = [device newBufferWithLength: Groups * 4 options: MTLResourceStorageModeShared];
	run(@"sum_tile", @[in, sumOut], @[], MTLSizeMake(Groups, 1, 1), MTLSizeMake(Size, 1, 1));
	CHECK(memcmp([sumOut contents], sums, sizeof(sums)) == 0);
}

static void testAtomics(void) {
	// 4 groups of 64 threads each add 1 and their grid position, and subtract 1
	uint32_t start[3] = { 0, 0, 1000 };
	id<MTLBuffer> counters = bufferOf(start, 3);
	run(@"add_counters", @[counters], @[], MTLSizeMake(4, 1, 1), MTLSizeMake(64, 1, 1));
	const uint32_t* c = [counters contents];
	CHECK(c[0] == 256 && c[1] == 32640 && c[2] == 744);

	// every thread's fetch-and-add returns a different ticket
	uint32_t zero = 0;
	id<MTLBuffer> counter = bufferOf(&zero, 1);
	id<MTLBuffer> tickets = [device newBufferWithLength: 128 * 4 options: MTLResourceStorageModeShared];
	run(@"tickets", @[counter, tickets], @[], MTLSizeMake(2, 1, 1), MTLSizeMake(64, 1, 1));
	const uint32_t* t = [tickets contents];
	BOOL seen[128] = { NO }, ok = YES;
	for (int i = 0; i < 128; i++) {
		ok = ok && t[i] < 128 && !seen[t[i]];
		if (t[i] < 128) {
			seen[t[i]] = YES;
		}
	}
	CHECK(ok && *(const uint32_t*)[counter contents] == 128);

	// exactly one compare-and-exchange succeeds, and a failure reports the value found
	uint32_t seven = 7;
	id<MTLBuffer> flag = bufferOf(&seven, 1);
	id<MTLBuffer> claims = [device newBufferWithLength: 64 * 4 options: MTLResourceStorageModeShared];
	run(@"claim_from_seven", @[flag, claims], @[], MTLSizeMake(1, 1, 1), MTLSizeMake(64, 1, 1));
	const uint32_t* r = [claims contents];
	uint32_t stored = *(const uint32_t*)[flag contents];
	int winners = 0;
	ok = stored >= 100 && stored < 164;
	for (int i = 0; i < 64; i++) {
		if (r[i] == 1) {
			winners++;
			ok = ok && stored == i + 100;
		} else {
			ok = ok && r[i] == 1000 + stored;
		}
	}
	CHECK(winners == 1 && ok);

	// threadgroup atomics: each group counts its 32 threads and sums their indices (0 + ... + 31)
	id<MTLBuffer> groupOut = [device newBufferWithLength: 6 * 4 options: MTLResourceStorageModeShared];
	run(@"group_counters", @[groupOut], @[], MTLSizeMake(3, 1, 1), MTLSizeMake(32, 1, 1));
	const uint32_t* g = [groupOut contents];
	CHECK(g[0] == 32 && g[1] == 496 && g[2] == 32 && g[3] == 496 && g[4] == 32 && g[5] == 496);
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
		dispatch_data_t data = dispatch_data_create(air_coverage_metallib, sizeof(air_coverage_metallib), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
		library = [device newLibraryWithData: data error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAIL\n");
			return 1;
		}
		testTextures();
		testThreadgroup();
		testAtomics();
		printf(failures ? "FAIL (%d)\n" : "ALL PASSED\n", failures);
	}
	return failures ? 1 : 0;
}
