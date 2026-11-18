// Copyright (C) 2026 Lubos Dolezel
// GPU counter sampling with the timestamp counter set (MTLCounters.h):
//  - the MTLCommonCounter and MTLCommonCounterSet constants exist and have their documented names;
//  - -counterSets holds the timestamp set with the GPUTimestamp counter and nothing else;
//  - -supportsCounterSampling: says yes to the stage boundary and no to the draw and tile dispatch boundaries;
//  - a sample buffer reports its sample count, label and device, and its unwritten samples read as zero;
//  - blit, compute and render passes store timestamps in a sample buffer through their pass descriptors, and
//    -sampleCountersInBuffer:atSampleIndex:withBarrier: does where the device supports the sampling point;
//    the resolved MTLCounterResultTimestamp values are non-zero and never go back;
//  - a pass descriptor's attachment indices default to MTLCounterDontSample;
//  - a bad descriptor (no counter set, sample count 0 or above 4096) fails with MTLCounterErrorDomain,
//    MTLCounterSampleBufferErrorInvalid; resolving an empty or out-of-bounds range gives nil;
//  - -sampleTimestamps:gpuTimestamp: gives non-zero values that do not go back.
// The expectations come from the documented API and the behaviour observed on an Apple Silicon Mac (macOS 27.0.1);
// the test is meant to give the same results there. An empty encoder does not store a timestamp on that Mac, so
// every pass below does some work.
// Exits 77 when there is no Metal device or it has no counter sets.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static const char kKernel[] =
	"#include <metal_stdlib>\n"
	"using namespace metal;\n"
	"kernel void fill(device uint* out [[buffer(0)]], uint i [[thread_position_in_grid]]) { out[i] = i; }\n";

static id<MTLCounterSampleBuffer> newSamples(id<MTLDevice> device, id<MTLCounterSet> set, NSUInteger count, NSString* label) {
	MTLCounterSampleBufferDescriptor* descriptor = [[MTLCounterSampleBufferDescriptor alloc] init];
	descriptor.counterSet = set;
	descriptor.sampleCount = count;
	descriptor.storageMode = MTLStorageModeShared;
	descriptor.label = label;
	NSError* error = nil;
	id<MTLCounterSampleBuffer> samples = [device newCounterSampleBufferWithDescriptor: descriptor error: &error];
	[descriptor release];
	CHECK(samples != nil && error == nil);
	return samples;
}

static const MTLCounterResultTimestamp* resolve(id<MTLCounterSampleBuffer> samples, NSUInteger start, NSUInteger count, NSData** keep) {
	*keep = [samples resolveCounterRange: NSMakeRange(start, count)];
	CHECK(*keep != nil && (*keep).length == count * sizeof(MTLCounterResultTimestamp));
	return (*keep).length == count * sizeof(MTLCounterResultTimestamp) ? (*keep).bytes : NULL;
}

// whether `v[0..count)` are non-zero and never go back
static BOOL increasing(const MTLCounterResultTimestamp* v, NSUInteger count) {
	if (v == NULL) return NO;
	for (NSUInteger i = 0; i < count; i++) {
		if (v[i].timestamp == 0 || v[i].timestamp == MTLCounterErrorValue) return NO;
		if (i > 0 && v[i].timestamp < v[i - 1].timestamp) return NO;
	}
	return YES;
}

