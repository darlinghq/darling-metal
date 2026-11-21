// Copyright (C) 2026 Lubos Dolezel
// -[MTLTexture getBytes:bytesPerRow:fromRegion:mipmapLevel:] on a block-compressed texture.
//
// Documented contract (the Metal framework reference and the Metal feature set tables): the texels of a block-compressed
// format (BC1, BC3, BC7 here) are stored in blocks of 4x4 texels, and bytesPerRow is the number of bytes from one
// row of blocks to the next. getBytes is the read direction of replaceRegion, so the bytes written with
// replaceRegion come back unchanged. A bytesPerRow that is not a whole number of blocks, or a region whose
// origin is not on a block boundary, is a programming error that Metal raises.
// Exits 77 when there is no Metal device (or the device has no BC formats).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static void fill(uint8_t* p, size_t n, uint32_t seed) {
	uint32_t x = seed * 2654435761u + 12345u;
	for (size_t i = 0; i < n; i++) {
		x = x * 1664525u + 1013904223u;
		p[i] = (uint8_t)(x >> 24);
	}
}

// the round trip of the whole of one mip level of a width x height texture, with a bytesPerRow of `pitchBlocks` blocks
static void roundTrip(id<MTLDevice> device, MTLPixelFormat format, size_t blockBytes, size_t width, size_t height, size_t level, size_t extraBlocks, MTLTextureUsage usage, const char* name) {
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: format width: width height: height mipmapped: level > 0];
	d.storageMode = MTLStorageModeManaged;
	d.usage = usage;
	id<MTLTexture> t = [device newTextureWithDescriptor: d];
	CHECK(t != nil);
	if (t == nil)
		return;
	size_t w = MAX(width >> level, 1), h = MAX(height >> level, 1);
	size_t blocksX = (w + 3) / 4, blocksY = (h + 3) / 4;
	size_t pitch = (blocksX + extraBlocks) * blockBytes;
	NSMutableData* source = [NSMutableData dataWithLength: pitch * blocksY];
	fill(source.mutableBytes, source.length, (uint32_t)(blockBytes * 7 + width + level));
	MTLRegion region = MTLRegionMake2D(0, 0, w, h);
	[t replaceRegion: region mipmapLevel: level withBytes: source.bytes bytesPerRow: pitch];

	NSMutableData* back = [NSMutableData dataWithLength: pitch * blocksY];
	BOOL raised = NO;
	@try {
		[t getBytes: back.mutableBytes bytesPerRow: pitch fromRegion: region mipmapLevel: level];
	} @catch (NSException* x) {
		raised = YES;
		printf("%s: raised: %s\n", name, [[x description] UTF8String]);
	}
	CHECK(!raised);
	// the bytes of every block row, without the padding of a row that is longer than the blocks
	int bad = 0;
	for (size_t row = 0; row < blocksY; row++)
		bad += memcmp((const uint8_t*)source.bytes + row * pitch, (const uint8_t*)back.bytes + row * pitch, blocksX * blockBytes) != 0;
	if (bad)
		printf("%s: %d of %zu block rows differ\n", name, bad, blocksY);
	CHECK(bad == 0);
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		struct { MTLPixelFormat format; size_t bytes; const char* name; } formats[] = {
			{ MTLPixelFormatBC1_RGBA, 8, "BC1" },
			{ MTLPixelFormatBC3_RGBA, 16, "BC3" },
			{ MTLPixelFormatBC7_RGBAUnorm, 16, "BC7" },
		};
		for (size_t i = 0; i < 3; i++) {
			MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: formats[i].format width: 16 height: 16 mipmapped: NO];
			d.storageMode = MTLStorageModeManaged;
			if ([device newTextureWithDescriptor: d] == nil) {
				printf("SKIP: no %s texture support\n", formats[i].name);
				return 77;
			}
		}

		for (size_t i = 0; i < 3; i++) {
			char name[64];
			MTLPixelFormat f = formats[i].format;
			size_t b = formats[i].bytes;
			snprintf(name, sizeof name, "%s 16x16", formats[i].name);
			roundTrip(device, f, b, 16, 16, 0, 0, MTLTextureUsageShaderRead, name);
			snprintf(name, sizeof name, "%s 16x16, row padding", formats[i].name);
			roundTrip(device, f, b, 16, 16, 0, 2, MTLTextureUsageShaderRead, name);
			// a size that is not a multiple of the block, and a smaller level of it
			snprintf(name, sizeof name, "%s 10x6", formats[i].name);
			roundTrip(device, f, b, 10, 6, 0, 0, MTLTextureUsageShaderRead, name);
			snprintf(name, sizeof name, "%s 40x24 level 2", formats[i].name);
			roundTrip(device, f, b, 40, 24, 2, 1, MTLTextureUsageShaderRead, name);
			// the usage an application gives every texture
			snprintf(name, sizeof name, "%s 16x16, blanket usage", formats[i].name);
			roundTrip(device, f, b, 16, 16, 0, 0, MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsagePixelFormatView, name);
		}

		// a sub-region on block boundaries
		{
			MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBC3_RGBA width: 16 height: 16 mipmapped: NO];
			d.storageMode = MTLStorageModeManaged;
			id<MTLTexture> t = [device newTextureWithDescriptor: d];
			uint8_t all[4 * 4 * 16];
			fill(all, sizeof all, 99);
			[t replaceRegion: MTLRegionMake2D(0, 0, 16, 16) mipmapLevel: 0 withBytes: all bytesPerRow: 4 * 16];
			uint8_t part[2 * 2 * 16];
			memset(part, 0, sizeof part);
			[t getBytes: part bytesPerRow: 2 * 16 fromRegion: MTLRegionMake2D(4, 8, 8, 8) mipmapLevel: 0];
			// blocks (1,2) (2,2) (1,3) (2,3) of the 4x4 block grid
			CHECK(memcmp(part, all + (2 * 4 + 1) * 16, 2 * 16) == 0);
			CHECK(memcmp(part + 2 * 16, all + (3 * 4 + 1) * 16, 2 * 16) == 0);
		}

		// documented programming errors are raised, not turned into wrong data
		{
			MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBC1_RGBA width: 16 height: 16 mipmapped: NO];
			d.storageMode = MTLStorageModeManaged;
			id<MTLTexture> t = [device newTextureWithDescriptor: d];
			uint8_t bytes[4 * 4 * 8 + 64];
			BOOL raised = NO;
			@try {
				[t getBytes: bytes bytesPerRow: 4 * 8 + 3 fromRegion: MTLRegionMake2D(0, 0, 16, 16) mipmapLevel: 0];
			} @catch (NSException* x) { raised = YES; }
			CHECK(raised);
			raised = NO;
			@try {
				[t getBytes: bytes bytesPerRow: 4 * 8 fromRegion: MTLRegionMake2D(2, 0, 8, 8) mipmapLevel: 0];
			} @catch (NSException* x) { raised = YES; }
			CHECK(raised);
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
