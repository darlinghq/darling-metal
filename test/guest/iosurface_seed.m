// SPDX-FileCopyrightText: 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0
//
// Metal work that writes a texture made from an IOSurface is reported to IOSurface when its
// command buffer completes, whether the buffer renders or blits into the texture, and whether
// the caller waits or uses a completion handler. Where the texture is the surface's memory the
// seed changes then. Where Metal holds a copy the memory is unchanged until a lock writes the
// copy back, so a lock with kIOSurfaceLockAvoidSync fails with kIOReturnCannotLock; any other
// lock gets the pixels and the seed changes. Command buffers that write other textures leave
// the surface alone. Prints SKIP without a Metal device.
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>
#include <dispatch/dispatch.h>
#include <stdio.h>

#define W 16
#define H 8

static int g_failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL %d: %s\n", __LINE__, #cond); g_failures++; } } while (0)

static uint32_t firstPixel(IOSurfaceRef surface, IOSurfaceLockOptions options, kern_return_t* result)
{
	uint32_t pixel = 0;
	*result = IOSurfaceLock(surface, options, NULL);
	if (*result == kIOReturnSuccess)
	{
		pixel = *(uint32_t*) IOSurfaceGetBaseAddress(surface);
		IOSurfaceUnlock(surface, options, NULL);
	}
	return pixel;
}

static id<MTLCommandBuffer> clearBuffer(id<MTLCommandQueue> queue, id<MTLTexture> texture, MTLClearColor color)
{
	MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = texture;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	pass.colorAttachments[0].clearColor = color;
	id<MTLCommandBuffer> buffer = [queue commandBuffer];
	[[buffer renderCommandEncoderWithDescriptor: pass] endEncoding];
	return buffer;
}

static id<MTLCommandBuffer> blitBuffer(id<MTLCommandQueue> queue, id<MTLTexture> from, id<MTLTexture> to)
{
	id<MTLCommandBuffer> buffer = [queue commandBuffer];
	id<MTLBlitCommandEncoder> blit = [buffer blitCommandEncoder];
	[blit copyFromTexture: from toTexture: to];
	[blit endEncoding];
	return buffer;
}

// What a completed write of `pixel` must look like from the CPU. Which of the two storage kinds
// the texture has shows in the seed: the memory case changes it at completion.
static void expectWritten(IOSurfaceRef surface, uint32_t seedBefore, uint32_t pixel, const char* what)
{
	kern_return_t result;
	if (IOSurfaceGetSeed(surface) != seedBefore)
	{
		printf("%s: memory, seed %u -> %u\n", what, seedBefore, IOSurfaceGetSeed(surface));
		uint32_t got = firstPixel(surface, kIOSurfaceLockAvoidSync | kIOSurfaceLockReadOnly, &result);
		CHECK(result == kIOReturnSuccess && got == pixel);
	}
	else
	{
		(void) firstPixel(surface, kIOSurfaceLockAvoidSync | kIOSurfaceLockReadOnly, &result);
		printf("%s: copy, AvoidSync lock 0x%x\n", what, result);
		CHECK(result == kIOReturnCannotLock);
		uint32_t got = firstPixel(surface, kIOSurfaceLockReadOnly, &result);
		CHECK(result == kIOReturnSuccess && got == pixel);
		CHECK(IOSurfaceGetSeed(surface) != seedBefore);
		// Written back: nothing is pending any more.
		(void) firstPixel(surface, kIOSurfaceLockAvoidSync | kIOSurfaceLockReadOnly, &result);
		CHECK(result == kIOReturnSuccess);
	}
}

int main(void)
{
	@autoreleasepool
	{
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (!device)
		{
			printf("SKIP: no Metal device\n");
			return 0;
		}
		IOSurfaceRef surface = IOSurfaceCreate((CFDictionaryRef) @{
			(id) kIOSurfaceWidth: @W, (id) kIOSurfaceHeight: @H,
			(id) kIOSurfaceBytesPerElement: @4, (id) kIOSurfacePixelFormat: @((int) 'BGRA'),
		});
		CHECK(surface != NULL);
		MTLTextureDescriptor* descriptor = [MTLTextureDescriptor
			texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm width: W height: H mipmapped: NO];
		descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
		id<MTLTexture> texture = [device newTextureWithDescriptor: descriptor iosurface: surface plane: 0];
		CHECK(texture != nil);
		if (!surface || !texture)
			return 1;
		id<MTLCommandQueue> queue = [device newCommandQueue];

		// Rendering, waited for.
		uint32_t seed = IOSurfaceGetSeed(surface);
		id<MTLCommandBuffer> buffer = clearBuffer(queue, texture, MTLClearColorMake(1, 0, 0, 1));
		[buffer commit];
		[buffer waitUntilCompleted];
		expectWritten(surface, seed, 0xffff0000u, "render");

		// Blitting a plain texture into it, completion seen through a handler.
		MTLTextureDescriptor* plainDescriptor = [MTLTextureDescriptor
			texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm width: W height: H mipmapped: NO];
		plainDescriptor.storageMode = MTLStorageModeShared;
		id<MTLTexture> plain = [device newTextureWithDescriptor: plainDescriptor];
		uint32_t green[W * H];
		for (int i = 0; i < W * H; i++)
			green[i] = 0xff00ff00u;
		[plain replaceRegion: MTLRegionMake2D(0, 0, W, H) mipmapLevel: 0 withBytes: green bytesPerRow: W * 4];
		seed = IOSurfaceGetSeed(surface);
		buffer = blitBuffer(queue, plain, texture);
		dispatch_semaphore_t done = dispatch_semaphore_create(0);
		[buffer addCompletedHandler: ^(id<MTLCommandBuffer> completed) { dispatch_semaphore_signal(done); }];
		[buffer commit];
		CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0);
		expectWritten(surface, seed, 0xff00ff00u, "blit");

		// Work that writes some other texture does not touch the surface.
		seed = IOSurfaceGetSeed(surface);
		buffer = clearBuffer(queue, plain, MTLClearColorMake(0, 0, 1, 1));
		[buffer commit];
		[buffer waitUntilCompleted];
		kern_return_t result;
		CHECK(IOSurfaceGetSeed(surface) == seed);
		uint32_t pixel = firstPixel(surface, kIOSurfaceLockAvoidSync | kIOSurfaceLockReadOnly, &result);
		CHECK(result == kIOReturnSuccess && pixel == 0xff00ff00u);
		CHECK(IOSurfaceGetSeed(surface) == seed);

		// A pass that does not store its attachment writes nothing either.
		MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
		pass.colorAttachments[0].texture = texture;
		pass.colorAttachments[0].loadAction = MTLLoadActionClear;
		pass.colorAttachments[0].storeAction = MTLStoreActionDontCare;
		buffer = [queue commandBuffer];
		[[buffer renderCommandEncoderWithDescriptor: pass] endEncoding];
		[buffer commit];
		[buffer waitUntilCompleted];
		CHECK(IOSurfaceGetSeed(surface) == seed);

		[plain release];
		[texture release];
		[queue release];
		CFRelease(surface);
	}
	if (g_failures == 0)
		printf("PASS\n");
	return g_failures == 0 ? 0 : 1;
}
