// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// A kernel compiled from source with a threadgroup memory argument ([[threadgroup(n)]]) gets as much memory as
// -[MTLComputeCommandEncoder setThreadgroupMemoryLength:atIndex:] gives it: a kernel that reverses its threadgroup
// through the argument does so for 64 and, in a later dispatch of the same encoder, 16 threads, and a kernel with
// two such arguments of different element sizes sizes each by its own index.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static BOOL reversed(id<MTLBuffer> buffer, int count) {
	const float* values = [buffer contents];
	for (int i = 0; i < count; i++) {
		if (values[i] != (float)(count - 1 - i)) return NO;
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
		id<MTLCommandQueue> queue = [device newCommandQueue];
		NSError* error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"kernel void reverse(device float *x [[buffer(0)]], threadgroup float *tmp [[threadgroup(0)]],\n"
			"                    uint i [[thread_position_in_threadgroup]], uint n [[threads_per_threadgroup]]) {\n"
			"	tmp[i] = x[i];\n"
			"	threadgroup_barrier(mem_flags::mem_threadgroup);\n"
			"	x[i] = tmp[n - 1 - i];\n"
			"}\n"
			"kernel void pair(device uint *out [[buffer(0)]], threadgroup uint4 *wide [[threadgroup(1)]], threadgroup uint *narrow [[threadgroup(0)]],\n"
			"                 uint i [[thread_position_in_threadgroup]], uint n [[threads_per_threadgroup]]) {\n"
			"	wide[n - 1 - i] = uint4(i, i, i, i * 10);\n"
			"	narrow[i] = i;\n"
			"	threadgroup_barrier(mem_flags::mem_threadgroup);\n"
			"	out[i] = wide[i].w + narrow[n - 1 - i];\n"
			"}\n" options: nil error: &error];
		if (library == nil) {
			printf("compile error: %s\n", [[error description] UTF8String]);
			printf("FAILED: 1\n");
			return 1;
		}
		id<MTLComputePipelineState> reverse = [device newComputePipelineStateWithFunction: [library newFunctionWithName: @"reverse"] error: &error];
		id<MTLComputePipelineState> pair = [device newComputePipelineStateWithFunction: [library newFunctionWithName: @"pair"] error: &error];
		CHECK(reverse != nil && pair != nil);
		if (reverse == nil || pair == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		id<MTLBuffer> (^floats)(int) = ^id<MTLBuffer>(int count) {
			id<MTLBuffer> buffer = [device newBufferWithLength: count * sizeof(float) options: MTLResourceStorageModeShared];
			float* values = [buffer contents];
			for (int i = 0; i < count; i++) values[i] = (float)i;
			return buffer;
		};

		// the length is encoder state, so the second dispatch gets the second length
		id<MTLBuffer> first = floats(64);
		id<MTLBuffer> second = floats(16);
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
		[encoder setComputePipelineState: reverse];
		[encoder setThreadgroupMemoryLength: 64 * sizeof(float) atIndex: 0];
		[encoder setBuffer: first offset: 0 atIndex: 0];
		[encoder dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(64, 1, 1)];
		[encoder setThreadgroupMemoryLength: 16 * sizeof(float) atIndex: 0];
		[encoder setBuffer: second offset: 0 atIndex: 0];
		[encoder dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(16, 1, 1)];
		[encoder endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		CHECK(reversed(first, 64));
		CHECK(reversed(second, 16));

		enum { n = 32 };
		id<MTLBuffer> out = [device newBufferWithLength: n * sizeof(uint32_t) options: MTLResourceStorageModeShared];
		commands = [queue commandBuffer];
		encoder = [commands computeCommandEncoder];
		[encoder setComputePipelineState: pair];
		[encoder setBuffer: out offset: 0 atIndex: 0];
		[encoder setThreadgroupMemoryLength: n * sizeof(uint32_t) atIndex: 0];
		[encoder setThreadgroupMemoryLength: n * 4 * sizeof(uint32_t) atIndex: 1];
		[encoder dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(n, 1, 1)];
		[encoder endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		const uint32_t* words = [out contents];
		BOOL ok = YES;
		for (int i = 0; i < n; i++) {
			ok = ok && words[i] == 11u * (n - 1 - i);
		}
		CHECK(ok);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
