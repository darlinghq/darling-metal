# Sampler / depth-stencil verification

The Metal shim itself can only be syntax-checked, but everything it maps onto can
be executed. These are the harnesses used to do that.

## `mtl-sampler-syntax.sh`

Compiles every `src/Metal/*.mm` with the flags of a real Darling compile rule
taken read-only from `darling/build`:

```
cd /home/cristi/src/darling/build && ninja -t commands | grep -m1 cocotron/QuartzCore/CARenderer.m
```

The `-o`/`-c` pair, the `-MD/-MT/-MF` dependency trio and the input path are
dropped and `-fsyntax-only` is used, so nothing is written under `darling/`. The
rule's own `-I…/src/external/metal/…` dirs are replaced by this clone's
`include`, `private-include` and `deps/indium` dirs and **hoisted to the front**,
because `-I…/framework-include` resolves `<Metal/…>` to the stale installed
snapshot and would otherwise shadow the headers under test. The script re-runs
one file without that hoist and requires it to fail, so a future edit that breaks
the hoist cannot silently make the check vacuous.

Run at `DARLING_METAL_ENABLED=1` and at `DARLING_METAL_ENABLED=0` (the 32-bit stub
build, where every class must still compile and link).

## `sampler-semantics.cpp`

Pixel verification of the `Indium::SamplerDescriptor` / `Indium::DepthStencilDescriptor`
mapping on a real GPU. Needs an Indium build (see `README` below) and the
`libindium.so` next to it.

The Metal it runs is `fragment_sample` in `fragment_sample.ll`, which is
`test/texturing`'s real `fragment_texture` sampling call with the lighting body
deleted, so the framebuffer pixel *is* the sampled texel and the host reference
is a bare sampler emulation with no shader maths in the way. The vertex stage is
`test/texturing`'s real `vertex_project`, and the drawn quad is a full-viewport
triangle whose texture coordinates are an exact affine function of the pixel
position, so the coordinate at a pixel centre is closed-form.

Building the fixture: `fragment_sample.ll` and `vertex_project.ll` each become one
LLVM bitcode blob, and `mtlb_multi.py` packs both into one MTLB metallib
(`AIR::Library` reads one bitcode blob per function-list entry).

```
llvm-as fragment_sample.ll -o fragment_sample.bc
llvm-as vertex_project.ll   -o vertex_project.bc
MTLB_DIR=<dir with mtlb.py> python3 mtlb_multi.py \
    <indium>/test/texturing/shaders.metallib sampler.metallib \
    vertex_project:vertex:vertex_project.bc \
    fragment_sample:fragment:fragment_sample.bc
```

Compiling and running:

```
g++ -std=c++17 -O2 -o sampler-semantics sampler-semantics.cpp \
    -I<indium>/include -I<indium>/private-include \
    -L<build> -lindium -liridium -Wl,-rpath,<build>
./sampler-semantics sampler.metallib
```

Groups 1, 2 and 5 compare every one of the 262144 channels against an exact
integer reference computed from the Vulkan texel-addressing rules. Group 6 is the
negative control: it requires the exact reference to reject a wrong address mode,
and requires a nearest and a linear fetch of the same gradient to differ, so
"all pixels matched" cannot be the check being too loose. Groups 7 and 8 report
rather than assert where no exact reference exists.
