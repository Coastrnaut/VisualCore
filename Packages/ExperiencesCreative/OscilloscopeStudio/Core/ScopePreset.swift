// ScopePreset — feature 064 (A08-P04) T-A08-402 (FR-A08-410, FR-A08-430; clarification 4; research D4; data-model
// "ScopePreset", format 1). A named set of scope settings: the test waveform, frequency, gain, timebase, the trigger
// (level, slope, mode) and the display mode — never the source, the freeze or the cursors, so a preset never switches on
// the microphone or carries a measurement, and never holds audio. One file per user preset, `scope-<lowercased
// uuid>.json`, written as format-1 JSON with sorted keys (the pattern of Audio Odyssey's `JourneyPreset`); three
// read-only built-ins with fixed synthetic ids `00000000-0000-4000-8000-0000000008A1…A3`.
//
// Rules: the name is trimmed of whitespace and newlines and must then be 1…40 characters (duplicates are allowed;
// presets are told apart by id); the settings follow the rules of `ScopeState`. A file with a greater format is refused
// as `.newer(format)`; anything else that is not a valid format-1 preset (bad JSON, a missing key, an unknown index, a
// non-finite or out-of-range level, a non-finite save time, an invalid name or a built-in id) is refused as
// `.malformed`.
import Foundation
import VisualCoreAudioDSP

/// A named, versioned set of scope settings.
public struct ScopePreset: Codable, Sendable, Equatable, Identifiable {
    /// The file format written by ``fileData()``; greater formats are refused as `.newer`.
    public static let format = 1
    /// The most characters of a preset name after trimming.
    public static let nameLimit = 40

    /// The settings a preset holds: everything of ``ScopeState`` except the source, the freeze and the cursors.
    public struct Settings: Sendable, Equatable {
        /// The test waveform.
        public let waveform: TestSignal.Waveform
        /// The index into ``ScopeSettings/frequencies``.
        public let frequencyIndex: Int
        /// The index into ``ScopeSettings/gains``.
        public let gainIndex: Int
        /// The index into ``ScopeSettings/timebasesMilliseconds``.
        public let timebaseIndex: Int
        /// The trigger level in full scale: finite, in −1…1.
        public let triggerLevel: Double
        /// The trigger slope.
        public let triggerSlope: TriggerSlope
        /// The trigger mode.
        public let triggerMode: TriggerMode
        /// The display mode.
        public let display: ScopeDisplay

        /// Validated settings; `nil` when an index is outside its table or the trigger level is not finite and in
        /// −1…1 (the rules of ``ScopeState``).
        public init?(waveform: TestSignal.Waveform, frequencyIndex: Int, gainIndex: Int, timebaseIndex: Int,
                     triggerLevel: Double, triggerSlope: TriggerSlope, triggerMode: TriggerMode,
                     display: ScopeDisplay) {
            guard let state = ScopeState(source: .testSignal, waveform: waveform, frequencyIndex: frequencyIndex,
                                         gainIndex: gainIndex, timebaseIndex: timebaseIndex,
                                         triggerLevel: triggerLevel, triggerSlope: triggerSlope,
                                         triggerMode: triggerMode, display: display) else { return nil }
            self.init(of: state)
        }

        /// The settings of `state` (its source, freeze and cursors are left out).
        public init(of state: ScopeState) {
            waveform = state.waveform
            frequencyIndex = state.frequencyIndex
            gainIndex = state.gainIndex
            timebaseIndex = state.timebaseIndex
            triggerLevel = state.triggerLevel
            triggerSlope = state.triggerSlope
            triggerMode = state.triggerMode
            display = state.display
        }
    }

    /// The stable identifier, also part of the file name.
    public let id: UUID
    /// The trimmed name, 1…40 characters.
    public let name: String
    /// When the preset was saved.
    public let savedAt: Date
    /// The settings the preset applies.
    public let settings: Settings

    /// A preset; `nil` when the trimmed name is not 1…40 characters.
    /// - Parameters:
    ///   - id: The stable identifier.
    ///   - name: The name as typed; it is stored trimmed.
    ///   - savedAt: The save time.
    ///   - settings: The settings.
    public init?(id: UUID, name: String, savedAt: Date, settings: Settings) {
        guard let name = Self.validName(name) else { return nil }
        self.id = id
        self.name = name
        self.savedAt = savedAt
        self.settings = settings
    }

