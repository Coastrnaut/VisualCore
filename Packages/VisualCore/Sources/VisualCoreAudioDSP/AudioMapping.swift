// AudioMapping — feature 049 (A06-P03) T-A06-302; gap G-AUDIOMAP (FR-A06-301, FR-A06-303; SC-A06-302; research D1, D3;
// data-model "AudioMapping"; contract specs/049-ml-p03-scenes-mapping/contracts/api.md). A versioned, validated
// description of how one audio feature drives one parameter: gain, attack/release smoothing and a clamp.
import Foundation

/// How one ``AudioFeatureKind`` drives one parameter: x = clamp(gain · n, clampLow, clampHigh), smoothed with
/// ``attack`` and ``release`` (see ``AudioMapper``).
///
/// Every stored mapping is valid: the memberwise initialiser returns `nil` and decoding throws
/// `DecodingError.dataCorrupted` for a gain outside ``gainRange``, a time constant outside ``timeRange``, a non-finite
/// number, a clamp that is not `0 ≤ clampLow < clampHigh ≤ 1`, an unknown feature or a ``schemaVersion`` other than 1.
public struct AudioMapping: Codable, Sendable, Equatable {
    /// The persisted schema version written by encoding and required by decoding.
    public static let schemaVersion: Int = 1
    /// The allowed gain.
    public static let gainRange: ClosedRange<Double> = 0...4
    /// The allowed attack and release time constants in seconds.
    public static let timeRange: ClosedRange<Double> = 0.001...5

    /// The feature followed.
    public var feature: AudioFeatureKind
    /// The factor applied to the normalised feature before the clamp (0…4).
    public var gain: Double
    /// Rise time constant in seconds (0.001…5).
    public var attack: Double
    /// Fall time constant in seconds (0.001…5).
    public var release: Double
    /// Lower clamp of the scaled feature (0 ≤ clampLow < clampHigh).
    public var clampLow: Double
    /// Upper clamp of the scaled feature (clampLow < clampHigh ≤ 1).
    public var clampHigh: Double

    /// Creates a mapping, or `nil` when any value is invalid.
    ///
    /// - Parameters:
    ///   - feature: the feature followed.
    ///   - gain: finite, within ``gainRange``.
    ///   - attack: finite, within ``timeRange``; default 0.02 s.
    ///   - release: finite, within ``timeRange``; default 0.25 s.
    ///   - clampLow: finite, `0 ≤ clampLow < clampHigh`; default 0.
    ///   - clampHigh: finite, `clampLow < clampHigh ≤ 1`; default 1.
    public init?(feature: AudioFeatureKind, gain: Double, attack: Double = 0.02, release: Double = 0.25,
                 clampLow: Double = 0, clampHigh: Double = 1) {
        guard Self.isValid(gain: gain, attack: attack, release: release, clampLow: clampLow, clampHigh: clampHigh)
        else { return nil }
        self.feature = feature
        self.gain = gain
        self.attack = attack
        self.release = release
        self.clampLow = clampLow
        self.clampHigh = clampHigh
    }

    /// Whether the numeric fields form a valid mapping.
    static func isValid(gain: Double, attack: Double, release: Double, clampLow: Double, clampHigh: Double) -> Bool {
        guard gain.isFinite, attack.isFinite, release.isFinite, clampLow.isFinite, clampHigh.isFinite else {
            return false
        }
        return gainRange.contains(gain) && timeRange.contains(attack) && timeRange.contains(release)
            && clampLow >= 0 && clampLow < clampHigh && clampHigh <= 1
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, feature, gain, attack, release, clampLow, clampHigh
    }

    /// Decodes and validates a mapping.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for an unsupported ``schemaVersion``, an unknown feature or any invalid
    ///   value; the decoder's own errors for missing or mistyped fields.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.schemaVersion else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath + [CodingKeys.schemaVersion],
                debugDescription: "Unsupported AudioMapping schemaVersion \(version)."))
        }
        let rawFeature = try container.decode(String.self, forKey: .feature)
        guard let feature = AudioFeatureKind(rawValue: rawFeature) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath + [CodingKeys.feature],
                debugDescription: "Unknown audio feature \(rawFeature)."))
        }
        let gain = try container.decode(Double.self, forKey: .gain)
        let attack = try container.decode(Double.self, forKey: .attack)
        let release = try container.decode(Double.self, forKey: .release)
        let clampLow = try container.decode(Double.self, forKey: .clampLow)
        let clampHigh = try container.decode(Double.self, forKey: .clampHigh)
        guard Self.isValid(gain: gain, attack: attack, release: release, clampLow: clampLow, clampHigh: clampHigh)
        else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Invalid AudioMapping values."))
        }
        self.feature = feature
        self.gain = gain
        self.attack = attack
        self.release = release
        self.clampLow = clampLow
        self.clampHigh = clampHigh
    }

    /// Encodes the mapping with ``schemaVersion``.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(feature.rawValue, forKey: .feature)
        try container.encode(gain, forKey: .gain)
        try container.encode(attack, forKey: .attack)
        try container.encode(release, forKey: .release)
        try container.encode(clampLow, forKey: .clampLow)
        try container.encode(clampHigh, forKey: .clampHigh)
    }
}
