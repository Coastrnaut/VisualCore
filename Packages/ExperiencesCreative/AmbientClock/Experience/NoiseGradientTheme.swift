// NoiseGradientTheme — feature 132 T-A18-203 (FR-A18-202, FR-A18-204, FR-A18-207, FR-A18-208; G-OVERLAY/G-BUDGETS;
// clarification Q3; research D3, D4). The first theme of Ambient Clock, "Noise gradient": one full-screen fragment
// shader on VisualCore's `FullScreenShaderScene` over the GLSL library (`vc/noise.glsl`, `vc/color.glsl`). No text
// is drawn by the shader; the time and date are the native overlay's (`ClockOverlay`).
//
//   - Coordinate: uv = (pixel / resolution.y) × 1.5 + time × 0.02 × (cos a, sin a) with the slowly turning angle
//     a = time × 0.01, so the gradient drifts calmly.
//   - Noise: n = vc_fbm(uv, octaves, 2, 0.5) (about −1…1), mapped to 0…1 as clamp(0.5 + 1.5 n, 0, 1) and blended
//     through the four palette colours in order (midnight blue, dusk violet, deep teal, slate), linear light, then
//     encoded to sRGB with `vc_srgbEncode` (as Infinite Geometry's kaleidoscope).
//   - Quality (G-BUDGETS): `u_octaves` is 5 at level-0 and 3 at level-1 (`AmbientCore.octaves(forTier:)`);
//     `u_block` is the pixel block edge (1 at level-0; 2 at level-1, `AmbientCore.pixelBlock(forTier:)`): one noise
//     sample per block, so the level-1 picture is the half-resolution picture. The scene still shades every
//     fragment of the drawable (VisualCore's full-screen scene has no reduced-size target), so the work saved at
//     level-1 is the two octaves; each level is exactly one full-screen draw.
//   - Time: `effectiveTime(frameTime:speed:motion:reduceMotion:)` is the uniform time: 0 when motion is off or Reduce
//     Motion is on (every frame identical), else the frame time × the speed. It is bound through the scene's
//     `fixedTime`, so the scene's own time scale is never used.
//   - Contrast (FR-A18-204): every palette colour is dark enough that the white text (`textColor`) reaches at least
//     4.5 : 1 (`minimumContrast()`, with `AccessibleColors.contrastRatio` on the sRGB-encoded colours: about 16.4 : 1);
//     every channel of every colour stays at most 0.18 encoded, so any blend has a Rec. 709 luma below 40 (the probe's
//     `dark`).
import Foundation
import UIKit
import VisualCoreRendering
import VisualCoreUI

/// The "Noise gradient" theme: its fragment shader, palette, uniforms and contrast rule (see the file header).
enum NoiseGradientTheme {
    /// The theme's id.
    static let id = "noise-gradient"
    /// The theme's name as shown and spoken.
    static let name = "Noise gradient"
    /// The name of the fragment in diagnostics.
    static let fragmentName = "ambient-noise-gradient.frag"
    /// The contrast the text must reach against every palette colour (WCAG AA for normal text).
    static let requiredContrast = 4.5
    /// The coordinate scale: noise cells per canvas height.
    static let coordinateScale = 1.5
    /// The drift speed of the coordinate, noise cells per second of uniform time.
    static let driftSpeed = 0.02
    /// The turning speed of the drift direction, radians per second of uniform time.
    static let turnSpeed = 0.01

    /// The four palette colours, sRGB-encoded (0…1): midnight blue, dusk violet, deep teal, slate (blend order).
    static let encodedPalette: [SIMD3<Double>] = [
        SIMD3(0.04, 0.06, 0.18),   // midnight blue
        SIMD3(0.14, 0.06, 0.18),   // dusk violet
        SIMD3(0.02, 0.14, 0.15),   // deep teal
        SIMD3(0.10, 0.12, 0.15),   // slate
    ]

    /// The names of the palette colours, in `encodedPalette` order.
    static let paletteNames = ["midnight blue", "dusk violet", "deep teal", "slate"]

