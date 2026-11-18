// ShaderTemplates — feature 159 (A22-P01) T-A22-110 (FR-A22-106; clarification Q5); feature 161 (A22-P03)
// T-A22-302 (FR-A22-304; clarification Q4) added `texture-mix`. The four starter templates, written in code, each a ``ShaderProject`` whose source runs inside ``ShaderAssembly``'s prelude (so it uses `v_uv`,
// `u_time`, `u_resolution`, `fragColor` and the `vc/` functions without declaring them), declares each of its uniforms
// as `uniform float u_x;` and each texture input as `uniform sampler2D u_x;`, uses every one in the colour it writes
// (so none is optimized away), and has no `#version` line:
//
//   gradient    a colour sweep over `v_uv` moved by `u_time`; uniform `u_speed`;
//   noise-flow  domain-warped `vc_fbm(p, octaves, lacunarity, gain)` from `vc/noise.glsl`; uniforms `u_scale`, `u_speed`;
//   rings       concentric rings around the centre, aspect-corrected with `u_resolution`; uniforms `u_count`, `u_width`;
//   texture-mix two texture inputs `u_texture0`, `u_texture1` mixed at `v_uv` by uniform `u_blend` (alpha 1).
//
// Each carries a licence record: original work written for VisualCore, no third-party source. The list is built
// without a crash path: a template whose project could not be built is left out, and the tests require all four.
import Foundation
import VisualCoreParameters

/// One starter template: an identifier, a title, the project it opens as, and its licence record.
public struct ShaderTemplate: Sendable, Equatable {
    /// Stable identifier (`gradient`, `noise-flow`, `rings`, `texture-mix`).
    public let id: String
    /// Short user-facing title.
    public let title: String
    /// The project the template opens as (source, uniforms, standard limits, texture inputs: none, or two for
    /// `texture-mix`).
    public let project: ShaderProject
    /// The licence record of the source.
    public let licence: String

    /// A template with the values as given.
    public init(id: String, title: String, project: ShaderProject, licence: String) {
        self.id = id
        self.title = title
        self.project = project
        self.licence = licence
    }

    /// The template's fragment source.
    public var source: String { project.source }

    /// The template's declared uniforms, in order.
    public var uniforms: [ParameterDefinition] { project.uniforms }

    /// The template's texture inputs, in order (sampled on units 0, 1, …).
    public var textureInputs: [String] { project.textureInputs }
}

/// The starter templates (feature 159, clarification Q5; `texture-mix` from feature 161, clarification Q4).
public enum ShaderTemplates {
    /// The licence record every template carries.
    public static let licence = "Original work written in code for VisualCore Shader Studio; no third-party source. "
        + "Free to copy, change and share inside Shader Studio projects."

    /// The identifiers, in order.
    public static let ids = ["gradient", "noise-flow", "rings", "texture-mix"]

    /// The source of `gradient`.
    public static let gradientSource = """
    // Gradient: a slow colour sweep across the screen.
    uniform float u_speed;

    void main() {
        float t = u_time * u_speed;
        vec3 deep = vec3(0.05, 0.10, 0.30);
        vec3 warm = vec3(0.90, 0.45, 0.20);
        float sweep = 0.5 + 0.5 * sin(t + v_uv.x * 3.14159);
        vec3 rgb = mix(deep, warm, mix(v_uv.y, sweep, 0.5));
        fragColor = vec4(vc_srgbEncode(rgb), 1.0);
    }

    """

    /// The source of `noise-flow`.
    public static let noiseFlowSource = """
    // Noise flow: fractal noise warped by itself, drifting over time.
    uniform float u_scale;
    uniform float u_speed;

    void main() {
        vec2 p = v_uv * u_scale;
        float t = u_time * u_speed;
        vec2 warp = vec2(vc_fbm(p + vec2(t, 0.0), 4, 2.0, 0.5),
                         vc_fbm(p + vec2(5.2, 1.3 - t), 4, 2.0, 0.5));
        float n = vc_fbm(p + 1.5 * warp, 5, 2.0, 0.5);
        vec3 rgb = mix(vec3(0.02, 0.06, 0.18), vec3(0.20, 0.70, 0.80), 0.5 + 0.5 * n);
        fragColor = vec4(vc_srgbEncode(rgb), 1.0);
    }

    """

