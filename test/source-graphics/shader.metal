/*
 MIT License

 Copyright (c) 2024 Mayur Pawashe

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */
// Diagnostic source normalizations documented in README.md; original app untouched.
typedef half2x2 matrix_half2x2;
typedef half3x2 matrix_half3x2;
typedef half4x2 matrix_half4x2;
typedef half2x3 matrix_half2x3;
typedef half3x3 matrix_half3x3;
typedef half4x3 matrix_half4x3;
typedef half2x4 matrix_half2x4;
typedef half3x4 matrix_half3x4;
typedef half4x4 matrix_half4x4;
typedef float2x2 matrix_float2x2;
typedef float3x2 matrix_float3x2;
typedef float4x2 matrix_float4x2;
typedef float2x3 matrix_float2x3;
typedef float3x3 matrix_float3x3;
typedef float4x3 matrix_float4x3;
typedef float2x4 matrix_float2x4;
typedef float3x4 matrix_float3x4;
typedef float4x4 matrix_float4x4;
typedef half2x2 simd_half2x2;
typedef half3x2 simd_half3x2;
typedef half4x2 simd_half4x2;
typedef half2x3 simd_half2x3;
typedef half3x3 simd_half3x3;
typedef half4x3 simd_half4x3;
typedef half2x4 simd_half2x4;
typedef half3x4 simd_half3x4;
typedef half4x4 simd_half4x4;
typedef float2x2 simd_float2x2;
typedef float3x2 simd_float3x2;
typedef float4x2 simd_float4x2;
typedef float2x3 simd_float2x3;
typedef float3x3 simd_float3x3;
typedef float4x3 simd_float4x3;
typedef float2x4 simd_float2x4;
typedef float3x4 simd_float3x4;
typedef float4x4 simd_float4x4;
typedef enum
{
METAL_BUFFER_VERTICES_INDEX = 0,
METAL_BUFFER_MODELVIEW_PROJECTION_INDEX = 1,
METAL_BUFFER_COLOR_INDEX = 2,
METAL_BUFFER_TEXTURE_COORDINATES_INDEX = 3,
METAL_BUFFER_TEXTURE_INDICES_INDEX = 4
} MetalBufferIndex;
typedef enum
{
METAL_TEXTURE_INDEX = 0
} MetalTextureIndex;
typedef float4 ZGFloat4;
typedef float2 ZGFloat2;
typedef float ZGFloat;
typedef matrix_float4x4 ZGFloat_matrix4x4;
using namespace metal;
struct DiagnosticPositionOutput { float4 position [[position]]; };
vertex DiagnosticPositionOutput positionVertexShader(const ushort vertexID [[ vertex_id ]], const device ZGFloat4 *vertices [[ buffer(METAL_BUFFER_VERTICES_INDEX) ]], constant ZGFloat_matrix4x4 *modelViewProjection [[ buffer(METAL_BUFFER_MODELVIEW_PROJECTION_INDEX) ]])
{
DiagnosticPositionOutput output;
output.position = float4((*modelViewProjection) * vertices[vertexID]);
return output;
}
fragment ZGFloat4 positionFragmentShader(constant ZGFloat4 *color [[ buffer(METAL_BUFFER_COLOR_INDEX) ]])
{
return *color;
}
typedef struct
{
float4 position [[position]];
float2 textureCoordinate;
} TextureRasterizerData;
vertex TextureRasterizerData texturePositionVertexShader(const ushort vertexID [[ vertex_id ]], const device ZGFloat4 *vertices [[ buffer(METAL_BUFFER_VERTICES_INDEX) ]], constant ZGFloat_matrix4x4 *modelViewProjection [[ buffer(METAL_BUFFER_MODELVIEW_PROJECTION_INDEX) ]], const device ZGFloat2 *textureCoordinates [[ buffer(METAL_BUFFER_TEXTURE_COORDINATES_INDEX) ]])
{
TextureRasterizerData output;
output.position = float4((*modelViewProjection) * vertices[vertexID]);
output.textureCoordinate = float2(textureCoordinates[vertexID]);
return output;
}
fragment ZGFloat4 texturePositionFragmentShader(const TextureRasterizerData input [[stage_in]], const texture2d<float> texture [[ texture(METAL_TEXTURE_INDEX) ]], constant ZGFloat4 *color [[ buffer(METAL_BUFFER_COLOR_INDEX) ]])
{
constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
const ZGFloat4 colorSample = texture.sample(textureSampler, input.textureCoordinate);
return (*color) * ZGFloat4(colorSample);
}
