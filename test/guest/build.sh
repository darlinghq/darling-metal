#!/bin/bash
# Cross-compiles the guest tests against the headers of a Metal worktree.
# usage: build.sh <metal worktree> <outdir>
set -eu
W=$1; O=$2; mkdir -p "$O"
for t in compile_options resource_api fill_mode_depth_clip indirect_draw_dispatch pixel_format_views a8unorm_write nonuniform_dispatch command_buffer_status device_queries device_feature_queries vertex_attributes function_constants stub_signatures drawable_present_handler heaps events_fences visibility_results texture_uploads; do
	~/darling-skills/darling-guest-testing/scripts/guest-cc.sh -o "$O/$t" "$(dirname "$0")/$t.m" \
		-I "$W/include" -fno-objc-arc -framework Foundation -framework Metal -Wno-deprecated-declarations -Wno-nullability-completeness
done
