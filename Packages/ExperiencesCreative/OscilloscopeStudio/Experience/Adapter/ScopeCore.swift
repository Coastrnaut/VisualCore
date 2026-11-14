// ScopeCore — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-111, FR-A08-121; clarification 5; contract
// "Experience actions"). The state of Oscilloscope Studio as an experience: a `ScopeState` (source, test waveform and
// frequency, gain, timebase, trigger level, slope and mode) and the preparation seed. Acquisition lives entirely in the
// presenter (the running source, its buffer and `ScopeAcquisition`), so a host step changes nothing in the state: the
// scope is a set of settings, not a simulation.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange` before the core sees it):
//   source.select [0…2]      test signal, file, microphone. A whole number is required; the presenter handles the
//                            microphone permission and the file picker before it sends the action (and falls back to
//                            the test signal when a restored microphone has no access).
//   signal.waveform [0…2]    sine, square, sweep (100 Hz → 10 kHz over 2 s).
//   signal.frequency [0…3]   100, 440, 1,000, 5,000 Hz.
//   gain.select [0…4]        ×0.5, ×1, ×2, ×5, ×10.
//   timebase.select [0…5]    0.1, 0.2, 0.5, 1, 2, 5 ms per division (ten divisions).
//   trigger.level [−1…1]     the trigger level in full scale (any finite value in range).
//   trigger.slope [0…1]      rising, falling.
//   trigger.mode [0…1]       auto, normal.
// A choice value that is not a whole number naming a table entry is refused with the rule `a08.invalid-choice`; a
// trigger level that is not finite in −1…1 with `a08.invalid-level` (the engine's range check catches it first; the
// rule keeps a direct call honest). A refusal changes nothing.
//
// No mirror actions: Reduce Motion changes nothing in a static trace, and the microphone permission stays with the
// presenter (the core never needs to refuse the microphone, because the presenter only sends `source.select 2` with
// access granted and sends `source.select 0` when a restored microphone selection has none).
//
// Snapshot schema 1 (A08-P01): `ScopeState` as JSON with sorted keys; the preparation seed comes from the snapshot
// envelope. One quality tier (`level-0`).
//
// Feature 062 (A08-P02) T-A08-206 (FR-A08-211, FR-A08-212; contract "Experience actions"): one more action.
//   display.select [0…1]     waveform, XY. A whole number is required (`a08.invalid-choice` otherwise). The core never
//                            refuses XY for a mono source: the choice is kept in the state (so snapshots stay
//                            deterministic) and the presenter draws the waveform with the mark "XY needs two channels"
//                            while the running source has one channel.
// Snapshot schema 2: `ScopeState` schema 2 (the eight A08-P01 keys plus `display`) as JSON with sorted keys. The step
// 1 → 2 adds `display` 0 (waveform), so a stored A08-P01 state restores unchanged with the waveform view.
// `schemaOneExample()` is the stored schema-1 payload the registry's migration check restores. The digest is
// `ScopeState.digestText` (`a08.scope.v2|…|display=…`).
//
// Feature 063 (A08-P03) T-A08-303 (FR-A08-304): `display.select [0…2]` — waveform, XY, spectrum. The range is derived
// from `ScopeDisplay.allCases`, so the spectrum view (raw value 2) is accepted without a schema change: the saved shape
// stays schema 2 and A08-P02 snapshots restore unchanged. The spectrum is drawn by the presenter (not triggered, not
// scaled by the gain); the core only keeps the choice.
import Foundation
import OscilloscopeStudioCore
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Oscilloscope Studio's refusals.
public enum ScopeRule {
    /// A choice value that is not a whole number naming an entry of the action's table.
    public static let invalidChoice = "a08.invalid-choice"
    /// A trigger level that is not finite and in −1…1.
    public static let invalidLevel = "a08.invalid-level"
    /// The microphone chosen while access is off: the presenter's answer (no action is sent, the previous source keeps
    /// running and the test signal is offered).
    public static let permissionDenied = "a08.permission-denied"
}