    /// The palette in linear light, as the shader receives it (`u_palette`): `encodedPalette` decoded with the sRGB
    /// transfer function.
    static var palette: [SIMD3<Float>] {
        encodedPalette.map { SIMD3(Float(srgbDecode($0.x)), Float(srgbDecode($0.y)), Float(srgbDecode($0.z))) }
    }

    /// The text colour of the overlay: opaque white.
    static let textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)

    /// The palette colours as opaque sRGB `UIColor`s (for the contrast rule).
    static var paletteColors: [UIColor] {
        encodedPalette.map { UIColor(red: CGFloat($0.x), green: CGFloat($0.y), blue: CGFloat($0.z), alpha: 1) }
    }

    /// The smallest contrast of `textColor` against any palette colour (`AccessibleColors.contrastRatio`); at least
    /// `requiredContrast` (FR-A18-204).
    static func minimumContrast() -> Double {
        paletteColors.map { AccessibleColors.contrastRatio(textColor, $0) }.min() ?? 1
    }

    /// The uniform time: 0 when `motion` is off or `reduceMotion` is on, else `frameTime × speed` (0 for a non-finite
    /// product).
    static func effectiveTime(frameTime: Double, speed: Double, motion: Bool, reduceMotion: Bool) -> Double {
        guard motion, !reduceMotion else { return 0 }
        let time = frameTime * speed
        return time.isFinite ? time : 0
    }

    /// The `u_<name>` float uniforms at quality tier `tier`: `octaves` and `block`.
    static func parameters(tier: Int) -> [String: Double] {
        ["octaves": Double(AmbientCore.octaves(forTier: tier)), "block": Double(AmbientCore.pixelBlock(forTier: tier))]
    }

    /// The sRGB transfer function's decode of one encoded channel (0…1), as `vc_srgbDecode`.
    static func srgbDecode(_ encoded: Double) -> Double {
        let c = min(max(encoded, 0), 1)
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// GLSL ES 3.00 (the program adds the version line), with the VisualCore includes `vc/noise.glsl` and
    /// `vc/color.glsl`.
    static let fragment = """
    precision highp float;
    #include "vc/noise.glsl"
    #include "vc/color.glsl"
    uniform vec2 u_resolution;
    uniform float u_time;
    uniform float u_octaves;
    uniform float u_block;
    uniform vec3 u_palette[4];
    out vec4 color;

    void main() {
        float block = max(floor(u_block + 0.5), 1.0);
        vec2 pixel = (floor(gl_FragCoord.xy / block) + 0.5) * block;
        float a = u_time * 0.01;
        vec2 uv = (pixel / max(u_resolution.y, 1.0)) * 1.5 + u_time * 0.02 * vec2(cos(a), sin(a));
        int octaves = clamp(int(u_octaves + 0.5), 1, 8);
        float n = vc_fbm(uv, octaves, 2.0, 0.5);
        float x = clamp(0.5 + 1.5 * n, 0.0, 1.0) * 3.0;
        vec3 rgb = mix(u_palette[0], u_palette[1], clamp(x, 0.0, 1.0));
        rgb = mix(rgb, u_palette[2], clamp(x - 1.0, 0.0, 1.0));
        rgb = mix(rgb, u_palette[3], clamp(x - 2.0, 0.0, 1.0));
        color = vec4(vc_srgbEncode(rgb), 1.0);
    }
    """

    /// A scene running the fragment with the VisualCore includes and the theme's palette.
    @MainActor
    static func makeScene() -> FullScreenShaderScene {
        let scene = FullScreenShaderScene(fragment: fragment, fragmentName: fragmentName,
                                          bundle: ShaderBundle(files: [:]))
        scene.palette = palette
        scene.fixedTime = 0
        return scene
    }
}

/// The theme's shader did not compile or link on this device: the session's setup fails with this message.
struct NoiseGradientShaderError: Error, CustomStringConvertible {
    /// The first diagnostic, `file:line: message`.
    let message: String
    /// "The noise gradient shader failed: <message>".
    var description: String { "The noise gradient shader failed: \(message)" }
}
