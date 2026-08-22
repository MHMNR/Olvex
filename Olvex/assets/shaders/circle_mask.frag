#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 uv = qt_TexCoord0.st;
    vec2 p = uv - vec2(0.5);
    float dist = length(p);
    
    // Analytical subpixel antialiasing via screen-space derivative
    float delta = fwidth(dist);
    float alpha = clamp((0.5 - dist) / max(delta, 0.0001), 0.0, 1.0);
    
    fragColor = texture(source, uv) * alpha * qt_Opacity;
}
