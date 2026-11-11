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

    /// One direction of a separable Gaussian: 9 taps spaced `u_step` texels apart, σ = radius / 2.
    static let blur = """
    precision highp float;
    uniform sampler2D u_input;
    uniform vec2 u_direction;   // (1,0) or (0,1) in texels
    uniform float u_radius;
    in vec2 uv;
    out vec4 color;
    void main() {
        vec2 texel = 1.0 / vec2(textureSize(u_input, 0));
        float sigma = max(u_radius * 0.5, 0.5);
        float spacing = max(u_radius / 4.0, 1.0);
        vec4 sum = vec4(0.0);
        float weights = 0.0;
        for (int i = -4; i <= 4; i++) {
            float x = float(i) * spacing;
            float w = exp(-(x * x) / (2.0 * sigma * sigma));
            sum += w * texture(u_input, uv + u_direction * texel * x);
            weights += w;
        }
        color = sum / weights;
    }
    """
}
