// ScopeCoreTests — feature 061 (A08-P01) T-A08-105 (FR-A08-111, FR-A08-120; contract "Experience actions"). The
// adapter core of Oscilloscope Studio against the experience contract, short runs only (simulated steps, no wall
// clock): the id, the eight controls and schema 1; conformance over four seeds; the first state; every action accepted
// in range and changing the digest; values outside the declared range refused by the engine and values naming no
// choice refused by the core with `a08.invalid-choice` (`a08.invalid-level` for the level), a refusal leaving the
// digest as it was; host steps changing nothing; the snapshot round trip into another session; damaged payloads
// refused; and reset.
// Feature 062 (A08-P02) T-A08-206 (FR-A08-211, FR-A08-212): the ninth control `display.select [0…1]` accepted and
// changing the digest, refused out of range and fractional; schema 2 with the stored schema-1 snapshot restored through
// the engine with the waveform view, and `schemaOneExample()` passing the migration check.
// Feature 063 (A08-P03) T-A08-303 (FR-A08-304): `display.select [0…2]` (the spectrum view, raw value 2) accepted and
// changing the digest; 3 refused out of range, fractional values (1.5) refused as invalid choices; a payload with
// `display` 2 restores the spectrum view in the same schema 2, and `display` 3 is refused.
// Feature 064 (A08-P04) T-A08-403 (FR-A08-401–403, FR-A08-410, FR-A08-411): the seven new controls (`freeze.set`,
// `cursors.show`, `cursor.a`, `cursor.b`, `cursor.frequency`, `cursor.level`, `preset.apply`) accepted in range and
// changing the digest, refused out of range or as invalid choices, levels or presets (`a08.invalid-preset`); schema 3
// with a stored schema-2 snapshot restored with the freeze and cursor defaults; `schemaTwoExample()` passing the
// migration check; `preset.apply` 0…2 applying the built-ins (source, freeze and cursors kept) and 3 refused.
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudioDSP
import VisualCoreExperience

final class ScopeCoreTests: XCTestCase {
    private let scopeID = ExperienceID(rawValue: ScopeCore.experienceID)!

