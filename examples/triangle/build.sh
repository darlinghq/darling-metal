#!/bin/bash

# meant to be run within Darling (or from macOS)

#rm -rf build
mkdir -p build

xcrun metal -o build/AAPLShaders.air -c Renderer/AAPLShaders.metal
xcrun metallib -o build/default.metallib build/AAPLShaders.air

clang -o build/triangle -g main.m Renderer/AAPLRenderer.m -framework Metal -framework MetalKit -framework AppKit
