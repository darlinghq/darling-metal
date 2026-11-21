// Copyright (C) 2026 Lubos Dolezel
// MTLTexture.usage reports the usage the texture was created with.
//
// Documented contract (the Metal framework reference): the usage property of a texture holds the options
// the texture was created with (MTLTextureDescriptor.usage, whose default is MTLTextureUsageShaderRead); a texture
// view has the usage of its parent.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLTexture> make(id<MTLDevice> device, MTLPixelFormat format, MTLTextureUsage usage, BOOL setUsage) {
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: format width: 8 height: 8 mipmapped: NO];
	d.storageMode = MTLStorageModePrivate;
	if (setUsage)
		d.usage = usage;
	return [device newTextureWithDescriptor: d];
}

int main(void) {
	@autoreleasepool {
		MTLTextureDescriptor* defaults = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 8 height: 8 mipmapped: NO];
		CHECK(defaults.usage == MTLTextureUsageShaderRead);

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf(failures ? "FAILED: %d\n" : "SKIP: no Metal device\n", failures);
			return failures ? 1 : 77;
		}

		// the default descriptor, then each documented combination
		id<MTLTexture> plain = make(device, MTLPixelFormatRGBA8Unorm, 0, NO);
		CHECK(plain != nil && plain.usage == MTLTextureUsageShaderRead);

		MTLTextureUsage combinations[] = {
			MTLTextureUsageShaderRead,
			MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite,
			MTLTextureUsageRenderTarget,
			MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget,
			MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget,
			MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView,
			MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsagePixelFormatView,
		};
		for (size_t i = 0; i < sizeof(combinations) / sizeof(combinations[0]); i++) {
			id<MTLTexture> t = make(device, MTLPixelFormatRGBA8Unorm, combinations[i], YES);
			CHECK(t != nil);
			if (t != nil && t.usage != combinations[i])
				printf("usage 0x%lx reads back 0x%lx\n", (unsigned long)combinations[i], (unsigned long)t.usage);
			CHECK(t != nil && t.usage == combinations[i]);
		}

		// a depth format
		id<MTLTexture> depth = make(device, MTLPixelFormatDepth32Float, MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead, YES);
		CHECK(depth != nil && depth.usage == (MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead));

		// a view has the usage of its parent
		id<MTLTexture> parent = make(device, MTLPixelFormatRGBA8Unorm, MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsagePixelFormatView, YES);
		id<MTLTexture> view = [parent newTextureViewWithPixelFormat: MTLPixelFormatRGBA8Unorm_sRGB];
		CHECK(view != nil && view.usage == parent.usage);

		// a texture made from a buffer
		id<MTLBuffer> buffer = [device newBufferWithLength: 8 * 8 * 4 options: MTLResourceStorageModeShared];
		MTLTextureDescriptor* bd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 8 height: 8 mipmapped: NO];
		bd.storageMode = MTLStorageModeShared;
		bd.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
		id<MTLTexture> fromBuffer = [buffer newTextureWithDescriptor: bd offset: 0 bytesPerRow: 8 * 4];
		if (fromBuffer != nil)
			CHECK(fromBuffer.usage == (MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite));
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
