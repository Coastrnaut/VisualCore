// LissajousLabyrinthFallbackTests — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-003, 007; SC-R02G0203-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a thread program that does not
// compile (the presenter's seam, before `setup`) draws the minimal tier's thread unlit, keeps the reason at every tier,
// and leaves the digest untouched; a zero-size view draws nothing without error and recovers; for every aspect 0.4 …
// 2.5 the whole figure stays inside the view (CPU: every element within the 5 % margin; pixels: the outer 4 % band is
// night) and the frame matches the reference; a memory warning releases the GPU objects and the next frame rebuilds
// them and draws the same image; Reduce Motion holds the head at tick 0 so frames at different times are identical;
// Reduce Flashing caps the glow. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct LissajousLabyrinthFallbackTests {
    @Test func aBrokenThreadProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 0) { $0.breakThreadShader() }
        let presenter = shell.presenter
        let before = try LissajousLabyrinthTest.digest(shell)
        let rgba = try LissajousLabyrinthTest.still(session)
        let reason = try #require(presenter.fallbackReason)
        print("lissajous-labyrinth fallback reason: \(reason)")
        #expect(reason.contains("lissajous-labyrinth shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(LissajousLabyrinthTest.nonNightPixels(rgba) > 0, "the fallback frame draws something")
        // The fallback draws the thread: most checked samples have a pixel that is not night within 2 px.
        let snapshot = try #require(presenter.lastSnapshot)
        let w = LissajousLabyrinthTest.width, h = LissajousLabyrinthTest.height
        let vp = LissajousLabyrinthTest.viewProjection(snapshot, width: w, height: h)
        var samples = 0
        var drawn = 0
        for sample in LissajousLabyrinthTest.checkedSamples(snapshot, tier: LissajousLabyrinthTier.of(2),
                                                           viewProjection: vp, width: w, height: h) {
            samples += 1
            guard let p = sample.pixel else { continue }
            let found = LissajousLabyrinthTest.anyPixel(rgba, near: p.x, p.y,
                                                        radius: LissajousLabyrinthTest.sampleRadius,
                                                        width: w, height: h) { c in
                LissajousLabyrinthTest.channelDistance(c, LissajousLabyrinthPalette.night) > 0.05
            }
            if found { drawn += 1 }
        }
        print("lissajous-labyrinth fallback: \(drawn) of \(samples) samples drawn")
        #expect(samples == 128 && drawn * 3 >= samples * 2, "fallback thread drawn near \(drawn) of \(samples) samples")
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            LissajousLabyrinthTest.pin(session, shell, tier: tier)
            try LissajousLabyrinthTest.draw(session, frames: 2)
            let again = try LissajousLabyrinthTest.still(session)
            #expect(LissajousLabyrinthTest.nonNightPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
        }
        session.qualityPin = 0
        #expect(try LissajousLabyrinthTest.digest(shell) == before)
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 20)
        let before = try LissajousLabyrinthTest.digest(shell)
        let host = try #require(session.renderHost)
        let view = host.view
        view.frame = .zero
        view.layoutIfNeeded()
        var tries = 0
        for _ in 0..<3 {
            _ = host.renderOneFrame(present: false)   // false without a valid surface; never an error
            tries += 1
        }
        #expect(tries == 3)
        #expect(shell.state != .failed)
        #expect(shell.presenter.fallbackReason == nil)
        // The CPU projection refuses a zero-size viewport.
        let snapshot = try #require(shell.presenter.lastSnapshot)
        let centre = LissajousLabyrinthSceneGeometry.bounds(snapshot).centre
        #expect(LissajousLabyrinthSceneGeometry.project(centre, aspect: 1, snapshot: snapshot, width: 0,
                                                        height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny = try LissajousLabyrinthTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try LissajousLabyrinthTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba = try LissajousLabyrinthTest.still(session)
        LissajousLabyrinthTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), tier: 0,
                                          "after a zero size")
        #expect(try LissajousLabyrinthTest.digest(shell) == before)
    }

    @Test func everyAspectKeepsTheFigureInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 80)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try LissajousLabyrinthTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 0.75, 1, 1.5 and 2.5, the short side 512 px (the thread's pixel width of the check size).
        let sizes: [(w: Int, h: Int)] = [(512, 1_280), (512, 683), (512, 512), (768, 512), (1_280, 512)]
        for size in sizes {
            let rgba = try LissajousLabyrinthTest.still(session, width: size.w, height: size.h)
            let snapshot = try #require(shell.presenter.lastSnapshot)
            let what = "\(size.w) × \(size.h)"
            // CPU: every element lies inside the 5 % margin.
            let vp = LissajousLabyrinthTest.viewProjection(snapshot, width: size.w, height: size.h)
            let lowX = 0.05 * Double(size.w), highX = 0.95 * Double(size.w)
            let lowY = 0.05 * Double(size.h), highY = 0.95 * Double(size.h)
            var outside = 0
            for q in LissajousLabyrinthSceneGeometry.path(snapshot, tier: LissajousLabyrinthTier.of(2)) {
                guard let p = LissajousLabyrinthSceneGeometry.project(q, viewProjection: vp, width: size.w,
                                                                      height: size.h) else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            var balls: [LissajousLabyrinthBall] = snapshot.level.checkpoints
            for ball in snapshot.level.obstacles { balls.append(ball) }
            for ball in balls {
                guard let d = LissajousLabyrinthTest.disc(ball, viewProjection: vp, width: size.w,
                                                          height: size.h) else {
                    outside += 1
                    continue
                }
                if d.centre.x - d.radius < lowX || d.centre.x + d.radius > highX || d.centre.y - d.radius < lowY
                    || d.centre.y + d.radius > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) elements outside the 5 % margin")
            // Pixels: the outer 4 % band is night, and the frame matches the reference.
            let border = LissajousLabyrinthTest.borderMisses(rgba, width: size.w, height: size.h)
            #expect(border.checked > 0 && border.misses.isEmpty, "\(what): border \(border.misses)")
            LissajousLabyrinthTest.checkFrame(rgba, snapshot: snapshot, tier: 0, width: size.w, height: size.h, what)
        }
    }

    @Test func reduceMotionHoldsTheHeadStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 60, reduceMotion: true)
        let first = try LissajousLabyrinthTest.still(session, time: 0.5)
        let firstSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0 && firstSnapshot.headTick == 0)
        try LissajousLabyrinthTest.draw(session, frames: 5)
        let second = try LissajousLabyrinthTest.still(session, time: 2.75)
        let secondSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0 && secondSnapshot.headTick == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        LissajousLabyrinthTest.checkFrame(second, snapshot: secondSnapshot, tier: 0, "Reduce Motion")
    }

    @Test func withoutReduceMotionTheHeadAdvances() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 60)
        let first = try LissajousLabyrinthTest.still(session, time: 0.5)
        #expect(try #require(shell.presenter.lastSnapshot).headTick == 30)
        let second = try LissajousLabyrinthTest.still(session, time: 2.75)
        #expect(try #require(shell.presenter.lastSnapshot).headTick == 165)
        #expect(first != second, "the head and the shimmer move with the presentation time")
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await LissajousLabyrinthTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            LissajousLabyrinthTest.pin(session, shell, tier: 0)
            let rgba = try LissajousLabyrinthTest.still(session)
            means.append(LissajousLabyrinthTest.meanLuminance(rgba))
            LissajousLabyrinthTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), tier: 0,
                                              "Reduce Flashing \(reduceFlashing)")
        }
        print("lissajous-labyrinth glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(LissajousLabyrinthThreadScene.reducedGlowGain < LissajousLabyrinthThreadScene.glowGain)
        #expect(LissajousLabyrinthThreadScene.glowGain <= LissajousLabyrinthShaders.maxGlow)
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 80)
        let before = try LissajousLabyrinthTest.digest(shell)
        let host = try #require(session.renderHost)
        try LissajousLabyrinthTest.draw(session, frames: 2)
        let image = try LissajousLabyrinthTest.still(session)
        try LissajousLabyrinthTest.draw(session, frames: 1)
        let held = host.resources.stats.totalBytes
        shell.presenter.shedCaches()
        let shed = host.resources.stats.totalBytes
        #expect(shed < held, "the GPU objects were released: \(held) → \(shed) bytes")
        try LissajousLabyrinthTest.draw(session, frames: 1)
        let rebuilt = host.resources.stats.totalBytes
        #expect(rebuilt > shed, "the next frame rebuilt them: \(shed) → \(rebuilt) bytes")
        let again = try LissajousLabyrinthTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        LissajousLabyrinthTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot), tier: 0,
                                          "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try LissajousLabyrinthTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(try LissajousLabyrinthTest.digest(shell) == before)
    }
}
#endif
