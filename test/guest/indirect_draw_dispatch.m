// Copyright (C) 2026 Lubos Dolezel
// Indirect dispatch and draws (MTLComputeCommandEncoder dispatchThreadgroupsWithIndirectBuffer:,
// MTLRenderCommandEncoder drawPrimitives:indirectBuffer: and drawIndexedPrimitives:...indirectBuffer:), with the
// argument structures from the headers. The expected results follow the documented meaning of the arguments:
// the arguments are read when the GPU runs the command, whether the CPU or an earlier dispatch wrote them.
// Arguments the documentation rules out (offset not a multiple of 4) are not exercised here; indium's own
// test covers what the backend does with them.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static const char* kSource =
	"#include <metal_stdlib>\n"
	"using namespace metal;\n"
	"kernel void fillArguments(device uint* args [[buffer(0)]]) { args[0] = 4; args[1] = 1; args[2] = 1; }\n"
	"kernel void mark(device uint* out [[buffer(0)]], uint gid [[thread_position_in_grid]]) { out[gid] = gid + 1; }\n";

static const char* kGraphics =
	"#include <metal_stdlib>\n"
	"using namespace metal;\n"
	"struct Vertex { float4 position [[position]]; };\n"
	"vertex Vertex triangleVertex(uint vid [[vertex_id]]) {\n"
	"	Vertex o;\n"
	"	float x = (vid == 1) ? 3.0 : -1.0;\n"
	"	float y = (vid == 2) ? 3.0 : -1.0;\n"
	"	o.position = (vid < 3) ? float4(x, y, 0.0, 1.0) : float4(0.0, 0.0, 0.0, 1.0);\n"
	"	return o;\n"
	"}\n"
	"fragment float4 redFragment() { return float4(1.0, 0.0, 0.0, 1.0); }\n";

