// SkyScene — feature 152 (A21-P01) T-A21-103 (FR-A21-101, FR-A21-102; clarification Q1). The sky scene: the preset
// id, a palette of 2…4 opaque sRGB colours, the ribbon count, turbulence, cloudiness, the star count and the
// animation speed, stored as a versioned JSON envelope of kind `a21.sky-scene` (at most 4,096 bytes) with typed
// refusals. Setters clamp to the bounds and ignore non-finite values; decoding refuses instead of clamping. Pure
// Foundation; no GPU, network or clock.
import Foundation

/// Why a sky scene file was refused. A refused file leaves the open scene unchanged.
public enum SceneRefusal: Error, Equatable, Sendable {
    /// The file is not valid JSON, has the wrong kind, lacks a field, has a field of the wrong type or has a version
    /// below 1.
    case damaged
    /// The file was written by a newer version (above ``SkyScene/schemaVersion``); the value is that version.
    case newerVersion(Int)
    /// The file is larger than ``SkyScene/maxBytes``; the value is its size in bytes.
    case tooLarge(Int)
    /// A number is NaN or infinite; the value names the field (`palette`, `turbulence`, `cloudiness`, `speed`).
    case notFinite(String)
    /// A value is outside its range; the value names the field (`palette`, `ribbons`, `turbulence`, `cloudiness`,
    /// `stars`, `speed`).
    case outOfRange(String)
    /// The preset id is not in ``SkyPresets/all``; the value is the id.
    case unknownPreset(String)
    /// The palette holds fewer than 2 or more than 4 colours; the value is the count.
    case paletteSize(Int)

    /// The stable code: `damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range`, `unknown-preset` or
    /// `palette-size`.
    public var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .tooLarge: return "too-large"
        case .notFinite: return "not-finite"
        case .outOfRange: return "out-of-range"
        case .unknownPreset: return "unknown-preset"
        case .paletteSize: return "palette-size"
        }
    }

    /// One plain sentence describing the refusal and naming the offending value.
    public var sentence: String {
        switch self {
        case .damaged:
            return "The sky scene file is damaged and was not opened."
        case .newerVersion(let version):
            return "The sky scene file has version \(version), newer than version \(SkyScene.schemaVersion) "
                + "that this version opens."
        case .tooLarge(let bytes):
            return "The sky scene file is \(bytes) bytes, above the limit of \(SkyScene.maxBytes) bytes."
        case .notFinite(let field):
            return "The sky scene file has a value that is not a finite number for \"\(field)\"."
        case .outOfRange(let field):
            return "The sky scene file has a value out of range for \"\(field)\"."
        case .unknownPreset(let id):
            return "The sky scene file names the unknown preset \"\(id)\"."
        case .paletteSize(let count):
            return "The sky scene file has \(count) palette colours; a palette holds "
                + "\(SkyScene.paletteCountRange.lowerBound) to \(SkyScene.paletteCountRange.upperBound)."
        }
    }
}

/// An opaque sRGB colour; every component is in 0…1 and there is no alpha, so it is opaque by construction.
public struct SkyColor: Codable, Equatable, Hashable, Sendable {
    /// The red component, in 0…1 (sRGB-encoded).
    public var red: Double
    /// The green component, in 0…1 (sRGB-encoded).
    public var green: Double
    /// The blue component, in 0…1 (sRGB-encoded).
    public var blue: Double

    /// Creates a colour from its sRGB components; nothing is clamped (``SkyScene/validate()`` checks them).
    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The three components in order red, green, blue.
    public var components: [Double] { [red, green, blue] }

    /// Whether every component is finite.
    public var isFinite: Bool { red.isFinite && green.isFinite && blue.isFinite }

    /// Whether every component is finite and in 0…1.
    public var isInRange: Bool { components.allSatisfy { $0.isFinite && (0...1).contains($0) } }

    /// The colour with each component clamped to 0…1, or nil when a component is not finite.
    public var clamped: SkyColor? {
        guard isFinite else { return nil }
        return SkyColor(red: min(max(red, 0), 1), green: min(max(green, 0), 1), blue: min(max(blue, 0), 1))
    }
}

/// A sky scene (schema 1): a preset id, a palette and the six sky values. Change it through the setters, which clamp
/// to the bounds and ignore non-finite values; a decoded file is checked by ``validate()`` and refused instead.
public struct SkyScene: Codable, Equatable, Sendable {
    /// The envelope kind of a sky scene file.
    public static let kind = "a21.sky-scene"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 1
    /// The largest sky scene file accepted, in bytes.
    public static let maxBytes = 4_096
    /// The accepted number of palette colours.
    public static let paletteCountRange: ClosedRange<Int> = 2...4
    /// The accepted ribbon count.
    public static let ribbonsRange: ClosedRange<Int> = 1...4
    /// The accepted turbulence.
    public static let turbulenceRange: ClosedRange<Double> = 0...1
    /// The accepted cloudiness.
    public static let cloudinessRange: ClosedRange<Double> = 0...1
    /// The accepted star count.
    public static let starsRange: ClosedRange<Int> = 0...400
    /// The accepted animation speed (a multiple of the clock rate).
    public static let speedRange: ClosedRange<Double> = 0...2

    /// The preset id this scene came from (one of ``SkyPresets/all``).
    public private(set) var preset: String
    /// The palette: 2…4 opaque sRGB colours, the first the sky and the rest the ribbons.
    public private(set) var palette: [SkyColor]
    /// The number of aurora ribbons (1…4).
    public private(set) var ribbons: Int
    /// How strongly the ribbons fold (0…1).
    public private(set) var turbulence: Double
    /// How much of the sky the clouds cover (0…1).
    public private(set) var cloudiness: Double
    /// The number of stars (0…400).
    public private(set) var stars: Int
    /// The animation speed (0…2); 0 holds the sky still.
    public private(set) var speed: Double

