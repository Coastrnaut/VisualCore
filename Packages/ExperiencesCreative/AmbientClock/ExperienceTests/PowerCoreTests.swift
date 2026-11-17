// PowerCoreTests — feature 134 (A18-P04) T-A18-405 (FR-A18-403, FR-A18-404, FR-A18-409; SC-A18-403; G-MOTION/
// G-FRAMERATE; clarifications Q1, Q2, Q5; contracts/power.md "Frame cap", "Snapshot"). The A18-P04 fields of the core
// and their effect on the session:
//   - every new control (`night.mode`, `night.window`, `night.dim`, `motion.reduce`, `screen.keepAwake`) is accepted
//     inside its declared range and refused outside it or as a fraction, a refusal changing nothing;
//   - the schema-1 and schema-2 examples migrate to schema 3 with the defaults (off, 1,320, 420, 0.5, off, off)
//     through an engine's restore; the schema-3 example round-trips with its digest;
//   - `motion.reduce [1]` makes two stills at frame times 1 and 7 identical and a `theme.select` a cut;
//   - a session of Ambient Clock paces at 30 frames per second (the value `FramePacing` gives for a declared 30 under
//     the conditions read, 30 at nominal heat with Low Power Mode off).
import Foundation
import Testing
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// One action of a new control.
private struct PowerStep: Sendable {
    let control: String
    let values: [Double]
    init(_ control: String, _ values: [Double]) {
        self.control = control
        self.values = values
    }
}

/// Accepted actions at the edges of the declared ranges.
private let acceptedPowerSteps: [PowerStep] = [
    PowerStep("night.mode", [0]), PowerStep("night.mode", [1]), PowerStep("night.mode", [2]),
    PowerStep("night.window", [0, 0]), PowerStep("night.window", [1439, 1439]), PowerStep("night.window", [1320, 420]),
    PowerStep("night.window", [780, 840]),
    PowerStep("night.dim", [0.3]), PowerStep("night.dim", [0.5]), PowerStep("night.dim", [1]),
    PowerStep("motion.reduce", [0]), PowerStep("motion.reduce", [1]),
    PowerStep("screen.keepAwake", [0]), PowerStep("screen.keepAwake", [1]),
]

/// Refused actions: outside a declared range, a fraction, not exactly 0 or 1, or a wrong value count.
private let refusedPowerSteps: [PowerStep] = [
    PowerStep("night.mode", [3]), PowerStep("night.mode", [-1]), PowerStep("night.mode", [1.5]),
    PowerStep("night.window", [1440, 0]), PowerStep("night.window", [0, 1440]), PowerStep("night.window", [-1, 0]),
    PowerStep("night.window", [10.5, 0]), PowerStep("night.window", [0, 20.5]), PowerStep("night.window", [0]),
    PowerStep("night.dim", [0.29]), PowerStep("night.dim", [1.01]), PowerStep("night.dim", [0]),
    PowerStep("motion.reduce", [0.5]), PowerStep("motion.reduce", [2]), PowerStep("motion.reduce", [-1]),
    PowerStep("screen.keepAwake", [0.5]), PowerStep("screen.keepAwake", [2]), PowerStep("screen.keepAwake", [-1]),
]

/// The refused actions inside the declared ranges, which only the core refuses (`a18.invalid-choice`).
private let invalidPowerChoices: [PowerStep] = [
    PowerStep("night.mode", [1.5]), PowerStep("night.window", [10.5, 0]), PowerStep("night.window", [0, 20.5]),
    PowerStep("motion.reduce", [0.5]), PowerStep("screen.keepAwake", [0.5]),
]

@MainActor
@Suite(.serialized) struct PowerCoreTests {
    @Test func everyNewControlIsAcceptedInsideItsRange() async throws {
        for step in acceptedPowerSteps {
            var engine = try await AmbientTest.engine()
            let result = engine.handle(control: step.control, values: step.values)
            #expect(result == .accepted, "\(step.control) \(step.values)")
        }
        let (core, _) = ambientApplied(AmbientCore(), "night.window", [1290, 375])
        #expect(core.nightStart == 1290 && core.nightEnd == 375)
        let (dimmed, _) = ambientApplied(core, "night.dim", [0.4])
        #expect(dimmed.nightDim == 0.4)
        let (still, _) = ambientApplied(dimmed, "motion.reduce", [1])
        let (awake, _) = ambientApplied(still, "screen.keepAwake", [1])
        let (night, _) = ambientApplied(awake, "night.mode", [1])
        #expect(night.reduceMotion && night.keepAwake && night.nightMode == 1)
        #expect(night.outcome?.code == AmbientCore.nightOnCode)
        #expect(try ambientDigest(night) != ambientDigest(AmbientCore()))
    }

    @Test func everyNewControlIsRefusedOutsideItsRangeAndARefusalChangesNothing() async throws {
        for step in refusedPowerSteps {
            var engine = try await AmbientTest.engine()
            let before = try #require(engine.core)
            let digest = try engine.digest()
            let result = engine.handle(control: step.control, values: step.values)
            #expect(!result.isAccepted, "\(step.control) \(step.values)")
            #expect(engine.core == before, "\(step.control) \(step.values)")
            #expect(try engine.digest() == digest, "\(step.control) \(step.values)")
        }
        let invalid = ActionResult.rejected(.rule(code: AmbientRule.invalidChoice))
        for step in invalidPowerChoices {
            let (next, result) = ambientApplied(AmbientCore(), step.control, step.values)
            #expect(result == invalid, "\(step.control) \(step.values)")
            #expect(next == AmbientCore(), "\(step.control) \(step.values)")
        }
        let (_, nonFinite) = ambientApplied(AmbientCore(), "night.dim", [.nan])
        #expect(!nonFinite.isAccepted)
    }