enum { kSize = 8, kSlots = 32 };

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
		NSError* error = nil;

		// --- dispatch
		id<MTLLibrary> compute = [device newLibraryWithSource: [NSString stringWithUTF8String: kSource] options: nil error: &error];
		CHECK(compute != nil);
		id<MTLComputePipelineState> fill = [device newComputePipelineStateWithFunction: [compute newFunctionWithName: @"fillArguments"] error: &error];
		id<MTLComputePipelineState> mark = [device newComputePipelineStateWithFunction: [compute newFunctionWithName: @"mark"] error: &error];
		CHECK(fill != nil && mark != nil);
		if (fill == nil || mark == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		id<MTLBuffer> out = [device newBufferWithLength: kSlots * 4 options: MTLResourceStorageModeShared];
		id<MTLBuffer> args = [device newBufferWithLength: 64 options: MTLResourceStorageModeShared];
		uint32_t* outWords = [out contents];

		memset([args contents], 0, 64);
		MTLDispatchThreadgroupsIndirectArguments* hostArgs = (MTLDispatchThreadgroupsIndirectArguments*)((char*)[args contents] + 16);
		hostArgs->threadgroupsPerGrid[0] = 3; hostArgs->threadgroupsPerGrid[1] = 1; hostArgs->threadgroupsPerGrid[2] = 1;
		for (int i = 0; i < kSlots; i++) outWords[i] = 0xDEADBEEF;
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
		[encoder setComputePipelineState: mark];
		[encoder setBuffer: out offset: 0 atIndex: 0];
		[encoder dispatchThreadgroupsWithIndirectBuffer: args indirectBufferOffset: 16 threadsPerThreadgroup: MTLSizeMake(2, 1, 1)];
		[encoder endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		int marked = 0;
		for (int i = 0; i < kSlots; i++) if (outWords[i] == (uint32_t)(i + 1)) marked++; else CHECK(outWords[i] == 0xDEADBEEF);
		CHECK(marked == 6);

		// arguments written by an earlier dispatch of the same encoder
		memset([args contents], 0, 64);
		for (int i = 0; i < kSlots; i++) outWords[i] = 0xDEADBEEF;
		commands = [queue commandBuffer];
		encoder = [commands computeCommandEncoder];
		[encoder setComputePipelineState: fill];
		[encoder setBuffer: args offset: 0 atIndex: 0];
		[encoder dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(1, 1, 1)];
		[encoder setComputePipelineState: mark];
		[encoder setBuffer: out offset: 0 atIndex: 0];
		[encoder dispatchThreadgroupsWithIndirectBuffer: args indirectBufferOffset: 0 threadsPerThreadgroup: MTLSizeMake(2, 1, 1)];
		[encoder endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		marked = 0;
		for (int i = 0; i < kSlots; i++) if (outWords[i] == (uint32_t)(i + 1)) marked++;
		CHECK(marked == 8);

		// --- draws
		id<MTLLibrary> graphics = [device newLibraryWithSource: [NSString stringWithUTF8String: kGraphics] options: nil error: &error];
		CHECK(graphics != nil);
		MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
		pd.vertexFunction = [graphics newFunctionWithName: @"triangleVertex"];
		pd.fragmentFunction = [graphics newFunctionWithName: @"redFragment"];
		pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
		id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor: pd error: &error];
		CHECK(pso != nil);
		if (pso == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
		td.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
		td.storageMode = MTLStorageModeManaged;
		id<MTLTexture> target = [device newTextureWithDescriptor: td];

		const uint16_t indices[6] = { 7, 7, 7, 0, 1, 2 };
		id<MTLBuffer> indexBuffer = [device newBufferWithBytes: indices length: sizeof(indices) options: MTLResourceStorageModeShared];
		id<MTLBuffer> drawArgs = [device newBufferWithLength: 64 options: MTLResourceStorageModeShared];

		// run one draw into a cleared target and count the red pixels (-1 when another color shows up)
		#define DRAW(body) ({ \
			MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor]; \
			rp.colorAttachments[0].texture = target; \
			rp.colorAttachments[0].loadAction = MTLLoadActionClear; \
			rp.colorAttachments[0].storeAction = MTLStoreActionStore; \
			rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0); \
			id<MTLCommandBuffer> cb = [queue commandBuffer]; \
			id<MTLRenderCommandEncoder> re = [cb renderCommandEncoderWithDescriptor: rp]; \
			[re setRenderPipelineState: pso]; \
			body \
			[re endEncoding]; \
			[cb commit]; \
			[cb waitUntilCompleted]; \
			uint32_t pixels[kSize * kSize]; \
			[target getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0]; \
			int red = 0; \
			for (int i = 0; i < kSize * kSize; i++) { if (pixels[i] == 0xFF0000FFu) red++; else if (pixels[i] != 0) { red = -1; break; } } \
			red; })

		MTLDrawPrimitivesIndirectArguments* d = [drawArgs contents];
		memset(d, 0, 64);
		d->vertexCount = 3; d->instanceCount = 1;
		CHECK(DRAW([re drawPrimitives: MTLPrimitiveTypeTriangle indirectBuffer: drawArgs indirectBufferOffset: 0];) == kSize * kSize);
		d->instanceCount = 0;
		CHECK(DRAW([re drawPrimitives: MTLPrimitiveTypeTriangle indirectBuffer: drawArgs indirectBufferOffset: 0];) == 0);
		d->instanceCount = 1; d->vertexStart = 3;
		CHECK(DRAW([re drawPrimitives: MTLPrimitiveTypeTriangle indirectBuffer: drawArgs indirectBufferOffset: 0];) == 0);

		MTLDrawIndexedPrimitivesIndirectArguments* x = [drawArgs contents];
		memset(x, 0, 64);
		x->indexCount = 3; x->instanceCount = 1; x->indexStart = 3;
		CHECK(DRAW([re drawIndexedPrimitives: MTLPrimitiveTypeTriangle indexType: MTLIndexTypeUInt16 indexBuffer: indexBuffer indexBufferOffset: 0 indirectBuffer: drawArgs indirectBufferOffset: 0];) == kSize * kSize);
		x->indexStart = 0;
		CHECK(DRAW([re drawIndexedPrimitives: MTLPrimitiveTypeTriangle indexType: MTLIndexTypeUInt16 indexBuffer: indexBuffer indexBufferOffset: 0 indirectBuffer: drawArgs indirectBufferOffset: 0];) == 0);
		CHECK(DRAW([re drawIndexedPrimitives: MTLPrimitiveTypeTriangle indexType: MTLIndexTypeUInt16 indexBuffer: indexBuffer indexBufferOffset: 6 indirectBuffer: drawArgs indirectBufferOffset: 0];) == kSize * kSize);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
