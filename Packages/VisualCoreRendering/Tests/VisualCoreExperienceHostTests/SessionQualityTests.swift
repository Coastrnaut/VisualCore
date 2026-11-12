// SessionQualityTests — feature 192 T-U06-017 (UA-F06; US2; FR-U06-010 to FR-U06-014; SC-U06-003). The quality
// level of the open experience as `ExperienceSession` decides it: a pinned level is applied before the first
// frame and after a retry, a pin beyond the profile means the last level, the automatic level follows scripted
// device conditions through `refreshQuality(now:)` (one step down per 2 s, one step up per 10 s of calm, Low
// Power Mode holds level 1), no decision is taken while suspended and the calm period starts again after a
// resume, a changed pin applies at once, and no level change touches the state digest.
// The helpers (`sampleRequest`, `SampleProbe`, `layOut`, `drawFrame`, …) are in SessionOpenCloseTests.swift.
//
// Timing: at every open the session takes one decision with its own clock (seconds since the session was
// created, far below 1 here). The scripted times of these tests therefore start at 10 and only increase. The
// tests that script the automatic level never lay the host out: without a surface no frame is drawn, so the
// session's frame hook takes no decision with the real clock between two scripted ones.
import XCTest
import VisualCoreDiagnostics
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

/// The device conditions a test scripts; the session's `conditions` closure reads them at every decision.
@MainActor
private final class ScriptedConditions {
    var value: DeviceConditions
    /// How often the session asked for the conditions.
    private(set) var reads = 0

    init(_ value: DeviceConditions = .nominal) { self.value = value }

    func read() -> DeviceConditions {
        reads += 1
        return value
    }
}

/// A flag a test flips between two factory calls of one request (the cause of a failure is removed).
@MainActor
private final class Flag {
    var isOn: Bool
    init(_ isOn: Bool) { self.isOn = isOn }
}

@MainActor
final class SessionQualityTests: XCTestCase {
    // MARK: Helpers

    private static let serious = DeviceConditions(thermal: .serious, lowPower: false)
    private static let lowPower = DeviceConditions(thermal: .nominal, lowPower: true)

    /// A session that reads its device conditions from `script`.
    private func scriptedSession(_ script: ScriptedConditions) -> ExperienceSession {
        let session = ExperienceSession()
        session.conditions = { script.read() }
        return session
    }

    /// Checks that the session's level and the tier the experience really has are both `level`.
    private func assertLevel(_ session: ExperienceSession, _ level: Int, _ note: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let sessionLevel = session.qualityLevel
        let tier = session.experience?.diagnostics.qualityTier
        XCTAssertEqual(sessionLevel, level, "session level: \(note)", file: file, line: line)
        XCTAssertEqual(tier, level, "tier of the experience: \(note)", file: file, line: line)
    }

    /// Opens the sample with `seed` under nominal conditions, sets each pin of `pins` in turn (none: the level
    /// is never touched) and draws `frames` frames in total, spread evenly over the pins. Returns the digest
    /// and the step index after the last frame. The session is closed before the function returns.
    private func digestAfterFrames(
        seed: UInt64, pins: [Int], frames: Int, file: StaticString = #filePath, line: UInt = #line
    ) async throws -> (digest: StateDigest, steps: Int) {
        let session = scriptedSession(ScriptedConditions(.nominal))
        defer { session.close() }
        let (request, probe) = sampleRequest(seed: seed)
        let result = await session.open(request)
        XCTAssertEqual(result, .running, file: file, line: line)
        layOut(session)
        if pins.isEmpty {
            for _ in 0..<frames {
                let drawn = drawFrame(session)
                XCTAssertTrue(drawn, file: file, line: line)
            }
            let level = session.qualityLevel
            XCTAssertEqual(level, 0, "nominal conditions keep the automatic level 0", file: file, line: line)
        } else {
            let perPin = frames / pins.count
            XCTAssertEqual(perPin * pins.count, frames, "the frames divide evenly", file: file, line: line)
            for pin in pins {
                session.qualityPin = pin
                let level = session.qualityLevel
                XCTAssertEqual(level, pin, file: file, line: line)
                for _ in 0..<perPin {
                    let drawn = drawFrame(session)
                    XCTAssertTrue(drawn, file: file, line: line)
                }
                let drawnTier = probe.presenter?.lastTier
                XCTAssertEqual(drawnTier, pin, "the frames were drawn with the pinned tier", file: file, line: line)
            }
        }
        let digest = try probe.digest()
        return (digest, probe.stepIndex)
    }