    private func makeEngine(seed: UInt64 = 7) async throws -> ExperienceEngine<ScopeCore> {
        var engine = ExperienceEngine<ScopeCore>(id: scopeID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    private func action(_ control: String, _ values: [Double]) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    func testIdControlsAndSchema() {
        XCTAssertEqual(ScopeCore.experienceID, "a08.oscilloscope-studio")
        XCTAssertEqual(OscilloscopeStudioExperience.id?.rawValue, "a08.oscilloscope-studio")
        XCTAssertEqual(ScopeCore.controls.map(\.id),
                       ["source.select", "signal.waveform", "signal.frequency", "gain.select", "timebase.select",
                        "trigger.level", "trigger.slope", "trigger.mode", "display.select", "freeze.set", "cursors.show",
                        "cursor.a", "cursor.b", "cursor.frequency", "cursor.level", "preset.apply"])
        XCTAssertEqual(ScopeCore.controls.map(\.id), ScopeCore.actionIDs)
        XCTAssertEqual(ScopeCore.controls.map { $0.ranges }, [[0...2], [0...2], [0...3], [0...4], [0...5], [-1...1],
                                                             [0...1], [0...1], [0...2], [0...1], [0...1], [0...1],
                                                             [0...1], [0...1], [-1...1], [0...2]])
        XCTAssertEqual(ScopeCore.migrations.currentVersion, 3)
        XCTAssertEqual(ScopeCore.qualityTiers, 3, "three quality levels since A08-P05")
    }

    func testConformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 12,
            actions: [ScriptedAction("signal.waveform", [1]), ScriptedAction("signal.frequency", [0]),
                      ScriptedAction("gain.select", [4]), ScriptedAction("timebase.select", [5]),
                      ScriptedAction("trigger.level", [-0.25]), ScriptedAction("trigger.slope", [1]),
                      ScriptedAction("trigger.mode", [1]), ScriptedAction("source.select", [2]),
                      ScriptedAction("source.select", [1]), ScriptedAction("signal.waveform", [2]),
                      ScriptedAction("display.select", [1]), ScriptedAction("display.select", [2]),
                      ScriptedAction("freeze.set", [1]), ScriptedAction("cursors.show", [1]),
                      ScriptedAction("cursor.a", [0.1]), ScriptedAction("cursor.b", [0.9]),
                      ScriptedAction("cursor.frequency", [0.3]), ScriptedAction("cursor.level", [-0.5]),
                      ScriptedAction("preset.apply", [1])],
            rejected: [ScriptedAction("source.select", [3]), ScriptedAction("source.select", [0.5]),
                       ScriptedAction("signal.waveform", [.nan]), ScriptedAction("signal.frequency", [4]),
                       ScriptedAction("gain.select", [-1]), ScriptedAction("timebase.select", [6]),
                       ScriptedAction("timebase.select", [2.5]), ScriptedAction("trigger.level", [1.5]),
                       ScriptedAction("trigger.slope", [2]), ScriptedAction("trigger.mode", [0.4]),
                       ScriptedAction("gain.select", []), ScriptedAction("display.select", [3]),
                       ScriptedAction("display.select", [0.5]), ScriptedAction("display.select", [1.5]),
                       ScriptedAction("freeze.set", [0.5]), ScriptedAction("freeze.set", [2]),
                       ScriptedAction("cursors.show", [0.25]), ScriptedAction("cursor.a", [1.5]),
                       ScriptedAction("cursor.b", [-0.1]), ScriptedAction("cursor.frequency", [.nan]),
                       ScriptedAction("cursor.level", [-1.5]), ScriptedAction("preset.apply", [3]),
                       ScriptedAction("preset.apply", [0.5]), ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(ScopeCore.self, id: scopeID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testTheFirstStateIsTheOneKilohertzSineAtOneMillisecondPerDivision() async throws {
        let engine = try await makeEngine(seed: 99)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.state, ScopeState.initial)
        XCTAssertEqual(core.state.source, .testSignal)
        XCTAssertEqual(core.state.waveform, .sine)
        XCTAssertEqual(core.state.frequency, 1_000)
        XCTAssertEqual(core.state.gain, 1)
        XCTAssertEqual(core.state.timebaseMilliseconds, 1)
        XCTAssertEqual(core.state.triggerLevel, 0)
        XCTAssertEqual(core.state.triggerSlope, .rising)
        XCTAssertEqual(core.state.triggerMode, .auto)
        XCTAssertEqual(core.state.display, .waveform)
        XCTAssertEqual(core.outcome?.code, ScopeCore.outcomeCode)
    }

    func testEveryActionIsAcceptedInRangeAndChangesTheDigest() async throws {
        var engine = try await makeEngine()
        let script: [(String, Double)] = [
            ("source.select", 2), ("source.select", 1), ("source.select", 0),
            ("signal.waveform", 1), ("signal.waveform", 2), ("signal.waveform", 0),
            ("signal.frequency", 0), ("signal.frequency", 1), ("signal.frequency", 3),
            ("gain.select", 0), ("gain.select", 2), ("gain.select", 3), ("gain.select", 4),
            ("timebase.select", 0), ("timebase.select", 1), ("timebase.select", 2), ("timebase.select", 4),
            ("timebase.select", 5),
            ("trigger.level", -1), ("trigger.level", 0.5), ("trigger.level", 1),
            ("trigger.slope", 1), ("trigger.slope", 0), ("trigger.mode", 1), ("trigger.mode", 0),
            ("display.select", 1), ("display.select", 0), ("display.select", 2), ("display.select", 1),
        ]
        for (control, value) in script {
            let before = try engine.digest()
            XCTAssertEqual(engine.handle(control: control, values: [value]), .accepted, "\(control) \(value)")
            XCTAssertNotEqual(try engine.digest(), before, "\(control) \(value) changes the digest")
        }
        let state = try XCTUnwrap(engine.core).state
        XCTAssertEqual(state.source, .testSignal)
        XCTAssertEqual(state.frequencyIndex, 3)
        XCTAssertEqual(state.gainIndex, 4)
        XCTAssertEqual(state.timebaseIndex, 5)
        XCTAssertEqual(state.triggerLevel, 1)
        XCTAssertEqual(state.display, .xy)
        // The value already chosen is accepted and changes nothing.
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "gain.select", values: [4]), .accepted)
        XCTAssertEqual(try engine.digest(), before)
    }

    func testRefusedValuesKeepTheDigestWithTheirReasons() async throws {
        var engine = try await makeEngine()
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "source.select", values: [3]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "display.select", values: [3]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "display.select", values: [1.5]),
                       .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "display.select", values: [-1]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "timebase.select", values: [-1]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "trigger.level", values: [1.01]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "trigger.level", values: [.infinity]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "gain.select", values: []),
                       .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(engine.handle(control: "bogus"), .rejected(.unknownControl("bogus")))
        for control in ["source.select", "signal.waveform", "signal.frequency", "gain.select", "timebase.select",
                        "trigger.slope", "trigger.mode", "display.select"] {
            XCTAssertEqual(engine.handle(control: control, values: [0.5]),
                           .rejected(.rule(code: ScopeRule.invalidChoice)), control)
        }
        XCTAssertEqual(try engine.digest(), before)

