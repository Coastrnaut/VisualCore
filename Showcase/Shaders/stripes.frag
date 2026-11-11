// stripes.frag — diagonal color stripes; content for the distortion scene (Showcase scene 3).
precision mediump float;
#include "common.glsl"
in vec2 v_uv;
uniform float u_aspect;
out vec4 color;
void main() {
    float s = step(0.5, fract((v_uv.x * u_aspect + v_uv.y) * 6.0));
    color = vec4(mix(vec3(0.08, 0.1, 0.25), hue(fract(v_uv.y * 0.5 + 0.55)), s), 1.0);
}
