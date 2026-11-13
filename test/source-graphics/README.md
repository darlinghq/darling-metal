# Source graphics

Compiles a vertex and fragment function from MSL source through
`-newLibraryWithSource:options:error:`, draws with a sampled texture into an
offscreen target and checks the pixels: the position-dependent red and the sampled
blue must each cover the expected number of pixels. Passing `negative-green` as
the last argument inverts the expectation and must exit 1. `window.m` shows the
same pipeline in a window.

`shader.metal` is preprocessed source derived from an MIT-licensed game's shaders
(licence notices retained in the file). Local changes only avoid constructs mslc
does not translate yet: half precision off, the sampled texture type aliased to
float, constant references turned into pointers with explicit dereferences, and
an explicit struct for the vertex output.

`build.py <build-dir> <output-dir>` compiles the programs with the flags of a
configured Darling build tree. The compiler library and the Metal objects that
include `mslc/mslc.h` must come from the same build, since `MslcOptions` grows
when mslc adds options.
