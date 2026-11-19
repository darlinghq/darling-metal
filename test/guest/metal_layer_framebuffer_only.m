// Copyright (C) 2026 Lubos Dolezel
// A CAMetalLayer with framebufferOnly set to NO: its drawables' textures can be used like other textures,
// here as the source of a blit, besides being rendered to and presented. The layer is in a window, so its
// drawables are made for that window. On a device that offers host-visible memory to linearly tiled images
// only (NVIDIA), making such drawables used to abort the process.
//
// With --opengl the layer is composited through the layer context's OpenGL rendering instead of a swapchain
// on a native window (the CAMetalLayerForceOpenGL preference, set for this process only).
// Exits 77 when there is no Metal device.
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#include <string.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static void spin(NSTimeInterval seconds) {
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: seconds]];
}

// Clears the drawable's texture to the color, copies the texture into a buffer and presents the drawable.
// Returns the first pixel of the copy (BGRA), or 0 when the work did not complete.
static uint32_t clearCopyAndPresent(id<MTLCommandQueue> queue, id<CAMetalDrawable> drawable, MTLClearColor color) {
	id<MTLTexture> texture = drawable.texture;
	NSUInteger bytesPerRow = texture.width * 4;
	id<MTLBuffer> buffer = [queue.device newBufferWithLength: bytesPerRow * texture.height options: MTLResourceStorageModeShared];
	memset(buffer.contents, 0, buffer.length);

	MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = texture;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	pass.colorAttachments[0].clearColor = color;

	id<MTLCommandBuffer> commands = [queue commandBuffer];
	[[commands renderCommandEncoderWithDescriptor: pass] endEncoding];
	id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
	[blit copyFromTexture: texture sourceSlice: 0 sourceLevel: 0 sourceOrigin: MTLOriginMake(0, 0, 0)
		sourceSize: MTLSizeMake(texture.width, texture.height, 1) toBuffer: buffer destinationOffset: 0
		destinationBytesPerRow: bytesPerRow destinationBytesPerImage: bytesPerRow * texture.height];
	[blit endEncoding];
	[commands presentDrawable: drawable];
	[commands commit];
	[commands waitUntilCompleted];

	uint32_t pixel = 0;
	if (commands.status == MTLCommandBufferStatusCompleted) {
		const uint8_t* bytes = buffer.contents;
		// the last pixel as well: the whole texture was cleared
		const uint8_t* last = bytes + bytesPerRow * (texture.height - 1) + (texture.width - 1) * 4;
		if (memcmp(bytes, last, 4) == 0) {
			memcpy(&pixel, bytes, 4);
		}
	}
	[buffer release];
	return pixel;
}

int main(int argc, char** argv) {
	@autoreleasepool {
		BOOL forceOpenGL = argc > 1 && strcmp(argv[1], "--opengl") == 0;
		CFStringRef forceKey = CFSTR("CAMetalLayerForceOpenGL");
		if (forceOpenGL) {
			// in memory only: removed again below, before anything could write it out
			CFPreferencesSetAppValue(forceKey, kCFBooleanTrue, kCFPreferencesCurrentApplication);
		}

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		printf("device: %s%s\n", device.name.UTF8String, forceOpenGL ? " (OpenGL composition)" : "");
		id<MTLCommandQueue> queue = [device newCommandQueue];

		[NSApplication sharedApplication];
		NSWindow* window = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, 160, 120)
			styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO];
		[window setReleasedWhenClosed: NO];
		NSView* host = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 160, 120)];

		CAMetalLayer* layer = [CAMetalLayer layer];
		layer.device = device;
		layer.bounds = CGRectMake(0, 0, 160, 120);
		layer.framebufferOnly = NO;
		CHECK(layer.framebufferOnly == NO);

		host.layer = layer;
		host.wantsLayer = YES;
		[window setContentView: host];
		[window makeKeyAndOrderFront: nil];
		spin(0.5);
		CHECK(CGSizeEqualToSize(layer.drawableSize, CGSizeMake(160, 120)));

		// --- every drawable can be rendered to, read by a blit and presented
		const MTLClearColor colors[] = { MTLClearColorMake(1, 0, 0, 1), MTLClearColorMake(0, 1, 0, 1), MTLClearColorMake(0, 0, 1, 1), MTLClearColorMake(1, 1, 1, 1) };
		const uint32_t expected[] = { 0xffff0000, 0xff00ff00, 0xff0000ff, 0xffffffff }; // BGRA in memory, read as little-endian
		for (int i = 0; i < 4; i++) {
			id<CAMetalDrawable> drawable = [layer nextDrawable];
			CHECK(drawable != nil);
			if (drawable == nil) {
				break;
			}
			CHECK(drawable.texture.width == 160 && drawable.texture.height == 120);
			uint32_t pixel = clearCopyAndPresent(queue, drawable, colors[i]);
			if (pixel != expected[i]) {
				printf("frame %d: pixel 0x%08x, expected 0x%08x\n", i, pixel, expected[i]);
			}
			CHECK(pixel == expected[i]);
			spin(0.05);
		}

		// --- the same after the drawables are made again for a new size (that the drawables follow the
		// layer's size is metal_layer_window's to check)
		[window setContentSize: NSMakeSize(200, 140)];
		host.frame = NSMakeRect(0, 0, 200, 140);
		layer.bounds = CGRectMake(0, 0, 200, 140);
		spin(0.5);
		{
			id<CAMetalDrawable> drawable = [layer nextDrawable];
			CHECK(drawable != nil);
			if (drawable) {
				CHECK(drawable.texture.width == layer.drawableSize.width && drawable.texture.height == layer.drawableSize.height);
				CHECK(clearCopyAndPresent(queue, drawable, colors[1]) == expected[1]);
			}
		}

		if (forceOpenGL) {
			CFPreferencesSetAppValue(forceKey, NULL, kCFPreferencesCurrentApplication);
		}
		spin(0.3);
		[window close];
		[window release];
		[host release];
		[queue release];
		[device release];
	}
	printf(failures ? "FAILED\n" : "OK\n");
	return failures ? 1 : 0;
}
