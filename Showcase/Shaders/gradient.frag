// gradient.frag — left half: animated hue gradient; right half: the bundled checker texture, tiled twice.
precision mediump float;
#include "common.glsl"
in vec2 v_uv;
uniform float u_time;
uniform sampler2D u_texture;
out vec4 color;
void main() {
    if (v_uv.x < 0.5) {
        float h = v_uv.y * 0.8 + v_uv.x * 0.4 + u_time * 0.05;
        color = vec4(hue(fract(h)), 1.0);
    } else {
        vec2 t = vec2((v_uv.x - 0.5) * 2.0, v_uv.y) * 2.0;
        color = texture(u_texture, fract(t));
    }
}
