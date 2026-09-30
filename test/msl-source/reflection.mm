// Unit test for MTLReadMSLReflection, the layer that turns mslc's reflection
// document into the values indium's SPIR-V library entry point takes.
//
// Runs under darlingserver like every other guest test here. Each case is a
// document and an expectation, and the last group is the negative controls: a
// reader that accepts everything would pass the first group and is caught by the
// second.
#import <Foundation/Foundation.h>
#import <Metal/MTLMSLReflection.h>
#import <stdio.h>
#import <string.h>

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

// mslc's own document, byte for byte, including the trailing comma after the last
// binding that makes it not strict JSON.
static NSString* realDocument(void) {
    return @"{\n"
        @"\t\"reflection_version\": 1,\n"
        @"\t\"stage\": \"kernel\",\n"
        @"\t\"entry_point\": \"add_arrays\",\n"
        @"\t\"local_size\": [1, 1, 1],\n"
        @"\t\"bindings\": [\n"
        @"\t\t{ \"kind\": \"Buffer\", \"metal_index\": 0, \"descriptor\": { \"set\": 0, \"binding\": 0 },"
            " \"member\": 0, \"param_index\": 0, \"name\": \"inA\" },\n"
        @"\t\t{ \"kind\": \"Buffer\", \"metal_index\": 1, \"descriptor\": { \"set\": 0, \"binding\": 0 },"
            " \"member\": 1, \"param_index\": 1, \"name\": \"inB\" },\n"
        @"\t\t{ \"kind\": \"Buffer\", \"metal_index\": 2, \"descriptor\": { \"set\": 0, \"binding\": 0 },"
            " \"member\": 2, \"param_index\": 2, \"name\": \"result\" },\n"
        @"\t]\n"
        @"}\n";
}

static bool read(NSString* document, Indium::LibraryReflection& out, NSString*& err) {
    return MTLReadMSLReflection([document UTF8String], [document lengthOfBytesUsingEncoding: NSUTF8StringEncoding],
                                out, err);
}

static void expectRejected(const char* what, NSString* document) {
    Indium::LibraryReflection reflection;
    NSString* err = nil;
    BOOL accepted = read(document, reflection, err);

    // The label has to outlive the ok() call: stringWithFormat hands back an
    // autoreleased object, and the pointer would be stale by the time ok read it.
    NSString* label = [NSString stringWithFormat: @"%s is refused", what];
    ok([label UTF8String], !accepted);
    if (accepted) {
        LOG("      (accepted, with %zu function(s))", reflection.functions.size());
    } else {
        LOG("      reason: %s", [err UTF8String]);
    }
}

