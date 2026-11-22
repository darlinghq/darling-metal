#!/bin/bash
# Cross-compiles the guest tests against the headers of a Metal worktree.
# usage: build.sh <metal worktree> <outdir>
set -eu
W=$1; O=$2; mkdir -p "$O"
for t in compile_options resource_api fill_mode_depth_clip indirect_draw_dispatch pixel_format_views a8unorm_write nonuniform_dispatch command_buffer_status device_queries device_feature_queries vertex_attributes function_constants stub_signatures sampler_defaults stencil_descriptor render_encoder_store_actions pipeline_sample_count compressed_texture_usage drawable_present_handler heaps events_fences visibility_results texture_uploads hazard_tracking command_buffer_submission parallel_render_encoder buffer_no_copy air_coverage air_coverage_2 air_coverage_3 air_coverage_4 pipeline_cache current_allocated_size diagnostics_settings counters iosurface_seed sample_offset stage_interface_names; do
	~/darling-skills/darling-guest-testing/scripts/guest-cc.sh -o "$O/$t" "$(dirname "$0")/$t.m" \
		-I "$W/include" -fno-objc-arc -framework Foundation -framework Metal -Wno-deprecated-declarations -Wno-nullability-completeness
done

# need a window system
for t in metal_layer_window metal_layer_framebuffer_only; do
	~/darling-skills/darling-guest-testing/scripts/guest-cc.sh -o "$O/$t" "$(dirname "$0")/$t.m" \
		-I "$W/include" -fno-objc-arc -framework Foundation -framework AppKit -framework QuartzCore -framework Metal -Wno-deprecated-declarations -Wno-nullability-completeness
done

# need MetalKit
for t in texture_loader_async; do
	~/darling-skills/darling-guest-testing/scripts/guest-cc.sh -o "$O/$t" "$(dirname "$0")/$t.m" \
		-I "$W/include" -fno-objc-arc -framework Foundation -framework AppKit -framework CoreGraphics -framework ImageIO -framework Metal -framework MetalKit -Wno-deprecated-declarations -Wno-nullability-completeness
done