        // Called directly (without the engine's range check), the core refuses by its own rules.
        var core = try XCTUnwrap(engine.core)
        let original = core
        XCTAssertEqual(core.apply(action("source.select", [3])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("signal.frequency", [4])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("gain.select", [5])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("timebase.select", [6])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("trigger.slope", [-1])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("trigger.mode", [.nan])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("display.select", [3])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("display.select", [1.5])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("display.select", [0.25])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("trigger.level", [1.5])), .rejected(.rule(code: ScopeRule.invalidLevel)))
        XCTAssertEqual(core.apply(action("trigger.level", [.nan])), .rejected(.rule(code: ScopeRule.invalidLevel)))
        XCTAssertEqual(core.apply(action("bogus", [0])), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(core, original)
        XCTAssertTrue(ScopeRule.invalidChoice.hasPrefix("a08.") && ScopeRule.invalidLevel.hasPrefix("a08.")
                      && ScopeRule.permissionDenied.hasPrefix("a08."))
    }

    func testHostStepsChangeNothing() async throws {
        var engine = try await makeEngine()
        XCTAssertTrue(engine.handle(control: "trigger.level", values: [0.25]).isAccepted)
        let before = try engine.digest()
        let state = try XCTUnwrap(engine.core).state
        try engine.run(steps: 240)
        XCTAssertEqual(try engine.digest(), before)
        XCTAssertEqual(try XCTUnwrap(engine.core).state, state)
    }

    func testTheSnapshotRoundTripsIntoAnotherSession() async throws {
        var first = try await makeEngine(seed: 7)
        for (control, value) in [("source.select", 1.0), ("signal.waveform", 1), ("signal.frequency", 1),
                                 ("gain.select", 3), ("timebase.select", 5), ("trigger.level", -0.35),
                                 ("trigger.slope", 1), ("trigger.mode", 1), ("display.select", 1)] {
            XCTAssertTrue(first.handle(control: control, values: [value]).isAccepted)
        }
        let snapshot = try first.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 3)
        let decoded = try ExperienceSnapshot(data: snapshot.encoded())
        var second = try await makeEngine(seed: 3)
        try second.restore(decoded)
        XCTAssertEqual(try second.digest(), try first.digest())
        XCTAssertEqual(second.core?.state, first.core?.state)
        XCTAssertEqual(second.core?.state.triggerLevel, -0.35)
        XCTAssertEqual(second.core?.state.display, .xy)

        // The payload is the scope state as JSON with sorted keys.
        let payload = try XCTUnwrap(first.core).snapshotPayload()
        let text = try XCTUnwrap(String(data: payload, encoding: .utf8))
        XCTAssertEqual(text, #"{"cursorA":0.25,"cursorB":0.75,"cursorsShown":false,"display":1,"frequency":1,"frequencyCursor":0.5,"frozen":false,"gain":3,"level":-0.35,"levelCursor":0.5,"mode":1,"slope":1,"source":1,"timebase":5,"waveform":1}"#)
    }

