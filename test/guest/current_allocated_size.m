// Copyright (C) 2026 Lubos Dolezel
// -[MTLDevice currentAllocatedSize]: the bytes currently allocated for the device's buffers, textures and heaps.
// Checked against the documented contract and what macOS 27.0.1 (Apple silicon) does, compiling this file there:
// a buffer or texture adds at least its allocatedSize (macOS adds some more for its own bookkeeping, and for a
// 100 byte buffer more than its size), a texture view adds nothing, a heap adds exactly its size and the buffers made from
// it nothing, and releasing a resource takes at least its allocatedSize off again. The value does not start at 0
// on macOS, so everything is a difference from an earlier reading.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (!device) {
			printf("SKIP no Metal device\n");
			return 77;
		}

		NSUInteger base = device.currentAllocatedSize;

		id<MTLBuffer> buffer = [device newBufferWithLength: 1 << 20 options: MTLResourceStorageModeShared];
		NSUInteger afterBuffer = device.currentAllocatedSize;
		CHECK(afterBuffer >= base + buffer.allocatedSize);
		CHECK(afterBuffer - base < 2 * buffer.allocatedSize);

		id<MTLBuffer> large = [device newBufferWithLength: 8 << 20 options: MTLResourceStorageModePrivate];
		NSUInteger afterLarge = device.currentAllocatedSize;
		CHECK(afterLarge >= afterBuffer + large.allocatedSize);

		MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm
		                                                                                              width: 1024 height: 1024 mipmapped: NO];
		textureDescriptor.storageMode = MTLStorageModePrivate;
		id<MTLTexture> texture = [device newTextureWithDescriptor: textureDescriptor];
		NSUInteger afterTexture = device.currentAllocatedSize;
		CHECK(afterTexture >= afterLarge + texture.allocatedSize);
		CHECK(afterTexture - afterLarge >= 1024 * 1024 * 4);

		id<MTLTexture> view = [texture newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm_sRGB];
		CHECK(device.currentAllocatedSize == afterTexture);

		MTLHeapDescriptor* heapDescriptor = [[MTLHeapDescriptor alloc] init];
		heapDescriptor.size = 8 << 20;
		heapDescriptor.storageMode = MTLStorageModePrivate;
		id<MTLHeap> heap = [device newHeapWithDescriptor: heapDescriptor];
		[heapDescriptor release];
		NSUInteger afterHeap = device.currentAllocatedSize;
		CHECK(afterHeap - afterTexture == heap.currentAllocatedSize);

		id<MTLBuffer> inHeap = [heap newBufferWithLength: 1 << 20 options: MTLResourceStorageModePrivate];
		CHECK(inHeap != nil);
		CHECK(device.currentAllocatedSize == afterHeap);
		[inHeap release];
		CHECK(device.currentAllocatedSize == afterHeap);

		[heap release];
		CHECK(afterHeap - device.currentAllocatedSize >= 8 << 20);
		[view release];
		NSUInteger beforeTexture = device.currentAllocatedSize;
		NSUInteger textureSize = texture.allocatedSize;
		[texture release];
		CHECK(beforeTexture - device.currentAllocatedSize >= textureSize);
		NSUInteger beforeLarge = device.currentAllocatedSize;
		NSUInteger largeSize = large.allocatedSize;
		[large release];
		CHECK(beforeLarge - device.currentAllocatedSize >= largeSize);
		NSUInteger beforeBuffer = device.currentAllocatedSize;
		NSUInteger bufferSize = buffer.allocatedSize;
		[buffer release];
		CHECK(beforeBuffer - device.currentAllocatedSize >= bufferSize);
	}
	printf("%s\n", failures ? "FAILED" : "ALL PASSED");
	return failures ? 1 : 0;
}
