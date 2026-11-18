// Copyright (C) 2026 Lubos Dolezel
// Compute kernels from a precompiled library (air_coverage_3_metallib.h, source air_coverage_3.metal) that use
// texture_buffer textures (MTLTextureTypeTextureBuffer: a buffer's contents read and written as texels), which the
// AIR translation has to cover. The results are what the language defines, so the same numbers come out on macOS.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>

#include "air_coverage_3_metallib.h"

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
	if (pso == nil) {
		printf("  pipeline %s: %s\n", [name UTF8String], [[error localizedDescription] UTF8String]);
	}
	return pso;
}

// Runs a kernel over `count` threads with the buffers bound from index 0 and the textures from index 0.
static void run(NSString* name, NSArray<id<MTLBuffer>>* buffers, NSArray<id<MTLTexture>>* textures, NSUInteger count) {
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
	[encoder dispatchThreads: MTLSizeMake(count, 1, 1) threadsPerThreadgroup: MTLSizeMake(count < 8 ? count : 8, 1, 1)];
	[encoder endEncoding];
	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];
	CHECK(commandBuffer.status == MTLCommandBufferStatusCompleted);
}

static id<MTLBuffer> buffer(NSUInteger length) {
	id<MTLBuffer> b = [device newBufferWithLength: length options: MTLResourceStorageModeShared];
	memset([b contents], 0, length);
	return b;
}

static id<MTLTexture> textureBuffer(id<MTLBuffer> b, MTLPixelFormat format, NSUInteger count, NSUInteger texelSize, MTLTextureUsage usage) {
	MTLTextureDescriptor* descriptor = [[MTLTextureDescriptor alloc] init];
	descriptor.textureType = MTLTextureTypeTextureBuffer;
	descriptor.pixelFormat = format;
	descriptor.width = count;
	descriptor.height = 1;
	descriptor.usage = usage;
	descriptor.storageMode = MTLStorageModeShared;
	id<MTLTexture> t = [b newTextureWithDescriptor: descriptor offset: 0 bytesPerRow: count * texelSize];
	CHECK(t != nil);
	if (t != nil) {
		CHECK(t.textureType == MTLTextureTypeTextureBuffer);
		CHECK(t.width == count);
	}
	return t;
}

enum { N = 16 };

static void testTextureBuffer(void) {
	// read: every element of an RGBA32Float texture buffer
	id<MTLBuffer> src = buffer(N * 16);
	float* f = [src contents];
	for (int i = 0; i < N * 4; i++) {
		f[i] = 0.5f * i + 1;
	}
	id<MTLTexture> t = textureBuffer(src, MTLPixelFormatRGBA32Float, N, 16, MTLTextureUsageShaderRead);
	id<MTLBuffer> out = buffer(N * 16);
	run(@"tb_read", @[out], @[t], N);
	CHECK(memcmp([out contents], f, N * 16) == 0);

	// the size
	id<MTLBuffer> sizes = buffer(N * 4);
	run(@"tb_size", @[sizes], @[t], N);
	BOOL ok = YES;
	for (int i = 0; i < N; i++) {
		ok = ok && ((uint32_t*)[sizes contents])[i] == N;
	}
	CHECK(ok);

	// write
	id<MTLBuffer> dst = buffer(N * 16);
	id<MTLTexture> w = textureBuffer(dst, MTLPixelFormatRGBA32Float, N, 16, MTLTextureUsageShaderWrite);
	run(@"tb_write", @[], @[w], N);
	f = [dst contents];
	ok = YES;
	for (int i = 0; i < N; i++) {
		ok = ok && f[i * 4] == i && f[i * 4 + 1] == i * 2 && f[i * 4 + 2] == i * 3 && f[i * 4 + 3] == 1;
	}
	CHECK(ok);

	// read_write of an unsigned format
	id<MTLBuffer> rw = buffer(N * 16);
	uint32_t* u = [rw contents];
	for (int i = 0; i < N * 4; i++) {
		u[i] = 100 * i;
	}
	id<MTLTexture> r = textureBuffer(rw, MTLPixelFormatRGBA32Uint, N, 16, MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite);
	run(@"tb_uint", @[], @[r], N);
	ok = YES;
	for (int i = 0; i < N; i++) {
		for (int c = 0; c < 4; c++) {
			ok = ok && u[i * 4 + c] == (uint32_t)(100 * (i * 4 + c) + c + 1);
		}
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
		dispatch_data_t data = dispatch_data_create(air_coverage_3_metallib, sizeof(air_coverage_3_metallib), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
		library = [device newLibraryWithData: data error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAIL\n");
			return 1;
		}
		testTextureBuffer();
		printf(failures ? "FAIL (%d)\n" : "ALL PASSED\n", failures);
	}
	return failures ? 1 : 0;
}