    func testDamagedPayloadsAreRefused() throws {
        let damaged = [
            #"{"frequency":4,"gain":1,"level":0,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":0}"#,
            #"{"frequency":2,"gain":5,"level":0,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":0}"#,
            #"{"frequency":2,"gain":1,"level":2,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":0}"#,
            #"{"frequency":2,"gain":1,"level":0,"mode":2,"slope":0,"source":0,"timebase":3,"waveform":0}"#,
            #"{"frequency":2,"gain":1,"level":0,"mode":0,"slope":0,"source":3,"timebase":3,"waveform":0}"#,
            #"{"frequency":2,"gain":1,"level":0,"mode":0,"slope":0,"source":0,"timebase":6,"waveform":0}"#,
            #"{"frequency":2,"gain":1,"level":0,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":3}"#,
            #"{"frequency":2,"gain":1,"level":0,"mode":0,"source":0,"timebase":3,"waveform":0}"#,
            #"{"display":3,"frequency":2,"gain":1,"level":0,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":0}"#,
            #"{"display":-1,"frequency":2,"gain":1,"level":0,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":0}"#,
        ]
        for text in damaged {
            XCTAssertThrowsError(try ScopeCore.restore(payload: Data(text.utf8), seed: 7), text)
        }
        let good = #"{"frequency":2,"gain":1,"level":0,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":0}"#
        XCTAssertEqual(try ScopeCore.restore(payload: Data(good.utf8), seed: 7).state, ScopeState.initial)
        let xy = #"{"display":1,"frequency":2,"gain":1,"level":0,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":0}"#
        XCTAssertEqual(try ScopeCore.restore(payload: Data(xy.utf8), seed: 7).state.display, .xy)
        let spectrum = #"{"display":2,"frequency":2,"gain":1,"level":0,"mode":0,"slope":0,"source":0,"timebase":3,"waveform":0}"#
        XCTAssertEqual(try ScopeCore.restore(payload: Data(spectrum.utf8), seed: 7).state.display, .spectrum)
    }

