#!/bin/bash
# Runs the metal_layer_window guest test and reads the window's pixels from the X screen while the test holds
# it up. Needs an X server (DISPLAY), the darling launcher on PATH and ImageMagick's import.
# usage: run_metal_layer_window.sh <built metal_layer_window> [ForceOpenGL]
#   ForceOpenGL runs it with CAMetalLayerForceOpenGL set, so that the layer presents through OpenGL.
# Prints the test's output, then "pixel RRGGBB" for the middle of the window as the X screen shows it (FF0000 when
# the last frame, solid red, got to the screen).
set -u
test_bin=$1
mode=${2:-}
out=$(mktemp)
trap 'rm -f "$out"' EXIT

if [ "$mode" = ForceOpenGL ]; then
	forced='defaults write -g CAMetalLayerForceOpenGL -bool YES; '
	reset='defaults delete -g CAMetalLayerForceOpenGL; '
else
	forced=''
	reset=''
fi

( cd "$(dirname "$test_bin")" && ulimit -v 8000000 && METAL_LAYER_HOLD=6 timeout -s KILL 120 darling shell bash -c "${forced}./$(basename "$test_bin"); ${reset}" </dev/null >"$out" 2>&1 ) &
pid=$!

for _ in $(seq 1 100); do
	grep -q '^READY' "$out" && break
	sleep 1
done

if read -r _ x y w h < <(grep '^READY' "$out"); then
	shot=$(mktemp --suffix=.png)
	import -window root "$shot" 2>/dev/null
	echo "pixel $(convert "$shot" -format '%[hex:p{'"$((x + w / 2)),$((y + h / 2))"'}]' info: 2>/dev/null)"
	rm -f "$shot"
fi
wait $pid
cat "$out"