    /// The source of `rings`.
    public static let ringsSource = """
    // Rings: concentric rings moving outwards from the centre.
    uniform float u_count;
    uniform float u_width;

    void main() {
        vec2 aspect = vec2(u_resolution.x / max(u_resolution.y, 1.0), 1.0);
        float r = length((v_uv - 0.5) * aspect) * 2.0;
        float f = fract(r * u_count - u_time * 0.25);
        float d = abs(f - 0.5);
        float ring = 1.0 - smoothstep(0.5 * u_width, 0.5 * u_width + 0.04, d);
        vec3 rgb = mix(vec3(0.03, 0.03, 0.08), vec3(0.85, 0.80, 0.55), ring);
        fragColor = vec4(vc_srgbEncode(rgb), 1.0);
    }

    """

    /// The source of `texture-mix`.
    public static let textureMixSource = """
    // Texture mix: two textures blended together.
    uniform sampler2D u_texture0;
    uniform sampler2D u_texture1;
    uniform float u_blend;

    void main() {
        vec4 mixed = mix(texture(u_texture0, v_uv), texture(u_texture1, v_uv), u_blend);
        fragColor = vec4(mixed.rgb, 1.0);
    }

    """

    /// The four templates in the order of ``ids``.
    public static let all: [ShaderTemplate] = [gradient(), noiseFlow(), rings(), textureMix()].compactMap { $0 }

    /// The template with `id`, if any.
    public static func template(id: String) -> ShaderTemplate? { all.first { $0.id == id } }

    /// `gradient`: uniform `u_speed` (0…4, default 1).
    static func gradient() -> ShaderTemplate? {
        make(id: "gradient", title: "Gradient", source: gradientSource,
             uniforms: [("u_speed", "Speed", 0...4, 1)])
    }

    /// `noise-flow`: uniforms `u_scale` (0.5…12, default 3) and `u_speed` (0…2, default 0.3).
    static func noiseFlow() -> ShaderTemplate? {
        make(id: "noise-flow", title: "Noise flow", source: noiseFlowSource,
             uniforms: [("u_scale", "Scale", 0.5...12, 3), ("u_speed", "Speed", 0...2, 0.3)])
    }

    /// `rings`: uniforms `u_count` (1…24, default 6) and `u_width` (0.02…0.9, default 0.3).
    static func rings() -> ShaderTemplate? {
        make(id: "rings", title: "Rings", source: ringsSource,
             uniforms: [("u_count", "Rings", 1...24, 6), ("u_width", "Width", 0.02...0.9, 0.3)])
    }

    /// `texture-mix`: texture inputs `u_texture0`, `u_texture1`; uniform `u_blend` (0…1, default 0.5).
    static func textureMix() -> ShaderTemplate? {
        make(id: "texture-mix", title: "Texture mix", source: textureMixSource,
             uniforms: [("u_blend", "Blend", 0...1, 0.5)], textureInputs: ["u_texture0", "u_texture1"])
    }

    /// A template, or nil when a uniform or the project is refused (the tests prove none is).
    private static func make(id: String, title: String, source: String,
                             uniforms: [(String, String, ClosedRange<Double>, Double)],
                             textureInputs: [String] = []) -> ShaderTemplate? {
        var definitions: [ParameterDefinition] = []
        for (name, uniformTitle, range, defaultValue) in uniforms {
            guard let definition = try? ParameterDefinition(name: name, title: uniformTitle, range: range,
                                                            defaultValue: defaultValue) else { return nil }
            definitions.append(definition)
        }
        guard let project = try? ShaderProject(name: title, source: source, uniforms: definitions,
                                               limits: .standard, textureInputs: textureInputs) else { return nil }
        return ShaderTemplate(id: id, title: title, project: project, licence: licence)
    }
}
