#version 440

layout(location = 0) in vec4 qt_VertexPosition;
layout(location = 1) in vec2 qt_VertexTexCoord;

layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float maxHeightRatio;
    float edgeFeather;
    float topFadeRatio;
    int bandCount;
    float _pad0;
    float _pad1;
    vec4 accentColor;
    vec4 boostedColor;
    vec4 values[8];
};

void main() {
    gl_Position = qt_Matrix * qt_VertexPosition;
    qt_TexCoord0 = qt_VertexTexCoord;
}
