// PreviewValues — feature 168 (A23-P03) T-A23-302 (FR-A23-301, FR-A23-302; clarification Q1; data-model.md
// "PreviewValues"). Resolves a pass's values for one frame: fixed floats as they are, Noise's time as the frame time
// times the Time node's rate (or the frame time when the input is empty), and the colours of a Gradient apart, so the
// presenter can hand floats and vec4 colours (alpha 1) to the operator programs.
// Choices recorded here: floats and colours are two separate maps (a colour is never a float); a colour is the small
// Equatable struct ``PassColour`` rather than a tuple so the maps compare in tests. Pure: the time is passed in.
import Foundation

/// A colour value of a pass: red, green and blue in 0…1 (alpha is 1).
public struct PassColour: Equatable, Sendable {
    /// The red component.
    public let r: Double
    /// The green component.
    public let g: Double
    /// The blue component.
    public let b: Double

    /// A colour of `r`, `g` and `b`.
    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// Resolves the uniform values of a ``Pass`` for one frame.
public enum PreviewValues {
    /// The float uniforms of `pass` at frame time `time` (seconds): a scalar as it is, ``PassValue/time(rate:)`` as
    /// `time × rate`, ``PassValue/frameTime`` as `time`; colours are left out.
    public static func floats(for pass: Pass, time: Double) -> [String: Double] {
        var floats: [String: Double] = [:]
        for (name, value) in pass.values {
            switch value {
            case .scalar(let number): floats[name] = number
            case .time(let rate): floats[name] = time * rate
            case .frameTime: floats[name] = time
            case .colour: continue
            }
        }
        return floats
    }

    /// The colour uniforms of `pass` (the same at every time).
    public static func colours(for pass: Pass) -> [String: PassColour] {
        var colours: [String: PassColour] = [:]
        for (name, value) in pass.values {
            if case .colour(let r, let g, let b) = value { colours[name] = PassColour(r: r, g: g, b: b) }
        }
        return colours
    }
}
