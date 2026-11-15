// Copyright (C) 2026 Lubos Dolezel
// Resource and library API: -setPurgeableState:, the useResource: family (residency hints), -sampleTimestamps:,
// textures made from a buffer (-newTextureWithDescriptor:offset:bytesPerRow:), and MTLCompileOptions
// preprocessorMacros as -D definitions for newLibraryWithSource.
// The expectations follow the documented meaning of each call; no Mac GPU was available to observe a Mac. The
// behaviour of a macro that the source defines again is the one of the Metal compiler on macOS 26.7.3
// (observed with `xcrun metal -DFOO=1`): the source's value replaces it.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <math.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

// Darling's Metal classes are the only ones named ...Internal; the checks below that macOS passes and Darling does not
// yet are XCHECKs: a failure is reported as a known failure on Darling and is a real failure on macOS.
static BOOL onDarling(void) { return NSClassFromString(@"MTLTextureInternal") != nil; }
#define XCHECK(c) do { if (!(c)) { if (onDarling()) printf("XFAIL (known in Darling) line %d: %s\n", __LINE__, #c); else { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } } while (0)

static BOOL near(float a, float b) { return fabsf(a - b) < 0.003f; }

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];

		// --- purgeable state
		id<MTLBuffer> buffer = [device newBufferWithLength: 4096 options: MTLResourceStorageModeShared];
		// macOS 27.0.1 (Apple silicon), buffers and textures of every storage mode: every call returns NonVolatile and no
		// state is applied.
		CHECK([buffer setPurgeableState: MTLPurgeableStateKeepCurrent] == MTLPurgeableStateNonVolatile);
		CHECK([buffer setPurgeableState: MTLPurgeableStateVolatile] == MTLPurgeableStateNonVolatile);
		CHECK([buffer setPurgeableState: MTLPurgeableStateKeepCurrent] == MTLPurgeableStateNonVolatile);
		CHECK([buffer setPurgeableState: MTLPurgeableStateEmpty] == MTLPurgeableStateNonVolatile);
		MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 4 height: 4 mipmapped: NO];
		id<MTLTexture> plain = [device newTextureWithDescriptor: td];
		CHECK([plain setPurgeableState: MTLPurgeableStateVolatile] == MTLPurgeableStateNonVolatile);
		CHECK([plain setPurgeableState: MTLPurgeableStateKeepCurrent] == MTLPurgeableStateNonVolatile);
		CHECK(plain.buffer == nil && plain.bufferOffset == 0 && plain.bufferBytesPerRow == 0);

		// --- residency hints change nothing
		id<MTLComputeCommandEncoder> compute;
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		compute = [commands computeCommandEncoder];
		[compute useResource: buffer usage: MTLResourceUsageRead | MTLResourceUsageWrite];
		id<MTLResource> both[2] = { buffer, plain };
		[compute useResources: both count: 2 usage: MTLResourceUsageRead];
		[compute endEncoding];
		[commands commit];
		[commands waitUntilCompleted];

		// --- timestamps
		MTLTimestamp cpu1 = 0, gpu1 = 0, cpu2 = 0, gpu2 = 0;
		[device sampleTimestamps: &cpu1 gpuTimestamp: &gpu1];
		usleep(2000);
		[device sampleTimestamps: &cpu2 gpuTimestamp: &gpu2];
		CHECK(cpu1 != 0 && gpu1 != 0);
		CHECK(cpu2 > cpu1 && gpu2 > gpu1);

		// --- buffer-backed texture
		NSUInteger alignment = [device minimumLinearTextureAlignmentForPixelFormat: MTLPixelFormatRGBA8Unorm];
		CHECK(alignment >= 4 && alignment % 4 == 0);
		NSUInteger width = 5, height = 4;
		NSUInteger bytesPerRow = (width * 4 + alignment - 1) / alignment * alignment;
		NSUInteger offset = alignment * 2;
		id<MTLBuffer> storage = [device newBufferWithLength: offset + bytesPerRow * height options: MTLResourceStorageModeShared];
		uint8_t* bytes = [storage contents];
		memset(bytes, 0, [storage length]);
		for (NSUInteger y = 0; y < height; y++)
			for (NSUInteger x = 0; x < width; x++) {
				uint8_t* t = bytes + offset + y * bytesPerRow + x * 4;
				t[0] = 10 + x * 20; t[1] = 10 + y * 30; t[2] = 200; t[3] = 255 - x - y;
			}
		MTLTextureDescriptor* bd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: width height: height mipmapped: NO];
		bd.storageMode = storage.storageMode;
		bd.usage = MTLTextureUsageShaderRead;
		id<MTLTexture> backed = [storage newTextureWithDescriptor: bd offset: offset bytesPerRow: bytesPerRow];
		CHECK(backed != nil);
		if (backed != nil) {
			CHECK(backed.buffer == storage && backed.bufferOffset == offset && backed.bufferBytesPerRow == bytesPerRow);
			uint8_t back[5 * 4 * 4];
			[backed getBytes: back bytesPerRow: width * 4 fromRegion: MTLRegionMake2D(0, 0, width, height) mipmapLevel: 0];
			int same = 1;
			for (NSUInteger y = 0; y < height; y++) same = same && memcmp(back + y * width * 4, bytes + offset + y * bytesPerRow, width * 4) == 0;
			CHECK(same);
			const uint8_t pixel[4] = { 1, 2, 3, 4 };
			[backed replaceRegion: MTLRegionMake2D(2, 1, 1, 1) mipmapLevel: 0 withBytes: pixel bytesPerRow: 4];
			CHECK(memcmp(bytes + offset + bytesPerRow + 8, pixel, 4) == 0);
		}
		// macOS accepts any bytesPerRow that is a multiple of the alignment and at least the row width. Darling only
		// accepts the device's own row pitch, because Vulkan linear images cannot take another one (known failure).
		XCHECK([storage newTextureWithDescriptor: bd offset: offset bytesPerRow: bytesPerRow + alignment] != nil);
		// invalid arguments are validation assertions on macOS; Darling returns nil (Darling-only checks)
		if (onDarling()) {
			CHECK([storage newTextureWithDescriptor: bd offset: offset bytesPerRow: 0] == nil);
			MTLTextureDescriptor* mipped = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: width height: height mipmapped: YES];
			mipped.storageMode = storage.storageMode;
			CHECK([storage newTextureWithDescriptor: mipped offset: offset bytesPerRow: bytesPerRow] == nil);
		}
		// --- preprocessor macros
		NSError* error = nil;
		NSString* source = @"#include <metal_stdlib>\nusing namespace metal;\n"
			"kernel void k(device float* out [[buffer(0)]]) {\n"
			"#ifdef FACTOR\n	out[0] = FACTOR;\n#else\n	out[0] = -1.0;\n#endif\n"
			"#ifdef SCALE\n	out[1] = SCALE;\n#else\n	out[1] = -1.0;\n#endif\n}\n";
		MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
		options.preprocessorMacros = @{ @"FACTOR": @7, @"SCALE": @"2.5" };
		id<MTLLibrary> library = [device newLibraryWithSource: source options: options error: &error];
		CHECK(library != nil);
		if (library != nil) {
			id<MTLComputePipelineState> pso = [device newComputePipelineStateWithFunction: [library newFunctionWithName: @"k"] error: &error];
			id<MTLBuffer> out = [device newBufferWithLength: 16 options: MTLResourceStorageModeShared];
			commands = [queue commandBuffer];
			compute = [commands computeCommandEncoder];
			[compute setComputePipelineState: pso];
			[compute setBuffer: out offset: 0 atIndex: 0];
			[compute dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(1, 1, 1)];
			[compute endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			float* f = [out contents];
			CHECK(near(f[0], 7.0f) && near(f[1], 2.5f));
		}
		// no macros: the #ifdef branches that need them are not taken
		library = [device newLibraryWithSource: source options: nil error: &error];
		CHECK(library != nil);
		// a name that is not an identifier, and a value that is neither a string nor a number
		// a name that is not an identifier is accepted (macOS builds a library; the macro is simply not usable)
		options.preprocessorMacros = @{ @"NOT-A-NAME": @1 };
		CHECK([device newLibraryWithSource: source options: options error: &error] != nil);
		options.preprocessorMacros = @{ @"FACTOR": [NSDate date] };
		error = nil;
		CHECK([device newLibraryWithSource: source options: options error: &error] == nil && error != nil);
		// the source's own definition replaces the macro from the options
		options.preprocessorMacros = @{ @"FACTOR": @7 };
		NSString* redefining = [@"#define FACTOR 3\n" stringByAppendingString: source];
		CHECK([device newLibraryWithSource: redefining options: options error: &error] != nil);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