    /// A user preset of the settings of `state`; `nil` when the trimmed name is not 1…40 characters.
    /// - Parameters:
    ///   - state: The scope state to capture (its source, freeze and cursors are left out).
    ///   - name: The name as typed.
    ///   - id: The new preset's identifier.
    ///   - now: The save time.
    public static func from(state: ScopeState, name: String, id: UUID, now: Date) -> ScopePreset? {
        ScopePreset(id: id, name: name, savedAt: now, settings: Settings(of: state))
    }

    /// `name` trimmed of whitespace and newlines when the result is 1…40 characters, otherwise `nil`.
    public static func validName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= nameLimit else { return nil }
        return trimmed
    }

    /// Whether the preset is one of the read-only built-ins (its id is one of theirs).
    public var isBuiltIn: Bool { Self.builtInIDs.contains(id) }

    /// `state` with this preset's settings; the source, the freeze and the cursors of `state` are kept.
    public func applied(to state: ScopeState) -> ScopeState {
        var result = state
        result.select(settings.waveform)
        result.selectFrequency(settings.frequencyIndex)
        result.selectGain(settings.gainIndex)
        result.selectTimebase(settings.timebaseIndex)
        result.setTriggerLevel(settings.triggerLevel)
        result.select(settings.triggerSlope)
        result.select(settings.triggerMode)
        result.select(settings.display)
        return result
    }

    // MARK: - Built-ins

    /// The three read-only built-ins in list order (clarification 4), saved at the reference date: "Audio overview"
    /// (sine, 1 kHz, ×1, 1 ms/div, rising auto trigger at 0, waveform), "Bass detail" (sine, 100 Hz, ×2, 5 ms/div,
    /// rising auto at 0, waveform) and "Spectrum check" (sine, 1 kHz, ×1, 1 ms/div, rising auto at 0, spectrum); ids
    /// `00000000-0000-4000-8000-0000000008A1…A3`.
    public static let builtIns: [ScopePreset] = [
        builtIn("00000000-0000-4000-8000-0000000008A1", "Audio overview", frequency: 2, gain: 1, timebase: 3,
                display: .waveform),
        builtIn("00000000-0000-4000-8000-0000000008A2", "Bass detail", frequency: 0, gain: 2, timebase: 5,
                display: .waveform),
        builtIn("00000000-0000-4000-8000-0000000008A3", "Spectrum check", frequency: 2, gain: 1, timebase: 3,
                display: .spectrum),
    ]

    /// The ids of the built-ins.
    private static let builtInIDs: Set<UUID> = Set(builtIns.map(\.id))

    private static func builtIn(_ id: String, _ name: String, frequency: Int, gain: Int, timebase: Int,
                                display: ScopeDisplay) -> ScopePreset {
        guard let uuid = UUID(uuidString: id),
              let settings = Settings(waveform: .sine, frequencyIndex: frequency, gainIndex: gain,
                                      timebaseIndex: timebase, triggerLevel: 0, triggerSlope: .rising,
                                      triggerMode: .auto, display: display),
              let preset = ScopePreset(id: uuid, name: name, savedAt: Date(timeIntervalSinceReferenceDate: 0),
                                       settings: settings) else {
            preconditionFailure("built-in scope preset \(name) is invalid")
        }
        return preset
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case display, format, frequency, gain, id, level, mode, name, savedAt, slope, timebase, waveform
    }

    /// Decodes and validates a format-1 preset: refuses another format, an id that is not a UUID, a name that is not
    /// 1…40 characters after trimming, a non-finite save time, an unknown waveform, frequency, gain, timebase, slope,
    /// mode or display and a trigger level that is not finite and in −1…1.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let format = try c.decode(Int.self, forKey: .format)
        guard format == Self.format else {
            throw DecodingError.dataCorruptedError(forKey: .format, in: c, debugDescription: "format \(format)")
        }
        guard let id = UUID(uuidString: try c.decode(String.self, forKey: .id)) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "id is not a UUID")
        }
        let saved = try c.decode(Double.self, forKey: .savedAt)
        let name = try c.decode(String.self, forKey: .name)
        let waveform = try c.decode(Int.self, forKey: .waveform)
        let slope = try c.decode(Int.self, forKey: .slope)
        let mode = try c.decode(Int.self, forKey: .mode)
        let display = try c.decode(Int.self, forKey: .display)
        guard saved.isFinite,
              ScopeSettings.waveforms.indices.contains(waveform),
              ScopeSettings.slopes.indices.contains(slope),
              ScopeSettings.modes.indices.contains(mode),
              let knownDisplay = ScopeDisplay(rawValue: display),
              let settings = Settings(waveform: ScopeSettings.waveforms[waveform],
                                      frequencyIndex: try c.decode(Int.self, forKey: .frequency),
                                      gainIndex: try c.decode(Int.self, forKey: .gain),
                                      timebaseIndex: try c.decode(Int.self, forKey: .timebase),
                                      triggerLevel: try c.decode(Double.self, forKey: .level),
                                      triggerSlope: ScopeSettings.slopes[slope], triggerMode: ScopeSettings.modes[mode],
                                      display: knownDisplay),
              let preset = ScopePreset(id: id, name: name, savedAt: Date(timeIntervalSinceReferenceDate: saved),
                                       settings: settings) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                                                    debugDescription: "invalid scope preset settings or name"))
        }
        self = preset
    }

    /// Encodes the format-1 keys `display`, `format`, `frequency`, `gain`, `id`, `level`, `mode`, `name`, `savedAt`
    /// (seconds since 2001-01-01), `slope`, `timebase` and `waveform`; choices as their table indices or raw values.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(settings.display.rawValue, forKey: .display)
        try c.encode(Self.format, forKey: .format)
        try c.encode(settings.frequencyIndex, forKey: .frequency)
        try c.encode(settings.gainIndex, forKey: .gain)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(settings.triggerLevel, forKey: .level)
        try c.encode(ScopeSettings.index(of: settings.triggerMode), forKey: .mode)
        try c.encode(name, forKey: .name)
        try c.encode(savedAt.timeIntervalSinceReferenceDate, forKey: .savedAt)
        try c.encode(ScopeSettings.index(of: settings.triggerSlope), forKey: .slope)
        try c.encode(settings.timebaseIndex, forKey: .timebase)
        try c.encode(ScopeSettings.index(of: settings.waveform), forKey: .waveform)
    }

    // MARK: - Files

    /// Why a preset file was refused.
    public enum FileError: Error, Equatable {
        /// The file has a greater format than ``ScopePreset/format`` (the associated value); it is never rewritten.
        case newer(Int)
        /// The file cannot be read as a valid format-1 user preset.
        case malformed
    }

    private struct FormatProbe: Decodable {
        let format: Int
    }

    /// The preset as format-1 JSON with sorted keys.
    public func fileData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Decodes a preset file: a greater format is refused as `.newer(format)`; anything else that is not a valid
    /// format-1 preset, or that claims a built-in id, is refused as `.malformed`. The caller checks the id against the
    /// file name (``id(fromFileName:)``).
    public static func decode(_ data: Data) throws(FileError) -> ScopePreset {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(FormatProbe.self, from: data) else { throw .malformed }
        if probe.format > format { throw .newer(probe.format) }
        guard let preset = try? decoder.decode(ScopePreset.self, from: data), !preset.isBuiltIn else {
            throw .malformed
        }
        return preset
    }

    /// The file name of a preset: `scope-<lowercased uuid>.json`.
    public static func fileName(for id: UUID) -> String { "scope-\(id.uuidString.lowercased()).json" }

    /// The preset id encoded in a file name made by ``fileName(for:)``, or `nil` for any other name.
    public static func id(fromFileName fileName: String) -> UUID? {
        let prefix = "scope-"
        let suffix = ".json"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else { return nil }
        let core = fileName.dropFirst(prefix.count).dropLast(suffix.count)
        guard core.count == 36 else { return nil }
        return UUID(uuidString: String(core))
    }
}
