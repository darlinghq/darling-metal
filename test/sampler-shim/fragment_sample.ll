; AIR for the harness's fragment stage: a pure pass-through of the sampled texel.
;
; The body is the real shaders.metal fragment_texture's sampling call and nothing
; else, so the framebuffer pixel IS the sampled texel and the host reference is a
; bare sampler emulation. The argument list and the !air.fragment metadata are
; copied verbatim from the real fragment_texture.air (disassembled from
; test/texturing/shaders.metallib) so the stage_in linkage, the buffer binding
; and the texture/sampler bindings are known-good.
;
; Signature: position, eyePosition, normal, texCoords (stage_in), uniforms
; (buffer 0), diffuseTexture (texture 0, sample), samplr (sampler 0).

define <4 x float> @fragment_sample(<4 x float> %0, <3 x float> %1, <3 x float> %2, <2 x float> %3, ptr addrspace(2) noalias readnone captures(none) dereferenceable(176) %4, ptr addrspace(1) readonly captures(none) %5, ptr addrspace(2) readonly captures(none) %6) local_unnamed_addr #0 {
  %8 = tail call { <4 x float>, i8 } @air.sample_texture_2d.v4f32(ptr addrspace(1) readonly captures(none) %5, ptr addrspace(2) readonly captures(none) %6, <2 x float> %3, i1 true, <2 x i32> zeroinitializer, i1 false, float 0.000000e+00, float 0.000000e+00, i32 0) #2
  %9 = extractvalue { <4 x float>, i8 } %8, 0
  ret <4 x float> %9
}

; Function Attrs: nounwind memory(none)
declare { <4 x float>, i8 } @air.sample_texture_2d.v4f32(ptr addrspace(1) readonly captures(none), ptr addrspace(2) readonly captures(none), <2 x float>, i1, <2 x i32>, i1, float, float, i32) local_unnamed_addr #2

attributes #0 = { convergent nounwind memory(read) "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #2 = { convergent nounwind memory(argmem: read) }

!llvm.module.flags = !{!0, !1}
!llvm.ident = !{!2}
!air.version = !{!3}
!air.language_version = !{!4}
!air.compile_options = !{!5, !6, !7}
!air.fragment = !{!8}

!0 = !{i32 2, !"SDK Version", [3 x i32] [i32 10, i32 15, i32 6]}
!1 = !{i32 1, !"wchar_size", i32 4}
!2 = !{!"Apple LLVM version 902.14 (metalfe-902.14.12)"}
!3 = !{i32 2, i32 2, i32 0}
!4 = !{!"Metal", i32 2, i32 2, i32 0}
!5 = !{!"air.compile.denorms_disable"}
!6 = !{!"air.compile.fast_math_enable"}
!7 = !{!"air.compile.framebuffer_fetch_disable"}
!8 = !{ptr @fragment_sample, !9, !11}
!9 = !{!10}
!10 = !{!"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4"}
!11 = !{!12, !13, !14, !15, !16, !18, !19}
!12 = !{i32 0, !"air.position", !"air.center", !"air.no_perspective", !"air.arg_type_name", !"float4", !"air.arg_name", !"position"}
!13 = !{i32 1, !"air.fragment_input", !"generated(11eyePositionDv3_f)", !"air.center", !"air.perspective", !"air.arg_type_name", !"float3", !"air.arg_name", !"eyePosition"}
!14 = !{i32 2, !"air.fragment_input", !"generated(6normalDv3_f)", !"air.center", !"air.perspective", !"air.arg_type_name", !"float3", !"air.arg_name", !"normal"}
!15 = !{i32 3, !"air.fragment_input", !"generated(9texCoordsDv2_f)", !"air.center", !"air.perspective", !"air.arg_type_name", !"float2", !"air.arg_name", !"texCoords"}
!16 = !{i32 4, !"air.buffer", !"air.buffer_size", i32 176, !"air.location_index", i32 0, i32 1, !"air.read", !"air.struct_type_info", !17, !"air.arg_type_size", i32 176, !"air.arg_type_align_size", i32 16, !"air.arg_type_name", !"Uniforms", !"air.arg_name", !"uniforms"}
!17 = !{i32 0, i32 64, i32 0, !"float4x4", !"modelViewProjectionMatrix", i32 64, i32 64, i32 0, !"float4x4", !"modelViewMatrix", i32 128, i32 48, i32 0, !"float3x3", !"normalMatrix"}
!18 = !{i32 5, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.sample", !"air.arg_type_name", !"texture2d<float, sample>", !"air.arg_name", !"diffuseTexture"}
!19 = !{i32 6, !"air.sampler", !"air.location_index", i32 0, i32 1, !"air.arg_type_name", !"sampler", !"air.arg_name", !"samplr"}
