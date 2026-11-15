// AquariumSessionTests — feature 068 (A09-P01) T-A09-103 (FR-A09-111, FR-A09-120, FR-A09-121, FR-A09-123; story 1
// scenario 1; story 4 scenarios 1–3; SC-A09-101, SC-A09-104). The A09 adapter inside the one app's session host on the
// simulator, short runs only (each test well under 10 s, no wall-clock assertion): the first frame draws the Reef with
// every fish and plant and describes it in words; each drawn frame advances one simulation step; a suspension of any
// wall-clock length does not advance the step count, and the resume continues from the same step (no fast-forward);
// pause stops the motion; the state saved by the shell restores identically in a new session; a newer saved state is
// refused and the starter habitat opens; Reduce Motion halves the sway and the swim motion (wave, tail sweep, bend)
// but never changes the state; every action has a native control.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
final class AquariumSessionTests: XCTestCase {
    func testTheFirstFrameDrawsTheReefAndDescribesIt() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        let core = try AquariumTest.core(shell)
        XCTAssertEqual(presenter.lastFishDrawn, core.document.fish.count)
        XCTAssertEqual(presenter.lastPlantsDrawn, core.document.plants.count)
        XCTAssertGreaterThan(presenter.lastScale, 0)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        let summary = shell.accessibilitySummary
        XCTAssertTrue(summary.hasPrefix("Digital Aquarium: Reef, \(core.document.fish.count) fish of 2 species ("),
                      summary)
        for name in ["Orange striped fish", "Blue fish with yellow tail", "\(core.document.plants.count) plants",
                     "lighting soft", "swimming."] {
            XCTAssertTrue(summary.contains(name), "\(summary) names \(name)")
        }
        XCTAssertTrue(presenter.mirror.ready)
        XCTAssertEqual(presenter.mirror.habitatIndex, 0)
        XCTAssertEqual(presenter.nativeActions, Set(AquariumCore.actionIDs))

        XCTAssertTrue(shell.handle(control: "habitat.select", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "lighting.level", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let kelp = shell.accessibilitySummary
        XCTAssertTrue(kelp.hasPrefix("Digital Aquarium: Kelp, "), kelp)
        for name in ["Silver slender fish", "Gold round fish", "of 2 species", "lighting bright", "paused."] {
            XCTAssertTrue(kelp.contains(name), "\(kelp) names \(name)")
        }
        XCTAssertEqual(presenter.mirror.habitatIndex, 1)
        XCTAssertEqual(presenter.mirror.lightingLevel, 2)
        XCTAssertTrue(presenter.mirror.paused)

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testFramesAdvanceTheFishAndPauseStopsThem() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session)
        let before = try AquariumTest.core(shell)
        try AquariumTest.frames(session, 30)
        let after = try AquariumTest.core(shell)
        XCTAssertGreaterThan(after.step, before.step)
        XCTAssertLessThanOrEqual(after.step - before.step, 32, "about one step per 1/60 s frame")
        XCTAssertNotEqual(after.document.fish.map(\.position), before.document.fish.map(\.position))

        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let paused = try AquariumTest.core(shell)
        try AquariumTest.frames(session, 30)
        XCTAssertEqual(try AquariumTest.core(shell), paused, "nothing moves while paused")
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("paused."), shell.accessibilitySummary)

