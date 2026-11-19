// Copyright (C) 2026 Lubos Dolezel
// sample() and gather() with a texel offset that the compiled library does not pass as a constant
// (sample_offset_metallib.h, source sample_offset.metal): an offset from a buffer, from the counter of a loop,
// from a loop whose length comes from a buffer, and one that differs between neighbouring fragments, in fragment
// functions (implicit level of detail) and in kernels. The Metal Shading Language specification defines the offset
// as a whole number of texels added to the texel coordinates before the address mode applies, so with nearest
// filtering at texel centres every result is a sum of texels of level 0; the other levels hold a value that
// would show up if the offset changed the level of detail. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "sample_offset_metallib.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { N = 8 };

struct Offsets {
	int32_t offset[2];
	int32_t radius;
	int32_t padding;
};

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;
static id<MTLLibrary> library;
static id<MTLTexture> source;

static float texel(int x, int y, int channel) {
	x = x < 0 ? 0 : (x > N - 1 ? N - 1 : x);
	y = y < 0 ? 0 : (y > N - 1 ? N - 1 : y);
	return 100 * channel + 10 * y + x;
}

static id<MTLBuffer> offsetsBuffer(int x, int y, int radius) {
	struct Offsets offsets = { { x, y }, radius, 0 };
	return [device newBufferWithBytes: &offsets length: sizeof(offsets) options: MTLResourceStorageModeShared];
}

// Draws the fragment function over an N x N target and compares each pixel with expected(x, y, channel).
static void checkFragment(NSString* name, id<MTLBuffer> offsets, float (^expected)(int x, int y, int channel)) {
	MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor alloc] init];
	descriptor.vertexFunction = [library newFunctionWithName: @"cover"];
	descriptor.fragmentFunction = [library newFunctionWithName: name];
	descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
	NSError* error = nil;
	id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor: descriptor error: &error];
	[descriptor release];
	if (pipeline == nil) {
		printf("FAIL %s: no pipeline: %s\n", name.UTF8String, error.localizedDescription.UTF8String);
		failures++;
		return;
	}

	MTLTextureDescriptor* targetDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA32Float width: N height: N mipmapped: NO];
	targetDescriptor.usage = MTLTextureUsageRenderTarget;
	targetDescriptor.storageMode = MTLStorageModeManaged;
	id<MTLTexture> target = [device newTextureWithDescriptor: targetDescriptor];

	MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = target;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	pass.colorAttachments[0].clearColor = MTLClearColorMake(-1, -1, -1, -1);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLRenderCommandEncoder> encoder = [commands renderCommandEncoderWithDescriptor: pass];
	[encoder setRenderPipelineState: pipeline];
	[encoder setFragmentTexture: source atIndex: 0];
	if (offsets != nil) {
		[encoder setFragmentBuffer: offsets offset: 0 atIndex: 0];
	}
	[encoder drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	CHECK(commands.status == MTLCommandBufferStatusCompleted);

	static float pixels[N * N * 4];
	[target getBytes: pixels bytesPerRow: N * 16 fromRegion: MTLRegionMake2D(0, 0, N, N) mipmapLevel: 0];
	int wrong = 0;
	for (int y = 0; y < N; y++) {
		for (int x = 0; x < N; x++) {
			for (int c = 0; c < 4; c++) {
				float want = expected(x, y, c), got = pixels[(y * N + x) * 4 + c];
				if (got != want && wrong++ < 4) {
					printf("%s: pixel (%d, %d) channel %d is %g, expected %g\n", name.UTF8String, x, y, c, got, want);
				}
			}
		}
	}
	if (wrong) {
		printf("FAIL %s: %d wrong values\n", name.UTF8String, wrong);
		failures++;
	}
	[target release];
	[pipeline release];
}