    func testAStoredSchemaOneSnapshotRestoresWithTheWaveformView() async throws {
        // An A08-P01 snapshot: schema 1, the eight keys without `display`, restored through the engine.
        var first = try await makeEngine(seed: 7)
        let before = try first.digest()
        let stored = #"{"frequency":3,"gain":0,"level":0.5,"mode":1,"slope":1,"source":0,"timebase":1,"waveform":0}"#
        let snapshot = try ExperienceSnapshot(experience: scopeID, schemaVersion: 1, seed: 11, stepIndex: 0,
                                              digest: before, payload: Data(stored.utf8))
        var engine = try await makeEngine(seed: 3)
        try engine.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let state = try XCTUnwrap(engine.core).state
        XCTAssertEqual(state.display, .waveform, "schema 1 migrates to the waveform view")
        XCTAssertEqual(state.frequencyIndex, 3)
        XCTAssertEqual(state.gainIndex, 0)
        XCTAssertEqual(state.triggerLevel, 0.5)
        XCTAssertEqual(state.triggerSlope, .falling)
        XCTAssertEqual(state.triggerMode, .normal)
        XCTAssertEqual(state.timebaseIndex, 1)
        XCTAssertTrue(state.digestText.hasPrefix("a08.scope.v3|"))
        XCTAssertTrue(state.digestText.contains("|display=0|frozen=0|cursors=0|"))
        // The same settings chosen by actions give the same digest.
        for (control, value) in [("signal.frequency", 3.0), ("gain.select", 0), ("trigger.level", 0.5),
                                 ("trigger.slope", 1), ("trigger.mode", 1), ("timebase.select", 1)] {
            XCTAssertTrue(first.handle(control: control, values: [value]).isAccepted)
        }
        XCTAssertEqual(try engine.digest(), try first.digest())
        // Saved again, it is schema 3 with the display key.
        let resaved = try engine.snapshot()
        XCTAssertEqual(resaved.schemaVersion, 3)
        let payload = try XCTUnwrap(String(data: try XCTUnwrap(engine.core).snapshotPayload(), encoding: .utf8))
        XCTAssertTrue(payload.contains(#""display":0"#), payload)
    }

    func testTheSchemaOneExampleMigratesToTheWaveformView() async throws {
        let example = try XCTUnwrap(ScopeCore.schemaOneExample())
        XCTAssertEqual(example.version, 1)
        // The check wants one stored example per older version (1 and 2 since schema 3).
        let all = [ScopeCore.schemaOneExample(), ScopeCore.schemaTwoExample()].compactMap { $0 }
        let problems = await SnapshotMigrationCheck.problems(for: ScopeCore.self, id: scopeID, examples: all)
        XCTAssertEqual(problems, [])
        // The stored payload has no `display` key.
        let stored = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(stored.schemaVersion, 1)
        let object = try JSONSerialization.jsonObject(with: Data(stored.payload.utf8))
        let keys = try XCTUnwrap(object as? [String: Any]).keys.sorted()
        XCTAssertEqual(keys, ["frequency", "gain", "level", "mode", "slope", "source", "timebase", "waveform"])
        // Restored by an engine: the same scope with the waveform view and the expected digest.
        var engine = try await makeEngine(seed: 3)
        try engine.restore(stored)
        let state = try XCTUnwrap(engine.core).state
        XCTAssertEqual(state.display, .waveform)
        XCTAssertEqual(state.waveform, .square)
        XCTAssertEqual(state.triggerMode, .normal)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
    }

    func testTheFreezeAndCursorActionsAreAcceptedAndChangeTheDigest() async throws {
        var engine = try await makeEngine()
        let script: [(String, Double)] = [
            ("freeze.set", 1), ("cursors.show", 1), ("cursor.a", 0.1), ("cursor.b", 0.2), ("cursor.frequency", 0.75),
            ("cursor.level", -0.5), ("cursor.level", 1), ("freeze.set", 0), ("cursors.show", 0),
        ]
        for (control, value) in script {
            let before = try engine.digest()
            XCTAssertEqual(engine.handle(control: control, values: [value]), .accepted, "\(control) \(value)")
            XCTAssertNotEqual(try engine.digest(), before, "\(control) \(value) changes the digest")
        }
        let state = try XCTUnwrap(engine.core).state
        XCTAssertFalse(state.frozen)
        XCTAssertFalse(state.cursorsShown)
        XCTAssertEqual(state.cursorA, 0.1)
        XCTAssertEqual(state.cursorB, 0.2)
        XCTAssertEqual(state.frequencyCursor, 0.75)
        XCTAssertEqual(state.levelCursor, 1)

        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "freeze.set", values: [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "freeze.set", values: [0.5]), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "cursors.show", values: [0.5]),
                       .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "cursor.a", values: [1.5]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "cursor.level", values: [-1.01]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "cursor.b", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "preset.apply", values: [3]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "preset.apply", values: [1.5]),
                       .rejected(.rule(code: ScopeRule.invalidPreset)))
        XCTAssertEqual(try engine.digest(), before)

        // Called directly, the core refuses by its own rules.
        var core = try XCTUnwrap(engine.core)
        let original = core
        XCTAssertEqual(core.apply(action("freeze.set", [2])), .rejected(.rule(code: ScopeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("cursor.a", [.infinity])), .rejected(.rule(code: ScopeRule.invalidLevel)))
        XCTAssertEqual(core.apply(action("cursor.level", [.nan])), .rejected(.rule(code: ScopeRule.invalidLevel)))
        XCTAssertEqual(core.apply(action("preset.apply", [3])), .rejected(.rule(code: ScopeRule.invalidPreset)))
        XCTAssertEqual(core.apply(action("preset.apply", [-1])), .rejected(.rule(code: ScopeRule.invalidPreset)))
        XCTAssertEqual(core, original)
        XCTAssertTrue(ScopeRule.invalidPreset.hasPrefix("a08.") && ScopeRule.nothingToFreeze.hasPrefix("a08."))
    }

