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

Groups 1, 2, 3 and 5 compare every one of the 262144 channels against an exact
integer reference computed from the Vulkan texel-addressing rules. Group 6 is the
negative control: it requires the exact reference to reject a wrong address mode,
and requires a nearest and a linear fetch of the same gradient to differ, so
"all pixels matched" cannot be the check being too loose. Group 7 shows the
depth test and depth writes actually changing which of three draws survives.
Group 10 checks anisotropic filtering against an exact expectation of its own,
and carries its own controls in both directions.

Groups 3, 3b and 10 are the minification and anisotropy groups, and the way they
reach a verdict is worth spelling out, because getting it wrong is what made
`minFilter` look broken in the first place.

**The driver picks between `minFilter` and `magFilter` on the LOD *after* clamping
it to `[minLod, maxLod]`.** Pinning `lodMaxClamp` to 0 therefore pins the LOD at
0, which is not a minifying LOD, and every footprint is then filtered with
`magFilter`. A minification test that pins `lodMaxClamp = 0` cannot observe
`minFilter` at any footprint, however heavily minified. The reverse works too:
`lodMinClamp` above 0 turns a deep magnification into a minification. Group 3
asserts all four combinations at two footprints, group 3b asserts the switch
directly, and the last two rows of group 3 are the pinned-LOD case kept as a
standing demonstration of the blind condition.

**Group 10's exact reference comes from the texture, not from a filter model.**
The stripe texture's level 0 is constant along x, and the footprint is 16 texels
long in x and one texel tall in y, so every anisotropic tap lands on the same
stripe: the weighted average of N identical taps is that stripe, and with 1
texel per pixel in y the bilinear fetch lands on a texel centre, so the answer is
the level-0 stripe value and nothing else. `maxAnisotropy` at the device limit
must reproduce those values exactly, and `maxAnisotropy = 1` must not, because
isotropic filtering takes the LOD from the long axis (log2(16) = 4) and lands on
a level that is flat grey. The two conditions are mutually exclusive, so each
also serves as the control for the other.