/// The state of Oscilloscope Studio. Schema version 2.
public struct ScopeCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a08.oscilloscope-studio"

    /// The outcome code: every state shows a configured scope (a source and a trigger are always chosen); the
    /// completion scenario checks it after a change of settings.
    public static let outcomeCode = "scope-configured"

    /// The action ids in declaration order.
    public static let actionIDs = ["source.select", "signal.waveform", "signal.frequency", "gain.select",
                                   "timebase.select", "trigger.level", "trigger.slope", "trigger.mode",
                                   "display.select"]

    /// The preparation seed; `reset()` returns to the first state (the seed does not change the scope's settings).
    public private(set) var preparationSeed: UInt64
    /// The domain state: source, waveform, frequency, gain, timebase, trigger and display mode.
    public internal(set) var state: ScopeState

    /// The first state (`ScopeState.initial`) prepared with `seed`.
    init(seed: UInt64, state: ScopeState = .initial) {
        preparationSeed = seed
        self.state = state
    }

    // MARK: Contract

    /// Schema 2; the step from schema 1 adds `"display": 0` (the waveform view).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 2, steps: [
            1: { payload in
                var upgraded = payload
                upgraded["display"] = ScopeDisplay.waveform.rawValue
                return upgraded
            },
        ])
    }

    /// The stored example of schema 1 for the registry's migration check (feature 062, T-A08-206): the feature 061
    /// payload (the eight A08-P01 keys, no `display`) of a scope on the square test signal at 440 Hz, gain ×2, 2 ms per
    /// division, a falling normal trigger at −0.25, with the digest its restore must give — the same scope with the
    /// waveform view. Nil only if the encoding failed.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let expected = ScopeState(source: .testSignal, waveform: .square, frequencyIndex: 1, gainIndex: 2,
                                        timebaseIndex: 4, triggerLevel: -0.25, triggerSlope: .falling,
                                        triggerMode: .normal, display: .waveform) else { return nil }
        let payload: [String: Any] = ["source": expected.source.rawValue,
                                      "waveform": ScopeSettings.index(of: expected.waveform),
                                      "frequency": expected.frequencyIndex, "gain": expected.gainIndex,
                                      "timebase": expected.timebaseIndex, "level": expected.triggerLevel,
                                      "slope": ScopeSettings.index(of: expected.triggerSlope),
                                      "mode": ScopeSettings.index(of: expected.triggerMode)]
        return example(version: 1, seed: seed, payload: payload, expected: expected)
    }

    /// A stored example of `version` with `payload` and the digest of a core prepared with `seed` holding `expected`.
    private static func example(version: Int, seed: UInt64, payload: [String: Any],
                                expected state: ScopeState) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID) else { return nil }
        let expected = ScopeCore(seed: seed, state: state)
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? expected.writeDigest(into: &builder)) != nil,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: version, seed: seed, stepIndex: 0,
                                                     digest: builder.finish(), payload: data),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: version, snapshot: encoded, expectedDigest: builder.finish().hex)
    }

    /// The nine controls with their declared ranges (the positions of the `ScopeSettings` tables and of
    /// `ScopeDisplay`).
    public static var controls: [ExperienceControl] {
        func last<T>(_ table: [T]) -> Double { Double(table.count - 1) }
        return [
            ExperienceControl(id: "source.select", ranges: [0...Double(ScopeSource.allCases.count - 1)]),
            ExperienceControl(id: "signal.waveform", ranges: [0...last(ScopeSettings.waveforms)]),
            ExperienceControl(id: "signal.frequency", ranges: [0...last(ScopeSettings.frequencies)]),
            ExperienceControl(id: "gain.select", ranges: [0...last(ScopeSettings.gains)]),
            ExperienceControl(id: "timebase.select", ranges: [0...last(ScopeSettings.timebasesMilliseconds)]),
            ExperienceControl(id: "trigger.level", ranges: [ScopeSettings.triggerLevelRange]),
            ExperienceControl(id: "trigger.slope", ranges: [0...last(ScopeSettings.slopes)]),
            ExperienceControl(id: "trigger.mode", ranges: [0...last(ScopeSettings.modes)]),
            ExperienceControl(id: "display.select", ranges: [0...Double(ScopeDisplay.allCases.count - 1)]),
        ]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> ScopeCore {
        try Task.checkCancellation()
        return ScopeCore(seed: seed)
    }

    /// Nothing: acquisition happens in the presenter, so a step leaves the state as it was.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (the engine checked the control, the value count, finiteness and ranges).
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard v.count == 1 else { return .rejected(.wrongValueCount(expected: 1, found: v.count)) }
        let x = v[0]
        switch action.control {
        case "source.select":
            guard let i = Self.choice(x, count: ScopeSource.allCases.count), let source = ScopeSource(rawValue: i) else {
                return .rejected(.rule(code: ScopeRule.invalidChoice))
            }
            state.select(source)
        case "signal.waveform":
            guard let i = Self.choice(x, count: ScopeSettings.waveforms.count) else {
                return .rejected(.rule(code: ScopeRule.invalidChoice))
            }
            state.select(ScopeSettings.waveforms[i])
        case "signal.frequency":
            guard let i = Self.choice(x, count: ScopeSettings.frequencies.count), state.selectFrequency(i) else {
                return .rejected(.rule(code: ScopeRule.invalidChoice))
            }
        case "gain.select":
            guard let i = Self.choice(x, count: ScopeSettings.gains.count), state.selectGain(i) else {
                return .rejected(.rule(code: ScopeRule.invalidChoice))
            }
        case "timebase.select":
            guard let i = Self.choice(x, count: ScopeSettings.timebasesMilliseconds.count), state.selectTimebase(i) else {
                return .rejected(.rule(code: ScopeRule.invalidChoice))
            }
        case "trigger.level":
            guard state.setTriggerLevel(x) else { return .rejected(.rule(code: ScopeRule.invalidLevel)) }
        case "trigger.slope":
            guard let i = Self.choice(x, count: ScopeSettings.slopes.count) else {
                return .rejected(.rule(code: ScopeRule.invalidChoice))
            }
            state.select(ScopeSettings.slopes[i])
        case "trigger.mode":
            guard let i = Self.choice(x, count: ScopeSettings.modes.count) else {
                return .rejected(.rule(code: ScopeRule.invalidChoice))
            }
            state.select(ScopeSettings.modes[i])
        case "display.select":
            guard let i = Self.choice(x, count: ScopeDisplay.allCases.count), state.selectDisplay(i) else {
                return .rejected(.rule(code: ScopeRule.invalidChoice))
            }
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// `scope-configured`, always (see ``outcomeCode``).
    public var outcome: ExperienceOutcome? { ExperienceOutcome(code: Self.outcomeCode) }

    /// Back to the first state (`ScopeState.initial`).
    public mutating func reset() {
        state = .initial
    }

    /// The canonical text of every field (`ScopeState.digestText`, `a08.scope.v2|…|display=…`).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(state.digestText)
    }

    /// The scope state (schema 2) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(state)
    }

    /// The core of a schema-2 payload (a schema-1 payload arrives migrated with `display` 0) with the envelope's `seed`
    /// as preparation seed; an unknown source, waveform, index, slope, mode or display, or a trigger level that is not
    /// finite in −1…1, is refused (the decoding throws).
    public static func restore(payload: Data, seed: UInt64) throws -> ScopeCore {
        ScopeCore(seed: seed, state: try JSONDecoder().decode(ScopeState.self, from: payload))
    }
}
