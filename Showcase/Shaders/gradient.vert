// gradient.vert — full-screen triangle (Showcase scene 1).
#include "common.glsl"
out vec2 v_uv;
void main() {
    vec2 p = fullscreenCorner(gl_VertexID);
    v_uv = p;
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