int main(void) {
    @autoreleasepool {
        logFile = fopen("/tmp/reflection.log", "w");
        LOG("reflection unit test");

        // ------------------------------------------------- mslc's real document
        LOG("  mslc's document, trailing comma and all");
        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;

            if (!read(realDocument(), reflection, err)) {
                LOG("  FATAL: refused mslc's own document: %s", [err UTF8String]);
                return 2;
            }

            ok("one function", reflection.functions.size() == 1);

            const Indium::FunctionReflection* fn = NULL;
            for (const auto& entry : reflection.functions) {
                if (strcmp(entry.first.c_str(), "add_arrays") != 0) {
                    LOG("  FATAL: the function is named '%s', not add_arrays", entry.first.c_str());
                    return 2;
                }
                fn = &entry.second;
            }
            ok("named add_arrays", fn != NULL);
            ok("the stage is Kernel", fn->functionType == Indium::FunctionType::Kernel);
            ok("three bindings", fn->bindings.size() == 3);

            if (fn->bindings.size() == 3) {
                ok("binding 0 is buffer 0 at Metal index 0",
                   fn->bindings[0].type == Indium::BindingType::Buffer
                   && fn->bindings[0].index == 0
                   && fn->bindings[0].internalIndex == 0);
                ok("binding 1 is buffer 1 at Metal index 1",
                   fn->bindings[1].type == Indium::BindingType::Buffer
                   && fn->bindings[1].index == 1
                   && fn->bindings[1].internalIndex == 0);
                ok("binding 2 is buffer 2 at Metal index 2",
                   fn->bindings[2].type == Indium::BindingType::Buffer
                   && fn->bindings[2].index == 2
                   && fn->bindings[2].internalIndex == 0);

                // Every buffer shares one block at set 0 binding 0, so a reader that
                // took the descriptor *set* for the Vulkan binding would produce
                // three different internalIndex values. If it had, this would fail.
                ok("all three read the same descriptor binding number 0",
                   fn->bindings[0].internalIndex == 0
                   && fn->bindings[1].internalIndex == 0
                   && fn->bindings[2].internalIndex == 0);

                // Nothing in the document is an embedded sampler, so this has to be
                // SIZE_MAX: a 0 would make indium bind a sampler that is not there.
                ok("no binding claims an embedded sampler",
                   fn->bindings[0].embeddedSamplerIndex == SIZE_MAX
                   && fn->bindings[1].embeddedSamplerIndex == SIZE_MAX
                   && fn->bindings[2].embeddedSamplerIndex == SIZE_MAX);
            }
        }

        // -------------------------------------------------------- other stages
        LOG("  stages");
        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;
            NSString* doc = [realDocument() stringByReplacingOccurrencesOfString: @"\"kernel\""
                                                                     withString: @"\"fragment\""];
            ok("fragment is accepted", read(doc, reflection, err));
            for (const auto& e : reflection.functions) {
                ok("and reads back as Fragment", e.second.functionType == Indium::FunctionType::Fragment);
            }
        }
        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;
            NSString* doc = [realDocument() stringByReplacingOccurrencesOfString: @"\"kernel\""
                                                                     withString: @"\"compute\""];
            expectRejected("a stage indium has no descriptor layout for, compute", doc);
        }

        // ------------------------------------------------ negative controls
        // Each of these is a document mslc could be changed into producing. A reader
        // that guessed instead of stopping would pass everything above and be wrong
        // on all of these.
        LOG("  negative controls");

        expectRejected("a Texture binding, which carries no access type",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Texture\",\"metal_index\":0,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a Sampler binding",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Sampler\",\"metal_index\":0,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a VertexInput binding",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"VertexInput\",\"metal_index\":0,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a binding of unknown kind",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"AccelerationStructure\",\"metal_index\":0,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a fractional metal_index, which must not be rounded to 2",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"metal_index\":2.5,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a negative metal_index",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"metal_index\":-1,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a string where an index belongs",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"metal_index\":\"0\",\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a binding with no descriptor",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"metal_index\":0}]}");

        expectRejected("a binding with no metal_index",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("no bindings array",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\"}");

        expectRejected("no entry point",
            @"{\"stage\":\"kernel\",\"bindings\":[]}");

        expectRejected("an empty entry point name",
            @"{\"stage\":\"kernel\",\"entry_point\":\"\",\"bindings\":[]}");

        expectRejected("no stage",
            @"{\"entry_point\":\"k\",\"bindings\":[]}");

        expectRejected("a document that is a JSON array, not an object",
            @"[{\"stage\":\"kernel\"}]");

        expectRejected("a document that is not JSON at all", @"this is not json");

        expectRejected("an empty document", @"");

        // The last one has to hold for the whole suite: a reflection of no
        // functions is what indium refuses with "reflection describes no
        // functions", so a reader that accepted it would push the diagnosis one
        // layer too far down.
        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;
            BOOL accepted = read(@"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":[]}",
                                 reflection, err);
            ok("a document with no bindings is read, and carries one empty function",
               accepted && reflection.functions.size() == 1
               && reflection.functions.begin()->second.bindings.empty());
        }

        LOG(failures == 0 ? "RESULT: PASS" : "RESULT: FAIL");
        return failures == 0 ? 0 : 1;
    }
}
