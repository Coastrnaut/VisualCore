// EffectShaders.swift — GLSL ES 3.00 sources of the built-in passes (feature 005). Every pass draws a
// full-screen triangle; inputs are sampled as `u_<slot>` (e.g. `u_input`, `u_base`, `u_overlay`).
// Feature 207 R02-F07 T-R02F07-005: the emissive programs (prefilter, blur, composite) with a local unclamped sRGB
// decode, composite mode 2 (premultiplied over) and the limiter's optional linear-light luma.

enum EffectShaders {
    /// Every built-in fragment source by name; shader validation compiles each one (feature 010 T-F905).
    static var fragments: [String: String] {
        ["copy": copy, "colorMatrix": colorMatrix, "blur": blur, "brightPass": brightPass, "addScaled": addScaled,
         "distort": distort, "composite": composite, "feedback": feedback, "luma": luma, "gainBias": gainBias]
    }

    /// The emissive pass's fragment sources by name (feature 207); compiled by EmissivePassTests. Kept apart from
    /// `fragments` so the feature 010 count of ten stays as it is.
    static var emissiveFragments: [String: String] {
        ["emissivePrefilter": emissivePrefilter, "emissiveBlur": emissiveBlur, "emissiveComposite": emissiveComposite]
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

    /// Mode 0: alpha "over" scaled by opacity; mode 1: additive; mode 2: premultiplied over
    /// `overlay · opacity + base · (1 − overlay.a · opacity)` on all four channels (feature 207).
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
        if (u_mode > 1.5) {
            color = clamp(o * u_opacity + b * (1.0 - a), 0.0, 1.0);
        } else {
            color = vec4(u_mode < 0.5 ? over : add, max(b.a, a));
        }
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

    /// Rec. 709 luma of the input (sampled into a 16×16 target for the mean). With `u_linear` = 1 (feature 207) the
    /// sample is decoded from sRGB to linear light first; 0 (the default) measures the encoded values as before.
    static let luma = """
    precision mediump float;
    uniform sampler2D u_input;
    uniform float u_linear;
    in vec2 uv;
    out vec4 color;
    \(emissiveTransfer)
    void main() {
        vec3 c = texture(u_input, uv).rgb;
        if (u_linear > 0.5) { c = em_decode(c); }
        float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
        color = vec4(y, y, y, 1.0);
    }
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

    // MARK: Emissive pass (feature 207 R02-F07 T-R02F07-005; research R1–R4)

    /// Exact piecewise sRGB transfer shared by the emissive programs and the limiter's linear luma. `em_decode` does
    /// not clamp above 1 (unlike `vc_srgbDecode`, research R4); `em_encode` clamps to 0…1, as
    /// `EmissiveReference.srgbEncode`.
    static let emissiveTransfer = """
    float em_decode(float x) { x = max(x, 0.0); return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4); }
    vec3 em_decode(vec3 c) { return vec3(em_decode(c.r), em_decode(c.g), em_decode(c.b)); }
    float em_encode(float x) {
        x = clamp(x, 0.0, 1.0);
        return clamp(x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1.0 / 2.4) - 0.055, 0.0, 1.0);
    }
    vec3 em_encode(vec3 c) { return vec3(em_encode(c.r), em_encode(c.g), em_encode(c.b)); }
    """

    /// Emissive prefilter, drawn at the blur size: four bilinear taps at ±0.25 blur texel (`u_tapOffset`, in uv)
    /// around the texel centre. At half size that is ±0.5 input texel, so each tap lands on one input texel centre
    /// and the four cover the 2×2 block exactly; at quarter size it is ±1 input texel, so each tap falls between two
    /// texel centres in both axes (an equal-weight 2×2 average) and the four cover the 4×4 block exactly. Each tap is
    /// decoded (unclamped), the four are averaged, then `EmissiveReference.prefilter` keeps the light above the
    /// threshold with the quadratic knee `k = knee · threshold`.
    static let emissivePrefilter = """
    precision highp float;
    uniform sampler2D u_input;
    uniform vec2 u_tapOffset;
    uniform float u_threshold;
    uniform float u_knee;
    in vec2 uv;
    out vec4 color;
    \(emissiveTransfer)
    void main() {
        vec2 o = u_tapOffset;
        vec3 s = em_decode(texture(u_input, uv + vec2(-o.x, -o.y)).rgb) + em_decode(texture(u_input, uv + vec2(o.x, -o.y)).rgb)
               + em_decode(texture(u_input, uv + vec2(-o.x, o.y)).rgb) + em_decode(texture(u_input, uv + vec2(o.x, o.y)).rgb);
        s *= 0.25;
        float k = u_knee * u_threshold;
        float l = dot(s, vec3(0.2126, 0.7152, 0.0722));
        float soft = clamp(l - u_threshold + k, 0.0, 2.0 * k);
        soft = soft * soft / (4.0 * k + 1e-5);
        float contribution = max(soft, l - u_threshold) / max(l, 1e-5);
        color = vec4(s * contribution, 1.0);
    }
    """

    /// One direction of the emissive blur: 9 taps one texel apart, Gaussian weights with σ = radius / 2, normalised;
    /// tap positions are clamped to the edge texel centres.
    static let emissiveBlur = """
    precision highp float;
    uniform sampler2D u_input;
    uniform vec2 u_direction;   // (1,0) or (0,1)
    uniform float u_radius;
    in vec2 uv;
    out vec4 color;
    void main() {
        vec2 texel = 1.0 / vec2(textureSize(u_input, 0));
        vec2 lo = 0.5 * texel;
        vec2 hi = vec2(1.0) - 0.5 * texel;
        float sigma = max(u_radius * 0.5, 0.5);
        vec3 sum = vec3(0.0);
        float weights = 0.0;
        for (int i = -4; i <= 4; i++) {
            float x = float(i);
            float w = exp(-(x * x) / (2.0 * sigma * sigma));
            sum += w * texture(u_input, clamp(uv + u_direction * texel * x, lo, hi)).rgb;
            weights += w;
        }
        color = vec4(sum / weights, 1.0);
    }
    """

    /// Emissive composite, drawn at the output size: `(decode(input) + glow · intensity) · 2^exposure`, tone-mapped
    /// per channel (`u_tonemap` 0 none = clamp, 1 Reinhard, 2 Narkowicz ACES fit), encoded to sRGB; alpha from the
    /// input. The glow is the blurred target sampled bilinearly (the upsample).
    static let emissiveComposite = """
    precision highp float;
    uniform sampler2D u_input;
    uniform sampler2D u_glow;
    uniform float u_intensity;
    uniform float u_exposure;
    uniform float u_tonemap;
    in vec2 uv;
    out vec4 color;
    \(emissiveTransfer)
    void main() {
        vec4 b = texture(u_input, uv);
        vec3 c = max((em_decode(b.rgb) + texture(u_glow, uv).rgb * u_intensity) * exp2(u_exposure), vec3(0.0));
        vec3 t;
        if (u_tonemap < 0.5) {
            t = min(c, vec3(1.0));
        } else if (u_tonemap < 1.5) {
            t = c / (vec3(1.0) + c);
        } else {
            t = clamp((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0);
        }
        color = vec4(em_encode(t), b.a);
    }
    """
}
