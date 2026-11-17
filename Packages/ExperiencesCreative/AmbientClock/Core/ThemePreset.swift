// ThemePreset — feature 133 T-A18-303 (FR-A18-302, FR-A18-304; clarification Q3). A theme preset: which theme, which
// palette, how fast and whether it moves, with its versioned file envelope and typed refusals. A favourite holds one.
// Pure Foundation; nothing here reads a clock.
import Foundation

/// Why a theme preset was refused (by ``ThemePreset/decode(_:)``, ``ThemePreset/validated()`` or the checking
/// initializer).
public enum ThemePresetRefusal: Error, Equatable, Sendable {
    /// The file is not valid JSON, has the wrong kind, lacks a field or has a schema version below 1.
    case damaged
    /// The file was written by a newer version (schema above 1); the value is that version.
    case newerVersion(Int)
    /// The file is larger than ``ThemePreset/maxBytes``; the value is its size in bytes.
    case tooLarge(Int)
    /// A field is outside its range; `field` is `theme`, `palette` or `speed`, and `value` is the value as written.
    case outOfRange(field: String, value: String)

    /// The stable code: `damaged`, `newer-version`, `too-large` or `out-of-range`.
    public var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .tooLarge: return "too-large"
        case .outOfRange: return "out-of-range"
        }
    }

    /// One sentence describing the refusal and naming the offending value.
    public var sentence: String {
        switch self {
        case .damaged:
            return "The theme preset is damaged and was not read."
        case .newerVersion(let version):
            return "The theme preset has schema version \(version), newer than version "
                + "\(ThemePreset.schemaVersion) that this version reads."
        case .tooLarge(let bytes):
            return "The theme preset is \(bytes) bytes, above the limit of \(ThemePreset.maxBytes) bytes."
        case .outOfRange(let field, let value):
            return "The theme preset has \(field) \(value), outside the range \(ThemePreset.rangeText(of: field))."
        }
    }
}

/// A theme preset (schema 1): a theme of ``ThemeCatalog/themes``, one of its palettes, a speed and the motion switch.
public struct ThemePreset: Codable, Equatable, Hashable, Sendable {
    /// The envelope kind of a theme preset.
    public static let kind = "a18.theme-preset"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 1
    /// The largest preset file accepted, in bytes.
    public static let maxBytes = 4096

    /// The valid theme indices (the four themes of ``ThemeCatalog/themes``).
    public static let themeRange = 0...3
    /// The valid palette indices (the three palettes of every theme).
    public static let paletteRange = 0...2
    /// The valid speed multipliers.
    public static let speedRange = 0.25...2.0

    /// The default preset: theme 0 (noise gradient), palette 0, speed 1, motion on.
    public static let standard = ThemePreset(unchecked: 0, palette: 0, speed: 1, motion: true)

    /// The theme index, 0–3.
    public let theme: Int
    /// The palette index within the theme, 0–2.
    public let palette: Int
    /// The speed multiplier, 0.25–2.
    public let speed: Double
    /// Whether the theme moves.
    public let motion: Bool

    /// Creates a preset, refusing a field outside its range with ``ThemePresetRefusal/outOfRange(field:value:)``
    /// (checked in the order theme, palette, speed; a non-finite speed is out of range).
    public init(theme: Int, palette: Int, speed: Double, motion: Bool) throws(ThemePresetRefusal) {
        let preset = ThemePreset(unchecked: theme, palette: palette, speed: speed, motion: motion)
        if let refusal = preset.rangeRefusal { throw refusal }
        self = preset
    }

    private init(unchecked theme: Int, palette: Int, speed: Double, motion: Bool) {
        self.theme = theme
        self.palette = palette
        self.speed = speed
        self.motion = motion
    }

    /// The first field outside its range, or nil when every field is in range.
    private var rangeRefusal: ThemePresetRefusal? {
        if !Self.themeRange.contains(theme) { return .outOfRange(field: "theme", value: "\(theme)") }
        if !Self.paletteRange.contains(palette) { return .outOfRange(field: "palette", value: "\(palette)") }
        if !speed.isFinite || !Self.speedRange.contains(speed) {
            return .outOfRange(field: "speed", value: "\(speed)")
        }
        return nil
    }

    /// This preset when every field is in range, otherwise the first out-of-range refusal.
    public func validated() -> Result<ThemePreset, ThemePresetRefusal> {
        if let refusal = rangeRefusal { return .failure(refusal) }
        return .success(self)
    }

    /// The range of `field` as text, for the refusal sentence ("0–3", "0–2", "0.25–2.0").
    static func rangeText(of field: String) -> String {
        switch field {
        case "theme": return "\(themeRange.lowerBound)–\(themeRange.upperBound)"
        case "palette": return "\(paletteRange.lowerBound)–\(paletteRange.upperBound)"
        case "speed": return "\(speedRange.lowerBound)–\(speedRange.upperBound)"
        default: return "of its field"
        }
    }

    private struct Envelope: Codable {
        var kind: String
        var schemaVersion: Int
        var preset: ThemePreset?
    }

    private struct Header: Decodable {
        var kind: String
        var schemaVersion: Int
    }

    /// The preset file: the JSON envelope `{"kind", "schemaVersion", "preset"}` with sorted keys and unescaped
    /// slashes.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Envelope(kind: Self.kind, schemaVersion: Self.schemaVersion, preset: self))
    }

    /// Reads a preset file. Checks, in order: size (``ThemePresetRefusal/tooLarge(_:)``), the envelope's kind and
    /// version (``ThemePresetRefusal/damaged``, ``ThemePresetRefusal/newerVersion(_:)``), the body
    /// (``ThemePresetRefusal/damaged``), then the ranges of theme, palette and speed
    /// (``ThemePresetRefusal/outOfRange(field:value:)``).
    public static func decode(_ data: Data) -> Result<ThemePreset, ThemePresetRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.schemaVersion >= 1 else { return .failure(.damaged) }
        guard header.schemaVersion <= schemaVersion else { return .failure(.newerVersion(header.schemaVersion)) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
              let preset = envelope.preset else { return .failure(.damaged) }
        return preset.validated()
    }
}
