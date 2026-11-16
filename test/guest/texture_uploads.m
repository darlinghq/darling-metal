// Copyright (C) 2026 Lubos Dolezel
// MTLTexture replaceRegion:/getBytes: ordering and views. replaceRegion is a CPU write that is complete when it
// returns: GPU work committed afterwards sees it, so does a command buffer committed earlier that has not started
// (it waits for an event), getBytes returns it at once, and a GPU write that completes afterwards is the last
// word. On a texture view, level and slice arguments address the texture's levels and slices from where the view
// starts, and a view of another pixel format of the same texel size passes the bytes through unchanged.
// The expectations follow the documented contract and what macOS 27.0.1 (Apple silicon) does (checked by
// compiling this file there). The checks with a held command buffer need MTLSharedEvent and are skipped when the
// device has none. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <string.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;

static NSMutableData* pattern(NSUInteger count, uint8_t base) {
	NSMutableData* data = [NSMutableData dataWithLength: count];
	uint8_t* p = data.mutableBytes;
	for (NSUInteger i = 0; i < count; i++) p[i] = (uint8_t)(base + i * 7);
	return data;
}

static MTLTextureDescriptor* descriptor(NSUInteger w, NSUInteger h, NSUInteger levels) {
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: w height: h mipmapped: NO];
	d.mipmapLevelCount = levels;
	d.storageMode = MTLStorageModeShared;
	d.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsagePixelFormatView;
	return d;
}

static void put(id<MTLTexture> t, NSUInteger w, NSUInteger h, NSData* bytes, NSUInteger level, NSUInteger slice) {
	[t replaceRegion: MTLRegionMake2D(0, 0, w, h) mipmapLevel: level slice: slice withBytes: bytes.bytes bytesPerRow: w * 4 bytesPerImage: 0];
}

static NSData* get(id<MTLTexture> t, NSUInteger w, NSUInteger h, NSUInteger level, NSUInteger slice) {
	NSMutableData* data = [NSMutableData dataWithLength: w * h * 4];
	memset(data.mutableBytes, 0xee, data.length);
	[t getBytes: data.mutableBytes bytesPerRow: w * 4 bytesPerImage: 0 fromRegion: MTLRegionMake2D(0, 0, w, h) mipmapLevel: level slice: slice];
	return data;
}

static void clearTexture(id<MTLCommandBuffer> commands, id<MTLTexture> texture) {
	MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = texture;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	pass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1);
	[[commands renderCommandEncoderWithDescriptor: pass] endEncoding];
}

static void copyOut(id<MTLCommandBuffer> commands, id<MTLTexture> t, id<MTLBuffer> out, NSUInteger w, NSUInteger h, NSUInteger slice, NSUInteger level) {
	id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
	[blit copyFromTexture: t sourceSlice: slice sourceLevel: level sourceOrigin: MTLOriginMake(0, 0, 0) sourceSize: MTLSizeMake(w, h, 1)
	             toBuffer: out destinationOffset: 0 destinationBytesPerRow: w * 4 destinationBytesPerImage: w * h * 4];
	[blit endEncoding];
}

static id<MTLBuffer> outBuffer(NSUInteger size) {
	id<MTLBuffer> b = [device newBufferWithLength: size options: MTLResourceStorageModeShared];
	memset(b.contents, 0xee, size);
	return b;
}

