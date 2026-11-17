// AmbientCoreTests — feature 132 (A18-P02) T-A18-204 (FR-A18-201, FR-A18-208, FR-A18-209; SC-A18-201;
// contracts/experience.md "Actions"; data-model.md "AmbientCore"). The numbers-only core against the experience
// contract: every control accepted inside its declared ranges and refused outside them (by the engine and by the core
// itself), a refusal changes nothing, equal action lists give equal digests, the snapshot round trip of the format and
// theme fields (the instant and the revision are not stored), the outcome and the two quality levels.
import Foundation
import Testing
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience

/// One action: a control and its values.
private struct AmbientStep: Sendable {
    let control: String
    let values: [Double]
    init(_ control: String, _ values: [Double]) {
        self.control = control
        self.values = values
    }
}

/// Accepted actions, one or more per control, at the edges of the declared ranges.
private let acceptedSteps: [AmbientStep] = [
    AmbientStep("time.set", [0]), AmbientStep("time.set", [1_781_546_700]), AmbientStep("time.set", [4.1e9]),
    AmbientStep("time.changed", [0]), AmbientStep("time.changed", [2]), AmbientStep("time.changed", [4]),
    AmbientStep("clock.format", [0, 0, 0]), AmbientStep("clock.format", [1, 1, 0]),
    AmbientStep("clock.format", [2, 1, 1]),
    AmbientStep("theme.motion", [0]), AmbientStep("theme.motion", [1]),
    AmbientStep("theme.speed", [0.25]), AmbientStep("theme.speed", [1.5]), AmbientStep("theme.speed", [2]),
]

/// Refused actions: outside a declared range, not a whole index or not exactly 0 or 1.
private let refusedSteps: [AmbientStep] = [
    AmbientStep("time.set", [4.1e9 + 1]), AmbientStep("time.set", [-1]),
    AmbientStep("time.changed", [5]), AmbientStep("time.changed", [0.5]),
    AmbientStep("clock.format", [3, 0, 0]), AmbientStep("clock.format", [0, 2, 0]),
    AmbientStep("clock.format", [0, 0, 0.5]), AmbientStep("clock.format", [1.5, 0, 0]),
    AmbientStep("theme.motion", [0.5]),
    AmbientStep("theme.speed", [0.2]), AmbientStep("theme.speed", [2.5]),
]

/// The refused actions that are inside the declared ranges, so only the core refuses them (`a18.invalid-choice`).
private let invalidChoiceSteps: [AmbientStep] = [
    AmbientStep("time.changed", [0.5]), AmbientStep("clock.format", [0, 0, 0.5]),
    AmbientStep("clock.format", [1.5, 0, 0]), AmbientStep("theme.motion", [0.5]),
]

