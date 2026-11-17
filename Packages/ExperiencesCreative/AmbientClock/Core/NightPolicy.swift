// NightPolicy — feature 134 T-A18-403 (FR-A18-401, FR-A18-405; SC-A18-401; clarification Q2). Night mode: off, on or
// scheduled over a window of minutes of the local day; the dim and warm tint the shader applies at night; the amber
// time-text colour and the contrast rule it must meet against every dimmed and tinted palette colour. Pure Foundation;
// nothing here reads a clock.
import Foundation

/// When night mode applies and how strongly it dims.
///
/// Colour space: ``nightColor(_:dim:)`` multiplies the **sRGB-encoded** components directly (no linearisation), exactly
/// as the theme shaders do with `gl_FragColor.rgb *= u_night.x * u_night.yzw` on the encoded values they write. The
/// contrast rule is therefore checked against the colours the screen really shows.
public struct NightPolicy: Equatable, Sendable {
    /// Whether night mode is off, always on, or follows the scheduled window.
    public enum Mode: Int, Equatable, Sendable, CaseIterable {
        /// Never night.
        case off = 0
        /// Always night.
        case on = 1
        /// Night inside the window [``NightPolicy/start``, ``NightPolicy/end``) of the local day.
        case scheduled = 2
    }

    /// The minutes of a day: 0…1439.
    public static let minuteRange = 0...1439
    /// The allowed dim factors: 0.3…1.
    public static let dimRange = 0.3...1.0
    /// The default window start, 22:00.
    public static let defaultStart = 1320
    /// The default window end, 07:00.
    public static let defaultEnd = 420
    /// The default dim factor.
    public static let defaultDim = 0.5

    /// The warm tint the scene colour is multiplied by at night (red, green, blue).
    public static let tint = SIMD3<Double>(1, 0.75, 0.55)
    /// The night time-text colour, warm amber #FFB27A, sRGB-encoded.
    public static let textColor = SIMD3<Double>(1.0, 0xB2 / 255.0, 0x7A / 255.0)

    /// The mode.
    public let mode: Mode
    /// The window start in minutes of the local day (0…1439).
    public let start: Int
    /// The window end in minutes of the local day (0…1439), exclusive.
    public let end: Int
    /// The dim factor (0.3…1) the scene colour is multiplied by at night.
    public let dim: Double

    /// Creates a policy; `start` and `end` are clamped to 0…1439 and `dim` to 0.3…1 (a non-finite dim becomes the
    /// default 0.5).
    public init(mode: Mode = .off, start: Int = NightPolicy.defaultStart, end: Int = NightPolicy.defaultEnd,
                dim: Double = NightPolicy.defaultDim) {
        self.mode = mode
        self.start = min(max(start, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        self.end = min(max(end, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        let finiteDim = dim.isFinite ? dim : Self.defaultDim
        self.dim = min(max(finiteDim, Self.dimRange.lowerBound), Self.dimRange.upperBound)
    }

    /// Creates a policy only when every value is in range (`mode` 0…2, minutes 0…1439, dim 0.3…1); otherwise nil.
    public init?(validatingMode mode: Int, start: Int, end: Int, dim: Double) {
        guard let parsed = Mode(rawValue: mode), Self.minuteRange.contains(start), Self.minuteRange.contains(end),
              dim.isFinite, Self.dimRange.contains(dim) else { return nil }
        self.init(mode: parsed, start: start, end: end, dim: dim)
    }

    /// Whether it is night at `localMinute` (minutes since local midnight). Off is never night and on always is.
    /// Scheduled: start < end means [start, end); start > end wraps midnight (m ≥ start or m < end); start = end is
    /// never night.
    public func isNight(localMinute: Int) -> Bool {
        switch mode {
        case .off: return false
        case .on: return true
        case .scheduled:
            let m = ((localMinute % 1440) + 1440) % 1440
            if start < end { return start <= m && m < end }
            if start > end { return m >= start || m < end }
            return false
        }
    }

    /// The minutes since local midnight of `date` in `calendar` (its time zone decides the local day): 0…1439.
    public static func localMinute(of date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// The night colour of an sRGB-encoded colour: `color × dim × tint`, component-wise in the encoded space (see the
    /// type's colour-space note); `dim` is clamped to 0.3…1.
    public static func nightColor(_ color: SIMD3<Double>, dim: Double) -> SIMD3<Double> {
        let d = min(max(dim.isFinite ? dim : defaultDim, dimRange.lowerBound), dimRange.upperBound)
        return color * d * tint
    }

    /// One sentence per palette colour and dim (the darkest allowed, 0.3, and 1) at which ``textColor`` falls below
    /// ``ThemeCatalog/requiredContrast`` against the night colour; empty when every combination passes. The default
    /// checks all 48 colours of ``ThemeCatalog/themes``.
    public static func contrastProblems(
        palettes: [ThemePalette] = ThemeCatalog.themes.flatMap(\.palettes)
    ) -> [String] {
        var problems: [String] = []
        for palette in palettes {
            for (index, color) in palette.colors.enumerated() {
                for d in [dimRange.lowerBound, dimRange.upperBound] {
                    let ratio = ThemeCatalog.contrastRatio(textColor, nightColor(color, dim: d))
                    if ratio < ThemeCatalog.requiredContrast {
                        problems.append("Palette \(palette.name) colour \(index) at dim \(d) gives night text "
                            + "\(String(format: "%.2f", ratio)) : 1, below \(ThemeCatalog.requiredContrast) : 1.")
                    }
                }
            }
        }
        return problems
    }
}
