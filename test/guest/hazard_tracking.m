// Copyright (C) 2026 Lubos Dolezel
// Ordering of the encoders of one command buffer for tracked resources, and for untracked ones with the fences and
// barriers the application provides. Metal runs the encoders of a command buffer in an order that gives each one
// the results of the encoders before it for the buffers and textures it tracks (read after write, write after read
// and write after write), also for resources reached through an argument buffer when they are declared with
// useResource: or useHeap:; resources made with MTLResourceHazardTrackingModeUntracked are ordered only by
// MTLFence, MTLEvent and memoryBarrier. The sequences are repeated so that a missing dependency shows up as a
// wrong number, and they run on macOS too (the numbers are the same there).
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static const char* kSource =
	"#include <metal_stdlib>\n"
	"using namespace metal;\n"
	"kernel void step(device uint* data [[buffer(0)]], uint gid [[thread_position_in_grid]]) { data[gid] = data[gid] * 3 + 1; }\n"
	"kernel void addOne(device uint* in [[buffer(0)]], device uint* out [[buffer(1)]], uint gid [[thread_position_in_grid]]) { out[gid] = in[gid] + 1; }\n"
	"kernel void writeTexture(texture2d<float, access::write> t [[texture(0)]], constant uint& value [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) { t.write(float4(float(value + gid.x + gid.y * 16), 0.0, 0.0, 1.0), gid); }\n"
	"kernel void readTexture(texture2d<float> t [[texture(0)]], device uint* out [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) { out[gid.x + gid.y * 16] = uint(t.read(gid).x + 0.5); }\n"
	"kernel void readColor(texture2d<float> t [[texture(0)]], device uint* out [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) { out[gid.x + gid.y * 16] = uint(t.read(gid).r * 255.0 + 0.5); }\n";

enum { kElements = 4096, kThreads = 64, kRepeats = 60 };

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;
static id<MTLComputePipelineState> stepPSO, addOnePSO, writeTexturePSO, readTexturePSO, readColorPSO;

static id<MTLComputePipelineState> pipeline(id<MTLLibrary> library, NSString* name) {
	NSError* error = nil;
	id<MTLComputePipelineState> pso = [device newComputePipelineStateWithFunction: [library newFunctionWithName: name] error: &error];
	CHECK(pso != nil);
	return pso;
}

static id<MTLBuffer> makeBuffer(MTLResourceOptions tracking) {
	return [device newBufferWithLength: kElements * 4 options: MTLResourceStorageModeShared | tracking];
}

static id<MTLBuffer> counting(MTLResourceOptions tracking) {
	id<MTLBuffer> b = makeBuffer(tracking);
	uint32_t* w = [b contents];
	for (uint32_t i = 0; i < kElements; i++) {
		w[i] = i;
	}
	return b;
}

static uint32_t stepped(uint32_t v, int n) {
	while (n-- > 0) {
		v = v * 3 + 1;
	}
	return v;
}

static BOOL holdsStepped(id<MTLBuffer> b, int n, uint32_t add) {
	const uint32_t* w = [b contents];
	for (uint32_t i = 0; i < kElements; i++) {
		if (w[i] != stepped(i, n) + add) {
			return NO;
		}
	}
	return YES;
}

static BOOL holdsConstant(id<MTLBuffer> b, uint32_t value) {
	const uint32_t* w = [b contents];
	for (uint32_t i = 0; i < kElements; i++) {
		if (w[i] != value) {
			return NO;
		}
	}
	return YES;
}

static void dispatch1D(id<MTLComputeCommandEncoder> e, id<MTLComputePipelineState> pso, NSArray<id<MTLBuffer>>* buffers) {
	[e setComputePipelineState: pso];
	for (NSUInteger i = 0; i < buffers.count; i++) {
		[e setBuffer: buffers[i] offset: 0 atIndex: i];
	}
	[e dispatchThreadgroups: MTLSizeMake(kElements / kThreads, 1, 1) threadsPerThreadgroup: MTLSizeMake(kThreads, 1, 1)];
}

static void dispatchTexture(id<MTLComputeCommandEncoder> e, id<MTLComputePipelineState> pso, id<MTLTexture> texture) {
	[e setComputePipelineState: pso];
	[e setTexture: texture atIndex: 0];
	[e dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(16, 16, 1)];
}

static void finish(id<MTLCommandBuffer> cb) {
	[cb commit];
	[cb waitUntilCompleted];
	CHECK(cb.status == MTLCommandBufferStatusCompleted);
}

