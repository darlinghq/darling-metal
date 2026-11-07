#import <Foundation/Foundation.h>
#import <Metal/MTLCommandBuffer.h>
#include <dlfcn.h>
#include <stdio.h>
int main(void) {
    @autoreleasepool {
        if (!dlopen("/System/Library/Frameworks/Metal.framework/Versions/A/Metal", RTLD_NOW)) { puts("FAIL load Metal"); return 2; }
        Class cls = NSClassFromString(@"MTLCommandBufferDescriptor");
        if (!cls) { puts("FAIL missing MTLCommandBufferDescriptor"); return 1; }
        MTLCommandBufferDescriptor *descriptor = [[cls alloc] init];
        descriptor.retainedReferences = YES;
        descriptor.errorOptions = MTLCommandBufferErrorOptionEncoderExecutionStatus;
        MTLCommandBufferDescriptor *copy = [descriptor copy];
        if (!copy || copy == descriptor || !copy.retainedReferences ||
            copy.errorOptions != MTLCommandBufferErrorOptionEncoderExecutionStatus) {
            puts("FAIL descriptor copy"); return 3;
        }
        descriptor.retainedReferences = NO;
        if (!copy.retainedReferences) { puts("FAIL independent copy"); return 4; }
        [copy release]; [descriptor release];
        puts("PASS descriptor exported and copy properties preserved");
        return 0;
    }
}
