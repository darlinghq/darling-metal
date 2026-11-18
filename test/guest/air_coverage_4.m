// Copyright (C) 2026 Lubos Dolezel
// Compute kernels from a precompiled library (air_coverage_4_metallib.h, source air_coverage_4.metal) that call
// functions the Metal compiler did not inline ([[noinline]] helpers taking scalars, vectors, device pointers, a
// structure by value and a thread reference). The results are what the language defines, so the same numbers
// come out on macOS. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>

#include "air_coverage_4_metallib.h"

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

enum { N = 16 };

static void testCalls(void) {
	id<MTLBuffer> ints = buffer(256 * 4);
	id<MTLBuffer> vecs = buffer(N * 16);
	id<MTLBuffer> floats = buffer(N * 4);
	int* p = [ints contents];
	for (int k = 0; k < 4; k++) {
		p[64 + k] = k + 1;
	}
	p[128] = 100;
	run(@"call_helpers", @[ints, vecs, floats], @[], N);
	p = [ints contents];
	const float* v = [vecs contents];
	const float* fl = [floats contents];
	BOOL ok = YES, okVec = YES, okPair = YES;
	for (int i = 0; i < N; i++) {
		int nested = (i + i * 2 + 3) + 1;
		ok = ok && p[i * 4] == i + 4 + 9 && p[i * 4 + 1] == 10 && p[i * 4 + 2] == nested && p[i * 4 + 3] == i + 10;
		okVec = okVec && v[i * 4] == i * 2 + 1 && v[i * 4 + 1] == 4 && v[i * 4 + 2] == 7 && v[i * 4 + 3] == 10;
		okPair = okPair && fl[i] == (float)((i + 1) * 3) + 3.0f;
	}
	CHECK(ok);
	CHECK(okVec);
	CHECK(okPair);
	CHECK(p[128] == 105 && p[129] == 210);
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
		dispatch_data_t data = dispatch_data_create(air_coverage_4_metallib, sizeof(air_coverage_4_metallib), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
		library = [device newLibraryWithData: data error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAIL\n");
			return 1;
		}
		testCalls();
		printf(failures ? "FAIL (%d)\n" : "ALL PASSED\n", failures);
	}
	return failures ? 1 : 0;
}