    // MARK: Pinned level (FR-U06-013)

    func testAPinnedLevelIsAppliedBeforeTheFirstFrame() async throws {
        let session = scriptedSession(ScriptedConditions(.nominal))
        defer { session.close() }
        session.qualityPin = 2
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        assertLevel(session, 2, "the pin holds right after the open")

        // The sample presenter records the tier of every `draw` (`lastTier`). The session's host has no surface
        // until the test lays it out, so the frame drawn below is the first frame that reaches the presenter;
        // the level was applied before the host existed, so no frame can have had another tier.
        layOut(session)
        let drawn = drawFrame(session)
        XCTAssertTrue(drawn)
        let drawCalls = probe.presenter?.drawCalls ?? 0
        let drawnTier = probe.presenter?.lastTier
        XCTAssertGreaterThanOrEqual(drawCalls, 1)
        XCTAssertEqual(drawnTier, 2, "the first drawn frame had the pinned tier")
        assertLevel(session, 2, "the pin holds after a frame")
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    func testAPinBeyondTheProfileGivesTheLastLevel() async throws {
        let session = scriptedSession(ScriptedConditions(.nominal))
        defer { session.close() }
        session.qualityPin = 7
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        let levels = session.experience?.qualityProfile.count
        XCTAssertEqual(levels, 3, "the sample declares three levels")
        assertLevel(session, 2, "pin 7 of three levels is the last level")
        XCTAssertEqual(session.qualityPin, 7, "the pin itself is kept as given")
    }

    // MARK: Automatic level (FR-U06-010, FR-U06-011)

    func testTheAutomaticLevelStepsDownWhileHotAndUpAfterCalm() async throws {
        let script = ScriptedConditions(Self.serious)
        let session = scriptedSession(script)
        defer { session.close() }
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        XCTAssertGreaterThanOrEqual(script.reads, 1, "the open read the scripted conditions")

        // Open decision at t0 (below 1 s): hot, no change yet, so one step down: 0 → 1; last change = t0.
        assertLevel(session, 1, "one step down at the open decision")

        // t = 10: hot; 10 − t0 ≥ 2 s (decision interval), so one more step: 1 → 2; last change = 10.
        session.refreshQuality(now: 10)
        assertLevel(session, 2, "second step down")

        // t = 12: hot and the interval passed, but 2 is the last of three levels: it stays.
        session.refreshQuality(now: 12)
        assertLevel(session, 2, "the last level is the floor")

        // t = 14: first calm decision; the calm period starts at 14, no step.
        script.value = .nominal
        session.refreshQuality(now: 14)
        assertLevel(session, 2, "calm begins, no step yet")

        // t = 23: 9 s of calm < 10 s (calm period): no step.
        session.refreshQuality(now: 23)
        assertLevel(session, 2, "9 s of calm are not enough")

        // t = 24: 10 s of calm and 24 − 10 ≥ 2 s since the last change: 2 → 1; calm starts again at 24.
        session.refreshQuality(now: 24)
        assertLevel(session, 1, "one step up after 10 s of calm")

        // t = 33: 9 s since the step up: no step.
        session.refreshQuality(now: 33)
        assertLevel(session, 1, "the calm period started again at the step up")

        // t = 34: 10 s since the step up: 1 → 0.
        session.refreshQuality(now: 34)
        assertLevel(session, 0, "another step up after 10 more seconds")

        // t = 50: level 0 is the best: nothing left to step.
        session.refreshQuality(now: 50)
        assertLevel(session, 0, "the best level stays")
        XCTAssertEqual(session.state, .running)
    }

    func testLowPowerModeHoldsLevelOneAndDoesNotRecoverWhileItIsOn() async throws {
        let script = ScriptedConditions(Self.lowPower)
        let session = scriptedSession(script)
        defer { session.close() }
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)

        // Open decision: Low Power Mode with level 0 better than the ceiling 1 (min(1, 3 − 1)): 0 → 1.
        assertLevel(session, 1, "Low Power Mode steps to level 1 at the open decision")

        // t = 10, 30, 60: Low Power Mode with the level at the ceiling: no step down (not hot, not better than
        // the ceiling) and no calm (Low Power Mode is never calm), however long it lasts.
        for time in [10.0, 30, 60] {
            session.refreshQuality(now: time)
            assertLevel(session, 1, "Low Power Mode at t = \(time)")
        }

        // Low Power Mode off. t = 70: the calm period starts. t = 79: 9 s, no step. t = 80: 10 s: 1 → 0.
        script.value = .nominal
        session.refreshQuality(now: 70)
        assertLevel(session, 1, "calm begins when Low Power Mode ends")
        session.refreshQuality(now: 79)
        assertLevel(session, 1, "9 s of calm are not enough")
        session.refreshQuality(now: 80)
        assertLevel(session, 0, "recovery 10 s after Low Power Mode ended")
    }