    /// Creates a scene with the values as given; nothing is clamped (``validate()`` checks them).
    public init(preset: String, palette: [SkyColor], ribbons: Int, turbulence: Double, cloudiness: Double,
                stars: Int, speed: Double) {
        self.preset = preset
        self.palette = palette
        self.ribbons = ribbons
        self.turbulence = turbulence
        self.cloudiness = cloudiness
        self.stars = stars
        self.speed = speed
    }

    /// Sets the preset id; an id not in ``SkyPresets/all`` is ignored. Only the id changes, not the values.
    public mutating func setPreset(_ id: String) {
        guard SkyPresets.preset(id: id) != nil else { return }
        preset = id
    }

    /// Sets the palette; a palette whose size is outside ``paletteCountRange`` or that holds a non-finite component
    /// is ignored, and each component is clamped to 0…1.
    public mutating func setPalette(_ colors: [SkyColor]) {
        guard Self.paletteCountRange.contains(colors.count) else { return }
        let clamped = colors.compactMap(\.clamped)
        guard clamped.count == colors.count else { return }
        palette = clamped
    }

    /// Sets the ribbon count, clamped to ``ribbonsRange``.
    public mutating func setRibbons(_ value: Int) { ribbons = Self.clamp(value, Self.ribbonsRange) }

    /// Sets the turbulence, clamped to ``turbulenceRange``; a non-finite value is ignored.
    public mutating func setTurbulence(_ value: Double) {
        if let value = Self.clamp(value, Self.turbulenceRange) { turbulence = value }
    }

    /// Sets the cloudiness, clamped to ``cloudinessRange``; a non-finite value is ignored.
    public mutating func setCloudiness(_ value: Double) {
        if let value = Self.clamp(value, Self.cloudinessRange) { cloudiness = value }
    }

    /// Sets the star count, clamped to ``starsRange``.
    public mutating func setStars(_ value: Int) { stars = Self.clamp(value, Self.starsRange) }

    /// Sets the animation speed, clamped to ``speedRange``; a non-finite value is ignored.
    public mutating func setSpeed(_ value: Double) {
        if let value = Self.clamp(value, Self.speedRange) { speed = value }
    }

    private struct Envelope: Codable {
        var kind: String
        var version: Int
        var body: SkyScene?
    }

    private struct Header: Decodable {
        var kind: String
        var version: Int
    }

    /// The strings that stand for non-finite numbers in a file, so that a NaN or infinity is refused as
    /// ``SceneRefusal/notFinite(_:)`` rather than as damage, and so that encoding never fails.
    private static let positiveInfinityText = "Infinity"
    private static let negativeInfinityText = "-Infinity"
    private static let nanText = "NaN"

    /// The scene file: the JSON envelope `{"body", "kind", "version"}` with sorted keys and unescaped slashes, the
    /// same bytes for the same scene. A non-finite number (possible only through the initializer, which does not
    /// clamp) is written as a string, which ``decode(_:)`` refuses.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: Self.positiveInfinityText, negativeInfinity: Self.negativeInfinityText,
            nan: Self.nanText)
        return (try? encoder.encode(Envelope(kind: Self.kind, version: Self.schemaVersion, body: self))) ?? Data()
    }

    /// Reads a scene file. Checks, in order: the size (``SceneRefusal/tooLarge(_:)``), the envelope and its kind
    /// (``SceneRefusal/damaged``), the version (``SceneRefusal/newerVersion(_:)``), the body
    /// (``SceneRefusal/damaged``), then every value (``validate()``). Nothing the caller holds is changed.
    public static func decode(_ data: Data) -> Result<SkyScene, SceneRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: positiveInfinityText, negativeInfinity: negativeInfinityText, nan: nanText)
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion(header.version)) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
              let scene = envelope.body else { return .failure(.damaged) }
        if let refusal = scene.validate() { return .failure(refusal) }
        return .success(scene)
    }

    /// The first refusal of the scene's values, or nil when it is valid. Checks, in order: the preset, the palette
    /// size, every number's finiteness (palette, turbulence, cloudiness, speed), then every range (palette,
    /// ribbons, turbulence, cloudiness, stars, speed).
    public func validate() -> SceneRefusal? {
        guard SkyPresets.preset(id: preset) != nil else { return .unknownPreset(preset) }
        guard Self.paletteCountRange.contains(palette.count) else { return .paletteSize(palette.count) }
        guard palette.allSatisfy(\.isFinite) else { return .notFinite("palette") }
        guard turbulence.isFinite else { return .notFinite("turbulence") }
        guard cloudiness.isFinite else { return .notFinite("cloudiness") }
        guard speed.isFinite else { return .notFinite("speed") }
        guard palette.allSatisfy(\.isInRange) else { return .outOfRange("palette") }
        guard Self.ribbonsRange.contains(ribbons) else { return .outOfRange("ribbons") }
        guard Self.turbulenceRange.contains(turbulence) else { return .outOfRange("turbulence") }
        guard Self.cloudinessRange.contains(cloudiness) else { return .outOfRange("cloudiness") }
        guard Self.starsRange.contains(stars) else { return .outOfRange("stars") }
        guard Self.speedRange.contains(speed) else { return .outOfRange("speed") }
        return nil
    }

    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double? {
        guard value.isFinite else { return nil }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