        XCTAssertTrue(shell.handle(control: "motion.pause", values: [0]).isAccepted)
        try AquariumTest.frames(session, 5)
        XCTAssertGreaterThan(try AquariumTest.core(shell).step, paused.step)
        session.close()
    }

    func testASuspensionDoesNotFastForwardTheFish() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session)
        try AquariumTest.frames(session, 10)
        let before = try AquariumTest.core(shell)
        let stepIndex = shell.engine.stepIndex
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(try AquariumTest.core(shell), before, "nothing moves while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try AquariumTest.core(shell), before, "the resume continues from the same state")
        try AquariumTest.frames(session, 1)
        let resumed = try AquariumTest.core(shell)
        XCTAssertLessThanOrEqual(resumed.step - before.step, 2, "one frame's steps, never the suspended time")
        session.close()
    }

    func testTheSavedStateRestoresIdenticallyInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await AquariumTest.open(first)
        XCTAssertTrue(shell.handle(control: "habitat.select", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "lighting.level", values: [2]).isAccepted)
        try AquariumTest.frames(first, 20)
        let snapshot = try shell.snapshot()
        let saved = try AquariumTest.core(shell)
        first.close()

        let second = ExperienceSession()
        let restored = try await AquariumTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let core = try AquariumTest.core(restored)
        XCTAssertEqual(core.state, saved.state, "habitat, species, plants and fish positions are identical")
        XCTAssertEqual(core.document.habitatId, "kelp")
        XCTAssertEqual(core.document.lighting, 2)
        second.close()
    }

    func testANewerSavedStateIsRefusedAndTheStarterHabitatOpens() async throws {
        let first = ExperienceSession()
        let shell = try await AquariumTest.open(first)
        XCTAssertTrue(shell.handle(control: "habitat.select", values: [1]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let newer = try ExperienceSnapshot(experience: AquariumTest.id, schemaVersion: 4, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))

        let second = ExperienceSession()
        let opened = try await AquariumTest.open(second, snapshot: newer)
        let core = try AquariumTest.core(opened)
        XCTAssertNotNil(second.lastRestoreRefusal, "the newer state is refused")
        XCTAssertEqual(core.document.habitatId, "reef", "the refused state leaves the starter habitat")
        XCTAssertThrowsError(try opened.restore(newer))
        second.close()
    }

    func testReduceMotionHalvesTheSwayButNeverChangesTheState() async throws {
        let full = ExperienceSession()
        let fullShell = try await AquariumTest.open(full)
        try AquariumTest.frames(full, 10)
        let reduced = ExperienceSession()
        let reducedShell = try await AquariumTest.open(reduced, reduceMotion: true)
        try AquariumTest.frames(reduced, 10)
        XCTAssertEqual(fullShell.presenter.lastSwayFactor, 1)
        XCTAssertEqual(reducedShell.presenter.lastSwayFactor, 0.5)
        let a = try AquariumTest.core(fullShell), b = try AquariumTest.core(reducedShell)
        XCTAssertEqual(a.document, b.document, "the preference is presentation only")
        XCTAssertEqual(try fullShell.engine.digest(), try reducedShell.engine.digest())
        let x = 4.0, step = 30
        XCTAssertEqual(AquariumPresenter.sway(t: 1, x: x, step: step, factor: 0.5),
                       AquariumPresenter.sway(t: 1, x: x, step: step, factor: 1) / 2, accuracy: 1e-12)
        full.close()
        reduced.close()
    }

    func testFishShapesHaveTwelveOutlinePointsAndMirrorWhenSwimmingLeft() {
        for shape in FishShape.allCases {
            let outline = AquariumPresenter.outline(shape, length: 1)
            XCTAssertEqual(outline.count, 12)
            XCTAssertEqual(outline.map(\.x).max() ?? 0, 0.5, accuracy: 1e-9, "the nose at half the length")
        }
        let right = AquariumPresenter.placed([Vec2(1, 0.5)], position: Vec2(5, 5), heading: 0, mirrored: false)
        let left = AquariumPresenter.placed([Vec2(1, 0.5)], position: Vec2(5, 5), heading: .pi, mirrored: true)
        XCTAssertEqual(right[0].x, 6, accuracy: 1e-9)
        XCTAssertEqual(left[0].x, 4, accuracy: 1e-9, "the nose points left")
        XCTAssertEqual(left[0].y, 5.5, accuracy: 1e-9, "the back stays up: the fish is not upside down")
    }
}
