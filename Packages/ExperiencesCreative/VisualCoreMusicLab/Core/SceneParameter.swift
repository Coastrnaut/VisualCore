// SceneParameter — feature 049 (A06-P03) T-A06-304 (FR-A06-310, FR-A06-311; data-model "SceneParameter",
// "MappingChoice"; research D4, D5). One drivable parameter of a Music Lab scene and the person's choice of which
// analysis feature drives it with which gain. GPU-free and audio-free: the feature is a plain index 0…6 (level, peak,
// beat, low, low-mid, high-mid, high), resolved to the audio feature by the experience.
import Foundation

/// A drivable parameter of a Music Lab scene: its stable name, the title shown in the mapping editor, the output range
/// the mapped feature is scaled into, and the smoothing time constants in seconds.
public struct SceneParameter: Sendable, Equatable {
    /// The stable identifier of the parameter within its scene (for example `height`).
    public let name: String
    /// The title shown in the mapping editor (for example "Bar height").
    public let title: String
    /// The output range a normalized feature value of 0…1 is mapped into; `lowerBound < upperBound`.
    public let range: ClosedRange<Double>
    /// The attack time constant in seconds (how fast the value rises).
    public let attack: Double
    /// The release time constant in seconds (how fast the value falls).
    public let release: Double

    /// Creates a scene parameter.
    /// - Parameters:
    ///   - name: The stable identifier within the scene.
    ///   - title: The title shown in the mapping editor.
    ///   - range: The output range of the parameter.
    ///   - attack: The attack time constant in seconds.
    ///   - release: The release time constant in seconds.
    public init(name: String, title: String, range: ClosedRange<Double>, attack: Double, release: Double) {
        self.name = name
        self.title = title
        self.range = range
        self.attack = attack
        self.release = release
    }
}

/// The person's choice for one scene parameter: which analysis feature drives it (index 0…6) and with which gain
/// (0…4, finite). Decoding refuses values outside these ranges.
public struct MappingChoice: Codable, Sendable, Equatable, Hashable {
    /// The valid feature indices: 0 level, 1 peak, 2 beat, 3 low, 4 low-mid, 5 high-mid, 6 high.
    public static let featureRange = 0...6
    /// The valid gains.
    public static let gainRange: ClosedRange<Double> = 0.0...4.0
    /// The names of the features in index order, as shown in the mapping editor.
    public static let featureNames = ["Level", "Peak", "Beat", "Low", "Low-mid", "High-mid", "High"]

    /// The index of the analysis feature that drives the parameter (see `featureNames`).
    public var feature: Int
    /// The gain applied to the normalized feature value.
    public var gain: Double

    /// Creates a choice, or returns `nil` when the feature is outside `featureRange` or the gain is not finite or
    /// outside `gainRange`.
    /// - Parameters:
    ///   - feature: The feature index 0…6.
    ///   - gain: The gain 0…4.
    public init?(feature: Int, gain: Double) {
        guard Self.isValid(feature: feature, gain: gain) else { return nil }
        self.feature = feature
        self.gain = gain
    }

    /// Whether the feature and gain are within their ranges (they can leave them through the mutable properties).
    public var isValid: Bool { Self.isValid(feature: feature, gain: gain) }

    private static func isValid(feature: Int, gain: Double) -> Bool {
        featureRange.contains(feature) && gain.isFinite && gainRange.contains(gain)
    }

    private enum CodingKeys: String, CodingKey {
        case feature
        case gain
    }

    /// Decodes a choice and throws `DecodingError.dataCorrupted` when the feature or gain is out of range.
    /// - Parameter decoder: The decoder to read from.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let feature = try container.decode(Int.self, forKey: .feature)
        let gain = try container.decode(Double.self, forKey: .gain)
        guard Self.isValid(feature: feature, gain: gain) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "MappingChoice feature \(feature) or gain \(gain) out of range"))
        }
        self.feature = feature
        self.gain = gain
    }

    /// Encodes the feature and gain.
    /// - Parameter encoder: The encoder to write to.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(feature, forKey: .feature)
        try container.encode(gain, forKey: .gain)
    }
}
