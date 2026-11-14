// MusicLabScene — feature 049 (A06-P03) T-A06-304 (FR-A06-310, FR-A06-311; data-model "MusicLabScene"; research D4).
// The three scenes of VisualCore Music Lab (bars 0, rings 1, geometry 2), their drivable parameters with ranges and
// smoothing, and the default feature choice for every parameter. GPU-free and audio-free.
import Foundation

/// A scene of Music Lab. The raw value is the persisted scene index 0…2.
public enum MusicLabScene: Int, Sendable, Codable, CaseIterable {
    /// Sixteen bars across the full width.
    case bars = 0
    /// Five concentric rings of the waveform.
    case rings = 1
    /// A sphere and sixteen cubes on a ring.
    case geometry = 2

    /// The name shown in the scene picker and spoken by the canvas description.
    public var displayName: String {
        switch self {
        case .bars: "Bars"
        case .rings: "Rings"
        case .geometry: "Geometry"
        }
    }

    /// The drivable parameters of the scene, in slot order (2, 2 and 3 parameters).
    public var parameters: [SceneParameter] {
        switch self {
        case .bars:
            [
                Self.parameter("height", "Bar height", 0.3...1.0),
                Self.beatParameter("glow", "Glow", 0.4...1.0),
            ]
        case .rings:
            [
                Self.parameter("radius", "Ring size", 0.2...0.45),
                Self.parameter("wobble", "Wobble", 0.02...0.15),
            ]
        case .geometry:
            [
                Self.beatParameter("pulse", "Pulse", 0.6...1.2),
                Self.parameter("spin", "Spin", 0.1...2.0),
                Self.parameter("lift", "Lift", 0.2...1.5),
            ]
        }
    }

    /// The default feature choice for every parameter, in slot order, each with gain 1.
    public var defaultChoices: [MappingChoice] {
        switch self {
        case .bars: [Self.choice(Self.level), Self.choice(Self.beat)]
        case .rings: [Self.choice(Self.level), Self.choice(Self.highMid)]
        case .geometry: [Self.choice(Self.beat), Self.choice(Self.level), Self.choice(Self.low)]
        }
    }

    /// The default choices of every scene, in scene order.
    public static func defaultMappings() -> [[MappingChoice]] {
        allCases.map(\.defaultChoices)
    }

    /// The slot of the rotation-speed parameter, which Reduce Motion holds still; `nil` for scenes without one.
    public var spinParameterIndex: Int? {
        self == .geometry ? 1 : nil
    }

    private static let level = 0
    private static let beat = 2
    private static let low = 3
    private static let highMid = 5

    private static func parameter(_ name: String, _ title: String, _ range: ClosedRange<Double>) -> SceneParameter {
        SceneParameter(name: name, title: title, range: range, attack: 0.02, release: 0.25)
    }

    private static func beatParameter(_ name: String, _ title: String, _ range: ClosedRange<Double>) -> SceneParameter {
        SceneParameter(name: name, title: title, range: range, attack: 0.01, release: 0.2)
    }

    private static func choice(_ feature: Int) -> MappingChoice {
        guard let choice = MappingChoice(feature: feature, gain: 1) else {
            preconditionFailure("default feature \(feature) out of range")
        }
        return choice
    }
}
