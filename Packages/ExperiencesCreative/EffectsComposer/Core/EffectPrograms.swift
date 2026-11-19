// EffectPrograms — feature 180 (A25-P01) T-A25-107 (FR-A25-104, FR-A25-107; SC-A25-104; clarification Q1; research
// R1, R2, R4; contracts/core.md). Each effect's fragment program as GLSL ES 3.00 text for VisualCore's `FieldPass`,
// which adds `#version 300 es` and the full-screen vertex shader (`in vec2 v_uv`, 0…1 from the bottom-left, at texel
// centres when the output has the input's size). The single sampler input is `u_source`; parameters are packed into
// the vec4 `u_params` and the texel size into the vec2 `u_texel`:
//
//   grade      u_params = (exposure, contrast, saturation, 0)
//   blur       u_params = (radius, 0, 0, 0), u_texel = (1/w, 1/h)
//   distort    u_params = (amplitude, frequency, 0, 0)
//   vignette   u_params = (amount, radius, softness, 0)
//   posterize  u_params = (levels, 0, 0, 0)
//
// The formulas are those of `EffectReference`. Choices recorded here: the programs sample at texel centres with
// `texture` (exact for an `.rgba8` source) except `distort`, which samples between them with the target's `LINEAR`
// filter; `blur` loops over the constant bound −8…8 and skips taps outside the radius, so GLSL ES compiles it, and
// clamps each tap to the edge texel centres; no effect needs `u_params2` in version 1 (research R4 keeps it for a
// later effect with more than four parameters). `uniforms(for:width:height:)` lists only the uniforms a program
// uses, because the GL compiler strips unused ones and `FieldPass` refuses an unknown uniform. The programs are
// strings; the core compiles nothing (FR-A25-107). Pure Swift; no UI, GPU or clock.

/// The fragment programs of the five effects and their uniform values.
public enum EffectPrograms {
    /// The name of the sampler input every program reads.
    public static let sourceInput = "u_source"

    /// The fragment program of `effect` (GLSL ES 3.00 without the `#version` line).
    public static func source(for effect: EffectID) -> String {
        switch effect {
        case .grade: grade
        case .blur: blur
        case .distort: distort
        case .vignette: vignette
        case .posterize: posterize
        }
    }

    /// The uniform values of `node`'s program for a `width × height` output: `u_params` (4 floats) and, for `blur`,
    /// `u_texel` (2 floats).
    public static func uniforms(for node: EffectNode, width: Int, height: Int) -> [String: [Float]] {
        func v(_ name: String) -> Float { NodeValues.value(node, name) }
        switch node.effect {
        case .grade:
            return ["u_params": [v("exposure"), v("contrast"), v("saturation"), 0]]
        case .blur:
            return ["u_params": [v("radius"), 0, 0, 0], "u_texel": [1 / Float(width), 1 / Float(height)]]
        case .distort:
            return ["u_params": [v("amplitude"), v("frequency"), 0, 0]]
        case .vignette:
            return ["u_params": [v("amount"), v("radius"), v("softness"), 0]]
        case .posterize:
            return ["u_params": [v("levels"), 0, 0, 0]]
        }
    }

    /// The declarations every program starts with.
    static let header = """
    precision highp float;
    in vec2 v_uv;
    uniform highp sampler2D u_source;
    uniform vec4 u_params;
    out vec4 color;

    """

    /// `grade`: exposure, contrast and saturation (Rec. 709 luma).
    static let grade = header + """
    void main() {
        vec4 x = texture(u_source, v_uv);
        vec3 y = x.rgb * exp2(u_params.x);
        y = (y - 0.5) * u_params.y + 0.5;
        float l = 0.2126 * y.r + 0.7152 * y.g + 0.0722 * y.b;
        y = l + (y - l) * u_params.z;
        color = vec4(clamp(y, 0.0, 1.0), x.a);
    }
    """

    /// `blur`: the mean of the (2r + 1)² texel centres around the pixel, clamped to the edge.
    static let blur = header + """
    uniform vec2 u_texel;
    void main() {
        int r = int(floor(u_params.x + 0.5));
        vec2 lo = 0.5 * u_texel;
        vec2 hi = 1.0 - 0.5 * u_texel;
        vec3 sum = vec3(0.0);
        for (int j = -8; j <= 8; j++) {
            if (abs(j) > r) continue;
            for (int i = -8; i <= 8; i++) {
                if (abs(i) > r) continue;
                vec2 at = clamp(v_uv + vec2(float(i), float(j)) * u_texel, lo, hi);
                sum += texture(u_source, at).rgb;
            }
        }
        float n = float((2 * r + 1) * (2 * r + 1));
        color = vec4(clamp(sum / n, 0.0, 1.0), texture(u_source, v_uv).a);
    }
    """

    /// `distort`: a sine displacement of the sampling coordinate.
    static let distort = header + """
    void main() {
        float k = 6.2831853 * u_params.y;
        vec2 at = v_uv + u_params.x * vec2(sin(k * v_uv.y), sin(k * v_uv.x));
        color = vec4(clamp(texture(u_source, at).rgb, 0.0, 1.0), texture(u_source, v_uv).a);
    }
    """

    /// `vignette`: darkening towards the corners.
    static let vignette = header + """
    void main() {
        vec4 x = texture(u_source, v_uv);
        float d = 2.0 * length(v_uv - 0.5) / sqrt(2.0);
        float e0 = u_params.y - u_params.z;
        float t = clamp((d - e0) / (u_params.y - e0), 0.0, 1.0);
        float s = t * t * (3.0 - 2.0 * t);
        color = vec4(clamp(x.rgb * (1.0 - u_params.x * s), 0.0, 1.0), x.a);
    }
    """

    /// `posterize`: each channel quantised to `levels` values.
    static let posterize = header + """
    void main() {
        vec4 x = texture(u_source, v_uv);
        float steps = floor(u_params.x + 0.5) - 1.0;
        vec3 y = floor(x.rgb * steps + 0.5) / steps;
        color = vec4(clamp(y, 0.0, 1.0), x.a);
    }
    """
}
