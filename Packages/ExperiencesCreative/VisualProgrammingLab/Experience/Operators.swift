// Operators — feature 168 (A23-P03) T-A23-303 (FR-A23-302, FR-A23-307; clarification Q4; contracts/preview.md
// "Operators"; contract gap G-OPERATORS). The fragment programs of the preview, one per `PassOperator`, as GLSL ES
// 3.00 text for VisualCore's `FieldPass` (which adds the full-screen vertex shader, `in vec2 v_uv` 0…1 from the
// bottom-left, and resolves `#include` against `ShaderBundle.visualCoreIncludes`):
//
//   noise     grey `0.5 + 0.5 × vc_fbm(v_uv × u_scale + u_time × u_speed, int(u_octaves), 2, 0.5)`;
//   gradient  `mix(u_start, u_end, clamp(dot(v_uv − 0.5, (cos a, sin a)) + 0.5, 0, 1))`, `a` = `u_angle` degrees;
//   mix       `mix(texture(u_a), texture(u_b), u_amount)`;
//   blur-h,   a normalised Gaussian of 2r + 1 taps along (`u_directionX`, `u_directionY`) in texels of `u_image`,
//   blur-v    r = `u_radius` rounded and capped at 16, σ = max(r / 2, 0.5), each tap's coordinate clamped to the
//             texel centres of the edge (edges clamped);
//   output    a copy of `u_image`.
//
// Choices recorded here: the blur's direction is two floats (`u_directionX`, `u_directionY`), as the compiler gives
// it (`directionX`, `directionY`), rather than a `vec2`; octaves arrive as a float and are rounded and clamped to 1…8
// in the shader. Every program writes `out vec4 color` with alpha 1. Text only: no GL call.
import VisualProgrammingLabCore

/// The fragment programs of the preview (see the file header).
enum Operators {
    /// The largest blur radius a program honours, texels (the parameter's range ends there too).
    static let maxRadius = 16

    /// The sampler names `operator` reads, in texture-unit order.
    static func inputs(of op: PassOperator) -> [String] {
        switch op {
        case .noise, .gradient: return []
        case .mix: return ["u_a", "u_b"]
        case .blurH, .blurV, .output: return ["u_image"]
        }
    }

    /// The program `operator` runs: Blur's two passes share one program (their text is the same, and VisualCore's
    /// program cache would hand both the same program), every other operator has its own.
    static func program(of op: PassOperator) -> String {
        switch op {
        case .blurH, .blurV: return "blur"
        default: return op.rawValue
        }
    }

    /// The diagnostic label of `operator`'s program, for example `vpl-preview-blur.frag`.
    static func label(of op: PassOperator) -> String {
        "vpl-preview-" + program(of: op) + ".frag"
    }

    /// The fragment text of `operator`.
    static func fragment(of op: PassOperator) -> String {
        switch op {
        case .noise: return noise
        case .gradient: return gradient
        case .mix: return mix
        case .blurH, .blurV: return blur
        case .output: return output
        }
    }

    /// Layered gradient noise as grey.
    static let noise = """
    precision highp float;
    #include "vc/noise.glsl"
    in vec2 v_uv;
    uniform float u_scale;
    uniform float u_octaves;
    uniform float u_speed;
    uniform float u_time;
    out vec4 color;

    void main() {
        int octaves = int(clamp(floor(u_octaves + 0.5), 1.0, 8.0));
        float n = vc_fbm(v_uv * u_scale + vec2(u_time * u_speed), octaves, 2.0, 0.5);
        float g = clamp(0.5 + 0.5 * n, 0.0, 1.0);
        color = vec4(g, g, g, 1.0);
    }
    """

    /// A linear ramp between two colours at an angle in degrees.
    static let gradient = """
    precision highp float;
    in vec2 v_uv;
    uniform float u_angle;
    uniform vec4 u_start;
    uniform vec4 u_end;
    out vec4 color;

    void main() {
        float a = radians(u_angle);
        float t = clamp(dot(v_uv - 0.5, vec2(cos(a), sin(a))) + 0.5, 0.0, 1.0);
        color = vec4(mix(u_start.rgb, u_end.rgb, t), 1.0);
    }
    """

    /// The blend of two pictures by an amount.
    static let mix = """
    precision highp float;
    in vec2 v_uv;
    uniform sampler2D u_a;
    uniform sampler2D u_b;
    uniform float u_amount;
    out vec4 color;

    void main() {
        vec3 a = texture(u_a, v_uv).rgb;
        vec3 b = texture(u_b, v_uv).rgb;
        color = vec4(mix(a, b, clamp(u_amount, 0.0, 1.0)), 1.0);
    }
    """

    /// One axis of a normalised Gaussian blur with clamped edges (both passes of Blur run it).
    static let blur = """
    precision highp float;
    in vec2 v_uv;
    uniform sampler2D u_image;
    uniform float u_radius;
    uniform float u_directionX;
    uniform float u_directionY;
    out vec4 color;

    void main() {
        vec2 size = vec2(textureSize(u_image, 0));
        vec2 texel = 1.0 / size;
        vec2 lo = 0.5 * texel;
        vec2 hi = vec2(1.0) - 0.5 * texel;
        int r = int(clamp(floor(u_radius + 0.5), 0.0, 16.0));
        float sigma = max(float(r) * 0.5, 0.5);
        vec2 stride = vec2(u_directionX, u_directionY) * texel;
        vec3 sum = vec3(0.0);
        float total = 0.0;
        for (int i = -16; i <= 16; i++) {
            if (i < -r || i > r) continue;
            float x = float(i);
            float w = exp(-(x * x) / (2.0 * sigma * sigma));
            vec2 uv = clamp(v_uv + stride * x, lo, hi);
            sum += w * texture(u_image, uv).rgb;
            total += w;
        }
        color = vec4(sum / total, 1.0);
    }
    """

    /// A copy of its input.
    static let output = """
    precision highp float;
    in vec2 v_uv;
    uniform sampler2D u_image;
    out vec4 color;

    void main() {
        color = vec4(texture(u_image, v_uv).rgb, 1.0);
    }
    """
}
