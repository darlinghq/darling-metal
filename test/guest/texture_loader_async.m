// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// MTKTextureLoader completion-handler loaders and the synchronous URL-array loader, from the documented contract
// (https://developer.apple.com/documentation/metalkit/mtktextureloader): a single-texture handler gets a texture
// and a nil error, or a nil texture and an error; an array handler gets one entry per request in request order,
// an NSNull in the place of a failed one, and the first failure as the error (nil when everything loaded).
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static const size_t kWidth = 4, kHeight = 2;

static CGImageRef makeImage(void) {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, kWidth, kHeight, 8, 0, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(colorSpace);
	CGContextSetRGBFillColor(context, 1, 0, 0, 1);
	CGContextFillRect(context, CGRectMake(0, 0, kWidth, kHeight));
	CGImageRef image = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	return image;
}

static NSData* pngData(CGImageRef image) {
	NSMutableData* data = [NSMutableData data];
	CGImageDestinationRef destination = CGImageDestinationCreateWithData((CFMutableDataRef)data, CFSTR("public.png"), 1, NULL);
	CGImageDestinationAddImage(destination, image, NULL);
	BOOL ok = CGImageDestinationFinalize(destination);
	CFRelease(destination);
	return ok ? data : nil;
}

typedef struct {
	id<MTLTexture> texture;
	NSError* error;
	int calls;
} SingleResult;

typedef struct {
	NSArray* textures;
	NSError* error;
	int calls;
} ArrayResult;

static BOOL waitFor(dispatch_semaphore_t done) {
	return dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) == 0;
}

// Starts a single-texture load with the given starter and waits for its handler.
static SingleResult runSingle(void (^start)(MTKTextureLoaderCallback handler)) {
	__block SingleResult result = {nil, nil, 0};
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	start([[^(id<MTLTexture> texture, NSError* error) {
		result.texture = [texture retain];
		result.error = [error retain];
		result.calls++;
		dispatch_semaphore_signal(done);
	} copy] autorelease]);
	CHECK(waitFor(done));
	// a handler that is called twice would show up as a second call shortly after the first
	usleep(200 * 1000);
	dispatch_release(done);
	return result;
}

static ArrayResult runArray(void (^start)(MTKTextureLoaderArrayCallback handler)) {
	__block ArrayResult result = {nil, nil, 0};
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	start([[^(NSArray<id<MTLTexture>>* textures, NSError* error) {
		result.textures = [textures retain];
		result.error = [error retain];
		result.calls++;
		dispatch_semaphore_signal(done);
	} copy] autorelease]);
	CHECK(waitFor(done));
	// a handler that is called twice would show up as a second call shortly after the first
	usleep(200 * 1000);
	dispatch_release(done);
	return result;
}

static void checkLoaded(SingleResult result, id<MTLDevice> device) {
	CHECK(result.calls == 1);
	CHECK(result.texture != nil);
	CHECK(result.error == nil);
	CHECK(result.texture.width == kWidth);
	CHECK(result.texture.height == kHeight);
	CHECK(result.texture.device == device);
	[result.error release];
}

