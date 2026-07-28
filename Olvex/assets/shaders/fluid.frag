#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color1;
    vec4 color2;
    float time;
    float freq1;
    float freq2;
    float freq3;
};

void main() {
    vec2 uv = qt_TexCoord0;
    
    // Smooth time for motion
    float t = time * 2.0;
    
    // Create sharp wavy lines that react directly to frequencies
    vec2 p = uv;
    
    // Vertical displacement based on sine waves tied to frequencies
    float wave1 = sin(p.x * 10.0 + t) * freq1 * 0.4;
    float wave2 = sin(p.x * 20.0 - t * 1.5) * freq2 * 0.3;
    float wave3 = sin(p.x * 30.0 + t * 2.0) * freq3 * 0.2;
    
    float totalWave = wave1 + wave2 + wave3;
    
    // Distance from the horizontal center line, distorted by the waves
    float distToLine = abs(p.y - 0.5 - totalWave);
    
    // Make a sharp bright line at the center of the wave
    float lineIntensity = smoothstep(0.1, 0.0, distToLine);
    
    // Add glowing aura around the line based on the frequency intensity
    float aura = exp(-distToLine * 5.0) * (freq1 + freq2 + freq3) * 0.8;
    
    // Add pulsing background that reacts to bass (freq1)
    float bgPulse = exp(-distance(p, vec2(0.5, 0.5)) * 2.0) * freq1 * 0.5;
    
    // Combine colors: background is dark, aura is color2, line is color1
    vec3 baseBg = mix(vec3(0.0), color2.rgb, bgPulse * 0.5);
    vec3 finalColor = baseBg + (color2.rgb * aura) + (color1.rgb * lineIntensity * 1.5);
    
    fragColor = vec4(finalColor, 1.0) * qt_Opacity;
}
