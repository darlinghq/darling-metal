# msl-source

Two guest programs that check what `-[MTLDevice newLibraryWithSource:options:error:]`
does, plus the shader they run. Neither opens a window and neither can: there is no
swapchain, no drawable and no CAContext anywhere in them, only compute over buffers
the guest reads back itself.

They are built and run by hand against a Darling prefix, because this repository has
no test target and the compile needs the flags of the surrounding Darling build. The
flags are harvested read-only out of the shared tree with `ninja -t commands`; the
shared tree is never written to. Guest binaries go in the prefix's `/usr/bin`: a
guest executable in the prefix's `/tmp` does not run.

## What they measure

`msl-source.mm` is the end to end claim. It reads `add.metal`, compiles it through
the framework, dispatches 16,777,216 elements and compares the readback bit for bit
against `a + b` computed by the host. Bit comparison rather than a tolerance,
because a tolerance test passes on a NaN and a NaN in the result would be a silent
pass.

It carries four controls, all of which have to fire:

- one result element is corrupted and the comparison has to report exactly one
  difference, and none once it is put back;
- a shader that parses but does not compile has to come back `nil` with an error in
  `MTLLibraryErrorDomain` carrying mslc's own diagnostic, rather than a library that
  does not exist or a hang;
- a second dispatch off the same library still has to be correct, which is the
  observable half of indium borrowing the module rather than keeping it;
- and it prints, rather than asserts, what happens to a set of shaders that cannot
  compile yet. Those are mslc's limits and mslc will move them, so pinning them as
  assertions here would turn someone else's progress into a failure.

`reflection.mm` tests `MTLReadMSLReflection` on its own: mslc's real document byte
for byte including the trailing comma that makes it not strict JSON, then eighteen
documents that have to be refused. A reader that guessed instead of stopping would
pass the first document and be wrong on all of them.

## Result

On the only device this reaches, `Apple M1 (G13G B1)`, under `darlingserver`:

```
  [PASS] newLibraryWithSource: returned a library
  [PASS] every element reads back as a+b, bit for bit
  0 of 16777216 elements differ from a+b
  control: one element corrupted -> 1 differ
  control: mslc could not compile the source: "out_of_scope_identifier" is not a
           parameter, local, constant or builtin mslc knows about
  control: a second dispatch off the same library -> 0 of 4096 differ
RESULT: PASS
```

`reflection.mm`: 25 of 25, `RESULT: PASS`.

## What cannot compile, and where the reason lives

Printed by `msl-source.mm`, each with mslc's own diagnostic:

| Shader | Result | Why |
| --- | --- | --- |
| `kernel void go(device float* out [[buffer(0)]])` | library | the shape that works |
| `#include <metal_stdlib>` alone | library | the directive is accepted and ignored |
| `texture2d<float> src [[texture(0)]]` | nil | mslc's parser has no template argument list: `expected a parameter name, found <` |
| `texture2d src [[texture(0)]]` | nil | mslc's sema: `texture and sampler parameters are not lowered yet` |
| `sampler s [[sampler(0)]]` | nil | the same sema diagnostic |
| `float4 p [[attribute(0)]]` as a parameter | nil | mslc's parser: `unsupported attribute "attribute"` |
| `struct V { float4 p [[attribute(0)]]; }` | nil | mslc's parser accepts it on a field, then sema wants an address space |
| `metal::sqrt(4.0f)` | nil | mslc's parser has no `::` |
| `float4(1.0f)` | nil | mslc: `a scalar cannot be converted to a vector` |

So: **buffer-only compute kernels compile and run**. Everything else is blocked in
mslc's front end before this framework is asked for anything, and one gap is behind
another. `#include <metal_stdlib>` being ignored is the one that will bite first: it
succeeds, so an app that includes it gets a library, and then fails on the first
`metal::` it uses.

Blender's `mtl_context` needs a texture and a sampler, so it still fails, on the
first two rows.

## The reflection gap behind the mslc gap

mslc writes `"kind": "Buffer"` as a literal at one site (`src/sema.cpp`, the buffer
branch of the parameter loop). There is no code path in it that can emit a Texture, a
Sampler or a VertexInput, and the document has no `embeddedSamplers` key at all. So
even once mslc lowers textures, its reflection would still describe buffers only, and
`MTLReadMSLReflection` would refuse the document: it reads no texture access type, so
mapping a Texture onto indium's `TextureAccessType` would mean guessing between
sampling and storage access, and guessing wrong binds a sampled texture as a storage
image.

That is why the reader accepts `Buffer` and refuses every other kind rather than
accepting the three kinds indium defines. The two mslc-side gaps have to close
together for a textured shader to work, and `cristim/mslc`#33 is where the format
decision belongs.
