// StillWorkTests — feature 135 (A18-P05) T-A18-503 (FR-A18-501, FR-A18-502; SC-A18-501, SC-A18-502; clarifications
// Q1, Q2; contracts/qa.md "Presenter"). Ambient Clock's still picture through VisualCoreRendering's `CachedScene`,
// drawn on the live surface of the one app's session host (each frame at a later frame time; the offscreen still is
// not used because it resizes the scene for every picture), with a fixed clock; short runs only, no wall-clock
// assertion:
//   - motion off and seconds off: 120 frames at one clock instant draw the background once and are byte-identical;
//   - a palette change (a cut under Reduce Motion) draws once more;
//   - motion on draws every frame (120), and seconds on with motion off is pass-through (120);
//   - a resize draws once more;
//   - advancing the fixed clock until the shown drift step changes draws once more, and 60 frames inside one drift
//     step draw nothing more.
import Foundation
import Testing
import UIKit
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct StillWorkTests {
    /// The number of frames of a still or moving run.
    private static let frames = 120

    /// Draws `count` frames on the live surface of `session` and returns their pixels.
    private func draw(_ session: ExperienceSession, count: Int) throws -> [[UInt8]] {
        var pictures: [[UInt8]] = []
        pictures.reserveCapacity(count)
        for _ in 0..<count {
            pictures.append(try AmbientTest.picture(session).rgba)
        }
        return pictures
    }

    /// Opens Ambient Clock with motion turned off (one frame drawn after the change, so the still picture is cached).
    private func openStill(_ session: ExperienceSession, clock: FixedClock = FixedClock(AmbientFixtures.instant),
                           reduceMotion: Bool = false) async throws -> ExperienceShell<AmbientPresenter> {
        let shell = try await AmbientTest.open(session, clock: clock, reduceMotion: reduceMotion)
        let off = shell.handle(control: "theme.motion", values: [0])
        #expect(off == .accepted)
        _ = try draw(session, count: 1)
        #expect(shell.presenter.isStill)
        return shell
    }

    @Test func withMotionAndSecondsOffOneHundredTwentyFramesDrawTheBackgroundOnce() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let off = shell.handle(control: "theme.motion", values: [0])
        #expect(off == .accepted)
        let before = shell.presenter.backgroundDrawCount
        let pictures = try draw(session, count: Self.frames)
        #expect(shell.presenter.isStill)
        #expect(shell.presenter.backgroundDrawCount == before + 1, "one draw for the still picture")
        let first = try #require(pictures.first)
        #expect(!first.isEmpty)
        var differing = 0
        for picture in pictures where picture != first { differing += 1 }
        #expect(differing == 0, "every frame is byte-identical")
        #expect(shell.presenter.drawCount == 1, "a cached frame counts its copy")
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func aPaletteChangeDrawsOnceMore() async throws {
        let session = ExperienceSession()
        let shell = try await openStill(session, reduceMotion: true)
        let before = shell.presenter.backgroundDrawCount
        let old = try AmbientTest.picture(session).rgba
        #expect(shell.presenter.backgroundDrawCount == before)
        let chosen = shell.handle(control: "theme.palette", values: [1])
        #expect(chosen == .accepted)
        let pictures = try draw(session, count: Self.frames)
        #expect(shell.presenter.shownPalette == 1 && shell.presenter.fadeStart == nil, "a cut under Reduce Motion")
        #expect(shell.presenter.backgroundDrawCount == before + 1)
        let first = try #require(pictures.first)
        #expect(AmbientTest.differingPixels(first, old) > 0, "the new palette is shown")
        session.close()
    }

    @Test func withMotionOnEveryFrameDraws() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        #expect(!shell.presenter.isStill)
        let before = shell.presenter.backgroundDrawCount
        _ = try draw(session, count: Self.frames)
        #expect(shell.presenter.backgroundDrawCount == before + Self.frames)
        session.close()
    }

    @Test func withSecondsOnAndMotionOffEveryFrameDraws() async throws {
        let session = ExperienceSession()
        let shell = try await openStill(session)
        let values = AmbientCore.formatValues(AmbientCore.preferences(hourCycle: 0, showSeconds: true, showDate: true))
        let seconds = shell.handle(control: "clock.format", values: values)
        #expect(seconds == .accepted)
        let before = shell.presenter.backgroundDrawCount
        _ = try draw(session, count: Self.frames)
        #expect(!shell.presenter.isStill, "seconds keep the picture moving")
        #expect(shell.presenter.cache?.passThrough == true)
        #expect(shell.presenter.backgroundDrawCount == before + Self.frames)
        session.close()
    }

    @Test func aResizeDrawsOnceMore() async throws {
        let session = ExperienceSession()
        let shell = try await openStill(session)
        let before = shell.presenter.backgroundDrawCount
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 240, height: 180)
        view.layoutIfNeeded()
        let pictures = try draw(session, count: 30)
        #expect(shell.presenter.backgroundDrawCount == before + 1)
        let first = try #require(pictures.first)
        var differing = 0
        for picture in pictures where picture != first { differing += 1 }
        #expect(differing == 0)
        session.close()
    }

    @Test func aNewDriftStepDrawsOnceMoreAndFramesInsideOneStepDoNot() async throws {
        let clock = FixedClock(AmbientFixtures.instant)
        let session = ExperienceSession()
        let shell = try await openStill(session, clock: clock)
        let before = shell.presenter.backgroundDrawCount
        let drift = shell.presenter.shownDrift
        var advanced = 0.0
        while shell.presenter.shownDrift == drift, advanced < 120 {
            clock.advance(by: 0.1)
            advanced += 0.1
        }
        #expect(shell.presenter.shownDrift != drift, "the drift step changes within two minutes")
        #expect(advanced < 120)
        _ = try draw(session, count: 1)
        #expect(shell.presenter.backgroundDrawCount == before + 1)
        let step = shell.presenter.shownDrift
        for _ in 0..<60 {
            clock.advance(by: 0.001)
            _ = try draw(session, count: 1)
        }
        #expect(shell.presenter.shownDrift == step, "60 frames inside one drift step")
        #expect(shell.presenter.backgroundDrawCount == before + 1)
        session.close()
    }

    @Test func theStillKeyIsDeterministicAndFollowsThePicture() {
        var a = AmbientPresenter.StillKeyMix()
        var b = AmbientPresenter.StillKeyMix()
        a.add(3)
        a.add(0.5)
        b.add(3)
        b.add(0.5)
        #expect(a.value == b.value)
        var c = AmbientPresenter.StillKeyMix()
        c.add(3)
        c.add(1.0)
        #expect(c.value != a.value)
        var zero = AmbientPresenter.StillKeyMix()
        var negativeZero = AmbientPresenter.StillKeyMix()
        zero.add(0.0)
        negativeZero.add(-0.0)
        #expect(zero.value == negativeZero.value)
    }
}
