// End to end: MSL source through -[MTLDevice newLibraryWithSource:options:error:],
// dispatched and read back bit for bit, under a real darlingserver.
//
// No window is opened and none can be: there is no MTLCreateSystemDefaultDevice
// drawable, no swapchain and no CAContext, only compute over buffers that the
// guest reads back itself.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <stdarg.h>
#import <string.h>
#import <math.h>

static int failures = 0;
static FILE* logFile = NULL;

static void LOG(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    if (logFile) { vfprintf(logFile, fmt, ap); fputc('\n', logFile); fflush(logFile); }
    vprintf(fmt, ap);
    putchar('\n');
    fflush(stdout);
    va_end(ap);
}

static void ok(const char* what, BOOL cond) {
    LOG("  [%s] %s", cond ? "PASS" : "FAIL", what);
    if (!cond) failures++;
}

// What add.metal says the result has to be: in[i] = a[i] + b[i].
static size_t countDiffering(const float* result, const float* a, const float* b, size_t count) {
    size_t bad = 0;
    size_t firstBad = (size_t)-1;
    for (size_t i = 0; i < count; ++i) {
        float expected = a[i] + b[i];
        // A NaN compares unequal to everything, so a tolerance test would pass on
        // it. Assert it is not one before comparing, and compare the bits.
        if (isnan(expected) || memcmp(&result[i], &expected, sizeof(float)) != 0) {
            if (firstBad == (size_t)-1) { firstBad = i; }
            ++bad;
        }
    }
    if (firstBad != (size_t)-1) {
        LOG("    first difference at %zu: result=%g a=%g b=%g expected=%g",
            firstBad, result[firstBad], a[firstBad], b[firstBad], a[firstBad] + b[firstBad]);
    }
    return bad;
}

// Fills two buffers and poisons the result with a value a+b can never produce,
// so a dispatch that does not run at all cannot look like a pass.
static void fillInputs(id<MTLDevice> device, size_t count,
                       id<MTLBuffer>* outA, id<MTLBuffer>* outB, id<MTLBuffer>* outResult)
{
    size_t bytes = count * sizeof(float);
    *outA = [device newBufferWithLength: bytes options: MTLResourceStorageModeShared];
    *outB = [device newBufferWithLength: bytes options: MTLResourceStorageModeShared];
    *outResult = [device newBufferWithLength: bytes options: MTLResourceStorageModeShared];

    float* a = (float*)[*outA contents];
    float* b = (float*)[*outB contents];
    float* r = (float*)[*outResult contents];

    // A deterministic pattern rather than rand(): the test has to be able to say
    // which element is wrong, and the same run has to be reproducible.
    for (size_t i = 0; i < count; ++i) {
        a[i] = (float)(i % 1024) * 0.5f;
        b[i] = (float)(i % 977) * 0.25f;
        r[i] = -1.0e30f;
    }
}

// Dispatches `kernel` over [0, count) and returns how many result elements differ
// from a+b.
static size_t runAndCompare(id<MTLDevice> device, id<MTLLibrary> library,
                            const char* kernelName, size_t count,
                            id<MTLBuffer> bufA, id<MTLBuffer> bufB, id<MTLBuffer> bufResult)
{
    id<MTLFunction> kernel = [library newFunctionWithName: @(kernelName)];
    if (kernel == nil) {
        LOG("    newFunctionWithName(%s) returned nil", kernelName);
        return (size_t)-1;
    }

    id<MTLComputePipelineState> pso =
        [device newComputePipelineStateWithFunction: kernel error: NULL];
    if (pso == nil) {
        LOG("    newComputePipelineState returned nil");
        return (size_t)-1;
    }

    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLCommandBuffer> cb = [queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];

    [enc setComputePipelineState: pso];
    [enc setBuffer: bufA offset: 0 atIndex: 0];
    [enc setBuffer: bufB offset: 0 atIndex: 1];
    [enc setBuffer: bufResult offset: 0 atIndex: 2];

    MTLSize grid = MTLSizeMake(count, 1, 1);
    NSUInteger group = [pso maxTotalThreadsPerThreadgroup];
    if (group == 0) { group = 1; }
    if (group > grid.width) { group = grid.width; }
    [enc dispatchThreads: grid threadsPerThreadgroup: MTLSizeMake(group, 1, 1)];

    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];

    return countDiffering((float*)[bufResult contents], (float*)[bufA contents],
                          (float*)[bufB contents], count);
}

