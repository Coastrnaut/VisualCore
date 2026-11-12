// SessionQualityTests — feature 192 T-U06-017 (UA-F06; US2; FR-U06-010 to FR-U06-014; SC-U06-003). The quality
// level of the open experience as `ExperienceSession` decides it: a pinned level is applied before the first
// frame and after a retry, a pin beyond the profile means the last level, the automatic level follows scripted
// device conditions (one step down per 2 s, one step up per 10 s of calm, Low Power Mode holds level 1), the
// frame hook takes the decisions while frames are drawn (at most one per second), no decision is taken while
// suspended, one is taken at the resume and the calm period starts again there, a changed or removed pin
// applies at once, every open sets the tier of the experience instance, and no level change touches the state
// digest.
// The helpers (`sampleRequest`, `SampleProbe`, `layOut`, `drawFrame`, …) are in SessionOpenCloseTests.swift.
//
// Timing: the tests of the automatic level give the session a scripted clock (`session.timeSource`) before the
// open, so that every decision of the session (at the open, from the frame hook, at a resume, at the removal of
// a pin, on `refreshQuality()`) is on one scale. A test sets the clock and then calls `refreshQuality()` or
// draws a frame. The scripted time starts at 100 and only increases.
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

/// The time a test scripts, in seconds; the session's `timeSource` closure reads it at every decision.
@MainActor
private final class ScriptedClock {
    var now: Double
    init(_ now: Double = 100) { self.now = now }
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

    /// A session that reads its device conditions from `script` and, with a `clock`, the time of its quality
    /// decisions from that clock.
    private func scriptedSession(_ script: ScriptedConditions, clock: ScriptedClock? = nil) -> ExperienceSession {
        let session = ExperienceSession()
        session.conditions = { script.read() }
        if let clock {
            session.timeSource = { clock.now }
        }
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
        let clock = ScriptedClock(100)
        let session = scriptedSession(script, clock: clock)
        defer { session.close() }
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        XCTAssertGreaterThanOrEqual(script.reads, 1, "the open read the scripted conditions")

        // t = 100, open decision: hot, no change yet, so one step down: 0 → 1; last change = 100.
        assertLevel(session, 1, "one step down at the open decision")

        // t = 101: hot; the governor asks the policy (1 s since its last decision), but 101 − 100 < 2 s
        // (decision interval): no step.
        clock.now = 101
        session.refreshQuality()
        assertLevel(session, 1, "no second step within the decision interval")

        // t = 102: hot; 102 − 100 ≥ 2 s, so one more step: 1 → 2; last change = 102.
        clock.now = 102
        session.refreshQuality()
        assertLevel(session, 2, "second step down")

        // t = 104: hot and the interval passed, but 2 is the last of three levels: it stays.
        clock.now = 104
        session.refreshQuality()
        assertLevel(session, 2, "the last level is the floor")

        // t = 106: first calm decision; the calm period starts at 106, no step.
        script.value = .nominal
        clock.now = 106
        session.refreshQuality()
        assertLevel(session, 2, "calm begins, no step yet")

        // t = 115: 9 s of calm < 10 s (calm period): no step.
        clock.now = 115
        session.refreshQuality()
        assertLevel(session, 2, "9 s of calm are not enough")

        // t = 116: 10 s of calm and 116 − 102 ≥ 2 s since the last change: 2 → 1; calm starts again at 116.
        clock.now = 116
        session.refreshQuality()
        assertLevel(session, 1, "one step up after 10 s of calm")

        // t = 125: 9 s since the step up: no step.
        clock.now = 125
        session.refreshQuality()
        assertLevel(session, 1, "the calm period started again at the step up")

        // t = 126: 10 s since the step up: 1 → 0.
        clock.now = 126
        session.refreshQuality()
        assertLevel(session, 0, "another step up after 10 more seconds")

        // t = 140: level 0 is the best: nothing left to step.
        clock.now = 140
        session.refreshQuality()
        assertLevel(session, 0, "the best level stays")
        XCTAssertEqual(session.state, .running)
    }

