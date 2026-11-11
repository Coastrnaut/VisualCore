// EffectShaders.swift — GLSL ES 3.00 sources of the built-in passes (feature 005). Every pass draws a
// full-screen triangle; inputs are sampled as `u_<slot>` (e.g. `u_input`, `u_base`, `u_overlay`).

enum EffectShaders {
    /// Every built-in fragment source by name; shader validation compiles each one (feature 010 T-F905).
    static var fragments: [String: String] {
        ["copy": copy, "colorMatrix": colorMatrix, "blur": blur, "brightPass": brightPass, "addScaled": addScaled,
         "distort": distort, "composite": composite, "feedback": feedback, "luma": luma, "gainBias": gainBias]
    }

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

    /// Bloom bright pass: keeps light above `u_threshold` with a 0.1 soft knee (Rec. 709 luma).
    static let brightPass = """
    precision mediump float;
    uniform sampler2D u_input;
    uniform float u_threshold;
    in vec2 uv;
    out vec4 color;
    void main() {
        vec4 c = texture(u_input, uv);
        float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
        float k = smoothstep(u_threshold - 0.1, u_threshold + 0.1, luma);
        color = vec4(c.rgb * k, 1.0);
    }
    """

    /// Adds `u_intensity × u_overlay` to `u_base`.
    static let addScaled = """
    precision mediump float;
    uniform sampler2D u_base;
    uniform sampler2D u_overlay;
    uniform float u_intensity;
    in vec2 uv;
    out vec4 color;
    void main() {
        vec4 b = texture(u_base, uv);
        color = vec4(min(b.rgb + u_intensity * texture(u_overlay, uv).rgb, vec3(1.0)), b.a);
    }
    """

    /// Sinusoidal displacement: uv += strength × (sin, cos)(2π · frequency · uv.yx + time · speed).
    static let distort = """
    precision highp float;
    uniform sampler2D u_input;
    uniform float u_strength;
    uniform float u_frequency;
    uniform float u_phase;
    in vec2 uv;
    out vec4 color;
    void main() {
        float a = 6.2831853 * u_frequency * uv.y + u_phase;
        float b = 6.2831853 * u_frequency * uv.x + u_phase;
        vec2 offset = u_strength * vec2(sin(a), cos(b));
        color = texture(u_input, clamp(uv + offset, 0.0, 1.0));
    }
    """

    /// Mode 0: alpha "over" scaled by opacity; mode 1: additive.
    static let composite = """
    precision mediump float;
    uniform sampler2D u_base;
    uniform sampler2D u_overlay;
    uniform float u_mode;
    uniform float u_opacity;
    in vec2 uv;
    out vec4 color;
    void main() {
        vec4 b = texture(u_base, uv);
        vec4 o = texture(u_overlay, uv);
        float a = o.a * u_opacity;
        vec3 over = mix(b.rgb, o.rgb, a);
        vec3 add = min(b.rgb + o.rgb * u_opacity, vec3(1.0));
        color = vec4(u_mode < 0.5 ? over : add, max(b.a, a));
    }
    """

    /// output = input × (1 − decay) + history × decay.
    static let feedback = """
    precision mediump float;
    uniform sampler2D u_input;
    uniform sampler2D u_history;
    uniform float u_decay;
    in vec2 uv;
    out vec4 color;
    void main() { color = mix(texture(u_input, uv), texture(u_history, uv), u_decay); }
    """

    /// Rec. 709 luma of the input (sampled into a 16×16 target for the mean).
    static let luma = """
    precision mediump float;
    uniform sampler2D u_input;
    in vec2 uv;
    out vec4 color;
    void main() { float y = dot(texture(u_input, uv).rgb, vec3(0.2126, 0.7152, 0.0722)); color = vec4(y, y, y, 1.0); }
    """

    /// color × gain + bias (gain darkens, bias lifts) so the displayed mean equals the adapted value.
    static let gainBias = """
    precision mediump float;
    uniform sampler2D u_input;
    uniform float u_gain;
    uniform float u_bias;
    in vec2 uv;
    out vec4 color;
    void main() { vec4 c = texture(u_input, uv); color = vec4(clamp(c.rgb * u_gain + u_bias, 0.0, 1.0), c.a); }
    """
}