@MainActor
@Suite struct AmbientCoreTests {
    @Test func theControlsAreDeclaredInOrder() {
        let ids = AmbientCore.controls.map(\.id)
        #expect(ids == AmbientCore.actionIDs)
        #expect(ids == ["time.set", "time.changed", "clock.format", "theme.motion", "theme.speed", "theme.select",
                       "theme.palette", "night.mode", "night.window", "night.dim", "motion.reduce",
                       "screen.keepAwake"])
        #expect(AmbientCore.experienceID == "a18.ambient-clock")
    }

    @Test func everyControlIsAcceptedInsideItsRanges() async throws {
        for step in acceptedSteps {
            var engine = try await AmbientTest.engine()
            let result = engine.handle(control: step.control, values: step.values)
            #expect(result == .accepted, "\(step.control) \(step.values)")
        }
    }

    @Test func everyControlIsRefusedOutsideItsRangesAndARefusalChangesNothing() async throws {
        for step in refusedSteps {
            var engine = try await AmbientTest.engine()
            let before = try #require(engine.core)
            let digest = try engine.digest()
            let result = engine.handle(control: step.control, values: step.values)
            #expect(!result.isAccepted, "\(step.control) \(step.values)")
            let after = try #require(engine.core)
            #expect(after == before, "\(step.control) \(step.values)")
            #expect(try engine.digest() == digest, "\(step.control) \(step.values)")
        }
    }

    @Test func theCoreRefusesInvalidChoicesItself() {
        let invalid = ActionResult.rejected(.rule(code: AmbientRule.invalidChoice))
        for step in invalidChoiceSteps {
            let (next, result) = ambientApplied(AmbientCore(), step.control, step.values)
            #expect(result == invalid, "\(step.control) \(step.values)")
            #expect(next == AmbientCore(), "\(step.control) \(step.values)")
        }
        let (_, unknown) = ambientApplied(AmbientCore(), "time.speak", [0])
        #expect(!unknown.isAccepted)
        let (_, count) = ambientApplied(AmbientCore(), "clock.format", [0, 0])
        #expect(!count.isAccepted)
        let (_, nonFinite) = ambientApplied(AmbientCore(), "theme.speed", [.nan])
        #expect(!nonFinite.isAccepted)
        let (_, late) = ambientApplied(AmbientCore(), "time.set", [4.1e9 + 1])
        #expect(!late.isAccepted)
        let (_, slow) = ambientApplied(AmbientCore(), "theme.speed", [0.2])
        #expect(!slow.isAccepted)
    }

    @Test func acceptedActionsSetTheFields() {
        var core = AmbientCore()
        #expect(core.instant == 0 && core.hourCycle == 0 && !core.showSeconds && core.showDate)
        #expect(core.motion && core.speed == 1 && core.revision == 0 && core.date == nil)
        let steps = [AmbientStep("time.set", [1_781_546_700]), AmbientStep("clock.format", [2, 1, 0]),
                     AmbientStep("theme.motion", [0]), AmbientStep("theme.speed", [0.5]),
                     AmbientStep("time.changed", [2]), AmbientStep("time.changed", [0])]
        for step in steps {
            let (next, result) = ambientApplied(core, step.control, step.values)
            #expect(result == .accepted, "\(step.control)")
            core = next
        }
        #expect(core.instant == 1_781_546_700)
        #expect(core.date == Date(timeIntervalSince1970: 1_781_546_700))
        #expect(core.hourCycle == 2 && core.hourCycleValue == .h24)
        #expect(core.showSeconds && !core.showDate)
        #expect(!core.motion && core.speed == 0.5)
        #expect(core.revision == 2)
        #expect(core.preferences == ClockPreferences(hourCycle: .h24, showSeconds: true, showDate: false))
    }

    @Test func equalActionListsGiveEqualDigests() async throws {
        let steps = [AmbientStep("clock.format", [1, 1, 0]), AmbientStep("time.set", [1_781_546_700]),
                     AmbientStep("theme.speed", [1.75]), AmbientStep("time.changed", [2]),
                     AmbientStep("theme.motion", [0])]
        var first = try await AmbientTest.engine()
        var second = try await AmbientTest.engine()
        for step in steps {
            let a = first.handle(control: step.control, values: step.values)
            let b = second.handle(control: step.control, values: step.values)
            #expect(a == .accepted && b == .accepted, "\(step.control)")
        }
        #expect(try first.digest() == second.digest())
        #expect(first.core == second.core)
        // Another format gives another digest; the instant and the revision stay out of the digest.
        var other = try await AmbientTest.engine()
        let changed = other.handle(control: "clock.format", values: [2, 1, 0])
        #expect(changed == .accepted)
        #expect(try other.digest() != first.digest())
        let base = AmbientCore(hourCycle: 1, showSeconds: true, showDate: false, motion: false, speed: 1.75)
        let (timed, _) = ambientApplied(base, "time.set", [12_345])
        let (changedTime, _) = ambientApplied(timed, "time.changed", [3])
        #expect(try ambientDigest(changedTime) == ambientDigest(base))
        let (fast, _) = ambientApplied(base, "theme.speed", [2])
        #expect(try ambientDigest(fast) != ambientDigest(base))
    }

    @Test func theSnapshotRoundTripKeepsTheFormatAndThemeButNotTheInstant() throws {
        let base = AmbientCore(hourCycle: 2, showSeconds: true, showDate: false, motion: false, speed: 0.75)
        let (timed, _) = ambientApplied(base, "time.set", [1_781_546_700])
        let (core, _) = ambientApplied(timed, "time.changed", [2])
        #expect(core.revision == 1)
        let payload = try core.snapshotPayload()
        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(Set(object.keys) == AmbientFixtures.schemaThreeKeys)
        let restored = try AmbientCore.restore(payload: payload, seed: 1)
        #expect(restored.hourCycle == 2 && restored.showSeconds && !restored.showDate)
        #expect(!restored.motion && restored.speed == 0.75)
        #expect(restored.instant == 0 && restored.revision == 0)
        #expect(try ambientDigest(restored) == ambientDigest(core))
        #expect(try restored.snapshotPayload() == payload)
        #expect(AmbientCore.migrations.currentVersion == 3)
    }

    @Test func anEngineSnapshotRestoresIntoAnotherEngine() async throws {
        var source = try await AmbientTest.engine()
        let format = source.handle(control: "clock.format", values: [1, 0, 1])
        let speed = source.handle(control: "theme.speed", values: [1.25])
        #expect(format == .accepted && speed == .accepted)
        let snapshot = try source.snapshot()
        var target = try await AmbientTest.engine()
        try target.restore(snapshot)
        #expect(try target.digest() == source.digest())
        let core = try #require(target.core)
        #expect(core.hourCycle == 1 && !core.showSeconds && core.showDate && core.speed == 1.25)
    }

    @Test func aStoredValueOutsideItsRangeIsRefused() throws {
        let speed = Data(#"{"hourCycle":0,"motion":true,"palette":0,"showDate":true,"showSeconds":false,"speed":3,"theme":0}"#
            .utf8)
        #expect(throws: AmbientRestoreError.outOfRange("speed")) {
            _ = try AmbientCore.restore(payload: speed, seed: 1)
        }
        let cycle = Data(#"{"hourCycle":3,"motion":true,"palette":0,"showDate":true,"showSeconds":false,"speed":1,"theme":0}"#
            .utf8)
        #expect(throws: AmbientRestoreError.outOfRange("hourCycle")) {
            _ = try AmbientCore.restore(payload: cycle, seed: 1)
        }
    }

    @Test func theOutcomeIsShowingTimeOrMotionOff() {
        #expect(AmbientCore().outcome?.code == "showing-time")
        let (still, _) = ambientApplied(AmbientCore(), "theme.motion", [0])
        #expect(still.outcome?.code == "motion-off")
        let (moving, _) = ambientApplied(still, "theme.motion", [1])
        #expect(moving.outcome?.code == "showing-time")
    }

    @Test func theQualityProfileHasTwoLevelsWithFiveAndThreeOctaves() {
        #expect(AmbientCore.qualityTiers == 2)
        let levels = AmbientCore.qualityProfile.levels
        #expect(levels.count == 2)
        #expect(levels.map(\.name) == ["level-0", "level-1"])
        #expect(levels.map(\.resolutionShare) == [1, 0.5])
        #expect(levels.map(\.iterationShare) == [1, 0.6])
        #expect(AmbientCore.octaves(forTier: 0) == 5)
        #expect(AmbientCore.octaves(forTier: 1) == 3)
        #expect(AmbientCore.pixelBlock(forTier: 0) == 1)
        #expect(AmbientCore.pixelBlock(forTier: 1) == 2)
        var core = AmbientCore()
        core.setQualityTier(5)
        #expect(core.qualityTier == 1)
        #expect(core == AmbientCore())
    }
}