int main(int argc, const char** argv) {
    @autoreleasepool {
        const char* srcPath = (argc > 1) ? argv[1] : "/usr/bin/add.metal";
        const size_t count = (argc > 2) ? (size_t)atol(argv[2]) : (size_t)16777216;

        logFile = fopen("/tmp/mslsource.log", "w");
        LOG("mslsource: source=%s count=%zu", srcPath, count);

        NSArray* allDevices = MTLCopyAllDevices();
        id<MTLDevice> device = [allDevices firstObject];
        ok("a device exists", device != nil);
        if (device == nil) { return 2; }
        if ([device respondsToSelector: @selector(name)]) {
            LOG("  device=%s", [[device name] UTF8String]);
        }

        NSError* err = nil;
        NSString* source = [NSString stringWithContentsOfFile: @(srcPath)
                                                     encoding: NSUTF8StringEncoding
                                                        error: &err];
        ok("the MSL source read", source != nil);
        if (source == nil) { return 2; }
        LOG("  source is %lu bytes", (unsigned long)[source length]);

        // ---------------------------------------------------------- the compile
        LOG("  newLibraryWithSource:options:error:");
        id<MTLLibrary> library = [device newLibraryWithSource: source options: nil error: &err];
        ok("newLibraryWithSource: returned a library", library != nil);
        if (library == nil) {
            LOG("  error domain=%s", [[err domain] UTF8String]);
            LOG("  error code=%ld", (long)[err code]);
            LOG("  error=%s", [[err localizedDescription] UTF8String]);
            return 1;
        }
        LOG("  error is %s (no error is expected on success)", err ? "set" : "unset");

        id<MTLFunction> kernel = [library newFunctionWithName: @"add_arrays"];
        ok("newFunctionWithName: add_arrays found", kernel != nil);
        if (kernel == nil) { return 2; }

        // ------------------------------------------------------- the dispatch
        id<MTLBuffer> bufA, bufB, bufResult;
        fillInputs(device, count, &bufA, &bufB, &bufResult);

        size_t differing = runAndCompare(device, library, "add_arrays", count,
                                         bufA, bufB, bufResult);
        if (differing == (size_t)-1) { return 2; }
        LOG("  %zu of %zu elements differ from a+b", differing, count);
        ok("every element reads back as a+b, bit for bit", differing == 0);

        // ------------------------------------------- negative control 1: one bad element
        // One element is corrupted after the fact. The comparison has to notice,
        // and it has to notice exactly one.
        ((float*)[bufResult contents])[1234567] = 42.0f;
        size_t afterOne = countDiffering((float*)[bufResult contents], (float*)[bufA contents],
                                         (float*)[bufB contents], count);
        LOG("  control: one element corrupted -> %zu differ", afterOne);
        ok("a single wrong element is detected as exactly one difference", afterOne == 1);

        ((float*)[bufResult contents])[1234567] = ((float*)[bufA contents])[1234567]
                                                + ((float*)[bufB contents])[1234567];
        size_t afterFix = countDiffering((float*)[bufResult contents], (float*)[bufA contents],
                                         (float*)[bufB contents], count);
        ok("putting it back returns to 0 differences", afterFix == 0);

        // ------------------------------------------- negative control 2: bad shader
        // A shader mslc cannot compile must come back nil with a real error, not a
        // library that does not exist and not a hang. This one parses and is
        // rejected in sema, so it exercises the failure path rather than the parser.
        LOG("  control: a shader that parses but does not compile");
        NSError* badErr = nil;
        id<MTLLibrary> badLib = [device newLibraryWithSource:
            @"kernel void go() { out_of_scope_identifier = 1; }" options: nil error: &badErr];
        ok("an uncompilable shader returns nil", badLib == nil);
        ok("and sets an error", badErr != nil);
        if (badErr != nil) {
            LOG("    domain=%s code=%ld", [[badErr domain] UTF8String], (long)[badErr code]);
            LOG("    %s", [[badErr localizedDescription] UTF8String]);
            ok("the error is in MTLLibraryErrorDomain",
               [[badErr domain] isEqualToString: MTLLibraryErrorDomain]);
            ok("the code is MTLLibraryErrorCompileFailure",
               [badErr code] == MTLLibraryErrorCompileFailure);
            ok("the description carries mslc's own diagnostic, not a generic message",
               [[badErr localizedDescription] length] > 0
               && [[badErr localizedDescription] rangeOfString: @"mslc"].location != NSNotFound);
        }

        // ------------------------------- what cannot compile, measured not asserted
        // Each of these is a shader an app might reasonably write. What happens to
        // it is printed rather than asserted, because these are the limits and the
        // limits belong to mslc, not to this framework.
        LOG("  limits: shaders that cannot compile yet, and why");
        {
            struct { const char* name; const char* source; } cases[] = {
                { "texture2d<float> parameter (the type real MSL uses)",
                  "kernel void go(texture2d<float> src [[texture(0)]], "
                  "uint2 gid [[thread_position_in_grid]]) { }" },
                { "texture2d parameter (unlowered in sema)",
                  "kernel void go(texture2d src [[texture(0)]]) { }" },
                { "sampler parameter (unlowered in sema)",
                  "kernel void go(sampler s [[sampler(0)]]) { }" },
                { "vertex attribute parameter",
                  "vertex float4 go(float4 p [[attribute(0)]]) { return p; }" },
                { "vertex attribute on a struct field",
                  "struct V { float4 p [[attribute(0)]]; };\n"
                  "vertex float4 vtx(V v) { return v.p; }" },
                { "#include <metal_stdlib>",
                  "#include <metal_stdlib>\nkernel void go() { }" },
                { "a kernel mslc does support, as the positive case",
                  "kernel void ok_kernel(device float* out [[buffer(0)]]) { out[0] = 1.0; }" },
            };

            for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
                NSError* e = nil;
                id<MTLLibrary> lib = [device newLibraryWithSource: @(cases[i].source)
                                                         options: nil error: &e];
                LOG("    %-52s -> %s", cases[i].name, lib ? "LIBRARY" : "nil");
                if (!lib && e != nil) {
                    LOG("        %s", [[e localizedDescription] UTF8String]);
                }
                if (lib) { [lib release]; }
            }
        }

        // ------------------------------------------- control: a library is not freed early
        // indium borrows the module and the reflection for the newLibrary call and
        // nothing longer, so mslc_free has already run by the time the caller
        // dispatches. A library that kept a pointer would work here by luck, so this
        // is about the ordering being observable rather than about it being correct.
        {
            id<MTLBuffer> a, b, r;
            fillInputs(device, 4096, &a, &b, &r);
            size_t differing = runAndCompare(device, library, "add_arrays", 4096, a, b, r);
            LOG("  control: a second dispatch off the same library -> %zu of 4096 differ", differing);
            ok("the library is still usable after the module was freed", differing == 0);
        }

        LOG(failures == 0 ? "RESULT: PASS" : "RESULT: FAIL");
        return failures == 0 ? 0 : 1;
    }
}
