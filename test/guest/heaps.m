// Copyright (C) 2026 Lubos Dolezel
// Heaps: MTLHeapDescriptor, -[MTLDevice newHeapWithDescriptor:], the size and alignment queries, automatic
// and placement heaps, the heap properties of resources, aliasing, and the resources used by the GPU.
// The expectations follow the documented contract and what macOS 27.0.1 (Apple silicon) does (checked by
// compiling this file there): the sizes and alignments a device reports are its own, so the test only relates them
// to each other and to what a heap counts. Texture offsets in a placement heap use the larger of the reported
// alignment and 256 (the reported alignment of a texture is 128 there, yet an offset that is not a multiple of 256
// is refused).
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

// Darling's Metal classes are the only ones named ...Internal; heaps Darling refuses (managed, memoryless and sparse)
// are validation assertions or heaps on macOS, so those checks run on Darling only.
static BOOL onDarling(void) { return NSClassFromString(@"MTLTextureInternal") != nil; }

static NSUInteger alignUp(NSUInteger v, NSUInteger a) { return (v + a - 1) / a * a; }

static MTLHeapDescriptor* heapDescriptor(NSUInteger size, MTLStorageMode mode, MTLHeapType type) {
	MTLHeapDescriptor* d = [[[MTLHeapDescriptor alloc] init] autorelease];
	d.size = size;
	d.storageMode = mode;
	d.type = type;
	return d;
}

static MTLTextureDescriptor* textureDescriptor(NSUInteger w, NSUInteger h, MTLStorageMode mode) {
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: w height: h mipmapped: NO];
	d.storageMode = mode;
	d.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsagePixelFormatView;
	return d;
}

