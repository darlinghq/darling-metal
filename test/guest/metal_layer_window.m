// Copyright (C) 2026 Lubos Dolezel
// CAMetalLayer in a window: the documented properties and ranges, rendering to its drawables and presenting
// them, presented handlers in order with increasing presentedTime, the number of drawables that can be out at
// once and the wait (with allowsNextDrawableTimeout) when they all are, the drawable following a resize of the
// layer, and displaySyncEnabled. It does not matter whether the layer presents through a swapchain on its own
// native window or through the layer context's OpenGL rendering: every check holds for both.
//
// With METAL_LAYER_HOLD=<seconds> the test ends by filling the window with solid red and, after printing
// "READY x y w h" (the window's place on the screen, in screen pixels from the top left), keeps the window up for
// that long so that the pixels can be read from the screen.
// Exits 77 when there is no Metal device.
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static void spin(NSTimeInterval seconds) {
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: seconds]];
}

static id<MTLCommandQueue> queue;

// clears the drawable's texture to the color and presents it
static void paint(id<CAMetalDrawable> drawable, double r, double g, double b) {
	MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = drawable.texture;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	pass.colorAttachments[0].clearColor = MTLClearColorMake(r, g, b, 1);
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	[[commands renderCommandEncoderWithDescriptor: pass] endEncoding];
	[commands presentDrawable: drawable];
	[commands commit];
}

