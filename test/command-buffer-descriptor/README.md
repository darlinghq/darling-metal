# Command buffer descriptor export regression

This authored guest loads Metal and checks the existing descriptor's class export,
property round trips and independent copy. It requires no GPU or app credentials.
The contract comes from the vendored MTLCommandBuffer.h and existing
MTLCommandBufferDescriptor.mm, clean-room rung 2; this fix changes only source
registration, not descriptor behavior.

Build using the flags and libraries of a populated Darling build:

```sh
flock /tmp/agent-locks/darling-heavy-build.lock \
  python3 test/command-buffer-descriptor/build.py "$BUILD" "$SCRATCH/probe"
DPREFIX="$PREFIX" DARLING_INSTALL_PREFIX="$IMAGE/usr/local" \
  "$LAUNCHER" shell "$GUEST_PROBE"
```

Use the build's non-setuid launcher and a private committed runtime. Always stop
that prefix with the same launcher and `darling shutdown`.

Measured 2026-10-08: baseline Metal 9207e5a omits the descriptor source from its
explicit CMake list; guest prints `FAIL missing MTLCommandBufferDescriptor`,
exit 1. Adding the existing source to the library produces `PASS descriptor
exported and copy properties preserved`, exit 0. Candidate was compiled using
production Metal flags and linked using unchanged private build objects.

Actual Blender 5.1.2 baseline also fails at dyld on this class. Native Wayland
candidate passes that error, connects to the backend, then writes a crash report
before creating a window. The report contains no stack; no crash root cause or
interactive app success is claimed. X11 candidate also passes the missing-class barrier and writes a crash report
before showing a window. No binary instructions were inspected.