static id<MTLTexture> makeTexture(MTLPixelFormat format, MTLTextureUsage usage) {
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: format width: 16 height: 16 mipmapped: NO];
	d.usage = usage;
	d.storageMode = MTLStorageModePrivate;
	return [device newTextureWithDescriptor: d];
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
		id<MTLLibrary> library = [device newLibraryWithSource: [NSString stringWithUTF8String: kSource] options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("%s\n", [[error localizedDescription] UTF8String]);
			printf("FAILED: %d\n", failures);
			return 1;
		}
		stepPSO = pipeline(library, @"step");
		addOnePSO = pipeline(library, @"addOne");
		writeTexturePSO = pipeline(library, @"writeTexture");
		readTexturePSO = pipeline(library, @"readTexture");
		readColorPSO = pipeline(library, @"readColor");
		if (failures != 0) {
			printf("FAILED: %d\n", failures);
			return 1;
		}

		for (int r = 0; r < kRepeats; r++) {
			// read after write: a chain of dependent kernels, one encoder each
			{
				id<MTLBuffer> data = counting(0);
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				for (int i = 0; i < 12; i++) {
					id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
					dispatch1D(e, stepPSO, @[data]);
					[e endEncoding];
				}
				finish(cb);
				CHECK(holdsStepped(data, 12, 0));
			}

			// read after write across encoder kinds: kernel, blit copy, kernel
			{
				id<MTLBuffer> source = counting(0), copy = makeBuffer(0), result = makeBuffer(0);
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
				dispatch1D(e, stepPSO, @[source]);
				[e endEncoding];
				id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
				[blit copyFromBuffer: source sourceOffset: 0 toBuffer: copy destinationOffset: 0 size: kElements * 4];
				[blit endEncoding];
				e = [cb computeCommandEncoder];
				dispatch1D(e, addOnePSO, @[copy, result]);
				[e endEncoding];
				finish(cb);
				CHECK(holdsStepped(result, 1, 1));
			}

			// write after read: the second encoder overwrites what the first one reads
			{
				id<MTLBuffer> in = counting(0), out = makeBuffer(0);
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
				dispatch1D(e, addOnePSO, @[in, out]);
				[e endEncoding];
				e = [cb computeCommandEncoder];
				dispatch1D(e, stepPSO, @[in]);
				[e endEncoding];
				finish(cb);
				CHECK(holdsStepped(out, 0, 1));
				CHECK(holdsStepped(in, 1, 0));
			}

			// write after write: the later fill is the last word
			{
				id<MTLBuffer> data = counting(0);
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
				dispatch1D(e, stepPSO, @[data]);
				[e endEncoding];
				id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
				[blit fillBuffer: data range: NSMakeRange(0, kElements * 4) value: 0x5A];
				[blit endEncoding];
				finish(cb);
				CHECK(holdsConstant(data, 0x5A5A5A5Au));
			}

			// textures: write in one encoder, read in the next, then overwrite what the read saw
			{
				id<MTLTexture> t = makeTexture(MTLPixelFormatR32Float, MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite);
				id<MTLBuffer> first = makeBuffer(0), second = makeBuffer(0);
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				uint32_t one = 1000, two = 5000;
				id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
				[e setBytes: &one length: 4 atIndex: 0];
				dispatchTexture(e, writeTexturePSO, t);
				[e endEncoding];
				e = [cb computeCommandEncoder];
				[e setBuffer: first offset: 0 atIndex: 0];
				dispatchTexture(e, readTexturePSO, t);
				[e endEncoding];
				e = [cb computeCommandEncoder];
				[e setBytes: &two length: 4 atIndex: 0];
				dispatchTexture(e, writeTexturePSO, t);
				[e endEncoding];
				e = [cb computeCommandEncoder];
				[e setBuffer: second offset: 0 atIndex: 0];
				dispatchTexture(e, readTexturePSO, t);
				[e endEncoding];
				finish(cb);
				const uint32_t* a = [first contents];
				const uint32_t* b = [second contents];
				BOOL ok = YES;
				for (uint32_t i = 0; i < 256; i++) {
					ok = ok && a[i] == 1000 + i % 16 + (i / 16) * 16 && b[i] == 5000 + i % 16 + (i / 16) * 16;
				}
				CHECK(ok);
			}

			// a render pass writes a texture and the next compute encoder reads it
			{
				MTLTextureUsage usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
				id<MTLTexture> t = makeTexture(MTLPixelFormatRGBA8Unorm, usage);
				id<MTLBuffer> out = makeBuffer(0);
				MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
				pass.colorAttachments[0].texture = t;
				pass.colorAttachments[0].loadAction = MTLLoadActionClear;
				pass.colorAttachments[0].storeAction = MTLStoreActionStore;
				pass.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0);
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				[[cb renderCommandEncoderWithDescriptor: pass] endEncoding];
				id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
				[e setBuffer: out offset: 0 atIndex: 0];
				dispatchTexture(e, readColorPSO, t);
				[e endEncoding];
				finish(cb);
				const uint32_t* w = [out contents];
				BOOL ok = YES;
				for (uint32_t i = 0; i < 256; i++) {
					ok = ok && w[i] == 255;
				}
				CHECK(ok);
			}

			// resources declared with useResource: and useHeap: (the way an argument buffer's contents are declared; the
			// kernels here take their buffers directly, so the declaration only has to be accepted and keep the order)
			{
				id<MTLBuffer> data = counting(0), out = makeBuffer(0);
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
				dispatch1D(e, stepPSO, @[data]);
				[e endEncoding];
				e = [cb computeCommandEncoder];
				[e useResource: data usage: MTLResourceUsageRead];
				id<MTLResource> list[2] = { data, out };
				[e useResources: list count: 2 usage: MTLResourceUsageRead | MTLResourceUsageWrite];
				dispatch1D(e, addOnePSO, @[data, out]);
				[e endEncoding];
				e = [cb computeCommandEncoder];
				[e useResource: data usage: MTLResourceUsageWrite];
				dispatch1D(e, stepPSO, @[data]);
				[e endEncoding];
				finish(cb);
				CHECK(holdsStepped(out, 1, 1));
				CHECK(holdsStepped(data, 2, 0));
			}

			{
				MTLHeapDescriptor* hd = [[MTLHeapDescriptor alloc] init];
				hd.size = 256 * 1024;
				hd.storageMode = MTLStorageModeShared;
				hd.hazardTrackingMode = MTLHazardTrackingModeTracked;
				id<MTLHeap> heap = [device newHeapWithDescriptor: hd];
				[hd release];
				if (heap != nil && heap.hazardTrackingMode == MTLHazardTrackingModeTracked) {
					id<MTLBuffer> data = [heap newBufferWithLength: kElements * 4 options: MTLResourceStorageModeShared];
					id<MTLBuffer> out = [heap newBufferWithLength: kElements * 4 options: MTLResourceStorageModeShared];
					uint32_t* w = [data contents];
					for (uint32_t i = 0; i < kElements; i++) {
						w[i] = i;
					}
					id<MTLCommandBuffer> cb = [queue commandBuffer];
					id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
					dispatch1D(e, stepPSO, @[data]);
					[e endEncoding];
					e = [cb computeCommandEncoder];
					[e useHeap: heap];
					id<MTLHeap> heaps[1] = { heap };
					[e useHeaps: heaps count: 1];
					dispatch1D(e, addOnePSO, @[data, out]);
					[e endEncoding];
					finish(cb);
					CHECK(holdsStepped(out, 1, 1));
				}
			}

			// untracked buffers: a fence orders the encoders, as it does on every Metal device
			{
				id<MTLBuffer> data = counting(MTLResourceHazardTrackingModeUntracked);
				id<MTLFence> fence = [device newFence];
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				for (int i = 0; i < 6; i++) {
					id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
					if (i > 0) {
						[e waitForFence: fence];
					}
					dispatch1D(e, stepPSO, @[data]);
					[e updateFence: fence];
					[e endEncoding];
				}
				finish(cb);
				CHECK(holdsStepped(data, 6, 0));
			}

			// a concurrent encoder is ordered by memoryBarrier, for all buffers and for the listed ones
			{
				id<MTLBuffer> data = counting(MTLResourceHazardTrackingModeUntracked);
				id<MTLCommandBuffer> cb = [queue commandBuffer];
				id<MTLComputeCommandEncoder> e = [cb computeCommandEncoderWithDispatchType: MTLDispatchTypeConcurrent];
				dispatch1D(e, stepPSO, @[data]);
				[e memoryBarrierWithScope: MTLBarrierScopeBuffers];
				dispatch1D(e, stepPSO, @[data]);
				id<MTLResource> list[1] = { data };
				[e memoryBarrierWithResources: list count: 1];
				dispatch1D(e, stepPSO, @[data]);
				[e endEncoding];
				finish(cb);
				CHECK(holdsStepped(data, 3, 0));
			}
		}

		// two command buffers on one queue: the second sees what the first wrote, with the first still running
		{
			id<MTLBuffer> data = counting(0);
			id<MTLCommandBuffer> a = [queue commandBuffer];
			for (int i = 0; i < 20; i++) {
				id<MTLComputeCommandEncoder> e = [a computeCommandEncoder];
				dispatch1D(e, stepPSO, @[data]);
				[e endEncoding];
			}
			id<MTLCommandBuffer> b = [queue commandBuffer];
			for (int i = 0; i < 3; i++) {
				id<MTLComputeCommandEncoder> e = [b computeCommandEncoder];
				dispatch1D(e, stepPSO, @[data]);
				[e endEncoding];
			}
			[a commit];
			[b commit];
			[b waitUntilCompleted];
			CHECK(holdsStepped(data, 23, 0));
		}

		if (failures != 0) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		printf("OK\n");
	}
	return 0;
}
