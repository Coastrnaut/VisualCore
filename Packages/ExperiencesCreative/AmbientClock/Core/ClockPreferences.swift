// ClockPreferences — feature 131 T-A18-105 (FR-A18-103; G-FORMAT; clarifications Q3 and Q4). The clock's preferences,
// their versioned file envelope with typed refusals, and the environment (locale, zone, Gregorian calendar) they
// resolve to. Pure Foundation; nothing here reads a clock.
import Foundation

/// Which hour cycle the clock shows.
public enum HourCycle: String, Codable, Equatable, Sendable, CaseIterable {
    /// The locale's own cycle (for example 12-hour for en_US, 24-hour for de_DE).
    case system
    /// Always 12-hour, with the day period.
    case h12
    /// Always 24-hour.
    case h24
}

/// Which time zone the clock uses.
///
/// Encoded as a single JSON string: `"system"` for ``system``, otherwise the zone identifier itself
/// (for example `"Asia/Kolkata"`). No real zone identifier is `"system"`, so the form is unambiguous.
public enum ZonePolicy: Codable, Equatable, Sendable {
    /// The device's time zone at the time the environment is built.
    case system
    /// A fixed zone, by its identifier (any identifier `TimeZone(identifier:)` resolves, including current names such as `Asia/Kolkata`).
    case fixed(String)

    /// Decodes the plain-string form described on the type.
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = value == "system" ? .system : .fixed(value)
    }

    /// Encodes the plain-string form described on the type.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .system: try container.encode("system")
        case .fixed(let id): try container.encode(id)
        }
    }
}

/// Which locale the clock formats with.
///
/// Encoded as a single JSON string: `"system"` for ``system``, otherwise the locale identifier itself
/// (for example `"de_DE"`). No real locale identifier is `"system"`, so the form is unambiguous.
public enum LocalePolicy: Codable, Equatable, Sendable {
    /// The device's locale at the time the environment is built.
    case system
    /// A fixed locale, by its identifier (one of `Locale.availableIdentifiers`).
    case fixed(String)

    /// Decodes the plain-string form described on the type.
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = value == "system" ? .system : .fixed(value)
    }

    /// Encodes the plain-string form described on the type.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .system: try container.encode("system")
        case .fixed(let id): try container.encode(id)
        }
    }
}

/// Why a preferences file was refused. A refused file leaves the defaults.
public enum PreferencesRefusal: Error, Equatable, Sendable {
    /// The file is not valid JSON, has the wrong kind, lacks a field or has a schema version below 1.
    case damaged
    /// The file was written by a newer version (schema above 1); the value is that version.
    case newerVersion(Int)
    /// The fixed time zone is not a known identifier; the value is the identifier.
    case unknownTimeZone(String)
    /// The fixed locale is not an available identifier; the value is the identifier.
    case unknownLocale(String)
    /// The file is larger than ``ClockPreferences/maxBytes``; the value is its size in bytes.
    case tooLarge(Int)

    /// The stable code: `damaged`, `newer-version`, `unknown-time-zone`, `unknown-locale` or `too-large`.
    public var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .unknownTimeZone: return "unknown-time-zone"
        case .unknownLocale: return "unknown-locale"
        case .tooLarge: return "too-large"
        }
    }

    /// One sentence describing the refusal and naming the offending value.
    public var sentence: String {
        switch self {
        case .damaged:
            return "The clock preferences file is damaged and was not read."
        case .newerVersion(let version):
            return "The clock preferences file has schema version \(version), newer than version "
                + "\(ClockPreferences.schemaVersion) that this version reads."
        case .unknownTimeZone(let id):
            return "The clock preferences name the unknown time zone \"\(id)\"."
        case .unknownLocale(let id):
            return "The clock preferences name the unknown locale \"\(id)\"."
        case .tooLarge(let bytes):
            return "The clock preferences file is \(bytes) bytes, above the limit of \(ClockPreferences.maxBytes) bytes."
        }
    }
}

/// The clock's preferences (schema 1).
public struct ClockPreferences: Codable, Equatable, Sendable {
    /// The envelope kind of a preferences file.
    public static let kind = "a18.clock-preferences"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 1
    /// The largest preferences file accepted, in bytes.
    public static let maxBytes = 4096

    /// The hour cycle (default ``HourCycle/system``).
    public var hourCycle: HourCycle
    /// Whether seconds are shown (default false).
    public var showSeconds: Bool
    /// Whether the date line is shown (default true).
    public var showDate: Bool
    /// The time zone policy (default ``ZonePolicy/system``).
    public var timeZone: ZonePolicy
    /// The locale policy (default ``LocalePolicy/system``).
    public var locale: LocalePolicy

    /// Creates preferences; every argument defaults to the documented default.
    public init(hourCycle: HourCycle = .system, showSeconds: Bool = false, showDate: Bool = true,
                timeZone: ZonePolicy = .system, locale: LocalePolicy = .system) {
        self.hourCycle = hourCycle
        self.showSeconds = showSeconds
        self.showDate = showDate
        self.timeZone = timeZone
        self.locale = locale
    }

    private struct Envelope: Codable {
        var kind: String
        var schemaVersion: Int
        var preferences: ClockPreferences?
    }

    private struct Header: Decodable {
        var kind: String
        var schemaVersion: Int
    }

    /// The preferences file: the JSON envelope `{"kind", "schemaVersion", "preferences"}` with sorted keys and
    /// unescaped slashes.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Envelope(kind: Self.kind, schemaVersion: Self.schemaVersion, preferences: self))
    }

    /// Reads a preferences file. Checks, in order: size (``PreferencesRefusal/tooLarge(_:)``), the envelope's kind
    /// and version (``PreferencesRefusal/damaged``, ``PreferencesRefusal/newerVersion(_:)``), the body
    /// (``PreferencesRefusal/damaged``), then the fixed zone and locale identifiers.
    public static func decode(_ data: Data) -> Result<ClockPreferences, PreferencesRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.schemaVersion >= 1 else { return .failure(.damaged) }
        guard header.schemaVersion <= schemaVersion else { return .failure(.newerVersion(header.schemaVersion)) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
              let preferences = envelope.preferences else { return .failure(.damaged) }
        if case .fixed(let id) = preferences.timeZone, TimeZone(identifier: id) == nil {
            return .failure(.unknownTimeZone(id))
        }
        if case .fixed(let id) = preferences.locale, !Locale.availableIdentifiers.contains(id) {
            return .failure(.unknownLocale(id))
        }
        return .success(preferences)
    }
}

/// The resolved locale, time zone and calendar the clock formats in. Fixed policies win; otherwise the system values
/// passed in (captured when the environment is built). The calendar is Gregorian with the resolved locale and zone.
public struct ClockEnvironment: Equatable, Sendable {
    /// The resolved locale.
    public let locale: Locale
    /// The resolved time zone.
    public let timeZone: TimeZone
    /// A Gregorian calendar in ``locale`` and ``timeZone``.
    public let calendar: Calendar

    /// Resolves the environment. An unknown fixed zone identifier falls back to the system zone (decoding already
    /// refuses such a file).
    public init(preferences: ClockPreferences, systemLocale: Locale = .current, systemTimeZone: TimeZone = .current) {
        switch preferences.locale {
        case .system: locale = systemLocale
        case .fixed(let id): locale = Locale(identifier: id)
        }
        switch preferences.timeZone {
        case .system: timeZone = systemTimeZone
        case .fixed(let id): timeZone = TimeZone(identifier: id) ?? systemTimeZone
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        self.calendar = calendar
    }
}
