shader_type canvas_item;
uniform vec4 felt_color : source_color = vec4(0.05, 0.20, 0.17, 1.0);
uniform float motion = 1.0;
void fragment() {
    vec2 uv = UV;
    float t = TIME * 0.075 * motion;
    vec2 p = uv * 5.0;
    for(int i=1; i<4; i++) {
        float f = float(i);
        p += vec2(sin(p.y*f+t), cos(p.x*f-t)) * 0.23;
    }
    float veins = sin(p.x*3.0+p.y*2.5+t)*0.5+0.5;
    float weave = sin(FRAGCOORD.x*1.8)*sin(FRAGCOORD.y*1.8)*0.011;
    float vignette = 1.0-smoothstep(0.12,0.85,length((uv-0.5)*vec2(1.0,0.85)));
    vec3 col = felt_color.rgb * (0.73+veins*0.27+vignette*0.22)+weave;
    COLOR = vec4(col,1.0);
}
