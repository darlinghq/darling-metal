// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// requiredThreadsPerThreadgroup of MTLComputePipelineDescriptor and MTLComputePipelineState: zero in every
// dimension (no required size) by default and after -reset, kept by -copy, and reported by a pipeline made
// with it. A pipeline with a required size allows that many threads and runs a dispatch of that size.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static BOOL sizeIs(MTLSize size, NSUInteger width, NSUInteger height, NSUInteger depth) {
	return size.width == width && size.height == height && size.depth == depth;
}

int main(void) {
	@autoreleasepool {
		MTLComputePipelineDescriptor* descriptor = [[MTLComputePipelineDescriptor new] autorelease];
		CHECK(sizeIs(descriptor.requiredThreadsPerThreadgroup, 0, 0, 0));
		descriptor.requiredThreadsPerThreadgroup = MTLSizeMake(8, 4, 1);
		CHECK(sizeIs(descriptor.requiredThreadsPerThreadgroup, 8, 4, 1));
		MTLComputePipelineDescriptor* copy = [[descriptor copy] autorelease];
		CHECK(sizeIs(copy.requiredThreadsPerThreadgroup, 8, 4, 1));
		[copy reset];
		CHECK(sizeIs(copy.requiredThreadsPerThreadgroup, 0, 0, 0));
		CHECK(sizeIs(descriptor.requiredThreadsPerThreadgroup, 8, 4, 1));

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		NSError* error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"kernel void mark(device uint* out [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {\n"
			"	out[gid.y * 16 + gid.x] = gid.y * 16 + gid.x + 1;\n}\n" options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("library: %s\n", error.localizedDescription.UTF8String);
			printf("FAILED: %d\n", failures);
			return 1;
		}
		id<MTLFunction> function = [library newFunctionWithName: @"mark"];

		id<MTLComputePipelineState> plain = [device newComputePipelineStateWithFunction: function error: &error];
		CHECK(plain != nil);
		CHECK(sizeIs(plain.requiredThreadsPerThreadgroup, 0, 0, 0));

		descriptor.computeFunction = function;
		id<MTLComputePipelineState> pso = [device newComputePipelineStateWithDescriptor: descriptor options: MTLPipelineOptionNone reflection: nil error: &error];
		CHECK(pso != nil);
		if (pso == nil) {
			printf("pipeline: %s\n", error.localizedDescription.UTF8String);
			printf("FAILED: %d\n", failures);
			return 1;
		}
		CHECK(sizeIs(pso.requiredThreadsPerThreadgroup, 8, 4, 1));
		// a dispatch has to use the required size, so that is the most threads one can have
		CHECK(pso.maxTotalThreadsPerThreadgroup == 32);

		// two threadgroups of the required size side by side: a grid of 16x4
		enum { kThreads = 64 };
		id<MTLBuffer> out = [device newBufferWithLength: kThreads * 4 options: MTLResourceStorageModeShared];
		uint32_t* words = [out contents];
		for (int i = 0; i < kThreads; i++) words[i] = 0xDEADBEEF;
		id<MTLCommandQueue> queue = [device newCommandQueue];
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
		[encoder setComputePipelineState: pso];
		[encoder setBuffer: out offset: 0 atIndex: 0];
		[encoder dispatchThreadgroups: MTLSizeMake(2, 1, 1) threadsPerThreadgroup: MTLSizeMake(8, 4, 1)];
		[encoder endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		int correct = 0;
		for (int i = 0; i < kThreads; i++) correct += words[i] == (uint32_t)i + 1;
		CHECK(correct == kThreads);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
