// Copyright (C) 2026 Lubos Dolezel
// MTLDevice feature queries (32-bit float filtering, BC compression, pull-model interpolation,
// programmable sample positions, raster order groups, location, counter sets). The answers claimed as YES must be backed by working textures.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLTexture> makeTexture(id<MTLDevice> device, MTLPixelFormat format) {
	MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: format width: 16 height: 16 mipmapped: NO];
	d.usage = MTLTextureUsageShaderRead;
	return [device newTextureWithDescriptor: d];
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}

		// what the backend cannot lower stays NO
		CHECK(device.supportsPullModelInterpolation == NO);
		CHECK(device.areProgrammableSamplePositionsSupported == NO);
		CHECK(device.areRasterOrderGroupsSupported == NO);

		// a YES must be backed by textures that can be made
		if (device.supports32BitFloatFiltering) {
			CHECK(makeTexture(device, MTLPixelFormatR32Float) != nil);
			CHECK(makeTexture(device, MTLPixelFormatRGBA32Float) != nil);
		}
		if (device.supportsBCTextureCompression) {
			CHECK(makeTexture(device, MTLPixelFormatBC1_RGBA) != nil);
			CHECK(makeTexture(device, MTLPixelFormatBC7_RGBAUnorm) != nil);
		}

		MTLDeviceLocation location = device.location;
		CHECK(location == MTLDeviceLocationBuiltIn || location == MTLDeviceLocationSlot
			|| location == MTLDeviceLocationExternal || location == MTLDeviceLocationUnspecified);
		if (location == MTLDeviceLocationBuiltIn) {
			CHECK(device.locationNumber == (device.isLowPower ? 0 : 1));
		} else {
			CHECK(device.locationNumber == 0);
		}

		// no counter sets: nil, which iterates as empty
		CHECK(device.counterSets == nil);
		CHECK(device.counterSets.count == 0);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
