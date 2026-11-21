// Copyright (C) 2026 Lubos Dolezel
// The store actions a render encoder takes after it began (-setColorStoreAction:atIndex: and its siblings).
//
// Documented contract (the Metal framework reference): a store action left MTLStoreActionUnknown in the render
// pass descriptor is given before the encoder ends, and MTLStoreActionMultisampleResolve then resolves the
// multisample attachment into its resolve texture. No Mac GPU was available to observe a Mac; the expectations
// follow the documented meaning.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { kSize = 16 };

static uint32_t pixels[kSize * kSize];

// the number of pixels of the target that are not the expected value
static int mismatches(uint32_t expected) {
	int n = 0;
	for (int i = 0; i < kSize * kSize; i++)
		n += pixels[i] != expected;
	return n;
}

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

		// a color store action given after the encoder began (left Unknown in the descriptor)
		{
			id<MTLRenderPipelineState> redPipeline = pipeline(@"fullVertex", @"redFragment", NO, 1);
			MTLTextureDescriptor* cd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
			cd.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
			cd.storageMode = MTLStorageModeManaged;
			id<MTLTexture> color = [device newTextureWithDescriptor: cd];
			MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
			rp.colorAttachments[0].texture = color;
			rp.colorAttachments[0].loadAction = MTLLoadActionClear;
			rp.colorAttachments[0].storeAction = MTLStoreActionUnknown;
			rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLRenderCommandEncoder> e = [commands renderCommandEncoderWithDescriptor: rp];
			[e setRenderPipelineState: redPipeline];
			[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
			BOOL raised = NO;
			@try {
				[e setColorStoreAction: MTLStoreActionStore atIndex: 0];
				[e setColorStoreActionOptions: MTLStoreActionOptionNone atIndex: 0];
				[e setDepthStoreAction: MTLStoreActionDontCare];
				[e setStencilStoreAction: MTLStoreActionDontCare];
				[e setDepthStoreActionOptions: MTLStoreActionOptionNone];
				[e setStencilStoreActionOptions: MTLStoreActionOptionNone];
			} @catch (NSException* x) {
				raised = YES;
				printf("raised: %s\n", [[x description] UTF8String]);
			}
			CHECK(!raised);
			[e endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			[color getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
			CHECK(mismatches(0xFF0000FFu) == 0);
		}

		// a multisample resolve asked for after the encoder began
		{
			id<MTLRenderPipelineState> redPipeline = pipeline(@"fullVertex", @"redFragment", NO, 4);
			MTLTextureDescriptor* md = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
			md.textureType = MTLTextureType2DMultisample;
			md.sampleCount = 4;
			md.usage = MTLTextureUsageRenderTarget;
			md.storageMode = MTLStorageModePrivate;
			id<MTLTexture> multisample = [device newTextureWithDescriptor: md];
			MTLTextureDescriptor* rd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: kSize height: kSize mipmapped: NO];
			rd.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
			rd.storageMode = MTLStorageModeManaged;
			id<MTLTexture> resolved = [device newTextureWithDescriptor: rd];
			CHECK(multisample != nil && resolved != nil);
			MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
			rp.colorAttachments[0].texture = multisample;
			rp.colorAttachments[0].resolveTexture = resolved;
			rp.colorAttachments[0].loadAction = MTLLoadActionClear;
			rp.colorAttachments[0].storeAction = MTLStoreActionUnknown;
			rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 1, 1);
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLRenderCommandEncoder> e = [commands renderCommandEncoderWithDescriptor: rp];
			[e setRenderPipelineState: redPipeline];
			[e drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 3];
			BOOL raised = NO;
			@try {
				[e setColorStoreAction: MTLStoreActionMultisampleResolve atIndex: 0];
			} @catch (NSException* x) {
				raised = YES;
				printf("raised: %s\n", [[x description] UTF8String]);
			}
			CHECK(!raised);
			[e endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			[resolved getBytes: pixels bytesPerRow: kSize * 4 fromRegion: MTLRegionMake2D(0, 0, kSize, kSize) mipmapLevel: 0];
			CHECK(mismatches(0xFF0000FFu) == 0);
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