    // MARK: Suspension (FR-U06-012)

    func testNoDecisionIsTakenWhileSuspendedAndTheCalmPeriodStartsAgainAfterTheResume() async throws {
        let script = ScriptedConditions(Self.serious)
        let session = scriptedSession(script)
        defer { session.close() }
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        // Open decision: hot: 0 → 1 (as in the test of the automatic level).
        assertLevel(session, 1, "one step down before the suspension")

        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        let readsAtSuspension = script.reads

        // Still hot at t = 10: a decision would step 1 → 2 (10 − t0 ≥ 2 s). None is taken while suspended.
        session.refreshQuality(now: 10)
        assertLevel(session, 1, "no step down while suspended")
        // Calm at t = 40: a decision would start the calm period here. None is taken.
        script.value = .nominal
        session.refreshQuality(now: 40)
        assertLevel(session, 1, "no decision while suspended")
        XCTAssertEqual(script.reads, readsAtSuspension, "the conditions were not even read while suspended")

        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        assertLevel(session, 1, "the resume keeps the level")

        // The resume forgot the timing. t = 100: the first decision after the resume starts the calm period
        // at 100; the time away (and the refused calls at 10 and 40) count for nothing, so no step.
        session.refreshQuality(now: 100)
        assertLevel(session, 1, "the time away is not calm time")

        // t = 109: 9 s after the first decision following the resume: no step.
        session.refreshQuality(now: 109)
        assertLevel(session, 1, "9 s of calm after the resume are not enough")

        // t = 110: 10 s of calm; the decision interval was forgotten too, so the step is allowed: 1 → 0.
        session.refreshQuality(now: 110)
        assertLevel(session, 0, "one step up 10 s after the first decision following the resume")
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    // MARK: Changing the pin (FR-U06-013)

    func testChangingThePinWhileAnExperienceRunsAppliesAtOnce() async throws {
        let session = scriptedSession(ScriptedConditions(.nominal))
        defer { session.close() }
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        assertLevel(session, 0, "automatic under nominal conditions")
        let drawsBefore = probe.presenter?.drawCalls ?? -1

        // nil → 2: applied by the setter itself; no frame and no `refreshQuality` in between.
        session.qualityPin = 2
        assertLevel(session, 2, "the pin applies at once")
        let drawsAfter = probe.presenter?.drawCalls ?? -2
        XCTAssertEqual(drawsAfter, drawsBefore, "no frame was needed")

        // The same pin again changes nothing; a decision with a pin changes nothing either.
        session.qualityPin = 2
        session.refreshQuality(now: 10)
        assertLevel(session, 2, "the pin holds")

        // 2 → 1: at once.
        session.qualityPin = 1
        assertLevel(session, 1, "a changed pin applies at once")

        // 1 → nil: back to automatic, which starts again from level 0 with its timing forgotten.
        session.qualityPin = nil
        assertLevel(session, 0, "automatic starts again from level 0")
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.makes, 1, "the same experience all along")
    }