    func testPresetApplyAppliesTheBuiltInsAndKeepsSourceFreezeAndCursors() async throws {
        for (index, preset) in ScopePreset.builtIns.enumerated() {
            var engine = try await makeEngine()
            for (control, value) in [("source.select", 2.0), ("freeze.set", 1), ("cursors.show", 1),
                                     ("cursor.a", 0.4), ("gain.select", 4), ("signal.waveform", 1)] {
                XCTAssertTrue(engine.handle(control: control, values: [value]).isAccepted)
            }
            let before = try XCTUnwrap(engine.core).state
            XCTAssertEqual(engine.handle(control: "preset.apply", values: [Double(index)]), .accepted, preset.name)
            let state = try XCTUnwrap(engine.core).state
            XCTAssertEqual(state, preset.applied(to: before), preset.name)
            XCTAssertEqual(ScopePreset.Settings(of: state), preset.settings, preset.name)
            XCTAssertEqual(state.source, .microphone)
            XCTAssertTrue(state.frozen)
            XCTAssertTrue(state.cursorsShown)
            XCTAssertEqual(state.cursorA, 0.4)
        }
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "preset.apply", values: [3]), .rejected(.outOfRange(index: 0)))
    }

    func testAStoredSchemaTwoSnapshotRestoresWithTheFreezeAndCursorDefaults() async throws {
        let stored = #"{"display":2,"frequency":1,"gain":2,"level":-0.5,"mode":1,"slope":0,"source":0,"timebase":4,"waveform":1}"#
        let first = try await makeEngine(seed: 7)
        let snapshot = try ExperienceSnapshot(experience: scopeID, schemaVersion: 2, seed: 11, stepIndex: 0,
                                              digest: try first.digest(), payload: Data(stored.utf8))
        var engine = try await makeEngine(seed: 3)
        try engine.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let state = try XCTUnwrap(engine.core).state
        XCTAssertEqual(state.display, .spectrum)
        XCTAssertEqual(state.frequencyIndex, 1)
        XCTAssertEqual(state.gainIndex, 2)
        XCTAssertEqual(state.timebaseIndex, 4)
        XCTAssertEqual(state.triggerLevel, -0.5)
        XCTAssertFalse(state.frozen)
        XCTAssertFalse(state.cursorsShown)
        XCTAssertEqual(state.cursorA, 0.25)
        XCTAssertEqual(state.cursorB, 0.75)
        XCTAssertEqual(state.frequencyCursor, 0.5)
        XCTAssertEqual(state.levelCursor, 0.5)
        XCTAssertEqual(try engine.snapshot().schemaVersion, 3)
    }

    func testTheSchemaTwoExampleMigratesWithTheFreezeAndCursorDefaults() async throws {
        let example = try XCTUnwrap(ScopeCore.schemaTwoExample())
        XCTAssertEqual(example.version, 2)
        // The check wants one stored example per older version (1 and 2 since schema 3).
        let all = [ScopeCore.schemaOneExample(), ScopeCore.schemaTwoExample()].compactMap { $0 }
        let problems = await SnapshotMigrationCheck.problems(for: ScopeCore.self, id: scopeID, examples: all)
        XCTAssertEqual(problems, [])
        let stored = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(stored.schemaVersion, 2)
        let object = try JSONSerialization.jsonObject(with: Data(stored.payload.utf8))
        let keys = try XCTUnwrap(object as? [String: Any]).keys.sorted()
        XCTAssertEqual(keys, ["display", "frequency", "gain", "level", "mode", "slope", "source", "timebase",
                              "waveform"])
        var engine = try await makeEngine(seed: 3)
        try engine.restore(stored)
        let state = try XCTUnwrap(engine.core).state
        XCTAssertEqual(state.display, .spectrum)
        XCTAssertFalse(state.frozen)
        XCTAssertFalse(state.cursorsShown)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
    }

    func testResetReturnsToTheFirstState() async throws {
        var engine = try await makeEngine()
        let first = try engine.digest()
        XCTAssertTrue(engine.handle(control: "gain.select", values: [4]).isAccepted)
        XCTAssertTrue(engine.handle(control: "source.select", values: [2]).isAccepted)
        XCTAssertNotEqual(try engine.digest(), first)
        try engine.reset()
        XCTAssertEqual(try engine.digest(), first)
        XCTAssertEqual(engine.core?.state, ScopeState.initial)
    }
}
