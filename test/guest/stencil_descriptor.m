// Copyright (C) 2026 Lubos Dolezel
// MTLStencilDescriptor and the stencil half of MTLDepthStencilDescriptor.
//
// Documented contract (the Metal framework reference): a stencil descriptor starts with MTLCompareFunctionAlways,
// MTLStencilOperationKeep for all three operations and all-ones read and write masks; a depth-stencil descriptor's
// frontFaceStencil and backFaceStencil are null_resettable (nil restores a default descriptor) and are copied when
// set. A draw whose stencil state replaces the stencil value, followed by one that tests it, sees the replaced
// values.
// No Mac GPU was available to observe a Mac; the expectations follow the documented meaning.
// Exits 77 when there is no Metal device (the descriptor checks still run first).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kSize = 16 };

static uint32_t pixels[kSize * kSize];

static void descriptorChecks(void) {
	MTLStencilDescriptor* s = [[MTLStencilDescriptor alloc] init];
	CHECK(s.stencilCompareFunction == MTLCompareFunctionAlways);
	CHECK(s.stencilFailureOperation == MTLStencilOperationKeep);
	CHECK(s.depthFailureOperation == MTLStencilOperationKeep);
	CHECK(s.depthStencilPassOperation == MTLStencilOperationKeep);
	CHECK(s.readMask == 0xFFFFFFFFu && s.writeMask == 0xFFFFFFFFu);

	s.stencilCompareFunction = MTLCompareFunctionNotEqual;
	s.stencilFailureOperation = MTLStencilOperationZero;
	s.depthFailureOperation = MTLStencilOperationInvert;
	s.depthStencilPassOperation = MTLStencilOperationReplace;
	s.readMask = 0x0F;
	s.writeMask = 0xF0;
	CHECK(s.stencilCompareFunction == MTLCompareFunctionNotEqual);
	CHECK(s.stencilFailureOperation == MTLStencilOperationZero);
	CHECK(s.depthFailureOperation == MTLStencilOperationInvert);
	CHECK(s.depthStencilPassOperation == MTLStencilOperationReplace);
	CHECK(s.readMask == 0x0F && s.writeMask == 0xF0);

	MTLStencilDescriptor* copy = [s copy];
	CHECK(copy != s && copy.stencilCompareFunction == MTLCompareFunctionNotEqual && copy.writeMask == 0xF0);
	copy.writeMask = 1;
	CHECK(s.writeMask == 0xF0);

	// the numeric values of the operations are part of the ABI
	CHECK(MTLStencilOperationKeep == 0 && MTLStencilOperationDecrementWrap == 7 && MTLStencilOperationInvert == 5);

	MTLDepthStencilDescriptor* d = [[MTLDepthStencilDescriptor alloc] init];
	CHECK(d.frontFaceStencil != nil && d.backFaceStencil != nil && d.frontFaceStencil != d.backFaceStencil);
	CHECK(d.frontFaceStencil.stencilCompareFunction == MTLCompareFunctionAlways);
	d.frontFaceStencil = s;
	CHECK(d.frontFaceStencil != s && d.frontFaceStencil.stencilCompareFunction == MTLCompareFunctionNotEqual);
	s.stencilCompareFunction = MTLCompareFunctionNever;
	CHECK(d.frontFaceStencil.stencilCompareFunction == MTLCompareFunctionNotEqual);
	d.frontFaceStencil.readMask = 3;
	CHECK(d.frontFaceStencil.readMask == 3);
	d.frontFaceStencil = nil;
	CHECK(d.frontFaceStencil != nil && d.frontFaceStencil.stencilCompareFunction == MTLCompareFunctionAlways);
	d.backFaceStencil = nil;
	CHECK(d.backFaceStencil != nil && d.backFaceStencil.readMask == 0xFFFFFFFFu);
}

