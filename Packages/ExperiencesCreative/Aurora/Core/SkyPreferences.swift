// SkyPreferences — feature 154 (A21-P03) T-A21-304 (FR-A21-303, FR-A21-304; clarifications Q3, Q4). The person's
// saved choices of Aurora: the preset id, the hue shift, the five sky values, the brightness limit and the sound choice
// (on/off and volume), kept as the experience value `prefs.v1` in a versioned JSON envelope of kind `a21.preferences`
// (schema 1, at most 4,096 bytes) with three typed refusals: `damaged`, `newer-version` and `out-of-range`. Quality is
// the host's choice and is not saved. Decoding refuses instead of clamping; the caller then opens with ``defaults``.
// Choices recorded here: a NaN or infinity and an unknown preset id are refused as `out-of-range` (the value is
// readable but not acceptable); a fractional number for an integer field (`ribbons`, `stars`) is refused as `damaged`
// (the field has the wrong type), as is a file above 4,096 bytes, a wrong kind, a missing field or a version below 1.
// Pure Foundation; no UI, GPU or clock.
import Foundation

/// Why a saved preferences value was refused. The code is one of `damaged`, `newer-version` and `out-of-range`.
public enum PreferencesRefusal: Error, Equatable, Sendable {
    /// The value is not valid JSON, is larger than ``SkyPreferences/maxBytes``, has the wrong kind, lacks a field,
    /// has a field of the wrong type (including a fractional `ribbons` or `stars`) or has a version below 1.
    case damaged
    /// The value was written by a newer version (above ``SkyPreferences/schemaVersion``); the value is that version.
    case newerVersion(Int)
    /// A field is outside its range, is NaN or infinite, or (for `preset`) names no preset of ``SkyPresets/all``;
    /// the value names the field.
    case outOfRange(String)

    /// The stable code: `damaged`, `newer-version` or `out-of-range`.
    public var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .outOfRange: return "out-of-range"
        }
    }
}

/// Aurora's saved choices (schema 1). Every field is checked by ``validate()``; ``decode(_:)`` refuses a value that
/// fails it. The initializer does not clamp.
public struct SkyPreferences: Codable, Equatable, Sendable {
    /// The envelope kind of a preferences value.
    public static let kind = "a21.preferences"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 1
    /// The experience value key the preferences are kept under.
    public static let storageKey = "prefs.v1"
    /// The largest preferences value accepted, in bytes.
    public static let maxBytes = 4_096
    /// The accepted hue shift (a fraction of a turn).
    public static let hueRange: ClosedRange<Double> = -0.5...0.5
    /// The accepted animation speed.
    public static let speedRange: ClosedRange<Double> = SkyScene.speedRange
    /// The accepted turbulence.
    public static let turbulenceRange: ClosedRange<Double> = SkyScene.turbulenceRange
    /// The accepted ribbon count.
    public static let ribbonsRange: ClosedRange<Int> = SkyScene.ribbonsRange
    /// The accepted star count.
    public static let starsRange: ClosedRange<Int> = SkyScene.starsRange
    /// The accepted cloudiness.
    public static let cloudsRange: ClosedRange<Double> = SkyScene.cloudinessRange
    /// The accepted brightness limit (largest Rec. 709 luminance, linear light).
    public static let limitRange: ClosedRange<Double> = 0.2...0.72
    /// The accepted sound volume.
    public static let volumeRange: ClosedRange<Double> = 0...1
    /// The default brightness limit.
    public static let defaultLimit = 0.6
    /// The default sound volume.
    public static let defaultVolume = 0.5

    /// The defaults: the `polar-night` preset with its scene values, hue 0, limit 0.6, sound off, volume 0.5.
    public static let defaults = SkyPreferences(scene: SkyPresets.defaultPreset.scene)

    /// The preset id (one of ``SkyPresets/all``).
    public var preset: String
    /// The hue shift (−0.5…0.5).
    public var hue: Double
    /// The animation speed (0…2).
    public var speed: Double
    /// How strongly the ribbons fold (0…1).
    public var turbulence: Double
    /// The number of ribbons (1…4).
    public var ribbons: Int
    /// The number of stars (0…400).
    public var stars: Int
    /// How much of the sky the clouds cover (0…1).
    public var clouds: Double
    /// The brightness limit (0.2…0.72).
    public var limit: Double
    /// Whether sound is on (off by default).
    public var soundOn: Bool
    /// The sound volume (0…1, 0.5 by default).
    public var volume: Double

