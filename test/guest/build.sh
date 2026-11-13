#!/bin/bash
# Cross-compiles the guest tests against the headers of a Metal worktree.
# usage: build.sh <metal worktree> <outdir>
set -eu
W=$1; O=$2; mkdir -p "$O"
for t in compile_options device_queries device_feature_queries stub_signatures drawable_present_handler; do
	~/darling-skills/darling-guest-testing/scripts/guest-cc.sh -o "$O/$t" "$(dirname "$0")/$t.m" \
		-I "$W/include" -fno-objc-arc -framework Foundation -framework Metal -Wno-deprecated-declarations -Wno-nullability-completeness
done
