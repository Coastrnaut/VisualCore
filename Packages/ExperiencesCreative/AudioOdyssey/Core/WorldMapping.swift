// WorldMapping — feature 056 (A07-P03) T-A07-302 (FR-A07-302, FR-A07-311, FR-A07-312; clarifications 3 and 4;
// research D3; data-model "WorldMapping"). What the music moves in each world: the primary response (tunnel width,
// landscape height, star-corridor sparkle) and the light response, each driven by one envelope channel with a
// sensitivity; and the camera easing that scales the acceleration limit downward.
//
// Rules: sensitivity low/medium/high has the gain 0.6/1.0/1.6; a response target is `clamp(value × gain, 0, 1)` (NaN
// counts as 0). Easing gentle/standard/brisk multiplies the active acceleration limit by 0.33/0.66/1.0, never above it.
// Defaults: tunnel (low, overall), landscape (mid, overall), star corridor (transient, overall), all medium. The raw
// values are persisted.
import Foundation

/// How strongly a channel drives a response. The raw values are persisted (low 0, medium 1, high 2).
public enum Sensitivity: Int, CaseIterable, Codable, Sendable {
    /// Gain 0.6.
    case low = 0
    /// Gain 1.0 (the default).
    case medium = 1
    /// Gain 1.6.
    case high = 2

    /// The factor applied to the channel value before it is clamped to 0…1.
    public var gain: Double {
        switch self {
        case .low: 0.6
        case .medium: 1.0
        case .high: 1.6
        }
    }

    /// The name shown in the mapping editor.
    public var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

/// How gently the camera eases into a new speed. The raw values are persisted (gentle 0, standard 1, brisk 2).
public enum Easing: Int, CaseIterable, Codable, Sendable {
    /// A third of the active acceleration limit.
    case gentle = 0
    /// Two thirds of the active acceleration limit (the default).
    case standard = 1
    /// The full active acceleration limit.
    case brisk = 2

    /// The factor applied to the active acceleration limit (never above 1).
    public var accelerationFactor: Double {
        switch self {
        case .gentle: 0.33
        case .standard: 0.66
        case .brisk: 1.0
        }
    }

    /// The name shown in the easing picker and spoken in the canvas description.
    public var displayName: String {
        switch self {
        case .gentle: "Gentle"
        case .standard: "Standard"
        case .brisk: "Brisk"
        }
    }
}

/// One response's source: an envelope channel and a sensitivity.
public struct ChannelMapping: Codable, Equatable, Sendable {
    /// The envelope channel that drives the response.
    public var channel: EnvelopeChannel
    /// The sensitivity (gain) applied to the channel.
    public var sensitivity: Sensitivity

    /// A mapping of `channel` with `sensitivity` (medium by default).
    public init(channel: EnvelopeChannel, sensitivity: Sensitivity = .medium) {
        self.channel = channel
        self.sensitivity = sensitivity
    }

    /// The response target for `envelope`: `clamp(value × gain, 0, 1)`, NaN counting as 0.
    public func target(from envelope: AudioEnvelope) -> Double {
        let value = envelope.value(channel) * sensitivity.gain
        return value.isNaN ? 0 : min(max(value, 0), 1)
    }
}

/// The mapping of one world: the primary response and the light response.
public struct WorldMapping: Codable, Equatable, Sendable {
    /// The source of the world's primary response (tunnel width, landscape height, star-corridor sparkle).
    public var primary: ChannelMapping
    /// The source of the world's light response (ambient).
    public var light: ChannelMapping

    /// A mapping with the given primary and light sources.
    public init(primary: ChannelMapping, light: ChannelMapping) {
        self.primary = primary
        self.light = light
    }

    /// The default mapping of `world`: tunnel (low, overall), landscape (mid, overall), star corridor (transient,
    /// overall), all medium.
    public static func defaults(for world: JourneyWorld) -> WorldMapping {
        let primary: EnvelopeChannel = switch world {
        case .tunnel: .low
        case .landscape: .mid
        case .starCorridor: .transient
        }
        return WorldMapping(primary: ChannelMapping(channel: primary), light: ChannelMapping(channel: .overall))
    }

    /// The default mappings of every world, in world order.
    public static var allDefaults: [WorldMapping] { JourneyWorld.allCases.map(defaults(for:)) }

    /// The primary and light targets in 0…1 for `envelope`.
    public func target(from envelope: AudioEnvelope) -> (primary: Double, light: Double) {
        (primary.target(from: envelope), light.target(from: envelope))
    }

    /// The compact digest form `p-channel.p-sensitivity.l-channel.l-sensitivity` (raw values), e.g. `0.1.4.1`.
    public var digestText: String {
        "\(primary.channel.rawValue).\(primary.sensitivity.rawValue).\(light.channel.rawValue).\(light.sensitivity.rawValue)"
    }
}
