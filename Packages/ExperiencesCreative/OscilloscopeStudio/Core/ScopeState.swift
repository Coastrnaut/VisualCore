// ScopeState — feature 061 (A08-P01) T-A08-104 (FR-A08-111; clarifications 3–5; data-model "ScopeState", schema 1).
// The domain state of Oscilloscope Studio: the source, the test waveform and frequency, the gain, the timebase and the
// trigger (level, slope, mode). Every field is persisted and part of the digest; samples, windows and file URLs are
// never state.
//
// Rules: the frequency, gain and timebase indices point into the `ScopeSettings` tables; the trigger level is finite
// and in −1…1. The validating initialiser returns nil for a state that breaks a rule; a decoded payload that breaks one
// (an unknown source, waveform, index, slope or mode, a non-finite or out-of-range level) is refused with
// `DecodingError.dataCorrupted`; the mutating setters refuse such values, change nothing and return `false`.
//
// Feature 062 (A08-P02) T-A08-205 (FR-A08-211, FR-A08-212; data-model "ScopeState", schema 2): the display mode
// (waveform or XY) is a persisted field and part of the digest; a schema-1 payload (no `display` key) decodes with the
// waveform display, so stored A08-P01 states migrate unchanged.
// Feature 063 (A08-P03) T-A08-302 (FR-A08-304): `display` also accepts 2 (spectrum); the shape stays schema 2, so
// A08-P02 states restore unchanged.
import Foundation
import VisualCoreAudioDSP

/// The state of Oscilloscope Studio. Schema version 2.
public struct ScopeState: Sendable, Equatable, Codable {
    /// The schema version of the persisted fields.
    public static let currentSchema = 2

    /// The chosen signal source.
    public private(set) var source: ScopeSource
    /// The test waveform (used while the source is the test signal).
    public private(set) var waveform: TestSignal.Waveform
    /// The index of the test frequency in ``ScopeSettings/frequencies``.
    public private(set) var frequencyIndex: Int
    /// The index of the display gain in ``ScopeSettings/gains``.
    public private(set) var gainIndex: Int
    /// The index of the timebase in ``ScopeSettings/timebasesMilliseconds``.
    public private(set) var timebaseIndex: Int
    /// The trigger level in full scale: finite, in −1…1.
    public private(set) var triggerLevel: Double
    /// The trigger slope.
    public private(set) var triggerSlope: TriggerSlope
    /// The trigger mode.
    public private(set) var triggerMode: TriggerMode
    /// The display mode: waveform (the first choice) or XY.
    public private(set) var display: ScopeDisplay

    /// The first state: the 1 kHz sine test signal, gain ×1, 1 ms/div, a rising auto trigger at level 0, the waveform
    /// display.
    public static let initial = ScopeState()

    /// The first state (see ``initial``).
    public init() {
        source = .testSignal
        waveform = .sine
        frequencyIndex = ScopeSettings.defaultFrequencyIndex
        gainIndex = ScopeSettings.defaultGainIndex
        timebaseIndex = ScopeSettings.defaultTimebaseIndex
        triggerLevel = 0
        triggerSlope = .rising
        triggerMode = .auto
        display = .waveform
    }

    /// A validated state; `nil` when an index is outside its table or the trigger level is not finite and in −1…1.
    public init?(source: ScopeSource, waveform: TestSignal.Waveform, frequencyIndex: Int, gainIndex: Int,
                 timebaseIndex: Int, triggerLevel: Double, triggerSlope: TriggerSlope, triggerMode: TriggerMode,
                 display: ScopeDisplay = .waveform) {
        guard ScopeSettings.frequencies.indices.contains(frequencyIndex),
              ScopeSettings.gains.indices.contains(gainIndex),
              ScopeSettings.timebasesMilliseconds.indices.contains(timebaseIndex),
              Self.isUsableLevel(triggerLevel) else { return nil }
        self.source = source
        self.waveform = waveform
        self.frequencyIndex = frequencyIndex
        self.gainIndex = gainIndex
        self.timebaseIndex = timebaseIndex
        self.triggerLevel = triggerLevel == 0 ? 0 : triggerLevel   // −0 is stored as 0 (one digest text)
        self.triggerSlope = triggerSlope
        self.triggerMode = triggerMode
        self.display = display
    }

    /// Whether `level` is allowed as a trigger level: finite and in −1…1.
    public static func isUsableLevel(_ level: Double) -> Bool {
        level.isFinite && ScopeSettings.triggerLevelRange.contains(level)
    }

    // MARK: - Derived values

    /// The test frequency in hertz.
    public var frequency: Double { ScopeSettings.frequencies[frequencyIndex] }
    /// The display gain.
    public var gain: Double { ScopeSettings.gains[gainIndex] }
    /// The timebase in milliseconds per division.
    public var timebaseMilliseconds: Double { ScopeSettings.timebasesMilliseconds[timebaseIndex] }
    /// The timebase in seconds per division.
    public var secondsPerDivision: Double { timebaseMilliseconds / 1_000 }

    // MARK: - Mutation

    /// Selects the source.
    public mutating func select(_ source: ScopeSource) { self.source = source }

    /// Selects the test waveform.
    public mutating func select(_ waveform: TestSignal.Waveform) { self.waveform = waveform }

    /// Selects the trigger slope.
    public mutating func select(_ slope: TriggerSlope) { triggerSlope = slope }

    /// Selects the trigger mode.
    public mutating func select(_ mode: TriggerMode) { triggerMode = mode }

