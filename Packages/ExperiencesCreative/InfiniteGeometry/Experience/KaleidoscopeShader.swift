// KaleidoscopeShader — feature 041 (A05-P02) T-A05-204 (FR-A05-201, FR-A05-202; research D3; spec Clarifications).
// The kaleidoscope preset drawn by one full-screen fragment shader on VisualCore's `FullScreenShaderScene`, with the
// same geometry as the CPU composition (`Composition.build`, kaleidoscope rule):
//
//   - World point: the square −1…1 fills the view's shorter side (the presenter's fit), seen through the 2D camera
//     (`u_centerX`, `u_centerY`, `u_zoom`): world = (pixel − resolution / 2) / (fit · zoom) + centre, y up.
//   - Ring k (0-based, k < `u_repeats`) is the motif's dihedral images scaled about the origin by (k + 1) / repeats;
//     the pixel is folded into the fundamental wedge with `vc_foldDihedral` (VisualCore's GLSL twin of
//     `PointGroup.fold`) after dividing by that scale, so every image is exact by construction.
//   - The motif is a convex counter-clockwise polygon of 3–7 points (`u_count`, `u_p0x`…`u_p6y`); its signed distance
//     is the minimum of `vc_sdSegment` over the edges, negative when every edge's cross product is non-negative.
//   - As on the CPU, an image is kept only while its centroid (`u_cx`, `u_cy` folded back by the same operation) lies
//     in the view square ±1/scale (`u_scale`); at scale ≤ 1 every image is kept.
//   - Coverage is a smoothstep over one pixel; later rings paint over earlier ones (the CPU's drawing order). The
//     colour of ring k is palette slot k mod 6 (`u_palette`, linear light, encoded to sRGB), the same in every image,
//     so the picture has the full dihedral symmetry (FR-A05-202). The background is black (the probe's `dark`).
import Foundation
import InfiniteGeometryCore
import VisualCoreMath
import VisualCoreParameters
import VisualCoreRendering

/// The fragment shader of the kaleidoscope and the uniform values it reads from the core.
enum KaleidoscopeShader {
    /// The name of the fragment in diagnostics.
    static let fragmentName = "kaleidoscope.frag"
    /// The most motif points the shader reads (the motif has 3–7).
    static let maxPoints = 7
    /// The colour slots of the rings (as the CPU colour slots, 0…5).
    static let ringSlots = 6

    /// GLSL ES 3.00 (the program adds the version line), with the VisualCore includes `vc/sdf.glsl` and `vc/color.glsl`.
    static let fragment = """
    precision highp float;
    #include "vc/sdf.glsl"
    #include "vc/color.glsl"
    uniform vec2 u_resolution;
    uniform vec3 u_palette[8];
    uniform int u_paletteCount;
    uniform float u_order;
    uniform float u_repeats;
    uniform float u_scale;
    uniform float u_count;
    uniform float u_p0x; uniform float u_p0y;
    uniform float u_p1x; uniform float u_p1y;
    uniform float u_p2x; uniform float u_p2y;
    uniform float u_p3x; uniform float u_p3y;
    uniform float u_p4x; uniform float u_p4y;
    uniform float u_p5x; uniform float u_p5y;
    uniform float u_p6x; uniform float u_p6y;
    uniform float u_cx;
    uniform float u_cy;
    uniform float u_centerX;
    uniform float u_centerY;
    uniform float u_zoom;
    out vec4 color;

    const float TAU = 6.283185307179586;

    // Signed distance to the convex counter-clockwise motif polygon: negative inside.
    float motifDistance(vec2 p, vec2 pts[7], int count) {
        float d = 1e9;
        bool inside = true;
        for (int i = 0; i < 7; i++) {
            if (i >= count) break;
            vec2 a = pts[i];
            vec2 b = pts[i + 1 < count ? i + 1 : 0];
            d = min(d, vc_sdSegment(p, a, b));
            vec2 e = b - a, w = p - a;
            if (e.x * w.y - e.y * w.x < 0.0) inside = false;
        }
        return inside ? -d : d;
    }

    // The colour stop of ring slot `slot` (a loop instead of a dynamic uniform index).
    vec3 ringColor(int slot) {
        int n = clamp(u_paletteCount, 1, 8);
        int s = slot - (slot / n) * n;
        vec3 c = u_palette[0];
        for (int k = 0; k < 8; k++) {
            if (k == s) c = u_palette[k];
        }
        return c;
    }

    // The centroid of the image of the motif that contains the folded point of `q`: the fold's operation undone on
    // the motif's centroid (same wedge reduction as vc_foldDihedral).
    vec2 imageCentroid(vec2 q, float n) {
        float wedge = TAU / n;
        float theta = atan(q.y, q.x);
        float w = floor(theta / wedge);
        float t = theta - w * wedge;
        if (t < 0.0) { t = 0.0; }
        if (t >= wedge) { t = 0.0; w += 1.0; }
        float base = atan(u_cy, u_cx);
        float phi = w * wedge + (t > wedge * 0.5 ? wedge - base : base);
        return length(vec2(u_cx, u_cy)) * vec2(cos(phi), sin(phi));
    }

    void main() {
        float fit = 0.5 * min(u_resolution.x, u_resolution.y);
        float zoom = max(u_zoom, 1e-3);
        float pixel = 1.0 / (fit * zoom);
        vec2 p = (gl_FragCoord.xy - 0.5 * u_resolution) * pixel + vec2(u_centerX, u_centerY);
        vec2 pts[7];
        pts[0] = vec2(u_p0x, u_p0y); pts[1] = vec2(u_p1x, u_p1y); pts[2] = vec2(u_p2x, u_p2y);
        pts[3] = vec2(u_p3x, u_p3y); pts[4] = vec2(u_p4x, u_p4y); pts[5] = vec2(u_p5x, u_p5y);
        pts[6] = vec2(u_p6x, u_p6y);
        int count = clamp(int(u_count + 0.5), 3, 7);
        int repeats = clamp(int(u_repeats + 0.5), 1, 12);
        float n = max(floor(u_order + 0.5), 1.0);
        float extent = 1.0 / max(u_scale, 1e-3);
        vec3 rgb = vec3(0.0);
        for (int k = 0; k < 12; k++) {
            if (k >= repeats) break;
            float s = float(k + 1) / float(repeats);
            vec2 q = p / s;
            float d = motifDistance(vc_foldDihedral(q, n), pts, count) * s;
            float coverage = 1.0 - smoothstep(-0.5 * pixel, 0.5 * pixel, d);
            if (coverage <= 0.0) continue;
            vec2 c = imageCentroid(q, n) * s;
            if (abs(c.x) > extent || abs(c.y) > extent) continue;
            rgb = mix(rgb, ringColor(k - (k / 6) * 6), coverage);
        }
        color = vec4(vc_srgbEncode(rgb), 1.0);
    }
    """

