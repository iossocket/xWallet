#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// 这里直接从顶点数组里取位置和颜色
vertex VertexOut candle_vertex(
    uint vertexID [[vertex_id]],
    const device float2 *positions [[buffer(0)]],
    const device float4 *colors [[buffer(1)]]
) {
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.color = colors[vertexID];
    return out;
}

fragment float4 candle_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
