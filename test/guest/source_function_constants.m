// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// Function constants of a library compiled from source: the values given by index or by name reach a kernel
// and a fragment function, is_function_constant_defined is true for a constant that was given a value and
// false for one that was not, and the function reports its constants.
// The last part checks an implementation limit of Darling, not Metal's behaviour (Metal accepts half
// function constants, so it fails on macOS): a function that reads a constant of a type indium cannot
// specialize yet is refused with MTLLibraryErrorUnsupported, naming the constant, while the other functions
// of its library work.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static NSString* const kSource =
	@"#include <metal_stdlib>\nusing namespace metal;\n"
	"constant uint kScale [[function_constant(0)]];\n"
	"constant bool kFlag [[function_constant(1)]];\n"
	"constant float kRed [[function_constant(2)]];\n"
	"constant half kHalf [[function_constant(3)]];\n"
	"kernel void values(device uint* out [[buffer(0)]]) {\n"
	"	out[0] = kScale * 3;\n"
	"	out[1] = kFlag ? 1 : 2;\n"
	"	out[2] = is_function_constant_defined(kScale) ? 1 : 0;\n"
	"	out[3] = is_function_constant_defined(kFlag) ? 1 : 0;\n"
	"}\n"
	"vertex float4 fullscreen(uint vid [[vertex_id]]) {\n"
	"	return float4(select(float2(-1), float2(3), bool2(vid == 1, vid == 2)), 0, 1);\n"
	"}\n"
	"fragment float4 tint() { return float4(kRed, is_function_constant_defined(kRed) ? 1.0f : 0.0f, 0, 1); }\n"
	"kernel void halves(device float* out [[buffer(0)]]) { out[0] = float(kHalf); }\n";