static void roundTrips(void) {
	id<MTLTexture> t = [device newTextureWithDescriptor: descriptor(8, 6, 1)];
	NSData* bytes = pattern(8 * 6 * 4, 1);
	put(t, 8, 6, bytes, 0, 0);
	CHECK([get(t, 8, 6, 0, 0) isEqualToData: bytes]);

	// a sub-region from rows that are further apart than the region is wide
	put(t, 8, 6, [NSMutableData dataWithLength: 8 * 6 * 4], 0, 0);
	uint8_t source[64];
	memset(source, 0xcc, sizeof source);
	for (int i = 0; i < 12; i++) { source[i] = 0x40 + i; source[32 + i] = 0x60 + i; }
	[t replaceRegion: MTLRegionMake2D(2, 3, 3, 2) mipmapLevel: 0 withBytes: source bytesPerRow: 32];
	NSData* got = get(t, 8, 6, 0, 0);
	const uint8_t* g = got.bytes;
	BOOL ok = YES;
	for (int y = 0; y < 6; y++) for (int x = 0; x < 8; x++) for (int c = 0; c < 4; c++) {
		BOOL inside = x >= 2 && x < 5 && y >= 3 && y < 5;
		uint8_t want = inside ? source[(y - 3) * 32 + (x - 2) * 4 + c] : 0;
		ok = ok && g[(y * 8 + x) * 4 + c] == want;
	}
	CHECK(ok);

	// overlapping writes land in call order
	id<MTLTexture> o = [device newTextureWithDescriptor: descriptor(4, 4, 1)];
	put(o, 4, 4, pattern(64, 1), 0, 0);
	put(o, 4, 4, pattern(64, 2), 0, 0);
	NSMutableData* want = [pattern(64, 2) mutableCopy];
	NSData* inner = pattern(16, 0x77);
	[o replaceRegion: MTLRegionMake2D(1, 1, 2, 2) mipmapLevel: 0 withBytes: inner.bytes bytesPerRow: 8];
	memcpy((uint8_t*)want.mutableBytes + 20, inner.bytes, 8);
	memcpy((uint8_t*)want.mutableBytes + 36, (const uint8_t*)inner.bytes + 8, 8);
	CHECK([get(o, 4, 4, 0, 0) isEqualToData: want]);

	// every level and slice keeps its own bytes
	MTLTextureDescriptor* d = descriptor(8, 8, 3);
	d.textureType = MTLTextureType2DArray;
	d.arrayLength = 3;
	id<MTLTexture> a = [device newTextureWithDescriptor: d];
	ok = YES;
	for (NSUInteger l = 0; l < 3; l++) for (NSUInteger s = 0; s < 3; s++) put(a, 8 >> l, 8 >> l, pattern((8 >> l) * (8 >> l) * 4, 0x10 * (l + 1) + s), l, s);
	for (NSUInteger l = 0; l < 3; l++) for (NSUInteger s = 0; s < 3; s++) ok = ok && [get(a, 8 >> l, 8 >> l, l, s) isEqualToData: pattern((8 >> l) * (8 >> l) * 4, 0x10 * (l + 1) + s)];
	CHECK(ok);
}

static void manyWrites(void) {
	id<MTLTexture> t = [device newTextureWithDescriptor: descriptor(64, 64, 1)];
	NSMutableData* want = [NSMutableData dataWithLength: 64 * 64 * 4];
	put(t, 64, 64, want, 0, 0);
	for (int i = 0; i < 1000; i++) {
		NSUInteger x = (i * 7) % 64, y = (i * 13) % 64;
		uint8_t texel[4] = { (uint8_t)i, (uint8_t)(i >> 8), (uint8_t)(i * 3), 255 };
		[t replaceRegion: MTLRegionMake2D(x, y, 1, 1) mipmapLevel: 0 withBytes: texel bytesPerRow: 4];
		memcpy((uint8_t*)want.mutableBytes + (y * 64 + x) * 4, texel, 4);
	}
	id<MTLBuffer> out = outBuffer(64 * 64 * 4);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	copyOut(commands, t, out, 64, 64, 0, 0);
	[commands commit];
	[commands waitUntilCompleted];
	CHECK(memcmp(out.contents, want.bytes, want.length) == 0);
	CHECK([get(t, 64, 64, 0, 0) isEqualToData: want]);

	NSMutableData* big = pattern(1024 * 1024 * 4, 5);
	id<MTLTexture> b = [device newTextureWithDescriptor: descriptor(1024, 1024, 1)];
	put(b, 1024, 1024, big, 0, 0);
	CHECK([get(b, 1024, 1024, 0, 0) isEqualToData: big]);
}

