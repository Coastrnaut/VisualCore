// HueCompassFallbackTests — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-003, 007; SC-R02G0403-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a glass program that does not
// compile (the presenter's seam, before `setup`) draws the level-2 geometry unlit with the shared mesh renderer (the band
// samples keep their band colours, the needle tip and probe marks are lit), keeps the reason at every tier and leaves the
// digest untouched; a zero-size view draws nothing without error and recovers; for aspects 0.4 … 2.5 the frame keeps
// its outer 4 % band night and matches the reference; a memory warning releases the GPU objects and the next frame
// rebuilds them and draws the same image; Reduce Motion holds the snapshot time at 0 so frames at different times are
// identical, while without it the fog drifts; Reduce Flashing caps the glow. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import HueCompassCore
import Testing
import UIKit
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct HueCompassFallbackTests {
    @Test func aBrokenGlassProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 0) { $0.breakGlassShader() }
        let presenter: HueCompassPresenter = shell.presenter
        _ = try HueCompassTest.probeTwice(shell)
        let before: String = try HueCompassTest.digest(shell)
        let rgba: [UInt8] = try HueCompassTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("hue-compass fallback reason: \(reason)")
        #expect(reason.contains("hue-compass shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(HueCompassTest.nonNightPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the band colours, the lit needle tip and the probe marks: the same frame checks.
        let snapshot: HueCompassSceneSnapshot = try #require(presenter.lastSnapshot)
        HueCompassTest.checkFrame(rgba, snapshot: snapshot, "fallback")
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            HueCompassTest.pin(session, shell, tier: tier)
            try HueCompassTest.draw(session, frames: 2)
            let again: [UInt8] = try HueCompassTest.still(session)
            #expect(HueCompassTest.nonNightPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try HueCompassTest.digest(shell) == before)
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 20)
        let before: String = try HueCompassTest.digest(shell)
        let host = try #require(session.renderHost)
        let view = host.view
        view.frame = .zero
        view.layoutIfNeeded()
        var tries: Int = 0
        for _ in 0..<3 {
            _ = host.renderOneFrame(present: false)   // false without a valid surface; never an error
            tries += 1
        }
        #expect(tries == 3)
        #expect(shell.state != .failed)
        #expect(shell.presenter.fallbackReason == nil)
        // The CPU projection refuses a zero-size viewport.
        let camera = HueCompassSceneGeometry.camera(aspect: 1)
        #expect(HueCompassSceneGeometry.pixel(SIMD3<Double>(0, 0, 0), camera: camera, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try HueCompassTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try HueCompassTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try HueCompassTest.still(session)
        HueCompassTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "after a zero size")
        #expect(try HueCompassTest.digest(shell) == before)
    }

    @Test func everyAspectKeepsTheFigureInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 80)
        _ = try HueCompassTest.probeTwice(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try HueCompassTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 0.75, 1, 1.5 and 2.5, the short side 768 px (the check size's).
        let sizes: [(w: Int, h: Int)] = [(768, 1_920), (768, 1_024), (768, 768), (1_152, 768), (1_920, 768)]
        for size in sizes {
            let rgba: [UInt8] = try HueCompassTest.still(session, width: size.w, height: size.h)
            let snapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(size.w) × \(size.h)"
            // CPU: the needle tip, the band samples, the fog tops and the probe marks lie inside the 5 % margin.
            let lowX: Double = 0.05 * Double(size.w)
            let highX: Double = 0.95 * Double(size.w)
            let lowY: Double = 0.05 * Double(size.h)
            let highY: Double = 0.95 * Double(size.h)
            var outside: Int = 0
            for reference in HueCompassTest.referencePixels(snapshot, width: size.w, height: size.h) {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) reference points outside the 5 % margin")
            // Pixels: the outer 4 % band is night, and the frame matches the reference.
            let border = HueCompassTest.borderMisses(rgba, width: size.w, height: size.h)
            #expect(border.checked > 0 && border.misses.isEmpty, "\(what): border \(border.misses)")
            HueCompassTest.checkFrame(rgba, snapshot: snapshot, width: size.w, height: size.h, what)
        }
    }

    @Test func reduceMotionHoldsTheFogStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 60, reduceMotion: true)
        let first: [UInt8] = try HueCompassTest.still(session, time: 0.5)
        let firstSnapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0)
        try HueCompassTest.draw(session, frames: 5)
        let second: [UInt8] = try HueCompassTest.still(session, time: 2.75)
        let secondSnapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        HueCompassTest.checkFrame(second, snapshot: secondSnapshot, "Reduce Motion")
    }

    @Test func withoutReduceMotionTheFogDrifts() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 60)
        HueCompassTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try HueCompassTest.still(session, time: 0.5)
        let firstSnapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0.5)
        let second: [UInt8] = try HueCompassTest.still(session, time: 2.75)
        let secondSnapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 2.75)
        // The fog drifts with the presentation time wherever it is visible (density above 0).
        if secondSnapshot.fog.contains(where: { $0 > 0 }) {
            #expect(first != second, "the fog drifts with the presentation time")
        }
        HueCompassTest.checkFrame(second, snapshot: secondSnapshot, "fog drift")
        session.qualityPin = 0
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await HueCompassTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            #expect(shell.presenter.scene.gainLimit == HueCompassShaders.gainLimit(reduceFlashing: reduceFlashing))
            HueCompassTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try HueCompassTest.still(session)
            means.append(HueCompassTest.meanLuminance(rgba))
            HueCompassTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                      "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        print("hue-compass glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(HueCompassShaders.gainLimit(reduceFlashing: true) < HueCompassShaders.gainLimit(reduceFlashing: false))
        #expect(HueCompassShaders.glowGain(gain: HueCompassShaders.standardGain,
                                           limit: HueCompassShaders.gainLimit(reduceFlashing: true))
                < HueCompassShaders.glowGain(gain: HueCompassShaders.standardGain,
                                             limit: HueCompassShaders.gainLimit(reduceFlashing: false)))
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 80)
        _ = try HueCompassTest.probeTwice(shell)
        let before: String = try HueCompassTest.digest(shell)
        let host = try #require(session.renderHost)
        try HueCompassTest.draw(session, frames: 2)
        let image: [UInt8] = try HueCompassTest.still(session)
        try HueCompassTest.draw(session, frames: 1)
        let held = host.resources.stats.totalBytes
        shell.presenter.shedCaches()
        let shed = host.resources.stats.totalBytes
        #expect(shed < held, "the GPU objects were released: \(held) → \(shed) bytes")
        try HueCompassTest.draw(session, frames: 1)
        let rebuilt = host.resources.stats.totalBytes
        #expect(rebuilt > shed, "the next frame rebuilt them: \(shed) → \(rebuilt) bytes")
        let again: [UInt8] = try HueCompassTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        HueCompassTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot),
                                  "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try HueCompassTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(try HueCompassTest.digest(shell) == before)
    }
}
#endif