static void clearTexture(id<MTLCommandQueue> queue, id<MTLTexture> texture, double red) {
	MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = texture;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	pass.colorAttachments[0].clearColor = MTLClearColorMake(red, 0, 1, 1);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	[[commands renderCommandEncoderWithDescriptor: pass] endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
}

static uint32_t firstPixel(id<MTLDevice> device, id<MTLCommandQueue> queue, id<MTLTexture> texture) {
	id<MTLBuffer> out = [device newBufferWithLength: 256 options: MTLResourceStorageModeShared];
	memset(out.contents, 0, 256);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
	[blit copyFromTexture: texture sourceSlice: 0 sourceLevel: 0 sourceOrigin: MTLOriginMake(0, 0, 0) sourceSize: MTLSizeMake(1, 1, 1)
	             toBuffer: out destinationOffset: 0 destinationBytesPerRow: 4 destinationBytesPerImage: 4];
	[blit endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	uint32_t pixel = *(uint32_t*)out.contents;
	[out release];
	return pixel;
}

static void fillPattern(id<MTLBuffer> b, uint8_t seed) {
	for (NSUInteger i = 0; i < b.length; ++i) ((uint8_t*)b.contents)[i] = (uint8_t)(seed + i * 7);
}

static BOOL hasPattern(id<MTLBuffer> b, uint8_t seed) {
	for (NSUInteger i = 0; i < b.length; ++i) if (((uint8_t*)b.contents)[i] != (uint8_t)(seed + i * 7)) return NO;
	return YES;
}

static void testDescriptor(void) {
	MTLHeapDescriptor* d = [[[MTLHeapDescriptor alloc] init] autorelease];
	// defaults: size 0, private storage, default cache and hazard tracking, automatic
	CHECK(d.size == 0 && d.storageMode == MTLStorageModePrivate && d.cpuCacheMode == MTLCPUCacheModeDefaultCache);
	CHECK(d.hazardTrackingMode == MTLHazardTrackingModeDefault && d.type == MTLHeapTypeAutomatic);
	CHECK(d.resourceOptions == MTLResourceStorageModePrivate);
	d.resourceOptions = MTLResourceStorageModeShared | MTLResourceHazardTrackingModeTracked | MTLResourceCPUCacheModeWriteCombined;
	CHECK(d.storageMode == MTLStorageModeShared && d.hazardTrackingMode == MTLHazardTrackingModeTracked && d.cpuCacheMode == MTLCPUCacheModeWriteCombined);
	d.size = 4096;
	d.type = MTLHeapTypePlacement;
	MTLHeapDescriptor* copy = [[d copy] autorelease];
	CHECK(copy.size == 4096 && copy.type == MTLHeapTypePlacement && copy.resourceOptions == d.resourceOptions);
}

static void testCreation(id<MTLDevice> device) {
	CHECK([device newHeapWithDescriptor: heapDescriptor(0, MTLStorageModePrivate, MTLHeapTypeAutomatic)] == nil);
	CHECK([device newHeapWithDescriptor: heapDescriptor((NSUInteger)1 << 50, MTLStorageModePrivate, MTLHeapTypeAutomatic)] == nil);
	if (onDarling()) {
		// macOS asserts on a managed or memoryless heap and creates a sparse one
		CHECK([device newHeapWithDescriptor: heapDescriptor(1 << 20, MTLStorageModeManaged, MTLHeapTypeAutomatic)] == nil);
		CHECK([device newHeapWithDescriptor: heapDescriptor(1 << 20, MTLStorageModeMemoryless, MTLHeapTypeAutomatic)] == nil);
		CHECK([device newHeapWithDescriptor: heapDescriptor(1 << 20, MTLStorageModePrivate, MTLHeapTypeSparse)] == nil);
	}

	for (int shared = 0; shared < 2; ++shared) {
		MTLStorageMode mode = shared ? MTLStorageModeShared : MTLStorageModePrivate;
		for (int placement = 0; placement < 2; ++placement) {
			id<MTLHeap> heap = [device newHeapWithDescriptor: heapDescriptor(100000, mode, placement ? MTLHeapTypePlacement : MTLHeapTypeAutomatic)];
			CHECK(heap != nil);
			CHECK(heap.device == device && heap.storageMode == mode && heap.type == (placement ? MTLHeapTypePlacement : MTLHeapTypeAutomatic));
			CHECK(heap.cpuCacheMode == MTLCPUCacheModeDefaultCache);
			// a default hazard tracking mode is untracked for a heap
			CHECK(heap.hazardTrackingMode == MTLHazardTrackingModeUntracked);
			CHECK((heap.resourceOptions & (0xf << MTLResourceStorageModeShift)) == (shared ? MTLResourceStorageModeShared : MTLResourceStorageModePrivate));
			CHECK(heap.size >= 100000 && heap.size % 4096 == 0 && heap.size < 100000 + 65536);
			CHECK(heap.currentAllocatedSize == heap.size);
			CHECK(heap.usedSize == 0);
			CHECK([heap maxAvailableSizeWithAlignment: 1] == (placement ? 0 : heap.size));
			heap.label = @"heap";
			CHECK([heap.label isEqualToString: @"heap"]);
			[heap release];
		}
	}

	MTLHeapDescriptor* tracked = heapDescriptor(65536, MTLStorageModePrivate, MTLHeapTypeAutomatic);
	tracked.hazardTrackingMode = MTLHazardTrackingModeTracked;
	id<MTLHeap> trackedHeap = [device newHeapWithDescriptor: tracked];
	CHECK(trackedHeap.hazardTrackingMode == MTLHazardTrackingModeTracked);
	// the resources of a heap have the heap's hazard tracking mode, whatever they ask for
	id<MTLBuffer> b = [trackedHeap newBufferWithLength: 100 options: MTLResourceStorageModePrivate | MTLResourceHazardTrackingModeUntracked];
	CHECK(b != nil && b.hazardTrackingMode == MTLHazardTrackingModeTracked);
	[b release];
	id<MTLHeap> untracked = [device newHeapWithDescriptor: heapDescriptor(65536, MTLStorageModePrivate, MTLHeapTypeAutomatic)];
	b = [untracked newBufferWithLength: 100 options: MTLResourceStorageModePrivate | MTLResourceHazardTrackingModeTracked];
	CHECK(b != nil && b.hazardTrackingMode == MTLHazardTrackingModeUntracked);
	[b release];
	[untracked release];
	[trackedHeap release];

	// -setPurgeableState: on a heap returns the previous state and applies the new one, unlike resources
	id<MTLHeap> heap = [device newHeapWithDescriptor: heapDescriptor(65536, MTLStorageModePrivate, MTLHeapTypeAutomatic)];
	CHECK([heap setPurgeableState: MTLPurgeableStateKeepCurrent] == MTLPurgeableStateNonVolatile);
	CHECK([heap setPurgeableState: MTLPurgeableStateVolatile] == MTLPurgeableStateNonVolatile);
	CHECK([heap setPurgeableState: MTLPurgeableStateKeepCurrent] == MTLPurgeableStateVolatile);
	CHECK([heap setPurgeableState: MTLPurgeableStateEmpty] == MTLPurgeableStateVolatile);
	CHECK([heap setPurgeableState: MTLPurgeableStateKeepCurrent] == MTLPurgeableStateEmpty);
	CHECK([heap setPurgeableState: MTLPurgeableStateNonVolatile] == MTLPurgeableStateEmpty);
	CHECK([heap setPurgeableState: MTLPurgeableStateKeepCurrent] == MTLPurgeableStateNonVolatile);
	[heap release];
}

static void testSizeAndAlign(id<MTLDevice> device) {
	NSUInteger lengths[] = { 1, 16, 255, 1000, 4096, 100000 };
	for (int i = 0; i < 6; ++i) {
		MTLSizeAndAlign sa = [device heapBufferSizeAndAlignWithLength: lengths[i] options: MTLResourceStorageModePrivate];
		CHECK(sa.size >= lengths[i] && sa.align != 0 && (sa.align & (sa.align - 1)) == 0);
	}
	MTLSizeAndAlign zero = [device heapBufferSizeAndAlignWithLength: 0 options: MTLResourceStorageModePrivate];
	CHECK(zero.size == 0 && zero.align != 0);
	CHECK([device heapBufferSizeAndAlignWithLength: 100000 options: MTLResourceStorageModePrivate].size > [device heapBufferSizeAndAlignWithLength: 1000 options: MTLResourceStorageModePrivate].size);

	MTLSizeAndAlign small = [device heapTextureSizeAndAlignWithDescriptor: textureDescriptor(8, 8, MTLStorageModePrivate)];
	MTLSizeAndAlign large = [device heapTextureSizeAndAlignWithDescriptor: textureDescriptor(256, 256, MTLStorageModePrivate)];
	CHECK(small.size >= 8 * 8 * 4 && large.size >= 256 * 256 * 4 && large.size > small.size);
	CHECK(small.align != 0 && (small.align & (small.align - 1)) == 0 && (large.align & (large.align - 1)) == 0);
	MTLTextureDescriptor* mips = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 256 height: 256 mipmapped: YES];
	mips.storageMode = MTLStorageModePrivate;
	CHECK([device heapTextureSizeAndAlignWithDescriptor: mips].size > large.size);
	MTLSizeAndAlign none = [device heapTextureSizeAndAlignWithDescriptor: nil];
	CHECK(none.size == 0 && none.align == 0);
}

static void testAutomatic(id<MTLDevice> device, id<MTLCommandQueue> queue, MTLStorageMode mode) {
	MTLResourceOptions options = mode == MTLStorageModeShared ? MTLResourceStorageModeShared : MTLResourceStorageModePrivate;
	id<MTLHeap> heap = [device newHeapWithDescriptor: heapDescriptor(1 << 20, mode, MTLHeapTypeAutomatic)];
	CHECK(heap != nil);
	MTLSizeAndAlign sa1000 = [device heapBufferSizeAndAlignWithLength: 1000 options: options];
	MTLSizeAndAlign sa5000 = [device heapBufferSizeAndAlignWithLength: 5000 options: options];
	MTLSizeAndAlign sa1 = [device heapBufferSizeAndAlignWithLength: 1 options: options];

	id<MTLBuffer> a = [heap newBufferWithLength: 1000 options: options];
	CHECK(a != nil && a.length == 1000 && a.heap == heap);
	// an automatic heap's resources have no heap offset, and the heap's storage and hazard tracking modes
	CHECK(a.heapOffset == 0 && a.storageMode == mode && a.hazardTrackingMode == MTLHazardTrackingModeUntracked);
	CHECK(a.allocatedSize == sa1000.size && !a.isAliasable);
	CHECK(heap.usedSize == sa1000.size);
	CHECK([heap maxAvailableSizeWithAlignment: 1] == heap.size - sa1000.size);
	CHECK([heap maxAvailableSizeWithAlignment: 65536] <= [heap maxAvailableSizeWithAlignment: 1]);
	id<MTLBuffer> b = [heap newBufferWithLength: 5000 options: options];
	id<MTLBuffer> c = [heap newBufferWithLength: 1 options: options];
	CHECK(b != nil && c != nil && b.heapOffset == 0 && c.heapOffset == 0);
	CHECK(heap.usedSize == sa1000.size + sa5000.size + sa1.size);

	MTLSizeAndAlign sat = [device heapTextureSizeAndAlignWithDescriptor: textureDescriptor(64, 64, mode)];
	id<MTLTexture> t = [heap newTextureWithDescriptor: textureDescriptor(64, 64, mode)];
	if (t != nil) {
		CHECK(t.heap == heap && t.heapOffset == 0 && t.allocatedSize == sat.size && t.storageMode == mode);
		CHECK(heap.usedSize == sa1000.size + sa5000.size + sa1.size + sat.size);
		id<MTLTexture> view = [t newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm_sRGB];
		CHECK(view != nil && view.heap == heap);
		[view release];
		[t release];
		CHECK(heap.usedSize == sa1000.size + sa5000.size + sa1.size);
	} else {
		printf("SKIP: no textures in a heap with this storage mode on this device\n");
	}

	// no overlap, through the CPU and through the GPU
	if (mode == MTLStorageModeShared) {
		fillPattern(a, 1);
		fillPattern(b, 2);
		fillPattern(c, 3);
		CHECK(hasPattern(a, 1) && hasPattern(b, 2) && hasPattern(c, 3));
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
		[blit copyFromBuffer: b sourceOffset: 0 toBuffer: a destinationOffset: 0 size: 1000];
		[blit endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		CHECK(memcmp(a.contents, b.contents, 1000) == 0 && hasPattern(c, 3));
	} else {
		id<MTLBuffer> readback = [device newBufferWithLength: 5000 options: MTLResourceStorageModeShared];
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
		[blit fillBuffer: a range: NSMakeRange(0, 1000) value: 0x11];
		[blit fillBuffer: b range: NSMakeRange(0, 5000) value: 0x22];
		[blit copyFromBuffer: a sourceOffset: 0 toBuffer: readback destinationOffset: 0 size: 1000];
		[blit endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		BOOL ok = YES;
		for (NSUInteger i = 0; i < 1000; ++i) ok = ok && ((uint8_t*)readback.contents)[i] == 0x11;
		CHECK(ok);
		[readback release];
	}

	// useHeap: is a residency hint
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLComputeCommandEncoder> compute = [commands computeCommandEncoder];
	[compute useHeap: heap];
	[compute endEncoding];
	[commands commit];
	[commands waitUntilCompleted];

	[b release];
	CHECK(heap.usedSize == sa1000.size + sa1.size);
	[c release];
	[a release];
	CHECK(heap.usedSize == 0 && [heap maxAvailableSizeWithAlignment: 1] == heap.size && [heap maxAvailableSizeWithAlignment: 65536] == heap.size);

	// fill the heap
	NSMutableArray* all = [NSMutableArray array];
	MTLSizeAndAlign sa100k = [device heapBufferSizeAndAlignWithLength: 100000 options: options];
	for (int i = 0; i < 1000; ++i) {
		id<MTLBuffer> x = [heap newBufferWithLength: 100000 options: options];
		if (x == nil) break;
		[all addObject: x];
		[x release];
	}
	CHECK(all.count >= heap.size / (sa100k.size + sa100k.align) && all.count <= heap.size / sa100k.size);
	CHECK(heap.usedSize == all.count * sa100k.size);
	CHECK([heap newBufferWithLength: 100000 options: options] == nil);
	CHECK([heap newBufferWithLength: heap.size + 1 options: options] == nil);
	CHECK([heap maxAvailableSizeWithAlignment: 1] < sa100k.size);
	[all removeAllObjects];
	CHECK(heap.usedSize == 0 && [heap maxAvailableSizeWithAlignment: 1] == heap.size);
	// the whole heap in one buffer
	NSUInteger longest = heap.size;
	while ([device heapBufferSizeAndAlignWithLength: longest options: options].size > heap.size) longest--;
	id<MTLBuffer> whole = [heap newBufferWithLength: longest options: options];
	CHECK(whole != nil && [heap maxAvailableSizeWithAlignment: 1] < sa1000.size);
	[whole release];

	// refusals: the wrong kind of heap, zero length
	CHECK([heap newBufferWithLength: 100 options: options offset: 0] == nil);
	CHECK([heap newTextureWithDescriptor: textureDescriptor(8, 8, mode) offset: 0] == nil);
	CHECK([heap newBufferWithLength: 0 options: options] == nil);
	CHECK([heap newTextureWithDescriptor: nil] == nil);
	CHECK(heap.usedSize == 0);

	// a resource keeps its heap alive
	id<MTLBuffer> kept = [heap newBufferWithLength: 100 options: options];
	[heap release];
	CHECK(kept.heap != nil && kept.heap.usedSize >= 100);
	if (mode == MTLStorageModeShared) {
		memset(kept.contents, 7, 100);
		CHECK(((uint8_t*)kept.contents)[99] == 7);
	}
	[kept release];
}

static void testAliasable(id<MTLDevice> device) {
	MTLSizeAndAlign half = [device heapBufferSizeAndAlignWithLength: 1 << 15 options: MTLResourceStorageModePrivate];
	id<MTLHeap> heap = [device newHeapWithDescriptor: heapDescriptor(alignUp(2 * half.size, 16384), MTLStorageModePrivate, MTLHeapTypeAutomatic)];
	id<MTLBuffer> a = [heap newBufferWithLength: 1 << 15 options: MTLResourceStorageModePrivate];
	id<MTLBuffer> b = [heap newBufferWithLength: 1 << 15 options: MTLResourceStorageModePrivate];
	CHECK(a != nil && b != nil && !a.isAliasable && !b.isAliasable);
	CHECK(heap.usedSize == 2 * half.size);
	[a makeAliasable];
	CHECK(a.isAliasable && !b.isAliasable && a.heap == heap);
	CHECK(heap.usedSize == half.size);
	CHECK([heap maxAvailableSizeWithAlignment: 1] >= half.size);
	// the freed memory is reused
	id<MTLBuffer> c = [heap newBufferWithLength: 1 << 15 options: MTLResourceStorageModePrivate];
	CHECK(c != nil && heap.usedSize == 2 * half.size);
	[a makeAliasable];
	CHECK(heap.usedSize == 2 * half.size);
	[a release];
	CHECK(heap.usedSize == 2 * half.size);
	[b release];
	[c release];
	CHECK(heap.usedSize == 0);
	[heap release];

	// any other resource ignores makeAliasable
	id<MTLBuffer> plain = [device newBufferWithLength: 100 options: MTLResourceStorageModePrivate];
	[plain makeAliasable];
	CHECK(!plain.isAliasable && plain.heap == nil && plain.heapOffset == 0 && plain.allocatedSize >= 100);
	[plain release];
	id<MTLTexture> plainTexture = [device newTextureWithDescriptor: textureDescriptor(8, 8, MTLStorageModePrivate)];
	CHECK(!plainTexture.isAliasable && plainTexture.heap == nil && plainTexture.heapOffset == 0 && plainTexture.allocatedSize > 0);
	[plainTexture release];
}

static void testPlacement(id<MTLDevice> device, id<MTLCommandQueue> queue, MTLStorageMode mode) {
	MTLResourceOptions options = mode == MTLStorageModeShared ? MTLResourceStorageModeShared : MTLResourceStorageModePrivate;
	id<MTLHeap> heap = [device newHeapWithDescriptor: heapDescriptor(1 << 20, mode, MTLHeapTypePlacement)];
	CHECK(heap != nil);
	MTLSizeAndAlign sa = [device heapBufferSizeAndAlignWithLength: 1000 options: options];

	CHECK([heap newBufferWithLength: 1000 options: options] == nil);
	CHECK([heap newTextureWithDescriptor: textureDescriptor(8, 8, mode)] == nil);

	id<MTLBuffer> a = [heap newBufferWithLength: 1000 options: options offset: 0];
	CHECK(a != nil && a.heap == heap && a.heapOffset == 0 && a.allocatedSize == sa.size);
	CHECK(heap.usedSize == 0 && [heap maxAvailableSizeWithAlignment: 1] == 0);
	// resources of a placement heap are aliasable from the start
	CHECK(a.isAliasable);

	// aligned offsets; unaligned and out of range ones are refused
	BOOL aligned = YES;
	for (NSUInteger offset = sa.align; offset < heap.size / 2; offset *= 2) {
		id<MTLBuffer> x = [heap newBufferWithLength: 16 options: options offset: offset];
		aligned = aligned && x != nil && x.heapOffset == offset;
		[x release];
	}
	CHECK(aligned);
	CHECK([heap newBufferWithLength: 16 options: options offset: sa.align + 1] == nil);
	CHECK([heap newBufferWithLength: 16 options: options offset: 7] == nil);
	CHECK([heap newBufferWithLength: 1000 options: options offset: heap.size] == nil);
	CHECK([heap newBufferWithLength: 1000 options: options offset: heap.size - 16] == nil);
	NSUInteger end = (heap.size - sa.size) / sa.align * sa.align;
	id<MTLBuffer> last = [heap newBufferWithLength: 1000 options: options offset: end];
	CHECK(last != nil && last.heapOffset == end);
	[last release];
	CHECK([heap newBufferWithLength: 1000 options: options offset: end + sa.align] == nil);

	if (mode == MTLStorageModeShared) {
		// two buffers at one offset are the same memory
		id<MTLBuffer> b = [heap newBufferWithLength: 1000 options: options offset: 0];
		CHECK(b != nil && b.isAliasable && a.contents == b.contents);
		fillPattern(a, 9);
		CHECK(hasPattern(b, 9));
		id<MTLBuffer> next = [heap newBufferWithLength: 1000 options: options offset: alignUp(sa.size, sa.align)];
		fillPattern(next, 77);
		CHECK(hasPattern(a, 9) && hasPattern(next, 77));
		[next release];
		[b release];
	} else {
		// fill through one buffer, read through the other, with the GPU
		id<MTLBuffer> first = [heap newBufferWithLength: 4096 options: options offset: 4096 * 4];
		id<MTLBuffer> second = [heap newBufferWithLength: 4096 options: options offset: 4096 * 4];
		id<MTLBuffer> readback = [device newBufferWithLength: 4096 options: MTLResourceStorageModeShared];
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
		[blit fillBuffer: first range: NSMakeRange(0, 4096) value: 0xc3];
		[blit copyFromBuffer: second sourceOffset: 0 toBuffer: readback destinationOffset: 0 size: 4096];
		[blit endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		BOOL ok = first != nil && second != nil;
		for (NSUInteger i = 0; i < 4096; ++i) ok = ok && ((uint8_t*)readback.contents)[i] == 0xc3;
		CHECK(ok);
		[first release];
		[second release];
		[readback release];
	}
	[a release];

	// textures
	MTLTextureDescriptor* descriptor = textureDescriptor(16, 16, mode);
	MTLSizeAndAlign sat = [device heapTextureSizeAndAlignWithDescriptor: descriptor];
	NSUInteger step = sat.align > 256 ? sat.align : 256;
	NSUInteger at = alignUp(1 << 17, step);
	id<MTLTexture> t1 = [heap newTextureWithDescriptor: descriptor offset: at];
	if (t1 == nil) {
		printf("SKIP: no textures in a placement heap of this storage mode on this device\n");
		[heap release];
		return;
	}
	CHECK(t1.heap == heap && t1.heapOffset == at && t1.allocatedSize == sat.size && t1.isAliasable);
	CHECK([heap newTextureWithDescriptor: descriptor offset: at + 1] == nil);
	CHECK([heap newTextureWithDescriptor: descriptor offset: heap.size] == nil);
	id<MTLTexture> t2 = [heap newTextureWithDescriptor: descriptor offset: at];
	CHECK(t2 != nil && t2.isAliasable && t2.heapOffset == at);
	if (mode == MTLStorageModeShared) {
		uint32_t pixels[256], out[256];
		for (int i = 0; i < 256; ++i) pixels[i] = 0x11223300 + i;
		[t1 replaceRegion: MTLRegionMake2D(0, 0, 16, 16) mipmapLevel: 0 withBytes: pixels bytesPerRow: 64];
		memset(out, 0, sizeof(out));
		[t2 getBytes: out bytesPerRow: 64 fromRegion: MTLRegionMake2D(0, 0, 16, 16) mipmapLevel: 0];
		CHECK(memcmp(out, pixels, sizeof(out)) == 0);
	} else if (t2 != nil) {
		clearTexture(queue, t1, 1.0);
		CHECK(firstPixel(device, queue, t1) == 0xffff00ffu);
		clearTexture(queue, t2, 0.0);
		CHECK(firstPixel(device, queue, t2) == 0xffff0000u);
		// aliasing textures of one format and size: what one holds is read through the other
		CHECK(firstPixel(device, queue, t1) == 0xffff0000u);
	}
	[t1 release];
	[t2 release];
	[heap release];
}

static void testTextures(id<MTLDevice> device, id<MTLCommandQueue> queue) {
	id<MTLHeap> heap = [device newHeapWithDescriptor: heapDescriptor(1 << 20, MTLStorageModePrivate, MTLHeapTypeAutomatic)];
	id<MTLTexture> t1 = [heap newTextureWithDescriptor: textureDescriptor(64, 64, MTLStorageModePrivate)];
	id<MTLTexture> t2 = [heap newTextureWithDescriptor: textureDescriptor(64, 64, MTLStorageModePrivate)];
	CHECK(t1 != nil && t2 != nil);
	clearTexture(queue, t1, 1.0);
	clearTexture(queue, t2, 0.0);
	// two textures of an automatic heap are separate memory
	CHECK(firstPixel(device, queue, t1) == 0xffff00ffu && firstPixel(device, queue, t2) == 0xffff0000u);
	// a texture the heap has no room for
	CHECK([heap newTextureWithDescriptor: textureDescriptor(4096, 4096, MTLStorageModePrivate)] == nil);
	CHECK([heap newTextureWithDescriptor: textureDescriptor(8, 8, MTLStorageModePrivate)] != nil);
	[t1 release];
	[t2 release];
	[heap release];
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];

		testDescriptor();
		testCreation(device);
		testSizeAndAlign(device);
		testAutomatic(device, queue, MTLStorageModeShared);
		testAutomatic(device, queue, MTLStorageModePrivate);
		testAliasable(device);
		testPlacement(device, queue, MTLStorageModeShared);
		testPlacement(device, queue, MTLStorageModePrivate);
		testTextures(device, queue);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
