# Source reflection resources

Authored JSON uses published mslc c745234 src/sema.cpp resource/embedded sampler emission and src/ast.cpp enum names. Indium library.hpp specifies the typed consumer. No compiled guest shader inputs.

Build against a configured arm64 Darling tree, using its production Metal flags:

```
git show origin/main:src/Metal/MTLMSLReflection.mm > /tmp/reflection-before-reader.mm
flock /tmp/agent-locks/darling-heavy-build.lock python3 test/source-reflection/build.py /path/to/build /tmp/reflection-before --library /path/to/Metal --reader /tmp/reflection-before-reader.mm
flock /tmp/agent-locks/darling-heavy-build.lock python3 test/source-reflection/build.py /path/to/build /tmp/reflection-after --library /path/to/baseline/Metal --candidate
DPREFIX=/path/to/private/prefix DARLING_INSTALL_PREFIX=/path/to/private/image/usr/local /path/to/nonsetuid/darling shell env DARLING_ENABLE_METAL=1 /Volumes/SystemRoot/tmp/reflection-before
DPREFIX=/path/to/private/prefix DARLING_INSTALL_PREFIX=/path/to/private/image/usr/local /path/to/nonsetuid/darling shell env DARLING_ENABLE_METAL=1 /Volumes/SystemRoot/tmp/reflection-after
DPREFIX=/path/to/private/prefix DARLING_INSTALL_PREFIX=/path/to/private/image/usr/local /path/to/nonsetuid/darling shutdown
```

Measured with /home/cristi/tmp-opencode/metal-resume/build and baseline latest-source-build/Metal (a3f12e0): exit1, Buffer passes; sampled/storage textures and external/embedded samplers fail. Candidate exit0, all15 checks pass. Check binding type, stage, Metal/descriptor indices, all embedded fields; reject unknown access/address, invalid embedded index, numeric boolean substitute, null/inverted LOD, missing sampler list, boolean anisotropy, wrong descriptor set, conflicting external/embedded indices.

The reader accepts only producer-supported Sample/Write texture access and sampler names/states. Parser Write acceptance is not GPU storage-texture verification. Buffer-only version2 documents with no embedded_samplers remain valid. Unknown new schema values reject explicitly. Native sampled texture validation follows through public newLibraryWithSource and exact RGBA readback in the independent source-graphics fixture.

Standalone upstream main5231808 baseline source object exits1 with four positive resource failures; candidate all15 pass, using upstream Indiumdab28b3 headers. Full public source API baseline with compiler c745 rejects Texture; committed reader overlay compiles the normalized MIT Sky source and renders position-red60000/60000 and sampled texture-blue60000/60000 on M1. Wrong expected green exits1; source compute16/0 exits0. This requires matching c745 compiler/caller ABI and preprocessor build integration, separate from this reader patch.

Native Wayland source window: committed authored fixture f2603b3, independent no-Xwayland Sway, xdg_shell300x200; real standard evdev B48 changes exactly60000red to60000blue screenshot pixels. This proves sampled source presentation and input, not original SkyCheckers/DodgeDanger compatibility, storage-texture GPU behavior, or generic idle input wake behavior.