static void ordering(void) {
	id<MTLBuffer> out = outBuffer(64);
	id<MTLTexture> t = [device newTextureWithDescriptor: descriptor(4, 4, 1)];
	put(t, 4, 4, pattern(64, 0x10), 0, 0);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	copyOut(commands, t, out, 4, 4, 0, 0);
	[commands commit];
	[commands waitUntilCompleted];
	CHECK(memcmp(out.contents, pattern(64, 0x10).bytes, 64) == 0);

	if (![device respondsToSelector: @selector(newSharedEvent)]) {
		printf("SKIP the checks with a held command buffer: no MTLSharedEvent\n");
		return;
	}

	// committed first and held back by an event, written afterwards: the reader sees the later write
	{
		id<MTLTexture> r = [device newTextureWithDescriptor: descriptor(4, 4, 1)];
		id<MTLSharedEvent> event = [device newSharedEvent];
		memset(out.contents, 0xee, 64);
		put(r, 4, 4, pattern(64, 0x10), 0, 0);
		id<MTLCommandBuffer> held = [queue commandBuffer];
		[held encodeWaitForEvent: event value: 1];
		copyOut(held, r, out, 4, 4, 0, 0);
		[held commit];
		usleep(100000);
		put(r, 4, 4, pattern(64, 0x80), 0, 0);
		event.signaledValue = 1;
		[held waitUntilCompleted];
		CHECK(memcmp(out.contents, pattern(64, 0x80).bytes, 64) == 0);
	}
	// a held command buffer that clears the texture: getBytes before it ran returns the write, the clear is the last word
	{
		id<MTLTexture> r = [device newTextureWithDescriptor: descriptor(4, 4, 1)];
		id<MTLSharedEvent> event = [device newSharedEvent];
		put(r, 4, 4, pattern(64, 0x10), 0, 0);
		id<MTLCommandBuffer> held = [queue commandBuffer];
		[held encodeWaitForEvent: event value: 1];
		clearTexture(held, r);
		[held commit];
		usleep(100000);
		put(r, 4, 4, pattern(64, 0x80), 0, 0);
		CHECK([get(r, 4, 4, 0, 0) isEqualToData: pattern(64, 0x80)]);
		event.signaledValue = 1;
		[held waitUntilCompleted];
		const uint32_t* px = [get(r, 4, 4, 0, 0) bytes];
		BOOL allRed = YES;
		for (int i = 0; i < 16; i++) allRed = allRed && px[i] == 0xff0000ff;
		CHECK(allRed);
	}
	// a write after a completed GPU write changes only its region
	{
		id<MTLTexture> r = [device newTextureWithDescriptor: descriptor(4, 4, 1)];
		id<MTLCommandBuffer> c = [queue commandBuffer];
		clearTexture(c, r);
		[c commit];
		[c waitUntilCompleted];
		uint8_t two[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
		[r replaceRegion: MTLRegionMake2D(1, 1, 2, 1) mipmapLevel: 0 withBytes: two bytesPerRow: 8];
		NSData* got = get(r, 4, 4, 0, 0);
		const uint32_t* px = got.bytes;
		CHECK(px[4] == 0xff0000ff && memcmp((const uint8_t*)got.bytes + 20, two, 8) == 0);
	}
}

static void views(void) {
	MTLTextureDescriptor* d = descriptor(8, 8, 3);
	d.textureType = MTLTextureType2DArray;
	d.arrayLength = 6;
	id<MTLTexture> base = [device newTextureWithDescriptor: d];
	for (NSUInteger l = 0; l < 3; l++) for (NSUInteger s = 0; s < 6; s++) put(base, 8 >> l, 8 >> l, [NSMutableData dataWithLength: (8 >> l) * (8 >> l) * 4], l, s);

	id<MTLTexture> v1 = [base newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm textureType: MTLTextureType2DArray levels: NSMakeRange(1, 2) slices: NSMakeRange(2, 3)];
	CHECK(v1.width == 4 && v1.height == 4);
	put(v1, 4, 4, pattern(64, 0x40), 0, 1);
	CHECK([get(base, 4, 4, 1, 3) isEqualToData: pattern(64, 0x40)]);
	BOOL others = YES;
	for (NSUInteger s = 0; s < 6; s++) if (s != 3) others = others && [get(base, 4, 4, 1, s) isEqualToData: [NSMutableData dataWithLength: 64]];
	CHECK(others);
	CHECK([get(v1, 4, 4, 0, 1) isEqualToData: pattern(64, 0x40)]);

	MTLPixelFormat formats[3] = { MTLPixelFormatBGRA8Unorm, MTLPixelFormatRGBA8Unorm_sRGB, MTLPixelFormatRGBA8Snorm };
	for (int i = 0; i < 3; i++) {
		id<MTLTexture> v = [base newTextureViewWithPixelFormat: formats[i] textureType: MTLTextureType2DArray levels: NSMakeRange(0, 1) slices: NSMakeRange(0, 1)];
		put(v, 8, 8, pattern(256, 0x21 + i), 0, 0);
		CHECK([get(base, 8, 8, 0, 0) isEqualToData: pattern(256, 0x21 + i)]);
		put(base, 8, 8, pattern(256, 0x91), 0, 0);
		CHECK([get(v, 8, 8, 0, 0) isEqualToData: pattern(256, 0x91)]);
	}

	id<MTLTexture> v2d = [base newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm textureType: MTLTextureType2D levels: NSMakeRange(1, 1) slices: NSMakeRange(4, 1)];
	[v2d replaceRegion: MTLRegionMake2D(0, 0, 4, 4) mipmapLevel: 0 withBytes: pattern(64, 0x40).bytes bytesPerRow: 16];
	CHECK([get(base, 4, 4, 1, 4) isEqualToData: pattern(64, 0x40)]);

	id<MTLTexture> vv = [v1 newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm textureType: MTLTextureType2DArray levels: NSMakeRange(1, 1) slices: NSMakeRange(1, 2)];
	put(vv, 2, 2, pattern(16, 0x70), 0, 1);
	CHECK([get(base, 2, 2, 2, 4) isEqualToData: pattern(16, 0x70)]);

	id<MTLTexture> cube = [base newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm textureType: MTLTextureTypeCube levels: NSMakeRange(0, 1) slices: NSMakeRange(0, 6)];
	put(cube, 8, 8, pattern(256, 0x33), 0, 5);
	CHECK([get(base, 8, 8, 0, 5) isEqualToData: pattern(256, 0x33)]);

	// a write through a view is in the next GPU read of the texture
	id<MTLTexture> slice1 = [base newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm textureType: MTLTextureType2DArray levels: NSMakeRange(0, 1) slices: NSMakeRange(1, 1)];
	put(slice1, 8, 8, pattern(256, 0x66), 0, 0);
	id<MTLBuffer> out = outBuffer(256);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	copyOut(commands, base, out, 8, 8, 1, 0);
	[commands commit];
	[commands waitUntilCompleted];
	CHECK(memcmp(out.contents, pattern(256, 0x66).bytes, 256) == 0);
}

int main(void) {
	@autoreleasepool {
		device = MTLCreateSystemDefaultDevice();
		if (!device) { printf("SKIP no Metal device\n"); return 77; }
		queue = [device newCommandQueue];
		roundTrips();
		manyWrites();
		ordering();
		views();
		if (failures) { printf("FAILED: %d\n", failures); return 1; }
		printf("OK\n");
	}
	return 0;
}
