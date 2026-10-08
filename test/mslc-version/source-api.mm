#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>
int main() {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) return 2;
        NSError *error = nil;
        NSString *source = @"kernel void authored(device float* out [[buffer(0)]], uint i [[thread_position_in_grid]]) { out[i] = 123.0; }";
        id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
        if (!library) {
            fprintf(stderr, "FAIL source library: %s\n", [[error description] UTF8String]);
            return 1;
        }
        id<MTLFunction> function = [library newFunctionWithName:@"authored"];
        id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
        if (!pipeline) return 3;
        float values[16] = {};
        id<MTLBuffer> output = [device newBufferWithBytes:values length:sizeof(values) options:MTLResourceStorageModeShared];
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
        [encoder setComputePipelineState:pipeline];
        [encoder setBuffer:output offset:0 atIndex:0];
        [encoder dispatchThreadgroups:MTLSizeMake(16, 1, 1) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];
        float *actual = (float *)[output contents];
        unsigned failures = 0;
        for (unsigned i = 0; i < 16; ++i) failures += actual[i] != 123.0f;
        printf("source compute: 16 elements, %u failures\n", failures);
        return failures ? 4 : 0;
    }
}
