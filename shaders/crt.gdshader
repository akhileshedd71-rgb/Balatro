shader_type canvas_item;
uniform float intensity : hint_range(0.0,1.0) = 0.18;
void fragment() {
    float scan = sin(FRAGCOORD.y * 3.14159) * 0.025 + 0.025;
    float edge = smoothstep(0.35,0.78,length(UV-0.5))*0.22;
    COLOR = vec4(0.01,0.025,0.02,(scan+edge)*intensity);
}
