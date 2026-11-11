// EffectShaders.swift — GLSL ES 3.00 sources of the built-in passes (feature 005). Every pass draws a
// full-screen triangle; inputs are sampled as `u_<slot>` (e.g. `u_input`, `u_base`, `u_overlay`).

enum EffectShaders {
    static let vertex = """
    out vec2 uv;
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        uv = p;
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """

    static let copy = """
    precision mediump float;
    uniform sampler2D u_input;
    in vec2 uv;
    out vec4 color;
    void main() { color = texture(u_input, uv); }
    """

    static let colorMatrix = """
    precision mediump float;
    uniform sampler2D u_input;
    uniform mat4 u_matrix;
    uniform vec4 u_offset;
    in vec2 uv;
    out vec4 color;
    void main() { color = clamp(u_matrix * texture(u_input, uv) + u_offset, 0.0, 1.0); }
    """
}