static NSArray<NSNumber*>* runValues(id<MTLDevice> device, id<MTLFunction> function) {
	NSError* error = nil;
	id<MTLComputePipelineState> pso = [[device newComputePipelineStateWithFunction: function error: &error] autorelease];
	if (pso == nil) {
		printf("pipeline: %s\n", error.localizedDescription.UTF8String);
		return nil;
	}
	id<MTLBuffer> out = [[device newBufferWithLength: 16 options: MTLResourceStorageModeShared] autorelease];
	memset(out.contents, 0xee, 16);
	id<MTLCommandQueue> queue = [[device newCommandQueue] autorelease];
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
	[encoder setComputePipelineState: pso];
	[encoder setBuffer: out offset: 0 atIndex: 0];
	[encoder dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(1, 1, 1)];
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	const uint32_t* words = out.contents;
	return @[ @(words[0]), @(words[1]), @(words[2]), @(words[3]) ];
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		NSError* error = nil;
		id<MTLLibrary> library = [[device newLibraryWithSource: kSource options: nil error: &error] autorelease];
		CHECK(library != nil);
		if (library == nil) {
			printf("library: %s\nFAILED: %d\n", error.localizedDescription.UTF8String, failures + 1);
			return 1;
		}

		// a value by index for kScale, by name for kFlag
		MTLFunctionConstantValues* values = [[MTLFunctionConstantValues new] autorelease];
		uint32_t scale = 7;
		bool yes = true;
		[values setConstantValue: &scale type: MTLDataTypeUInt atIndex: 0];
		[values setConstantValue: &yes type: MTLDataTypeBool withName: @"kFlag"];
		id<MTLFunction> specialized = [[library newFunctionWithName: @"values" constantValues: values error: &error] autorelease];
		CHECK(specialized != nil);
		if (specialized != nil) {
			NSDictionary<NSString*, MTLFunctionConstant*>* constants = specialized.functionConstantsDictionary;
			CHECK(constants.count == 2);
			CHECK(constants[@"kScale"].index == 0 && constants[@"kScale"].type == MTLDataTypeUInt);
			CHECK(constants[@"kFlag"].index == 1 && constants[@"kFlag"].type == MTLDataTypeBool);
			NSArray<NSNumber*>* words = runValues(device, specialized);
			CHECK([words isEqual: (@[ @21, @1, @1, @1 ])]);
			if (words) printf("values with constants: %s\n", [words componentsJoinedByString: @","].UTF8String);
		}

		// without values every constant is undefined
		id<MTLFunction> plain = [[library newFunctionWithName: @"values"] autorelease];
		CHECK(plain != nil);
		if (plain != nil) {
			NSArray<NSNumber*>* words = runValues(device, plain);
			// an undefined constant reads as zero or false
			CHECK([words isEqual: (@[ @0, @2, @0, @0 ])]);
		}

		// a fragment function's constant reaches the render pipeline
		float red = 1.0f;
		MTLFunctionConstantValues* tintValues = [[MTLFunctionConstantValues new] autorelease];
		[tintValues setConstantValue: &red type: MTLDataTypeFloat atIndex: 2];
		MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor new] autorelease];
		pd.vertexFunction = [[library newFunctionWithName: @"fullscreen"] autorelease];
		CHECK(pd.vertexFunction != nil);
		pd.fragmentFunction = [[library newFunctionWithName: @"tint" constantValues: tintValues error: &error] autorelease];
		pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
		id<MTLRenderPipelineState> rps = [[device newRenderPipelineStateWithDescriptor: pd error: &error] autorelease];
		CHECK(rps != nil);
		if (rps != nil) {
			MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 4 height: 4 mipmapped: NO];
			td.usage = MTLTextureUsageRenderTarget;
			id<MTLTexture> target = [[device newTextureWithDescriptor: td] autorelease];
			MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
			pass.colorAttachments[0].texture = target;
			pass.colorAttachments[0].loadAction = MTLLoadActionClear;
			pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 1, 1);
			pass.colorAttachments[0].storeAction = MTLStoreActionStore;
			id<MTLCommandQueue> queue = [[device newCommandQueue] autorelease];
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLRenderCommandEncoder> encoder = [commands renderCommandEncoderWithDescriptor: pass];
			[encoder setRenderPipelineState: rps];
			[encoder drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
			[encoder endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			uint8_t pixel[4] = { 0 };
			[target getBytes: pixel bytesPerRow: 16 fromRegion: MTLRegionMake2D(1, 1, 1, 1) mipmapLevel: 0];
			printf("tint pixel: %u,%u,%u,%u\n", pixel[0], pixel[1], pixel[2], pixel[3]);
			CHECK(pixel[0] == 255 && pixel[1] == 255 && pixel[2] == 0 && pixel[3] == 255);
		}

		// Implementation limit, not Metal's behaviour: the function reading the half constant is refused by
		// every way of making it
		error = nil;
		id<MTLFunction> halves = [library newFunctionWithName: @"halves" constantValues: [[MTLFunctionConstantValues new] autorelease] error: &error];
		CHECK(halves == nil);
		CHECK(error != nil && [error.domain isEqualToString: MTLLibraryErrorDomain] && error.code == MTLLibraryErrorUnsupported);
		CHECK(error != nil && [error.localizedDescription rangeOfString: @"kHalf"].location != NSNotFound);
		if (error) printf("halves: %s\n", error.localizedDescription.UTF8String);
		id<MTLFunction> unnamed = [[library newFunctionWithName: @"halves"] autorelease];
		CHECK(unnamed == nil);
		MTLFunctionDescriptor* fd = [MTLFunctionDescriptor functionDescriptor];
		fd.name = @"halves";
		error = nil;
		id<MTLFunction> described = [[library newFunctionWithDescriptor: fd error: &error] autorelease];
		CHECK(described == nil);
		CHECK(error != nil && error.code == MTLLibraryErrorUnsupported);
	}
	if (failures) {
		printf("FAILED: %d\n", failures);
		return 1;
	}
	printf("PASSED\n");
	return 0;
}