    /// The `u_<name>` values of `core`: the order, repetitions, scale, motif points (unused slots 0) and centroid of
    /// its preset's kaleidoscope motif, and its 2D camera.
    static func parameters(for core: GeometryCore) -> [String: Double] {
        let preset = core.preset
        let points = motifPoints(preset)
        var values: [String: Double] = [
            "order": Double(preset.order), "repeats": Double(preset.repeats), "scale": preset.scale,
            "count": Double(points.count),
            "centerX": core.view2D.centerX, "centerY": core.view2D.centerY, "zoom": core.view2D.zoom,
        ]
        let centroid = points.isEmpty ? Vec2.zero : points.reduce(Vec2.zero, +) / Double(points.count)
        values["cx"] = centroid.x
        values["cy"] = centroid.y
        for k in 0..<maxPoints {
            let p = k < points.count ? points[k] : .zero
            values["p\(k)x"] = p.x
            values["p\(k)y"] = p.y
        }
        return values
    }

    /// The kaleidoscope motif of `preset` (the composition's own motif), at most `maxPoints` points.
    static func motifPoints(_ preset: GeometryPreset) -> [Vec2] {
        Array(Motif.make(seed: preset.seed, kind: .kaleidoscope, order: preset.order).points.prefix(maxPoints))
    }

    /// The ring colours in linear light: palette `palette` sampled at (slot + 1) / 6 for slots 0…5, the samples the
    /// CPU renderer uses for its colour slots.
    static func palette(_ palette: Int) -> [SIMD3<Float>] {
        let palettes = Palette.builtIns
        let p = palettes[min(max(palette, 0), palettes.count - 1)]
        return (0..<ringSlots).map { slot in
            let c = p.sample(Double(slot + 1) / Double(ringSlots))
            return SIMD3(Float(c.x), Float(c.y), Float(c.z))
        }
    }

    /// A scene running the fragment with the VisualCore includes.
    @MainActor
    static func makeScene() -> FullScreenShaderScene {
        FullScreenShaderScene(fragment: fragment, fragmentName: fragmentName, bundle: ShaderBundle(files: [:]))
    }
}

/// The kaleidoscope shader did not compile or link on this device: the session's setup fails with this message.
struct KaleidoscopeShaderError: Error, CustomStringConvertible {
    /// The first diagnostic, `file:line: message`.
    let message: String
    var description: String { "The kaleidoscope shader failed: \(message)" }
}