    func testLowPowerModeHoldsLevelOneAndDoesNotRecoverWhileItIsOn() async throws {
        let script = ScriptedConditions(Self.lowPower)
        let clock = ScriptedClock(100)
        let session = scriptedSession(script, clock: clock)
        defer { session.close() }
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)

        // t = 100, open decision: Low Power Mode with level 0 better than the ceiling 1 (min(1, 3 − 1)): 0 → 1.
        assertLevel(session, 1, "Low Power Mode steps to level 1 at the open decision")

        // t = 110, 130, 160: Low Power Mode with the level at the ceiling: no step down (not hot, not better
        // than the ceiling) and no calm (Low Power Mode is never calm), however long it lasts.
        for time in [110.0, 130, 160] {
            clock.now = time
            session.refreshQuality()
            assertLevel(session, 1, "Low Power Mode at t = \(time)")
        }

        // Low Power Mode off. t = 170: the calm period starts. t = 179: 9 s, no step. t = 180: 10 s of calm
        // and 180 − 100 ≥ 2 s since the last change: 1 → 0.
        script.value = .nominal
        clock.now = 170
        session.refreshQuality()
        assertLevel(session, 1, "calm begins when Low Power Mode ends")
        clock.now = 179
        session.refreshQuality()
        assertLevel(session, 1, "9 s of calm are not enough")
        clock.now = 180
        session.refreshQuality()
        assertLevel(session, 0, "recovery 10 s after Low Power Mode ended")
    }

    // MARK: Frame hook (FR-U06-010, FR-U06-011)

    func testTheFrameHookTakesTheDecisionsWhileFramesAreDrawn() async throws {
        let script = ScriptedConditions(Self.serious)
        let clock = ScriptedClock(100)
        let session = scriptedSession(script, clock: clock)
        defer { session.close() }
        let (request, probe) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        // t = 100, open decision: hot: 0 → 1; last change = 100; the session's last check = 100.
        assertLevel(session, 1, "one step down at the open decision")
        layOut(session)   // a frame drawn by the layout is at t = 100: 0 s since the last check, no decision
        let readsAfterOpen = script.reads

        // t = 100.5: a frame is drawn, but 0.5 s < 1 s since the session's last check: the governor is not
        // asked and the conditions are not read.
        clock.now = 100.5
        let drawnEarly = drawFrame(session)
        XCTAssertTrue(drawnEarly)
        assertLevel(session, 1, "no decision less than one second after the last one")
        XCTAssertEqual(script.reads, readsAfterOpen, "the frame hook did not read the conditions")

        // t = 102: a frame is drawn 2 s after the last check (≥ 1 s): the hook asks the governor (2 s ≥ 1 s
        // since its last decision), the policy steps (102 − 100 ≥ 2 s, hot): 1 → 2; last change = 102.
        clock.now = 102
        let readsBeforeFrame = script.reads
        let drawnLater = drawFrame(session)
        XCTAssertTrue(drawnLater)
        let readsAfterFrame = script.reads
        XCTAssertEqual(readsAfterFrame, readsBeforeFrame + 1, "the frame hook read the conditions once")
        assertLevel(session, 2, "the frame hook took the decision: second step down")

        // Nominal from here, one frame per second from t = 103 to t = 113. Every frame is 1 s after the last
        // check, so every frame takes a decision. t = 103: the calm period starts. t = 104 … 112: 1 … 9 s of
        // calm, no step. t = 113: 10 s of calm and 113 − 102 ≥ 2 s since the last change: 2 → 1.
        script.value = .nominal
        for second in 1...11 {
            clock.now = 102 + Double(second)
            let drawn = drawFrame(session)
            XCTAssertTrue(drawn)
            let expected = second < 11 ? 2 : 1
            assertLevel(session, expected, "frame at t = \(clock.now), \(second - 1) s of calm")
        }
        XCTAssertEqual(script.reads, readsAfterFrame + 11, "one decision per frame, one second apart")

        // The decision follows the drawing of its frame: the next frame (same time, so no decision) is the
        // first one drawn with level 1.
        let drawnAfterStep = drawFrame(session)
        XCTAssertTrue(drawnAfterStep)
        let drawnTier = probe.presenter?.lastTier
        XCTAssertEqual(drawnTier, 1, "the frame after the step up was drawn with level 1")
        assertLevel(session, 1, "one level up only")
        XCTAssertEqual(session.state, .running)
    }

    // MARK: Suspension (FR-U06-012)

    func testNoDecisionIsTakenWhileSuspendedAndTheCalmPeriodStartsAgainAfterTheResume() async throws {
        let script = ScriptedConditions(Self.serious)
        let clock = ScriptedClock(100)
        let session = scriptedSession(script, clock: clock)
        defer { session.close() }
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        // t = 100, open decision: hot: 0 → 1 (as in the test of the automatic level); last change = 100.
        assertLevel(session, 1, "one step down before the suspension")

        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        let readsAtSuspension = script.reads

        // Still hot at t = 110: a decision would step 1 → 2 (110 − 100 ≥ 2 s). None is taken while suspended.
        clock.now = 110
        session.refreshQuality()
        assertLevel(session, 1, "no step down while suspended")
        // Calm at t = 140: a decision would start the calm period here. None is taken.
        script.value = .nominal
        clock.now = 140
        session.refreshQuality()
        assertLevel(session, 1, "no decision while suspended")
        XCTAssertEqual(script.reads, readsAtSuspension, "the conditions were not even read while suspended")

        // t = 200: the resume forgets the timing and takes one decision from the conditions of that moment
        // (calm): the calm period starts at 200; the time away (and the refused calls at 110 and 140) count
        // for nothing, so no step.
        clock.now = 200
        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        assertLevel(session, 1, "the resume keeps the level: the time away is not calm time")
        XCTAssertEqual(script.reads, readsAtSuspension + 1, "the resume took one decision")

        // t = 209: 9 s after the decision of the resume: no step.
        clock.now = 209
        session.refreshQuality()
        assertLevel(session, 1, "9 s of calm after the resume are not enough")

        // t = 210: 10 s of calm; the last change was forgotten at the resume, so the step is allowed: 1 → 0;
        // last change = 210.
        clock.now = 210
        session.refreshQuality()
        assertLevel(session, 0, "one step up 10 s after the decision of the resume")

        // A second suspension; the device is hot when the app comes back at t = 211. The resume forgets the
        // timing (the change at 210 no longer blocks) and its decision steps at once: 0 → 1.
        session.setScenePhase(.background)
        XCTAssertEqual(session.state, .suspended)
        script.value = Self.serious
        clock.now = 211
        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        assertLevel(session, 1, "the decision of the resume uses the conditions of that moment")
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    func testAnExperienceOpenedWhileNotActiveGetsTheLevelOfTheMomentItIsActivated() async throws {
        let script = ScriptedConditions(.nominal)
        let clock = ScriptedClock(100)
        let session = scriptedSession(script, clock: clock)
        defer { session.close() }
        session.setScenePhase(.background)
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .suspended)
        XCTAssertEqual(session.state, .suspended)
        // t = 100, open decision: calm, level 0; the experience waits in the state ready.
        assertLevel(session, 0, "level 0 under nominal conditions while it waits")

        // The device gets hot while the experience waits. t = 105: the app becomes active; the session
        // activates the experience, forgets the timing and takes a decision: hot, no change yet: 0 → 1.
        script.value = Self.serious
        clock.now = 105
        session.setScenePhase(.active)
        XCTAssertEqual(session.state, .running)
        assertLevel(session, 1, "the level of the moment of the activation")
        XCTAssertEqual(session.diagnostics.rejectedTransitions, 0)
    }

    // MARK: Changing the pin (FR-U06-013)

    func testChangingThePinWhileAnExperienceRunsAppliesAtOnce() async throws {
        let clock = ScriptedClock(100)
        let session = scriptedSession(ScriptedConditions(.nominal), clock: clock)
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
        clock.now = 110
        session.refreshQuality()
        assertLevel(session, 2, "the pin holds")

        // 2 → 1: at once.
        session.qualityPin = 1
        assertLevel(session, 1, "a changed pin applies at once")

        // 1 → nil: back to automatic, which starts again from level 0 with its timing forgotten and takes a
        // decision at once (t = 110): calm, so level 0 stays.
        session.qualityPin = nil
        assertLevel(session, 0, "automatic starts again from level 0")
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(probe.makes, 1, "the same experience all along")
    }

    func testRemovingThePinUnderHeatAppliesTheAutomaticLevelAtOnce() async throws {
        let script = ScriptedConditions(Self.serious)
        let clock = ScriptedClock(100)
        let session = scriptedSession(script, clock: clock)
        defer { session.close() }
        session.qualityPin = 0
        let (request, _) = sampleRequest()
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        // t = 100, open decision: pinned, so the policy is not asked: level 0 in spite of the heat.
        assertLevel(session, 0, "the pin holds level 0 while the device is hot")

        // t = 105: still pinned: a decision changes nothing.
        clock.now = 105
        session.refreshQuality()
        assertLevel(session, 0, "the pin holds")

        // The pin is removed at t = 105: the policy starts again from level 0 with its timing forgotten, and
        // the session takes a decision at once: hot, no change yet: 0 → 1. No frame and no `refreshQuality`.
        session.qualityPin = nil
        let levelAtOnce = session.qualityLevel
        let tierAtOnce = session.experience?.diagnostics.qualityTier
        XCTAssertEqual(levelAtOnce, 1, "the automatic level for the heat applies at once")
        XCTAssertEqual(tierAtOnce, 1, "the experience has the automatic level at once")
        XCTAssertEqual(session.state, .running)
    }

    // MARK: Open (FR-U06-013)

    func testAnOpenAlwaysSetsTheTierOfTheExperienceInstance() async throws {
        let clock = ScriptedClock(100)
        let session = scriptedSession(ScriptedConditions(.nominal), clock: clock)
        defer { session.close() }
        // One experience instance for every open of the request (`sampleRequest` builds a new one each time).
        let shell = ExperienceShell(id: SampleExperience.id, presenter: SamplePresenter<NoFault>())
        let request = ExperienceOpenRequest(id: SampleExperience.id, seed: 42) { shell }

        session.qualityPin = 2
        let first = await session.open(request)
        XCTAssertEqual(first, .running)
        XCTAssertTrue(session.experience === shell)
        assertLevel(session, 2, "the pin at the first open")

        session.close()
        XCTAssertEqual(session.state, .idle)
        let tierAfterClose = shell.diagnostics.qualityTier
        XCTAssertEqual(tierAfterClose, 2, "the instance keeps its tier after the close")

        // Automatic and nominal: the level in force at the second open is 0, which is also the level a new
        // open of the session starts from. The session sets the tier all the same, so the instance leaves 2.
        session.qualityPin = nil
        clock.now = 110
        let second = await session.open(request)
        XCTAssertEqual(second, .running)
        XCTAssertTrue(session.experience === shell, "the same instance was opened again")
        let level = session.qualityLevel
        let tier = shell.diagnostics.qualityTier
        XCTAssertEqual(level, 0, "the session's level at the second open")
        XCTAssertEqual(tier, 0, "the open set the tier of the instance")
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
        let clock = ScriptedClock(100)
        let session = scriptedSession(script, clock: clock)
        defer { session.close() }
        let idleLevel = session.qualityLevel
        XCTAssertEqual(idleLevel, 0)

        session.refreshQuality()
        clock.now = 110
        session.refreshQuality()
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
        clock.now = 120
        session.refreshQuality()
        XCTAssertEqual(session.state, .idle)
        assertHoldsNothing(session)
    }
}
