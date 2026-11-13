// Copyright (C) 2026 Lubos Dolezel
// Darling-specific: -[MTLDrawableInternal addPresentedHandler:] raises NSInvalidArgumentException
// instead of terminating the process. The class has no public instantiator (a CAMetalLayer hands
// out its own drawable class), so the object is created without running an initialiser; the
// timing presents need a live Indium drawable and are covered by the CAMetalLayer tests.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>

int main(void) {
	int failures = 0;
	@autoreleasepool {
		Class cls = NSClassFromString(@"MTLDrawableInternal");
		if (cls == Nil) {
			printf("SKIP: no MTLDrawableInternal\n");
			return 77;
		}
		id obj = class_createInstance(cls, 0);
		BOOL raised = NO;
		@try {
			[obj addPresentedHandler: ^(id<MTLDrawable> d) {}];
		} @catch (NSException* e) {
			raised = [[e name] isEqualToString: NSInvalidArgumentException];
		}
		if (!raised) { printf("FAIL: no NSInvalidArgumentException\n"); failures++; }
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