    /// Preferences with the values as given; nothing is clamped (``validate()`` checks them).
    public init(preset: String, hue: Double, speed: Double, turbulence: Double, ribbons: Int, stars: Int,
                clouds: Double, limit: Double, soundOn: Bool = false, volume: Double = SkyPreferences.defaultVolume) {
        self.preset = preset
        self.hue = hue
        self.speed = speed
        self.turbulence = turbulence
        self.ribbons = ribbons
        self.stars = stars
        self.clouds = clouds
        self.limit = limit
        self.soundOn = soundOn
        self.volume = volume
    }

    /// Preferences taking the preset id and the five sky values from `scene`, with the other values as given.
    public init(scene: SkyScene, hue: Double = 0, limit: Double = SkyPreferences.defaultLimit, soundOn: Bool = false,
                volume: Double = SkyPreferences.defaultVolume) {
        self.init(preset: scene.preset, hue: hue, speed: scene.speed, turbulence: scene.turbulence,
                  ribbons: scene.ribbons, stars: scene.stars, clouds: scene.cloudiness, limit: limit,
                  soundOn: soundOn, volume: volume)
    }

    /// The sky scene of these preferences: the preset's palette with the saved sky values, or nil when the preset id
    /// is unknown. The scene's setters clamp, so the result is always within the scene's bounds.
    public var scene: SkyScene? {
        guard var scene = SkyPresets.scene(id: preset) else { return nil }
        scene.setSpeed(speed)
        scene.setTurbulence(turbulence)
        scene.setRibbons(ribbons)
        scene.setStars(stars)
        scene.setCloudiness(clouds)
        return scene
    }

    private struct Envelope: Codable {
        var body: SkyPreferences?
        var kind: String
        var version: Int
    }

    private struct Header: Decodable {
        var kind: String
        var version: Int
    }

    /// The strings that stand for non-finite numbers, so that encoding never fails and a NaN or infinity is refused
    /// as ``PreferencesRefusal/outOfRange(_:)`` rather than as damage.
    private static let positiveInfinityText = "Infinity"
    private static let negativeInfinityText = "-Infinity"
    private static let nanText = "NaN"

    /// The stored value: the JSON envelope `{"body", "kind", "version"}` with sorted keys and unescaped slashes, the
    /// same bytes for the same preferences. A non-finite number (possible only through the initializer) is written as
    /// a string, which ``decode(_:)`` refuses as out of range.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: Self.positiveInfinityText, negativeInfinity: Self.negativeInfinityText,
            nan: Self.nanText)
        return (try? encoder.encode(Envelope(body: self, kind: Self.kind, version: Self.schemaVersion))) ?? Data()
    }

    /// Reads a stored value. Checks, in order: the size, the envelope and its kind (``PreferencesRefusal/damaged``),
    /// the version (``PreferencesRefusal/newerVersion(_:)``), the body (``PreferencesRefusal/damaged``), then every
    /// value (``validate()``). Nothing the caller holds is changed.
    public static func decode(_ data: Data) -> Result<SkyPreferences, PreferencesRefusal> {
        guard data.count <= maxBytes else { return .failure(.damaged) }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: positiveInfinityText, negativeInfinity: negativeInfinityText, nan: nanText)
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion(header.version)) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
              let preferences = envelope.body else { return .failure(.damaged) }
        if let refusal = preferences.validate() { return .failure(refusal) }
        return .success(preferences)
    }

    /// The first refusal of the values, or nil when they are valid. Checks, in order: `preset`, `hue`, `speed`,
    /// `turbulence`, `ribbons`, `stars`, `clouds`, `limit`, `volume`; a NaN or infinity is out of range.
    public func validate() -> PreferencesRefusal? {
        guard SkyPresets.preset(id: preset) != nil else { return .outOfRange("preset") }
        let reals: [(String, Double, ClosedRange<Double>)] = [
            ("hue", hue, Self.hueRange), ("speed", speed, Self.speedRange),
            ("turbulence", turbulence, Self.turbulenceRange)]
        for (field, value, range) in reals where !(value.isFinite && range.contains(value)) {
            return .outOfRange(field)
        }
        guard Self.ribbonsRange.contains(ribbons) else { return .outOfRange("ribbons") }
        guard Self.starsRange.contains(stars) else { return .outOfRange("stars") }
        let rest: [(String, Double, ClosedRange<Double>)] = [
            ("clouds", clouds, Self.cloudsRange), ("limit", limit, Self.limitRange),
            ("volume", volume, Self.volumeRange)]
        for (field, value, range) in rest where !(value.isFinite && range.contains(value)) {
            return .outOfRange(field)
        }
        return nil
    }
}
