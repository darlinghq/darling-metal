# Source graphics compiler integration

Pin published mslc c745234 and compile its preprocessor unit. Its MslcOptions ABI grows from20 to48bytes onarm64, so all Metal caller objects must rebuild against the matching header; replacing only the compiler library is unsafe.

Fixture shader is preprocessed SOURCE from SkyCheckers a0783fa scengine/shaders.metal, float.h and metal_indices.h, each MIT Copyright2024MayurPawashe (notice retained). Diagnostic changes: USE_HALF0, sampled texture alias ->float, constant matrix/color references ->pointers with explicit dereference, direct vertex float4 return ->explicit Position struct. These isolate current source compilation; no original application/default.metallib is modified. Compiler issues142/185/187 track source gaps; no private AIR grammar is used.

```
flock /tmp/agent-locks/darling-heavy-build.lock python3 test/source-graphics/build.py /path/to/build /tmp/source-graphics
DPREFIX=/path/to/prefix DARLING_INSTALL_PREFIX=/path/to/private/image/usr/local /path/to/nonsetuid/darling shell env DARLING_ENABLE_METAL=1 VK_DRIVER_FILES=/usr/share/vulkan/icd.d/asahi_icd.json /Volumes/SystemRoot/tmp/source-graphics/graphics /Volumes/SystemRoot/path/to/test/source-graphics/shader.metal
# Same command with final argument negative-green must exit1.
# Native Wayland: hostenv -uDISPLAY -uDBUS_SESSION_BUS_ADDRESS, private XDG_RUNTIME_DIR/WAYLAND_DISPLAY;
# guest DARLING_APPKIT_BACKEND=wayland, window executable instead of graphics. X11 uses backend=x11 and own DISPLAY.
DPREFIX=/path/to/prefix DARLING_INSTALL_PREFIX=/path/to/private/image/usr/local /path/to/nonsetuid/darling shutdown
```

Recorded /home/cristi/tmp-opencode/metal-resume build and separate latest-source-runtime: old939source baseline exits2/typedefunsupported; latestc745 with oldreader exits2/unsupportedTexture; with separate source-reflection-reader fix c637fcd: position-red60000/60000, sampledtexture-blue60000/60000, exit0; wronggreen exits1. Sourcecompute16/0 remains0. Requires source-resource-reflection PR23 and existing Indium native-rendering fixes in this private baseline (541f353), independently tested; these are not bundled.

Native window public source pipelines and real Binput: native no-Xwayland Sway xdg_shell300x200 and X11 each screenshot60000red ->60000blue. Use real standard evdevB48 on Wayland or xdotoolb on X11, inspect screenshots and count pixels after a frame. Timer0.2 is rendercadence; no idle-runloop wake claim. No complete original-app compatibility claim. This newer compiler pin supersedes the older pin in PR22 only once its matching caller/preprocessor and reflection-reader prerequisites are included; it does not modify PR22.
