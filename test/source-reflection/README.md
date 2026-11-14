# Source reflection resources

`resources.mm` feeds hand-written mslc reflection documents to the reader in
`src/Metal/MTLMSLReflection.mm` and checks the resulting library reflection:
binding type, stage, Metal and descriptor indices, and every field of embedded
samplers. It also checks that malformed documents are refused: unknown access or
address mode, invalid embedded sampler index, a number where a boolean belongs,
null or inverted LOD limits, a missing sampler list, a boolean anisotropy, a wrong
descriptor set, and external and embedded indices that conflict.

The reader accepts only the sampler and texture access values mslc emits. Buffer
only documents without `embedded_samplers` remain valid, and any new schema value
is rejected explicitly.

`build.py <build-dir> <output>` compiles the check with the flags of a configured
Darling build tree (found with `ninja -t commands Metal`) and links it against the
Metal library of that tree. `--reader <file>` compiles another reader source in
place of the one in this tree, which is how the check is run against an older
reader to confirm it fails there. Run the program in a prefix and expect all
checks to pass with exit status 0.
