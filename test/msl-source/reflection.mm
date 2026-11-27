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

static void LOG(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
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
            ok("compute is accepted as the kernel stage", read(doc, reflection, err));
            for (const auto& e : reflection.functions) {
                ok("and reads back as Kernel", e.second.functionType == Indium::FunctionType::Kernel);
            }
        }

        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;
            NSString* doc = @"{\"reflection_version\":1,\"stage\":\"vertex\",\"entry_point\":\"v\",\"bindings\":["
                "{\"kind\":\"VertexInput\",\"metal_index\":2,\"location\":2,\"name\":\"position\"}]}";
            ok("a VertexInput binding on a vertex function is accepted", read(doc, reflection, err));
            for (const auto& e : reflection.functions) {
                ok("and keeps its attribute index",
                   e.second.bindings.size() == 1
                   && e.second.bindings[0].type == Indium::BindingType::VertexInput
                   && e.second.bindings[0].index == 2);
            }
        }

        // ------------------------------------------------ negative controls
        // Each of these is a document mslc could be changed into producing. A reader
        // that guessed instead of stopping would pass everything above and be wrong
        // on all of these.
        LOG("  negative controls");

        expectRejected("a Texture binding, which carries no access type",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Texture\",\"metal_index\":0,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a Sampler binding on a descriptor set its stage does not own",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Sampler\",\"metal_index\":0,\"descriptor\":{\"set\":1,\"binding\":0}}]}");

        expectRejected("a VertexInput binding on a kernel",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"VertexInput\",\"metal_index\":0,\"location\":0}]}");

        expectRejected("a VertexInput binding with no attribute index",
            @"{\"reflection_version\":1,\"stage\":\"vertex\",\"entry_point\":\"v\",\"bindings\":["
            "{\"kind\":\"VertexInput\",\"location\":0}]}");

        expectRejected("a binding of unknown kind",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"AccelerationStructure\",\"metal_index\":0,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a fractional metal_index, which must not be rounded to 2",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"metal_index\":2.5,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a negative metal_index",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"metal_index\":-1,\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        // ------------------------------------------- sample count constant
        LOG("  sample count");
        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;
            NSString* doc = [[realDocument() stringByReplacingOccurrencesOfString: @"\"kernel\""
                                                                      withString: @"\"fragment\""]
                stringByReplacingOccurrencesOfString: @"\"local_size\""
                                          withString: @"\"num_samples_spec_id\": 262147,\n\t\"local_size\""];
            ok("num_samples_spec_id is accepted", read(doc, reflection, err));
            for (const auto& e : reflection.functions) {
                ok("and reads back as the sample count's specialization ID",
                   e.second.numSamplesSpecializationID && *e.second.numSamplesSpecializationID == 262147);
            }
        }
        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;
            ok("a document without it is read", read(realDocument(), reflection, err));
            for (const auto& e : reflection.functions) {
                ok("and has no sample count constant", !e.second.numSamplesSpecializationID);
            }
        }
        expectRejected("a num_samples_spec_id that is a string",
            @"{\"reflection_version\":1,\"stage\":\"fragment\",\"entry_point\":\"f\",\"num_samples_spec_id\":\"262147\",\"bindings\":[]}");

        // --------------------------------------------------- function constants
        LOG("  function constants");
        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;
            NSString* doc = [realDocument() stringByReplacingOccurrencesOfString: @"\"local_size\""
                withString: @"\"function_constants\": [\n"
                    "\t\t{ \"name\": \"useMask\", \"type\": \"bool\", \"index\": 0, \"spec_id\": 65536, \"defined_spec_id\": 131072 },\n"
                    "\t\t{ \"name\": \"scale\", \"type\": \"float\", \"index\": 4, \"spec_id\": 65540, \"defined_spec_id\": 131076 }\n"
                    "\t],\n\t\"local_size\""];
            ok("function_constants is accepted", read(doc, reflection, err));
            ok("and the document still has its one function", reflection.functions.size() == 1);
            for (const auto& e : reflection.functions) {
                const auto& constants = e.second.functionConstants;
                ok("and reads back both constants with their names, types, indices and SpecIds",
                   constants.size() == 2
                   && constants[0].name == "useMask" && constants[0].type == Indium::FunctionConstantType::Bool
                   && constants[0].index == 0 && constants[0].specializationID == 65536 && constants[0].definedSpecializationID == 131072
                   && constants[1].name == "scale" && constants[1].type == Indium::FunctionConstantType::Float
                   && constants[1].index == 4 && constants[1].specializationID == 65540 && constants[1].definedSpecializationID == 131076);
            }
        }
        // a constant indium cannot specialize makes only the function reading it unusable: the reader that
        // a library is made with keeps the function, leaves the constant out and says why it cannot be used
        {
            Indium::LibraryReflection reflection;
            std::map<std::string, std::string> unusable;
            NSString* err = nil;
            NSString* doc = [realDocument() stringByReplacingOccurrencesOfString: @"\"local_size\""
                withString: @"\"function_constants\": [\n"
                    "\t\t{ \"name\": \"h\", \"type\": \"half\", \"index\": 0, \"spec_id\": 65536, \"defined_spec_id\": 131072 },\n"
                    "\t\t{ \"name\": \"n\", \"type\": \"uint\", \"index\": 1, \"spec_id\": 65537, \"defined_spec_id\": 131073 }\n"
                    "\t],\n\t\"local_size\""];
            bool accepted = MTLReadMSLReflection([doc UTF8String], [doc lengthOfBytesUsingEncoding: NSUTF8StringEncoding],
                                                 reflection, unusable, err);
            ok("a half function constant leaves the document readable for a library", accepted && reflection.functions.size() == 1);
            for (const auto& e : reflection.functions) {
                ok("and only the supported constant is kept",
                   e.second.functionConstants.size() == 1 && e.second.functionConstants[0].name == "n");
                ok("and the function is listed as unusable, naming the constant and its type",
                   unusable.size() == 1 && unusable.count(e.first) == 1
                   && unusable[e.first].find("'h'") != std::string::npos && unusable[e.first].find("half") != std::string::npos);
            }
        }

        // the refusals start from mslc's real document, so the only thing wrong with each is its constant
        expectRejected("a half function constant, by the reader that has nowhere to list an unusable function",
            [realDocument() stringByReplacingOccurrencesOfString: @"\"local_size\""
                withString: @"\"function_constants\": [{ \"name\": \"h\", \"type\": \"half\", \"index\": 0, \"spec_id\": 65536, \"defined_spec_id\": 131072 }],\n\t\"local_size\""]);
        expectRejected("a function constant with no spec_id",
            [realDocument() stringByReplacingOccurrencesOfString: @"\"local_size\""
                withString: @"\"function_constants\": [{ \"name\": \"c\", \"type\": \"int\", \"index\": 0, \"defined_spec_id\": 131072 }],\n\t\"local_size\""]);
        expectRejected("function_constants that is not an array",
            [realDocument() stringByReplacingOccurrencesOfString: @"\"local_size\""
                withString: @"\"function_constants\": 3,\n\t\"local_size\""]);

        expectRejected("a string where an index belongs",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"metal_index\":\"0\",\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("a binding with no descriptor",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"metal_index\":0}]}");

        expectRejected("a binding with no metal_index",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":["
            "{\"kind\":\"Buffer\",\"descriptor\":{\"set\":0,\"binding\":0}}]}");

        expectRejected("no bindings array",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\"}");

        expectRejected("no entry point",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"bindings\":[]}");

        expectRejected("an empty entry point name",
            @"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"\",\"bindings\":[]}");

        expectRejected("no stage",
            @"{\"reflection_version\":1,\"entry_point\":\"k\",\"bindings\":[]}");

        expectRejected("a document that is a JSON array, not an object",
            @"[{\"stage\":\"kernel\"}]");

        expectRejected("a document that is not JSON at all", @"this is not json");

        expectRejected("an empty document", @"");
        expectRejected("a document with no reflection_version",
            @"{\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":[]}");
        expectRejected("a reflection_version this reader does not know",
            @"{\"reflection_version\":3,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":[]}");

        // The last one has to hold for the whole suite: a reflection of no
        // functions is what indium refuses with "reflection describes no
        // functions", so a reader that accepted it would push the diagnosis one
        // layer too far down.
        {
            Indium::LibraryReflection reflection;
            NSString* err = nil;
            BOOL accepted = read(@"{\"reflection_version\":1,\"stage\":\"kernel\",\"entry_point\":\"k\",\"bindings\":[]}",
                                 reflection, err);
            ok("a document with no bindings is read, and carries one empty function",
               accepted && reflection.functions.size() == 1
               && reflection.functions.begin()->second.bindings.empty());
        }

        LOG(failures == 0 ? "RESULT: PASS" : "RESULT: FAIL");
        return failures == 0 ? 0 : 1;
    }
}
