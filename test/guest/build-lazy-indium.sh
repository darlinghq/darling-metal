#!/bin/bash
# usage: build-lazy-indium.sh <metal worktree> <outdir>
set -eu
W=$1; O=$2; mkdir -p "$O"
for t in lazy_indium_init lazy_indium_init_nodevice; do
	~/darling-skills/darling-guest-testing/scripts/guest-cc.sh -o "$O/$t" "$(dirname "$0")/$t.m" \
		-I "$W/include" -fno-objc-arc -framework Foundation -framework Metal -Wno-nullability-completeness
done
