// Copyright (C) 2026 Lubos Dolezel
// MTLDevice capability queries: supports32BitMSAA, maxArgumentBufferSamplerCount, the sparse tile sizes, the
// concurrent compilation properties, vertex amplification and the features of Apple6 and later GPUs that the device
// does not claim. The device reports the Mac and Common GPU families and argument buffers tier 1, so the values are
// the ones of Apple's Metal feature set tables for those: 16 samplers per stage from an argument buffer, no dynamic
// libraries, function pointers, ray tracing, vertex amplification or placement sparse. The sparse tile of a page size
// holds one page: width * height * depth * bytes per texel * samples == page bytes.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdlib.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static void checkTile(id<MTLDevice> d, MTLTextureType type, MTLPixelFormat format, NSUInteger bytes, NSUInteger samples, MTLSparsePageSize page, NSUInteger pageBytes) {
    MTLSize s = [d sparseTileSizeWithTextureType:type pixelFormat:format sampleCount:samples sparsePageSize:page];
    CHECK(s.width * s.height * s.depth * bytes * samples == pageBytes);
}

int main(void) {
    @autoreleasepool {
        id<MTLDevice> d = MTLCreateSystemDefaultDevice();
        if (!d) { printf("SKIP no Metal device\n"); return 77; }

        CHECK(d.argumentBuffersSupport == MTLArgumentBuffersTier1);
        CHECK(d.maxArgumentBufferSamplerCount == 16);
        CHECK(d.maximumConcurrentCompilationTaskCount >= 1);
        d.shouldMaximizeConcurrentCompilation = YES;
        CHECK(d.shouldMaximizeConcurrentCompilation);
        d.shouldMaximizeConcurrentCompilation = NO;
        CHECK(!d.shouldMaximizeConcurrentCompilation);

        // an 8-bit unsigned normalized and a 32-bit float color format multisample on every Vulkan device
        printf("supports32BitMSAA %d\n", (int)d.supports32BitMSAA);

        CHECK([d sparseTileSizeInBytesForSparsePageSize:MTLSparsePageSize16] == 16 * 1024);
        CHECK([d sparseTileSizeInBytesForSparsePageSize:MTLSparsePageSize64] == 64 * 1024);
        CHECK([d sparseTileSizeInBytesForSparsePageSize:MTLSparsePageSize256] == 256 * 1024);
        checkTile(d, MTLTextureType2D, MTLPixelFormatRGBA8Unorm, 4, 1, MTLSparsePageSize16, 16 * 1024);
        checkTile(d, MTLTextureType2D, MTLPixelFormatRGBA8Unorm, 4, 1, MTLSparsePageSize64, 64 * 1024);
        checkTile(d, MTLTextureType2D, MTLPixelFormatR8Unorm, 1, 1, MTLSparsePageSize64, 64 * 1024);
        checkTile(d, MTLTextureType2D, MTLPixelFormatRGBA32Float, 16, 1, MTLSparsePageSize256, 256 * 1024);
        checkTile(d, MTLTextureType3D, MTLPixelFormatRGBA8Unorm, 4, 1, MTLSparsePageSize64, 64 * 1024);
        MTLSize none = [d sparseTileSizeWithTextureType:MTLTextureTypeTextureBuffer pixelFormat:MTLPixelFormatRGBA8Unorm sampleCount:1];
        CHECK(none.width == 0 && none.height == 0 && none.depth == 0);
        none = [d sparseTileSizeWithTextureType:MTLTextureType2D pixelFormat:MTLPixelFormatInvalid sampleCount:1];
        CHECK(none.width == 0);

        CHECK([d supportsVertexAmplificationCount:1]);
        CHECK(![d supportsVertexAmplificationCount:2]);
        CHECK(!d.supportsDynamicLibraries);
        CHECK(!d.supportsRenderDynamicLibraries);
        CHECK(!d.supportsFunctionPointers);
        CHECK(!d.supportsFunctionPointersFromRender);
        CHECK(!d.supportsPrimitiveMotionBlur);
        CHECK(!d.supportsQueryTextureLOD);
        CHECK(!d.supportsRaytracing);
        CHECK(!d.supportsRaytracingFromRender);
        CHECK(!d.supportsPlacementSparse);

        printf(failures ? "FAIL\n" : "PASS\n");
        return failures != 0;
    }
}