// Runs the kernel over N x N threads and compares out[y * N + x] with expected(x, y, component).
static void checkKernel(NSString* name, id<MTLBuffer> offsets, float (^expected)(int x, int y, int component)) {
	id<MTLFunction> function = [library newFunctionWithName: name];
	NSError* error = nil;
	id<MTLComputePipelineState> pipeline = function ? [device newComputePipelineStateWithFunction: function error: &error] : nil;
	[function release];
	if (pipeline == nil) {
		printf("FAIL %s: no pipeline: %s\n", name.UTF8String, error.localizedDescription.UTF8String);
		failures++;
		return;
	}
	id<MTLBuffer> out = [device newBufferWithLength: N * N * 16 options: MTLResourceStorageModeShared];
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
	[encoder setComputePipelineState: pipeline];
	[encoder setTexture: source atIndex: 0];
	[encoder setBuffer: out offset: 0 atIndex: 0];
	[encoder setBuffer: offsets offset: 0 atIndex: 1];
	[encoder dispatchThreadgroups: MTLSizeMake(N, N, 1) threadsPerThreadgroup: MTLSizeMake(1, 1, 1)];
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	CHECK(commands.status == MTLCommandBufferStatusCompleted);

	const float* got = [out contents];
	int wrong = 0;
	for (int y = 0; y < N; y++) {
		for (int x = 0; x < N; x++) {
			for (int c = 0; c < 4; c++) {
				float want = expected(x, y, c), value = got[(y * N + x) * 4 + c];
				if (value != want && wrong++ < 4) {
					printf("%s: (%d, %d) component %d is %g, expected %g\n", name.UTF8String, x, y, c, value, want);
				}
			}
		}
	}
	if (wrong) {
		printf("FAIL %s: %d wrong values\n", name.UTF8String, wrong);
		failures++;
	}
	[out release];
	[pipeline release];
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
		dispatch_data_t data = dispatch_data_create(sample_offset_metallib, sample_offset_metallib_len, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
		library = [device newLibraryWithData: data error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		// level 0 holds texel(x, y, channel), the smaller levels a value no expectation contains
		MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA32Float width: N height: N mipmapped: YES];
		descriptor.storageMode = MTLStorageModeManaged;
		source = [device newTextureWithDescriptor: descriptor];
		static float texels[N * N * 4];
		for (int y = 0; y < N; y++) {
			for (int x = 0; x < N; x++) {
				for (int c = 0; c < 4; c++) {
					texels[(y * N + x) * 4 + c] = texel(x, y, c);
				}
			}
		}
		[source replaceRegion: MTLRegionMake2D(0, 0, N, N) mipmapLevel: 0 withBytes: texels bytesPerRow: N * 16];
		for (NSUInteger level = 1, size = N / 2; level < source.mipmapLevelCount; level++, size /= 2) {
			for (NSUInteger i = 0; i < size * size * 4; i++) {
				texels[i] = -1000;
			}
			[source replaceRegion: MTLRegionMake2D(0, 0, size, size) mipmapLevel: level withBytes: texels bytesPerRow: size * 16];
		}

		checkFragment(@"sample_buffer_offset", offsetsBuffer(2, -1, 0), ^float(int x, int y, int c) {
			return texel(x + 2, y - 1, c);
		});
		checkFragment(@"sample_loop_offset", nil, ^float(int x, int y, int c) {
			float sum = 0;
			for (int i = -2; i <= 2; i++) {
				sum += texel(x + i, y + 1, c);
			}
			return sum;
		});
		checkFragment(@"sample_radius_offset", offsetsBuffer(0, 0, 2), ^float(int x, int y, int c) {
			float sum = 0;
			for (int i = -2; i <= 2; i++) {
				sum += texel(x, y + i, c);
			}
			return sum;
		});
		checkFragment(@"sample_varying_offset", nil, ^float(int x, int y, int c) {
			return texel(x + x % 3 - 1, y + y % 2, c);
		});
		checkKernel(@"sample_kernel_offset", offsetsBuffer(-3, 2, 0), ^float(int x, int y, int c) {
			return texel(x - 3, y + 2, c);
		});
		// the footprint is (i0, j1), (i1, j1), (i1, j0), (i0, j0), moved by the offset and clamped to the texture
		checkKernel(@"gather_kernel_offset", offsetsBuffer(1, 1, 0), ^float(int x, int y, int c) {
			int i = x + 1 + (c == 1 || c == 2), j = y + 1 + (c == 0 || c == 1);
			return texel(i, j, 0);
		});
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