    // MARK: Retry (FR-U06-013)

    func testThePinnedLevelIsAppliedToTheRetriedExperience() async throws {
        let session = scriptedSession(ScriptedConditions(.nominal))
        defer { session.close() }
        session.qualityPin = 2
        // The way SessionFailureTests builds a request that fails until the cause is removed: the presenter
        // throws in `setup` while the flag is on.
        let broken = Flag(true)
        let (request, probe) = sampleRequest(seed: 1_000, configure: { $0.failsInSetup = broken.isOn })
        let first = await session.open(request)
        guard case .failed = first else { return XCTFail("got \(first)") }
        XCTAssertEqual(session.state, .failed)
        let levelWhenFailed = session.qualityLevel
        XCTAssertEqual(levelWhenFailed, 0, "a failed session has no experience and so level 0")
        XCTAssertEqual(session.qualityPin, 2, "the failure keeps the pin")

        broken.isOn = false
        let second = await session.retry()
        XCTAssertEqual(second, .running)
        XCTAssertEqual(probe.makes, 2, "the retry built a new experience")
        XCTAssertTrue(session.experience === probe.shell)
        assertLevel(session, 2, "the pin is applied to the retried experience")

        layOut(session)
        let drawn = drawFrame(session)
        XCTAssertTrue(drawn)
        let drawnTier = probe.presenter?.lastTier
        XCTAssertEqual(drawnTier, 2, "the first drawn frame of the retried experience had the pinned tier")
    }

    // MARK: Digest (FR-U06-014, SC-U06-003)

    func testLevelChangesDoNotChangeTheStateDigest() async throws {
        let untouched = try await digestAfterFrames(seed: 1_000, pins: [], frames: 12)
        let switched = try await digestAfterFrames(seed: 1_000, pins: [0, 1, 2, 1], frames: 12)
        XCTAssertGreaterThan(untouched.steps, 0, "the frames ran steps")
        XCTAssertEqual(switched.steps, untouched.steps, "the same number of steps with and without level changes")
        XCTAssertEqual(switched.digest, untouched.digest, "the digest is the same as without any level change")
    }

    // MARK: Without an experience

    func testWithoutAnExperienceTheLevelIsZeroAndRefreshDoesNothing() async throws {
        let script = ScriptedConditions(Self.serious)
        let session = scriptedSession(script)
        defer { session.close() }
        let idleLevel = session.qualityLevel
        XCTAssertEqual(idleLevel, 0)

        session.refreshQuality()
        session.refreshQuality(now: 10)
        let afterRefresh = session.qualityLevel
        XCTAssertEqual(afterRefresh, 0)
        XCTAssertEqual(script.reads, 0, "no decision without an experience: the conditions were not read")
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.experience)

        // A pin without an experience is only stored.
        session.qualityPin = 2
        let pinnedLevel = session.qualityLevel
        XCTAssertEqual(pinnedLevel, 0, "the level is 0 without an experience, whatever the pin")
        XCTAssertEqual(session.state, .idle)

        // After a close the session holds no experience again.
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        assertLevel(session, 2, "the stored pin applies to the next open")
        session.close()
        let closedLevel = session.qualityLevel
        XCTAssertEqual(closedLevel, 0, "level 0 again after the close")
        session.refreshQuality(now: 20)
        XCTAssertEqual(session.state, .idle)
        assertHoldsNothing(session)
    }
}
