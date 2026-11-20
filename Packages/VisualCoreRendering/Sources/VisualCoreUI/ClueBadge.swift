// ClueBadge.swift — feature 210 (R02-F10) T-R02F10-008 (FR-R02F10-007, FR-R02F10-010, FR-R02F10-013; research R9,
// R12). The non-colour clue of a coded state drawn in SwiftUI: its shape, its fill pattern and a black or white
// outline, next to its written name.
//
// Drawing method: the badge samples the CPU reference `ClueReference` once per device pixel (cell −1…1, y up) into an
// RGBA bitmap — the state colour weighted by `ClueReference.coverage(shape:pattern:at:antialias:)`, with the outline
// band `ClueReference.outline(shape:at:width:antialias:)` composited over it — and a `Canvas` draws that bitmap. It is
// therefore the same drawing as `vc/clue.glsl`, pixel for pixel, with no second set of shape formulas. The antialias
// half width is one device pixel; the outline is `max(1.5 pt, side / 16)` wide.
//
// Outline colours: `PerceptualColor.outlineRings(for:on:)` (T-R02F10-017) — an inner ring contrasting the state colour
// and, where that ring is below 3:1 against the background, an outer ring contrasting the background — against the
// background the badge stands on, approximated by the
// colour scheme: black (0, 0, 0) in dark appearance, white (1, 1, 1) in light appearance. Both are the extremes of the
// system backgrounds, so the chosen outline keeps at least the computed contrast on the real background too.
import CoreGraphics
import SwiftUI
import VisualCoreParameters
import VisualCoreSimulation

/// The clue of a coded state — shape, pattern and a contrasting outline — followed by its name, which wraps instead
/// of being truncated. The size follows Dynamic Type (relative to `.body`); VoiceOver reads the name only.
public struct ClueBadge: View {
    /// The state drawn.
    let state: CodedState
    /// The side of the drawn clue in points, scaled with Dynamic Type.
    @ScaledMetric private var side: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    /// The smallest outline width in points.
    public static let minimumOutlineWidth: CGFloat = 1.5

    /// Draws `state`; `size` is the clue's side in points at the default text size.
    public init(state: CodedState, size: CGFloat = 28) {
        self.state = state
        _side = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    /// The outline width in points for a clue of side `side`: `max(1.5, side / 16)`.
    public static func outlineWidth(side: CGFloat) -> CGFloat {
        max(minimumOutlineWidth, side / 16)
    }

    /// The background the outline is chosen against: black in dark appearance, white in light appearance.
    public static func background(for scheme: ColorScheme) -> SIMD3<Double> {
        scheme == .dark ? SIMD3(0, 0, 0) : SIMD3(1, 1, 1)
    }

    /// The badge: the clue and the wrapping name.
    public var body: some View {
        let rings = PerceptualColor.outlineRings(for: state.color, on: Self.background(for: colorScheme))
        let image = Self.render(state: state, outline: rings.inner, outer: rings.outer, side: side, scale: displayScale)
        HStack(alignment: .center, spacing: 8) {
            Canvas { context, size in
                if let image {
                    context.draw(Image(decorative: image, scale: displayScale), in: CGRect(origin: .zero, size: size))
                }
            }
            .frame(width: side, height: side)
            Text(state.name)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spokenLabel(for: state))
    }

    /// What VoiceOver reads for `state`: its name, and nothing else (the shape and pattern are seen, not spoken).
    public static func spokenLabel(for state: CodedState) -> String { state.name }

    /// The clue as a premultiplied RGBA bitmap of `side × scale` pixels (see the file header); nil only when the
    /// bitmap context cannot be made.
    /// `outer`, when given, is a second ring of the same width just outside the outline (T-R02F10-017), so that the
    /// outermost ring reaches 3:1 against the background.
    static func render(state: CodedState, outline: SIMD3<Double>, outer: SIMD3<Double>? = nil, side: CGFloat,
                       scale: CGFloat) -> CGImage? {
        let n = max(1, Int((side * scale).rounded()))
        let cellPerPixel = 2.0 / Double(n)
        let width = Double(outlineWidth(side: side)) * 2.0 / Double(side)
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        for row in 0..<n {
            for column in 0..<n {
                let p = SIMD2((Double(column) + 0.5) * cellPerPixel - 1, 1 - (Double(row) + 0.5) * cellPerPixel)
                let fill = ClueReference.coverage(shape: state.shape, pattern: state.pattern, at: p,
                                                  antialias: cellPerPixel)
                let band = ClueReference.outline(shape: state.shape, at: p, width: width, antialias: cellPerPixel)
                // Outline over fill, premultiplied: c = o·band + f·fill·(1 − band), α = band + fill·(1 − band); the
                // outer ring, when present, lies under both: the band of width `width` centred at distance `width`.
                var color = outline * band + state.color * fill * (1 - band)
                var alpha = band + fill * (1 - band)
                if let outer {
                    let d = ClueReference.distance(shape: state.shape, at: p)
                    let ring = 1 - ClueReference.smoothstep(-cellPerPixel, cellPerPixel, abs(d - width) - width / 2)
                    color = color + outer * ring * (1 - alpha)
                    alpha = alpha + ring * (1 - alpha)
                }
                let i = (row * n + column) * 4
                bytes[i] = byte(color.x)
                bytes[i + 1] = byte(color.y)
                bytes[i + 2] = byte(color.z)
                bytes[i + 3] = byte(alpha)
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private static func byte(_ v: Double) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }
}

extension ColorVisionChoice {
    /// The colour-vision preset of this choice: nil for `.standard` (the experience keeps its own colours), else
    /// `ColorVisionPresets.warmCool`, `.redCyan` or `.lightness`.
    public var palette: Palette? {
        switch self {
        case .standard: return nil
        case .warmCool: return ColorVisionPresets.warmCool
        case .redCyan: return ColorVisionPresets.redCyan
        case .lightness: return ColorVisionPresets.lightness
        }
    }
}