    @Test func theEarlierExamplesMigrateToSchemaThreeWithTheDefaults() async throws {
        let examples = [try #require(AmbientCore.schemaOneExample()), try #require(AmbientCore.schemaTwoExample())]
        let themes = [(0, 0), (2, 1)]
        for (index, example) in examples.enumerated() {
            let snapshot = try ExperienceSnapshot(data: example.snapshot)
            #expect(snapshot.schemaVersion == index + 1)
            var engine = try await AmbientTest.engine(seed: snapshot.seed)
            try engine.restore(snapshot)
            let core = try #require(engine.core)
            #expect(core.nightMode == 0, "schema \(index + 1)")
            #expect(core.nightStart == 1320 && core.nightEnd == 420, "schema \(index + 1)")
            #expect(core.nightDim == 0.5, "schema \(index + 1)")
            #expect(!core.reduceMotion && !core.keepAwake, "schema \(index + 1)")
            #expect(core.theme == themes[index].0 && core.palette == themes[index].1, "schema \(index + 1)")
            #expect(core.hourCycle == 2 && core.showSeconds && !core.showDate && core.speed == 1.5)
            #expect(try engine.digest().hex == example.expectedDigest, "schema \(index + 1)")
            let written = try engine.snapshot()
            #expect(written.schemaVersion == 3, "schema \(index + 1)")
            let object = try #require(try JSONSerialization.jsonObject(with: Data(written.payload.utf8))
                as? [String: Any])
            #expect(Set(object.keys) == AmbientFixtures.schemaThreeKeys, "schema \(index + 1)")
        }
    }

    @Test func theSchemaThreeExampleRoundTrips() async throws {
        let three = try #require(AmbientCore.schemaThreeExample())
        let snapshot = try ExperienceSnapshot(data: three.snapshot)
        #expect(snapshot.schemaVersion == 3)
        var first = try await AmbientTest.engine(seed: snapshot.seed)
        try first.restore(snapshot)
        let core = try #require(first.core)
        #expect(core.nightMode == 1 && core.nightStart == 1290 && core.nightEnd == 375 && core.nightDim == 0.4)
        #expect(core.reduceMotion && core.keepAwake)
        #expect(core.theme == 2 && core.palette == 1)
        #expect(try first.digest().hex == three.expectedDigest)
        let again = try first.snapshot()
        var second = try await AmbientTest.engine(seed: snapshot.seed)
        try second.restore(again)
        #expect(second.core == first.core)
        #expect(try second.digest() == first.digest())
        let payload = try core.snapshotPayload()
        let restored = try AmbientCore.restore(payload: payload, seed: 1)
        #expect(try restored.snapshotPayload() == payload)
        #expect(restored == core)
        // A stored value outside its range is refused.
        let cases: [(String, Any)] = [("nightMode", 3), ("nightStart", 1440), ("nightEnd", -1), ("nightDim", 0.2)]
        for (key, value) in cases {
            var object = try #require(AmbientCore.schemaExamplePayload(version: 3))
            object[key] = value
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            #expect(throws: AmbientRestoreError.outOfRange(key)) {
                _ = try AmbientCore.restore(payload: data, seed: 1)
            }
        }
    }

    @Test func inAppReducedMotionStillsTheThemeAndCutsAThemeChange() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        #expect(!shell.presenter.effectiveReduceMotion)
        let moving = try AmbientTest.still(session, time: 1)
        let movingLater = try AmbientTest.still(session, time: 7)
        #expect(AmbientTest.differingPixels(moving.rgba, movingLater.rgba) > 0, "motion on: the frames differ")
        let reduce = shell.handle(control: "motion.reduce", values: [1])
        #expect(reduce == .accepted)
        let early = try AmbientTest.still(session, time: 1)
        #expect(shell.presenter.effectiveReduceMotion)
        #expect(shell.presenter.lastUniformTime == 0)
        #expect(shell.presenter.currentDrift == .zero, "no drift under reduced motion")
        let late = try AmbientTest.still(session, time: 7)
        #expect(AmbientTest.differingPixels(early.rgba, late.rgba) == 0)
        #expect(early == late)
        let core = try AmbientTest.core(shell)
        #expect(core.motion, "reduced motion stills the background without turning motion off")
        let chosen = shell.handle(control: "theme.select", values: [2])
        #expect(chosen == .accepted)
        _ = try AmbientTest.still(session, time: 8)
        #expect(shell.presenter.shownTheme == 2)
        #expect(shell.presenter.fadeProgress == 1, "a cut")
        #expect(shell.presenter.fadeStart == nil)
        #expect(shell.presenter.drawCount == 1)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func aSessionOfAmbientClockPacesAtThirtyFramesPerSecond() async throws {
        let shell = AmbientClockExperience.make(id: AmbientTest.id, clock: FixedClock(AmbientFixtures.instant))
        #expect(shell.presenter.maxFramesPerSecond == 30)
        #expect(shell.maxFramesPerSecond == 30)
        let session = ExperienceSession()
        let opened = try await AmbientTest.open(session)
        #expect(opened.presenter.maxFramesPerSecond == 30)
        let host = try #require(session.renderHost)
        let info = ProcessInfo.processInfo
        let thermal = FramePacing.Thermal(rawValue: info.thermalState.rawValue) ?? .nominal
        let lowPower = info.isLowPowerModeEnabled
        let expected = FramePacing(thermal: thermal, lowPower: lowPower, requestedMaxFPS: 30).maxFPS
        #expect(host.framePacing.maxFPS == expected)
        if thermal == .nominal && !lowPower { #expect(host.framePacing.maxFPS == 30) }
        #expect(expected == FramePacing.minimumFPS, "a declared 30 stays at the floor under every condition")
        session.close()
    }
}