    /// Selects the display mode (both modes are valid in every state; a mono window in XY falls back in the
    /// presenter, not in the state).
    public mutating func select(_ display: ScopeDisplay) { self.display = display }

    /// Selects the display mode with the raw value `rawValue` (the `display.select` action value: 0 waveform, 1 XY,
    /// 2 spectrum); returns `false` and changes nothing when the value is unknown.
    @discardableResult
    public mutating func selectDisplay(_ rawValue: Int) -> Bool {
        guard let display = ScopeDisplay(rawValue: rawValue) else { return false }
        self.display = display
        return true
    }

    /// Selects the test frequency at `index`; returns `false` and changes nothing when the index is unknown.
    @discardableResult
    public mutating func selectFrequency(_ index: Int) -> Bool {
        guard ScopeSettings.frequencies.indices.contains(index) else { return false }
        frequencyIndex = index
        return true
    }

    /// Selects the gain at `index`; returns `false` and changes nothing when the index is unknown.
    @discardableResult
    public mutating func selectGain(_ index: Int) -> Bool {
        guard ScopeSettings.gains.indices.contains(index) else { return false }
        gainIndex = index
        return true
    }

    /// Selects the timebase at `index`; returns `false` and changes nothing when the index is unknown.
    @discardableResult
    public mutating func selectTimebase(_ index: Int) -> Bool {
        guard ScopeSettings.timebasesMilliseconds.indices.contains(index) else { return false }
        timebaseIndex = index
        return true
    }

    /// Sets the trigger level; returns `false` and changes nothing when it is not finite and in −1…1.
    @discardableResult
    public mutating func setTriggerLevel(_ level: Double) -> Bool {
        guard Self.isUsableLevel(level) else { return false }
        triggerLevel = level == 0 ? 0 : level
        return true
    }

    // MARK: - Digest

    /// The canonical text of every field for the experience digest: the indices of the source, waveform, frequency,
    /// gain, timebase, slope, mode and display, and the trigger level in Swift's shortest round-trip form.
    public var digestText: String {
        "a08.scope.v\(Self.currentSchema)|source=\(source.rawValue)|waveform=\(ScopeSettings.index(of: waveform))"
            + "|frequency=\(frequencyIndex)|gain=\(gainIndex)|timebase=\(timebaseIndex)|level=\(triggerLevel)"
            + "|slope=\(ScopeSettings.index(of: triggerSlope))|mode=\(ScopeSettings.index(of: triggerMode))"
            + "|display=\(display.rawValue)"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case source, waveform, frequency, gain, timebase, level, slope, mode, display
    }

    /// Decodes and validates a schema-2 state (or a schema-1 state, which has no `display` key and decodes with the
    /// waveform display); refuses an unknown source, waveform, frequency, gain, timebase, slope, mode or display value
    /// and a trigger level that is not finite and in −1…1.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let source = try c.decode(ScopeSource.self, forKey: .source)
        let waveform = try Self.decodeIndex(c, .waveform, into: ScopeSettings.waveforms)
        let slope = try Self.decodeIndex(c, .slope, into: ScopeSettings.slopes)
        let mode = try Self.decodeIndex(c, .mode, into: ScopeSettings.modes)
        let frequency = try c.decode(Int.self, forKey: .frequency)
        let gain = try c.decode(Int.self, forKey: .gain)
        let timebase = try c.decode(Int.self, forKey: .timebase)
        let level = try c.decode(Double.self, forKey: .level)
        let display: ScopeDisplay
        if let raw = try c.decodeIfPresent(Int.self, forKey: .display) {
            guard let known = ScopeDisplay(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(forKey: .display, in: c,
                                                       debugDescription: "unknown display \(raw)")
            }
            display = known
        } else {
            display = .waveform   // schema 1 (A08-P01) has no display field: migrate to the waveform view
        }
        guard Self.isUsableLevel(level) else {
            throw DecodingError.dataCorruptedError(forKey: .level, in: c,
                                                   debugDescription: "trigger level \(level) is not finite in −1…1")
        }
        guard let state = ScopeState(source: source, waveform: waveform, frequencyIndex: frequency, gainIndex: gain,
                                     timebaseIndex: timebase, triggerLevel: level, triggerSlope: slope,
                                     triggerMode: mode, display: display) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                                                    debugDescription: "unknown frequency \(frequency), gain \(gain) "
                                                        + "or timebase \(timebase) index"))
        }
        self = state
    }

    /// Encodes every schema-2 field: the source raw value, the table indices, the trigger level and the display raw
    /// value.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(source, forKey: .source)
        try c.encode(ScopeSettings.index(of: waveform), forKey: .waveform)
        try c.encode(frequencyIndex, forKey: .frequency)
        try c.encode(gainIndex, forKey: .gain)
        try c.encode(timebaseIndex, forKey: .timebase)
        try c.encode(triggerLevel, forKey: .level)
        try c.encode(ScopeSettings.index(of: triggerSlope), forKey: .slope)
        try c.encode(ScopeSettings.index(of: triggerMode), forKey: .mode)
        try c.encode(display.rawValue, forKey: .display)
    }

    /// The element of `table` at the index stored under `key`; refuses an index outside the table.
    private static func decodeIndex<T>(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys,
                                       into table: [T]) throws -> T {
        let index = try c.decode(Int.self, forKey: key)
        guard table.indices.contains(index) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: c,
                                                   debugDescription: "unknown \(key.stringValue) index \(index)")
        }
        return table[index]
    }
}
