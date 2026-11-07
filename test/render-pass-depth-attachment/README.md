Guest test: a render pass descriptor's depth attachment must exist before it is assigned,
like the color attachments, so that `descriptor.depthAttachment.texture = t` keeps `t`.
It creates a `Depth32Float` render-target texture, assigns it with a clear depth of 0.5 and
checks the properties read back.

Build it with the Darling tree's AppKit compile flags, linking Foundation and the Metal
framework, and run it in a guest with Metal enabled on a private runtime and prefix:

```sh
python3 build-probe.py test/render-pass-depth-attachment/client.m "$OUT/client" "$METAL"
env DARLING_ENABLE_METAL=1 DPREFIX="$PREFIX" DARLING_INSTALL_PREFIX="$RUNTIME/image/usr/local" "$RUNTIME/darling" shell env DARLING_ENABLE_METAL=1 "/Volumes/SystemRoot$OUT/client"
```

Before: `depth attachment texture LOST clearDepth 0.00 loadAction 0`, exit 1. After: `kept`, 0.50,
loadAction 2, exit 0.
