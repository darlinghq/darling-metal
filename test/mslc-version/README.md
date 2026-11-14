# Compiler and reflection reader agreement

`source-api.mm` compiles a single compute kernel through
`-[MTLDevice newLibraryWithSource:options:error:]`, dispatches 16 elements and
checks every value of the shared buffer. It fails with an `MTLLibraryErrorDomain`
error when the compiler emits a reflection document version that
`MTLMSLReflection.mm` cannot read, so it guards against moving the `deps/mslc`
pin to a compiler whose reflection format the reader does not understand.

It uses the public Metal headers only. Build it like the other guest programs in
`test/` (compile flags taken from the Darling build with `ninja -t commands`),
run it in a prefix with Metal enabled and a working Vulkan driver, and expect
`16 elements, 0 failures` and exit status 0.

It does not cover graphics pipelines or precompiled shader libraries.