int main(void) {
	@autoreleasepool {
		// --- the constants
		CHECK([MTLCommonCounterTimestamp isEqualToString: @"GPUTimestamp"]);
		CHECK([MTLCommonCounterSetTimestamp isEqualToString: @"timestamp"]);
		CHECK([MTLCommonCounterSetStageUtilization isEqualToString: @"stageutilization"]);
		CHECK([MTLCommonCounterSetStatistic isEqualToString: @"statistic"]);
		CHECK([MTLCommonCounterTessellationInputPatches isEqualToString: @"TessellationInputPatches"]);
		CHECK([MTLCommonCounterVertexInvocations isEqualToString: @"VertexInvocations"]);
		CHECK([MTLCommonCounterPostTessellationVertexInvocations isEqualToString: @"PostTessellationVertexInvocations"]);
		CHECK([MTLCommonCounterClipperInvocations isEqualToString: @"ClipperInvocations"]);
		CHECK([MTLCommonCounterClipperPrimitivesOut isEqualToString: @"ClipperPrimitivesOut"]);
		CHECK([MTLCommonCounterFragmentInvocations isEqualToString: @"FragmentInvocations"]);
		CHECK([MTLCommonCounterFragmentsPassed isEqualToString: @"FragmentsPassed"]);
		CHECK([MTLCommonCounterComputeKernelInvocations isEqualToString: @"KernelInvocations"]);
		CHECK([MTLCommonCounterTotalCycles isEqualToString: @"TotalCycles"]);
		CHECK([MTLCommonCounterVertexCycles isEqualToString: @"VertexCycles"]);
		CHECK([MTLCommonCounterTessellationCycles isEqualToString: @"TessellationCycles"]);
		CHECK([MTLCommonCounterPostTessellationVertexCycles isEqualToString: @"PostTessellationCycles"]);
		CHECK([MTLCommonCounterFragmentCycles isEqualToString: @"FragmentCycles"]);
		CHECK([MTLCommonCounterRenderTargetWriteCycles isEqualToString: @"RenderTargetWriteCycles"]);
		CHECK([MTLCounterErrorDomain isEqualToString: @"MTLCounterErrorDomain"]);
		CHECK(MTLCounterDontSample == (NSUInteger)-1);
		CHECK(MTLCounterErrorValue == UINT64_MAX);
		CHECK(sizeof(MTLCounterResultTimestamp) == 8);

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}

		// --- counter sets and sampling points
		NSArray<id<MTLCounterSet>>* sets = device.counterSets;
		if (sets.count == 0) {
			printf("SKIP: no counter sets\n");
			return 77;
		}
		id<MTLCounterSet> timestampSet = nil;
		for (id<MTLCounterSet> set in sets) {
			CHECK([set.name isEqualToString: MTLCommonCounterSetTimestamp]);
			if ([set.name isEqualToString: MTLCommonCounterSetTimestamp]) {
				timestampSet = set;
			}
		}
		CHECK(timestampSet != nil);
		CHECK(timestampSet.counters.count == 1);
		CHECK([timestampSet.counters[0].name isEqualToString: MTLCommonCounterTimestamp]);

		CHECK([device supportsCounterSampling: MTLCounterSamplingPointAtStageBoundary]);
		CHECK(![device supportsCounterSampling: MTLCounterSamplingPointAtDrawBoundary]);
		CHECK(![device supportsCounterSampling: MTLCounterSamplingPointAtTileDispatchBoundary]);
		BOOL dispatchSampling = [device supportsCounterSampling: MTLCounterSamplingPointAtDispatchBoundary];
		BOOL blitSampling = [device supportsCounterSampling: MTLCounterSamplingPointAtBlitBoundary];

		// --- a sample buffer
		id<MTLCounterSampleBuffer> samples = newSamples(device, timestampSet, 8, @"my samples");
		CHECK(samples.sampleCount == 8);
		CHECK([samples.label isEqualToString: @"my samples"]);
		CHECK(samples.device == device);
		NSData* data = nil;
		const MTLCounterResultTimestamp* unwritten = resolve(samples, 0, 8, &data);
		for (NSUInteger i = 0; unwritten != NULL && i < 8; i++) {
			CHECK(unwritten[i].timestamp == 0);
		}
		CHECK([samples resolveCounterRange: NSMakeRange(0, 0)] == nil);
		CHECK([samples resolveCounterRange: NSMakeRange(6, 3)] == nil);

		// --- the attachment defaults
		MTLBlitPassDescriptor* blitPass = [MTLBlitPassDescriptor blitPassDescriptor];
		CHECK(blitPass.sampleBufferAttachments[0].sampleBuffer == nil);
		CHECK(blitPass.sampleBufferAttachments[0].startOfEncoderSampleIndex == MTLCounterDontSample);
		CHECK(blitPass.sampleBufferAttachments[0].endOfEncoderSampleIndex == MTLCounterDontSample);
		MTLComputePassDescriptor* computePass = [MTLComputePassDescriptor computePassDescriptor];
		CHECK(computePass.sampleBufferAttachments[0].startOfEncoderSampleIndex == MTLCounterDontSample);
		MTLRenderPassDescriptor* renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
		CHECK(renderPass.sampleBufferAttachments[0].startOfVertexSampleIndex == MTLCounterDontSample);
		CHECK(renderPass.sampleBufferAttachments[0].endOfFragmentSampleIndex == MTLCounterDontSample);

		id<MTLCommandQueue> queue = [device newCommandQueue];
		id<MTLBuffer> work = [device newBufferWithLength: 1 << 20 options: MTLResourceStorageModeShared];

		// --- blit passes: samples 0 and 1, then 2 and 3, and one taken inside the pass at 4
		{
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			blitPass.sampleBufferAttachments[0].sampleBuffer = samples;
			blitPass.sampleBufferAttachments[0].startOfEncoderSampleIndex = 0;
			blitPass.sampleBufferAttachments[0].endOfEncoderSampleIndex = 1;
			id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoderWithDescriptor: blitPass];
			CHECK(blit != nil);
			[blit fillBuffer: work range: NSMakeRange(0, 1 << 20) value: 7];
			if (blitSampling) {
				[blit sampleCountersInBuffer: samples atSampleIndex: 4 withBarrier: YES];
			}
			[blit endEncoding];
			MTLBlitPassDescriptor* second = [MTLBlitPassDescriptor blitPassDescriptor];
			second.sampleBufferAttachments[0].sampleBuffer = samples;
			second.sampleBufferAttachments[0].startOfEncoderSampleIndex = 2;
			second.sampleBufferAttachments[0].endOfEncoderSampleIndex = 3;
			blit = [commands blitCommandEncoderWithDescriptor: second];
			[blit fillBuffer: work range: NSMakeRange(0, 1 << 20) value: 9];
			[blit endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			CHECK(commands.status == MTLCommandBufferStatusCompleted);

			const MTLCounterResultTimestamp* v = resolve(samples, 0, 4, &data);
			CHECK(increasing(v, 4));
			if (blitSampling) {
				// the sample inside the first pass lies between its start and the second pass
				const MTLCounterResultTimestamp* inside = resolve(samples, 4, 1, &data);
				CHECK(inside != NULL && inside[0].timestamp != 0 && v != NULL && inside[0].timestamp >= v[0].timestamp);
			}
			const MTLCounterResultTimestamp* untouched = resolve(samples, 5, 3, &data);
			for (NSUInteger i = 0; untouched != NULL && i < 3; i++) {
				CHECK(untouched[i].timestamp == 0);
			}
		}

		// --- compute pass with a dispatch: samples 0 and 1 of a fresh buffer
		{
			NSError* error = nil;
			id<MTLLibrary> library = [device newLibraryWithSource: @(kKernel) options: nil error: &error];
			id<MTLFunction> function = [library newFunctionWithName: @"fill"];
			id<MTLComputePipelineState> pipeline = function ? [device newComputePipelineStateWithFunction: function error: &error] : nil;
			CHECK(pipeline != nil);
			id<MTLCounterSampleBuffer> computeSamples = newSamples(device, timestampSet, 3, nil);
			computePass.sampleBufferAttachments[0].sampleBuffer = computeSamples;
			computePass.sampleBufferAttachments[0].startOfEncoderSampleIndex = 0;
			computePass.sampleBufferAttachments[0].endOfEncoderSampleIndex = 1;
			if (pipeline != nil) {
				id<MTLCommandBuffer> commands = [queue commandBuffer];
				id<MTLComputeCommandEncoder> compute = [commands computeCommandEncoderWithDescriptor: computePass];
				[compute setComputePipelineState: pipeline];
				[compute setBuffer: work offset: 0 atIndex: 0];
				[compute dispatchThreadgroups: MTLSizeMake(64, 1, 1) threadsPerThreadgroup: MTLSizeMake(64, 1, 1)];
				if (dispatchSampling) {
					[compute sampleCountersInBuffer: computeSamples atSampleIndex: 2 withBarrier: YES];
				}
				[compute endEncoding];
				[commands commit];
				[commands waitUntilCompleted];
				CHECK(commands.status == MTLCommandBufferStatusCompleted);
				CHECK(increasing(resolve(computeSamples, 0, 2, &data), 2));
				if (dispatchSampling) {
					const MTLCounterResultTimestamp* v = resolve(computeSamples, 0, 3, &data);
					CHECK(v != NULL && v[2].timestamp >= v[0].timestamp);
				}
			}
		}

		// --- render pass with its four stage samples
		{
			MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 16 height: 16 mipmapped: NO];
			textureDescriptor.usage = MTLTextureUsageRenderTarget;
			textureDescriptor.storageMode = MTLStorageModePrivate;
			id<MTLTexture> color = [device newTextureWithDescriptor: textureDescriptor];
			id<MTLCounterSampleBuffer> renderSamples = newSamples(device, timestampSet, 4, nil);
			renderPass.colorAttachments[0].texture = color;
			renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
			renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
			renderPass.sampleBufferAttachments[0].sampleBuffer = renderSamples;
			renderPass.sampleBufferAttachments[0].startOfVertexSampleIndex = 0;
			renderPass.sampleBufferAttachments[0].endOfVertexSampleIndex = 1;
			renderPass.sampleBufferAttachments[0].startOfFragmentSampleIndex = 2;
			renderPass.sampleBufferAttachments[0].endOfFragmentSampleIndex = 3;
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLRenderCommandEncoder> render = [commands renderCommandEncoderWithDescriptor: renderPass];
			CHECK(render != nil);
			[render endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			CHECK(commands.status == MTLCommandBufferStatusCompleted);
			// all four resolve; they are timestamps, or zero where the device sampled nothing for a pass without draws
			NSData* resolved = [renderSamples resolveCounterRange: NSMakeRange(0, 4)];
			CHECK(resolved.length == 4 * sizeof(MTLCounterResultTimestamp));
		}

		// --- errors
		{
			MTLCounterSampleBufferDescriptor* descriptor = [[MTLCounterSampleBufferDescriptor alloc] init];
			descriptor.counterSet = timestampSet;
			descriptor.storageMode = MTLStorageModeShared;
			NSUInteger counts[] = { 0, 4097 };
			for (int i = 0; i < 2; i++) {
				descriptor.sampleCount = counts[i];
				NSError* error = nil;
				CHECK([device newCounterSampleBufferWithDescriptor: descriptor error: &error] == nil);
				CHECK([error.domain isEqualToString: MTLCounterErrorDomain]);
				CHECK(error.code == MTLCounterSampleBufferErrorInvalid);
				CHECK(error.localizedDescription.length > 0);
			}
			descriptor.sampleCount = 4096;
			CHECK([device newCounterSampleBufferWithDescriptor: descriptor error: NULL] != nil);
			descriptor.counterSet = nil;
			descriptor.sampleCount = 4;
			NSError* error = nil;
			CHECK([device newCounterSampleBufferWithDescriptor: descriptor error: &error] == nil);
			CHECK([error.domain isEqualToString: MTLCounterErrorDomain]);
			CHECK(error.code == MTLCounterSampleBufferErrorInvalid);
			[descriptor release];
		}

		// --- the device clocks
		{
			MTLTimestamp cpu1 = 0, gpu1 = 0, cpu2 = 0, gpu2 = 0;
			[device sampleTimestamps: &cpu1 gpuTimestamp: &gpu1];
			[device sampleTimestamps: &cpu2 gpuTimestamp: &gpu2];
			CHECK(cpu1 != 0 && gpu1 != 0);
			CHECK(cpu2 >= cpu1 && gpu2 >= gpu1);
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