int main(void) {
	@autoreleasepool {
		descriptorChecks();

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf(failures ? "FAILED: %d\n" : "OK (descriptors only, no Metal device)\n", failures);
			return failures != 0 ? 1 : 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
		NSError* error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"struct Vertex { float4 position [[position]]; };\n"
			"vertex Vertex smallVertex(uint vid [[vertex_id]]) {\n"
			"	Vertex o;\n"
			"	float x = (vid == 0) ? -0.75 : ((vid == 1) ? 0.75 : 0.0);\n"
			"	float y = (vid == 2) ? 0.75 : -0.75;\n"
			"	o.position = float4(x, y, 0.5, 1.0);\n	return o;\n}\n"
			"vertex Vertex fullVertex(uint vid [[vertex_id]]) {\n"
			"	Vertex o;\n"
			"	float x = (vid == 1) ? 3.0 : -1.0;\n"
			"	float y = (vid == 2) ? 3.0 : -1.0;\n"
			"	o.position = float4(x, y, 0.5, 1.0);\n	return o;\n}\n"
			"fragment float4 redFragment() { return float4(1.0, 0.0, 0.0, 1.0); }\n"
			"fragment float4 greenFragment() { return float4(0.0, 1.0, 0.0, 1.0); }\n" options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("FAILED: %d\n", failures);
			return 1;
		}
		id<MTLRenderPipelineState> (^pipeline)(NSString*, NSString*, BOOL, NSUInteger) = ^id<MTLRenderPipelineState>(NSString* vertex, NSString* fragment, BOOL stencil, NSUInteger samples) {
			MTLRenderPipelineDescriptor* pd = [[MTLRenderPipelineDescriptor alloc] init];
			pd.vertexFunction = [library newFunctionWithName: vertex];
			pd.fragmentFunction = [library newFunctionWithName: fragment];
			pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
			pd.sampleCount = samples;
			if (stencil) {
				pd.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
				pd.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
			}
			return [device newRenderPipelineStateWithDescriptor: pd error: nil];
		};

		// stencil: replace the value inside a small triangle, then draw everywhere the value is not that
		{
			id<MTLRenderPipelineState> markPipeline = pipeline(@"smallVertex", @"redFragment", YES, 1);
			id<MTLRenderPipelineState> testPipeline = pipeline(@"fullVertex", @"greenFragment", YES, 1);
			CHECK(markPipeline != nil && testPipeline != nil);

			MTLDepthStencilDescriptor* mark = [[MTLDepthStencilDescriptor alloc] init];
			mark.frontFaceStencil.depthStencilPassOperation = MTLStencilOperationReplace;
			mark.backFaceStencil.depthStencilPassOperation = MTLStencilOperationReplace;
			MTLDepthStencilDescriptor* test = [[MTLDepthStencilDescriptor alloc] init];
			test.frontFaceStencil.stencilCompareFunction = MTLCompareFunctionNotEqual;
			test.backFaceStencil.stencilCompareFunction = MTLCompareFunctionNotEqual;
			id<MTLDepthStencilState> markState = [device newDepthStencilStateWithDescriptor: mark];
			id<MTLDepthStencilState> testState = [device newDepthStencilStateWithDescriptor: test];
			CHECK(markState != nil && testState != nil);

			MTLTextureDescriptor* cd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
			cd.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
			cd.storageMode = MTLStorageModeManaged;
			id<MTLTexture> color = [device newTextureWithDescriptor: cd];
			MTLTextureDescriptor* dd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatDepth32Float_Stencil8 width: kSize height: kSize mipmapped: NO];
			dd.usage = MTLTextureUsageRenderTarget;
			dd.storageMode = MTLStorageModePrivate;
			id<MTLTexture> depthStencil = [device newTextureWithDescriptor: dd];
			CHECK(color != nil && depthStencil != nil);

			MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
			rp.colorAttachments[0].texture = color;
			rp.colorAttachments[0].loadAction = MTLLoadActionClear;
			rp.colorAttachments[0].storeAction = MTLStoreActionStore;
			rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
			rp.depthAttachment.texture = depthStencil;
			rp.depthAttachment.loadAction = MTLLoadActionClear;
			rp.depthAttachment.clearDepth = 1.0;
			rp.stencilAttachment.texture = depthStencil;
			rp.stencilAttachment.loadAction = MTLLoadActionClear;
			rp.stencilAttachment.clearStencil = 0;
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLRenderCommandEncoder> e = [commands renderCommandEncoderWithDescriptor: rp];
			[e setRenderPipelineState: markPipeline];
			[e setDepthStencilState: markState];
			[e setStencilReferenceValue: 1];
			[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
			[e setRenderPipelineState: testPipeline];
			[e setDepthStencilState: testState];
			// the front and back values are the documented two-value form of the same call
			[e setStencilFrontReferenceValue: 1 backReferenceValue: 1];
			[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
			[e endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			[color getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
			// inside the small triangle the first draw's red stays (the stencil value is 1, so the test fails
			// there); outside it the second draw's green lands
			CHECK(pixels[(kSize / 2 - 1) * kSize + kSize / 2] == 0xFF0000FFu);
			CHECK(pixels[0] == 0xFF00FF00u);
			CHECK(pixels[kSize * kSize - 1] == 0xFF00FF00u);
		}

	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