static double now(void) {
	return CACurrentMediaTime();
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		queue = [device newCommandQueue];

		[NSApplication sharedApplication];
		NSWindow* window = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, 160, 120)
			styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO];
		[window setReleasedWhenClosed: NO];
		NSView* host = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 160, 120)];

		CAMetalLayer* layer = [CAMetalLayer layer];
		layer.device = device;
		layer.bounds = CGRectMake(0, 0, 160, 120);

		// --- documented defaults
		CHECK(layer.maximumDrawableCount == 3);
		CHECK(layer.allowsNextDrawableTimeout == YES);
		CHECK(layer.displaySyncEnabled == YES);
		CHECK(layer.framebufferOnly == YES);
		CHECK(layer.pixelFormat == MTLPixelFormatBGRA8Unorm);
		CHECK(layer.presentsWithTransaction == NO);

		// --- maximumDrawableCount is 2 or 3
		for (NSUInteger n = 0; n < 6; n++) {
			BOOL raised = NO;
			@try { layer.maximumDrawableCount = n; } @catch (NSException* e) { raised = YES; }
			CHECK(raised == (n < 2 || n > 3));
			if (!raised) CHECK(layer.maximumDrawableCount == n);
		}
		layer.maximumDrawableCount = 3;

		host.layer = layer;
		host.wantsLayer = YES;
		[window setContentView: host];
		[window makeKeyAndOrderFront: nil];
		spin(0.5);
		CHECK(CGSizeEqualToSize(layer.drawableSize, CGSizeMake(160, 120)));

		// --- drawables: size, format, layer, identity
		id<CAMetalDrawable> first = [layer nextDrawable];
		CHECK(first != nil);
		if (first == nil) {
			printf("FAILED: no drawable\n");
			return 1;
		}
		CHECK(first.texture.width == 160 && first.texture.height == 120);
		CHECK(first.texture.pixelFormat == MTLPixelFormatBGRA8Unorm);
		CHECK(first.layer == layer);
		CHECK(first.presentedTime == 0);

		// --- presented handlers run in the order of the presents, once each, with increasing presentedTime
		NSMutableArray<NSNumber*>* order = [NSMutableArray array];
		NSMutableArray<NSNumber*>* times = [NSMutableArray array];
		NSUInteger firstID = first.drawableID;
		NSMutableArray<id<CAMetalDrawable>>* frames = [NSMutableArray arrayWithObject: first];
		for (int i = 1; i < 3; i++) {
			[frames addObject: [layer nextDrawable]];
		}
		CHECK(frames[1].drawableID != firstID && frames[2].drawableID != firstID && frames[1].drawableID != frames[2].drawableID);
		for (int i = 0; i < 3; i++) {
			id<CAMetalDrawable> frame = frames[i];
			[frame addPresentedHandler: ^(id<MTLDrawable> d) {
				@synchronized(order) {
					[order addObject: @(i)];
					[times addObject: @(d.presentedTime)];
				}
			}];
		}
		double beforePresent = now();
		for (int i = 0; i < 3; i++) {
			paint(frames[i], i == 0, i == 1, i == 2);
			spin(0.05);
		}
		for (int i = 0; i < 100; i++) {
			@synchronized(order) { if (order.count == 3) break; }
			spin(0.05);
		}
		@synchronized(order) {
			CHECK(order.count == 3);
			if (order.count == 3) {
				CHECK([order[0] intValue] == 0 && [order[1] intValue] == 1 && [order[2] intValue] == 2);
				CHECK([times[0] doubleValue] >= beforePresent);
				CHECK([times[1] doubleValue] >= [times[0] doubleValue]);
				CHECK([times[2] doubleValue] >= [times[1] doubleValue]);
				CHECK([times[2] doubleValue] <= now());
				CHECK(frames[2].presentedTime == [times[2] doubleValue]);
			}
		}
		[frames removeAllObjects];
		first = nil;

		// --- at most maximumDrawableCount drawables are out; the next one waits for a present, then times out
		for (NSUInteger count = 2; count <= 3; count++) {
			layer.maximumDrawableCount = count;
			NSMutableArray<id<CAMetalDrawable>>* held = [NSMutableArray array];
			for (NSUInteger i = 0; i < count; i++) {
				id<CAMetalDrawable> d = [layer nextDrawable];
				CHECK(d != nil);
				if (d) [held addObject: d];
			}
			CHECK(held.count == count);
			double start = now();
			id<CAMetalDrawable> extra = [layer nextDrawable];
			double waited = now() - start;
			CHECK(extra == nil);
			CHECK(waited >= 0.9 && waited < 3.0);

			// presenting one makes room for the next
			__block BOOL presented = NO;
			[held[0] addPresentedHandler: ^(id<MTLDrawable> d) { presented = YES; }];
			paint(held[0], 0, 0, 1);
			extra = [layer nextDrawable];
			CHECK(extra != nil);
			CHECK(presented || ({ spin(0.5); presented; }));
			if (extra) paint(extra, 0, 0, 1);
			for (NSUInteger i = 1; i < held.count; i++) paint(held[i], 0, 0, 1);
			[held removeAllObjects];
			spin(0.3);
		}
		layer.maximumDrawableCount = 3;

		// --- without a timeout, the call waits until a drawable is presented
		layer.maximumDrawableCount = 2;
		layer.allowsNextDrawableTimeout = NO;
		{
			id<CAMetalDrawable> a = [layer nextDrawable];
			id<CAMetalDrawable> b = [layer nextDrawable];
			CHECK(a != nil && b != nil);
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
				paint(a, 1, 1, 0);
			});
			double start = now();
			id<CAMetalDrawable> c = [layer nextDrawable];
			double waited = now() - start;
			CHECK(c != nil);
			CHECK(waited >= 1.2 && waited < 5.0);
			if (c) paint(c, 1, 1, 0);
			if (b) paint(b, 1, 1, 0);
			spin(0.3);
		}
		layer.allowsNextDrawableTimeout = YES;
		layer.maximumDrawableCount = 3;

		// --- the drawables follow a resize
		[window setContentSize: NSMakeSize(200, 140)];
		host.frame = NSMakeRect(0, 0, 200, 140);
		layer.bounds = CGRectMake(0, 0, 200, 140);
		spin(0.5);
		CHECK(CGSizeEqualToSize(layer.drawableSize, CGSizeMake(200, 140)));
		{
			id<CAMetalDrawable> d = [layer nextDrawable];
			CHECK(d != nil);
			if (d) {
				CHECK(d.texture.width == 200 && d.texture.height == 140);
				paint(d, 0, 1, 1);
			}
		}
		spin(0.2);

		// --- displaySyncEnabled
		layer.displaySyncEnabled = NO;
		CHECK(layer.displaySyncEnabled == NO);
		for (int i = 0; i < 5; i++) {
			id<CAMetalDrawable> d = [layer nextDrawable];
			CHECK(d != nil);
			if (d) paint(d, 0.5, 0.5, 0.5);
		}
		layer.displaySyncEnabled = YES;
		spin(0.3);

		// --- the final frame: solid red
		const char* hold = getenv("METAL_LAYER_HOLD");
		for (int i = 0; i < 3; i++) {
			id<CAMetalDrawable> d = [layer nextDrawable];
			CHECK(d != nil);
			if (d) paint(d, 1, 0, 0);
			spin(0.1);
		}
		if (hold) {
			NSRect frame = [window frame];
			NSRect screen = [[NSScreen mainScreen] frame];
			printf("READY %d %d %d %d\n", (int)frame.origin.x, (int)(screen.size.height - NSMaxY(frame)), (int)frame.size.width, (int)frame.size.height);
			fflush(stdout);
			spin(atof(hold));
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
