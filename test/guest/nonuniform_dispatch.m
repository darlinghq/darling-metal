// Copyright (C) 2026 Lubos Dolezel
// -[MTLComputeCommandEncoder dispatchThreads:threadsPerThreadgroup:] over a grid that is not a multiple of the
// threadgroup size runs exactly the threads of the grid: no thread outside it, and each thread of it once.
// -setThreadgroupMemoryLength:atIndex: is accepted. The expectations follow the documented meaning of
// dispatchThreads: (non-uniform threadgroups); no Mac GPU was available to observe a Mac.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

// Darling's Metal classes are the only ones named ...Internal. An XCHECK is a check macOS passes and Darling does not yet:
// a failure is a known failure on Darling and a real failure on macOS.
static BOOL onDarling(void) { return NSClassFromString(@"MTLTextureInternal") != nil; }
#define XCHECK(c) do { if (!(c)) { if (onDarling()) printf("XFAIL (known in Darling) line %d: %s\n", __LINE__, #c); else { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } } while (0)

enum { kSlots = 64 };

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
			"kernel void mark1D(device uint* out [[buffer(0)]], uint gid [[thread_position_in_grid]]) { out[gid] = gid + 1; }\n"
			"kernel void mark2D(device uint* out [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) { out[gid.y * 5 + gid.x] = 1 + gid.y * 10 + gid.x; }\n"
			"kernel void markBarrier(device uint* out [[buffer(0)]], uint gid [[thread_position_in_grid]]) {\n"
			"	threadgroup_barrier(mem_flags::mem_device);\n	out[gid] = gid + 1;\n}\n" options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		id<MTLBuffer> out = [device newBufferWithLength: kSlots * 4 options: MTLResourceStorageModeShared];
		uint32_t* words = [out contents];

		// runs `name` over `grid` in threadgroups of `group`; returns how many slots were written, or -1 when one has a wrong value
		int (^run)(NSString*, MTLSize, MTLSize, uint32_t (^)(int)) = ^int(NSString* name, MTLSize grid, MTLSize group, uint32_t (^expected)(int)) {
			for (int i = 0; i < kSlots; i++) words[i] = 0xDEADBEEF;
			id<MTLComputePipelineState> pso = [device newComputePipelineStateWithFunction: [library newFunctionWithName: name] error: nil];
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
			[encoder setComputePipelineState: pso];
			[encoder setBuffer: out offset: 0 atIndex: 0];
			[encoder setThreadgroupMemoryLength: 16 atIndex: 0];
			@try {
				[encoder dispatchThreads: grid threadsPerThreadgroup: group];
			} @catch (NSException* exception) {
				// Darling raises for a kernel it cannot mask (known failure); the encoder still has to be ended
			}
			[encoder endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			int written = 0;
			for (int i = 0; i < kSlots; i++) {
				if (words[i] == 0xDEADBEEF) continue;
				if (words[i] != expected(i)) return -1;
				written++;
			}
			return written;
		};

		CHECK(run(@"mark1D", MTLSizeMake(10, 1, 1), MTLSizeMake(4, 1, 1), ^uint32_t(int i) { return i + 1; }) == 10);
		CHECK(run(@"mark1D", MTLSizeMake(1, 1, 1), MTLSizeMake(4, 1, 1), ^uint32_t(int i) { return i + 1; }) == 1);
		CHECK(run(@"mark1D", MTLSizeMake(12, 1, 1), MTLSizeMake(4, 1, 1), ^uint32_t(int i) { return i + 1; }) == 12);
		CHECK(run(@"mark2D", MTLSizeMake(5, 3, 1), MTLSizeMake(2, 2, 1), ^uint32_t(int i) { return 1 + (i / 5) * 10 + i % 5; }) == 15);
		// A kernel with a barrier over a grid that is cut: macOS runs exactly the grid. Darling cannot skip threads in a
		// kernel with a barrier (a thread that returns before it leaves the others waiting) and refuses (known failure).
		XCHECK(run(@"markBarrier", MTLSizeMake(10, 1, 1), MTLSizeMake(4, 1, 1), ^uint32_t(int i) { return i + 1; }) == 10);
		// a kernel with a barrier over whole threadgroups
		CHECK(run(@"markBarrier", MTLSizeMake(8, 1, 1), MTLSizeMake(4, 1, 1), ^uint32_t(int i) { return i + 1; }) == 8);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
