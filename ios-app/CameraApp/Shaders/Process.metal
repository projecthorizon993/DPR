#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Per-style 3x3 color matrix (row-major), passed as 9 floats.
struct ColorMatrix {
    float m00, m01, m02;
    float m10, m11, m12;
    float m20, m21, m22;
};

// Push constants for the compute kernel.
struct ProcessParams {
    ColorMatrix matrix;
    float gamma;
    float pad0;
    float pad1;
    float pad2;
};

// 3D LUT node: RGB offset in 0..255.
struct LutNode {
    float r, g, b;
    float pad;
};

kernel void process_frame(
    texture2d<float, access::read>  inTexture  [[ texture(0) ]],
    texture2d<float, access::write> outTexture [[ texture(1) ]],
    constant ProcessParams&         params     [[ buffer(0) ]],
    device const LutNode*           lutGrid    [[ buffer(1) ]],
    uint2                           gid        [[ thread_position_in_grid ]])
{
    const uint2 dim = outTexture.get_dimensions();
    if (gid.x >= dim.x || gid.y >= dim.y) {
        return;
    }

    // Read input pixel (RGBA, 0..1).
    float4 inColor = inTexture.read(gid);
    float3 rgb = inColor.rgb * 255.0;

    // --- 1. 3x3 color matrix ---
    float3 m;
    m.x = params.matrix.m00 * rgb.x + params.matrix.m01 * rgb.y + params.matrix.m02 * rgb.z;
    m.y = params.matrix.m10 * rgb.x + params.matrix.m11 * rgb.y + params.matrix.m12 * rgb.z;
    m.z = params.matrix.m20 * rgb.x + params.matrix.m21 * rgb.y + params.matrix.m22 * rgb.z;

    // --- 2. 3D LUT offset (trilinear sampled) ---
    const int LUT_DIM = 17;
    const float inv = float(LUT_DIM - 1);
    float3 nrgb = rgb / 255.0;

    float3 rf = nrgb * inv;
    int3   r0 = int3(floor(rf));
    int3   r1 = int3(clamp(r0 + 1, 0, LUT_DIM - 1));
    float3 fr = rf - float3(r0);

    // Node index: z * DIM * DIM + y * DIM + x.
    auto nodeIdx = [&](int x, int y, int z) -> int {
        return z * LUT_DIM * LUT_DIM + y * LUT_DIM + x;
    };

    LutNode c000 = lutGrid[nodeIdx(r0.x, r0.y, r0.z)];
    LutNode c100 = lutGrid[nodeIdx(r1.x, r0.y, r0.z)];
    LutNode c010 = lutGrid[nodeIdx(r0.x, r1.y, r0.z)];
    LutNode c110 = lutGrid[nodeIdx(r1.x, r1.y, r0.z)];
    LutNode c001 = lutGrid[nodeIdx(r0.x, r0.y, r1.z)];
    LutNode c101 = lutGrid[nodeIdx(r1.x, r0.y, r1.z)];
    LutNode c011 = lutGrid[nodeIdx(r0.x, r1.y, r1.z)];
    LutNode c111 = lutGrid[nodeIdx(r1.x, r1.y, r1.z)];

    // Trilinear interpolation.
    float3 c00 = float3(c000.r, c000.g, c000.b) * (1.0 - fr.x) +
                 float3(c100.r, c100.g, c100.b) * fr.x;
    float3 c10 = float3(c010.r, c010.g, c010.b) * (1.0 - fr.x) +
                 float3(c110.r, c110.g, c110.b) * fr.x;
    float3 c01 = float3(c001.r, c001.g, c001.b) * (1.0 - fr.x) +
                 float3(c101.r, c101.g, c101.b) * fr.x;
    float3 c11 = float3(c011.r, c011.g, c011.b) * (1.0 - fr.x) +
                 float3(c111.r, c111.g, c111.b) * fr.x;
    float3 c0 = c00 * (1.0 - fr.y) + c10 * fr.y;
    float3 c1 = c01 * (1.0 - fr.y) + c11 * fr.y;
    float3 lutOffset = c0 * (1.0 - fr.z) + c1 * fr.z;

    // --- 3. Combine matrix + LUT, apply gamma ---
    float3 combined = m + lutOffset;
    combined = clamp(combined, 0.0, 255.0);

    float invGamma = 1.0 / params.gamma;
    float3 t = combined / 255.0;
    float3 out = pow(t, float3(invGamma)) * 255.0;
    out = clamp(out, 0.0, 255.0);

    // Write output (RGBA, 0..1), preserve alpha.
    outTexture.write(
        float4(out / 255.0, inColor.a),
        gid);
}