static void checkFailed(SingleResult result) {
	CHECK(result.calls == 1);
	CHECK(result.texture == nil);
	CHECK(result.error != nil);
	[result.error release];
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (!device) {
			printf("no Metal device\n");
			return 77;
		}

		MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice: device];
		CGImageRef image = makeImage();
		NSData* png = pngData(image);
		CHECK(image && png);

		NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"texture_loader_async_%d", getpid()]];
		[[NSFileManager defaultManager] createDirectoryAtPath: directory withIntermediateDirectories: YES attributes: nil error: nil];
		NSURL* goodURL = [NSURL fileURLWithPath: [directory stringByAppendingPathComponent: @"good.png"]];
		NSURL* missingURL = [NSURL fileURLWithPath: [directory stringByAppendingPathComponent: @"missing.png"]];
		CHECK([png writeToURL: goodURL atomically: YES]);

		// single-texture loaders: success
		SingleResult result = runSingle(^(MTKTextureLoaderCallback handler) {
			[loader newTextureWithCGImage: image options: nil completionHandler: handler];
		});
		checkLoaded(result, device);
		[result.texture release];

		result = runSingle(^(MTKTextureLoaderCallback handler) {
			[loader newTextureWithData: png options: nil completionHandler: handler];
		});
		checkLoaded(result, device);
		[result.texture release];

		result = runSingle(^(MTKTextureLoaderCallback handler) {
			[loader newTextureWithContentsOfURL: goodURL options: nil completionHandler: handler];
		});
		checkLoaded(result, device);
		[result.texture release];

		// single-texture loaders: failure reports a nil texture and an error
		result = runSingle(^(MTKTextureLoaderCallback handler) {
			[loader newTextureWithContentsOfURL: missingURL options: nil completionHandler: handler];
		});
		checkFailed(result);

		result = runSingle(^(MTKTextureLoaderCallback handler) {
			[loader newTextureWithData: [NSData dataWithBytes: "not an image" length: 12] options: nil completionHandler: handler];
		});
		checkFailed(result);

		result = runSingle(^(MTKTextureLoaderCallback handler) {
			[loader newTextureWithName: @"texture_loader_async_no_such_texture" scaleFactor: 1.0 bundle: nil options: nil completionHandler: handler];
		});
		checkFailed(result);

		// the displayGamut variants load like the others and fail like the others
		result = runSingle(^(MTKTextureLoaderCallback handler) {
			[loader newTextureWithName: @"texture_loader_async_no_such_texture" scaleFactor: 1.0 displayGamut: NSDisplayGamutSRGB bundle: nil options: nil completionHandler: handler];
		});
		checkFailed(result);

		NSError* gamutError = nil;
		CHECK([loader newTextureWithName: @"texture_loader_async_no_such_texture" scaleFactor: 1.0 displayGamut: NSDisplayGamutP3 bundle: nil options: nil error: &gamutError] == nil);
		CHECK(gamutError != nil);

		// name loaders ignore the generateMipmaps, SRGB, cubeLayout and origin options (documented), so
		// options that the URL loader would refuse or act on do not matter here
		CHECK([png writeToFile: [directory stringByAppendingPathComponent: @"named.png"] atomically: YES]);
		NSBundle* directoryBundle = [NSBundle bundleWithPath: directory];
		NSDictionary* ignored = @{
			MTKTextureLoaderOptionGenerateMipmaps: @YES,
			MTKTextureLoaderOptionSRGB: @NO,
			MTKTextureLoaderOptionCubeLayout: @"MTKTextureLoaderCubeLayoutVertical",
			MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginBottomLeft,
		};
		NSError* nameError = nil;
		id<MTLTexture> named = [loader newTextureWithName: @"named" scaleFactor: 1.0 bundle: directoryBundle options: ignored error: &nameError];
		CHECK(named != nil && nameError == nil && named.width == kWidth && named.height == kHeight);
		[named release];

		// array loaders: request order, NSNull for the failed one, first failure as the error
		NSArray* urls = @[goodURL, missingURL, goodURL];
		NSError* error = (NSError*)@"unset";
		NSArray* textures = [loader newTexturesWithContentsOfURLs: urls options: nil error: &error];
		CHECK(textures.count == 3);
		CHECK([textures[0] conformsToProtocol: @protocol(MTLTexture)]);
		CHECK(textures[1] == [NSNull null]);
		CHECK([textures[2] conformsToProtocol: @protocol(MTLTexture)]);
		CHECK(error != nil && [error isKindOfClass: [NSError class]]);
		[textures release];

		error = (NSError*)@"unset";
		textures = [loader newTexturesWithContentsOfURLs: @[goodURL, goodURL] options: nil error: &error];
		CHECK(textures.count == 2);
		CHECK(error == nil);
		[textures release];

		ArrayResult arrayResult = runArray(^(MTKTextureLoaderArrayCallback handler) {
			[loader newTexturesWithContentsOfURLs: urls options: nil completionHandler: handler];
		});
		CHECK(arrayResult.calls == 1);
		CHECK(arrayResult.textures.count == 3);
		CHECK([arrayResult.textures[0] conformsToProtocol: @protocol(MTLTexture)] && [[arrayResult.textures[0] device] isEqual: device]);
		CHECK(arrayResult.textures[1] == [NSNull null]);
		CHECK([arrayResult.textures[2] conformsToProtocol: @protocol(MTLTexture)]);
		CHECK(arrayResult.error != nil);
		[arrayResult.textures release];
		[arrayResult.error release];

		arrayResult = runArray(^(MTKTextureLoaderArrayCallback handler) {
			[loader newTexturesWithContentsOfURLs: @[goodURL] options: nil completionHandler: handler];
		});
		CHECK(arrayResult.calls == 1 && arrayResult.textures.count == 1 && arrayResult.error == nil);
		[arrayResult.textures release];
		[arrayResult.error release];

		arrayResult = runArray(^(MTKTextureLoaderArrayCallback handler) {
			[loader newTexturesWithNames: @[@"texture_loader_async_no_such_a", @"texture_loader_async_no_such_b"] scaleFactor: 1.0 bundle: nil options: nil completionHandler: handler];
		});
		CHECK(arrayResult.calls == 1);
		CHECK(arrayResult.textures.count == 2);
		CHECK(arrayResult.textures[0] == [NSNull null] && arrayResult.textures[1] == [NSNull null]);
		CHECK(arrayResult.error != nil);
		[arrayResult.textures release];
		[arrayResult.error release];

		arrayResult = runArray(^(MTKTextureLoaderArrayCallback handler) {
			[loader newTexturesWithNames: @[@"texture_loader_async_no_such_a"] scaleFactor: 1.0 displayGamut: NSDisplayGamutSRGB bundle: nil options: nil completionHandler: handler];
		});
		CHECK(arrayResult.calls == 1 && arrayResult.textures.count == 1 && arrayResult.textures[0] == [NSNull null] && arrayResult.error != nil);
		[arrayResult.textures release];
		[arrayResult.error release];

		CGImageRelease(image);
		[[NSFileManager defaultManager] removeItemAtPath: directory error: nil];
		[loader release];
	}

	if (failures) {
		printf("%d failure(s)\n", failures);
		return 1;
	}
	printf("texture loader completion handlers passed\n");
	return 0;
}
