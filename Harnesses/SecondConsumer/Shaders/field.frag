// field.frag — slow aurora over a night field (Lumen Garden background, original).
precision mediump float;
in vec2 v_uv;
uniform float u_time;
out vec4 color;
void main() {
    float band = sin(v_uv.x * 3.0 + u_time * 0.15) * 0.08 + 0.72;
    float aurora = exp(-pow((v_uv.y - band) * 9.0, 2.0)) * 0.35;
    vec3 sky = mix(vec3(0.02, 0.03, 0.07), vec3(0.04, 0.08, 0.12), v_uv.y);
    vec3 glow = vec3(0.15, 0.55, 0.45) * aurora;
    float ground = smoothstep(0.32, 0.30, v_uv.y);
    color = vec4(mix(sky + glow, vec3(0.03, 0.06, 0.04), ground), 1.0);
}
