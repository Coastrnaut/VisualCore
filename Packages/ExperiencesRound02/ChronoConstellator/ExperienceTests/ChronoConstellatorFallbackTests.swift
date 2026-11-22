// ChronoConstellatorFallbackTests — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-003, 007; SC-R02G0603-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a field program that does not
// compile (the presenter's seam, before `setup`) draws the level-2 geometry unlit with the shared mesh renderer (the
// field-coloured background, the stars and the target rings: the same frame checks), keeps the reason at every tier,
// declares no frame probes and leaves the digest untouched; a live resize and a zero-size view draw nothing wrong and
// recover, and every star, target and loop cell stays inside the 5 % margin for aspects 0.4 … 2.5; a memory warning
// releases the GPU objects and the next frame rebuilds them and draws the same image; Reduce Motion holds the snapshot
// time at 0 so frames at different times are identical, while without it the ribbon shimmer moves; Reduce Flashing caps
// the glow at `ChronoConstellatorShaders.glowGainCap`; the frame probes are the two field corners after a real frame.
// Short runs only.
#if os(iOS)
import ChronoConstellatorCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct ChronoConstellatorFallbackTests {
    @Test func aBrokenFieldProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 0) { $0.breakFieldShader() }
        let presenter: ChronoConstellatorPresenter = shell.presenter
        ChronoConstellatorTest.advance(shell)
        let before: String = try ChronoConstellatorTest.digest(shell)
        let rgba: [UInt8] = try ChronoConstellatorTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("chrono-constellator fallback reason: \(reason)")
        #expect(reason.contains("chrono-constellator shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(ChronoConstellatorTest.nonFieldPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the field-coloured background, the stars and the rings: the same checks.
        let snapshot: ChronoConstellatorSceneSnapshot = try #require(presenter.lastSnapshot)
        ChronoConstellatorTest.checkFrame(rgba, snapshot: snapshot, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try ChronoConstellatorTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            ChronoConstellatorTest.pin(session, shell, tier: tier)
            try ChronoConstellatorTest.draw(session, frames: 2)
            let again: [UInt8] = try ChronoConstellatorTest.still(session)
            #expect(ChronoConstellatorTest.nonFieldPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try ChronoConstellatorTest.digest(shell) == before)
    }

    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        // The same actions on a working and on a broken presenter end in the same digest.
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ChronoConstellatorTest.open(session, seed: 20) { presenter in
                if broken { presenter.breakFieldShader() }
            }
            ChronoConstellatorTest.advance(shell)
            try ChronoConstellatorTest.draw(session, frames: 2)
            _ = try ChronoConstellatorTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try ChronoConstellatorTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 20)
        ChronoConstellatorTest.advance(shell)
        let before: String = try ChronoConstellatorTest.digest(shell)
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
        let snapshot0: ChronoConstellatorSceneSnapshot = try ChronoConstellatorTest.core(shell).snapshot(time: 0)
        let camera: ChronoConstellatorCamera = ChronoConstellatorSceneGeometry.camera(snapshot0, aspect: 1)
        #expect(ChronoConstellatorSceneGeometry.pixel(SIMD3<Double>(0, 0, 0), camera: camera, width: 0,
                                                      height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try ChronoConstellatorTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try ChronoConstellatorTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try ChronoConstellatorTest.still(session)
        ChronoConstellatorTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                          "after a zero size")
        #expect(try ChronoConstellatorTest.digest(shell) == before)
    }

    @Test func aResizeKeepsTheSkyInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 40)
        ChronoConstellatorTest.advance(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try ChronoConstellatorTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try ChronoConstellatorTest.still(session, width: w, height: h)
            let snapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every star centre, target centre and loop cell centre lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            for reference in ChronoConstellatorTest.referencePixels(snapshot, width: w, height: h) {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) reference points outside the 5 % margin")
            ChronoConstellatorTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 0)
        ChronoConstellatorTest.advance(shell)
        let before: String = try ChronoConstellatorTest.digest(shell)
        let host = try #require(session.renderHost)
        try ChronoConstellatorTest.draw(session, frames: 2)
        let image: [UInt8] = try ChronoConstellatorTest.still(session)
        try ChronoConstellatorTest.draw(session, frames: 1)
        let held = host.resources.stats.totalBytes
        shell.presenter.shedCaches()
        let shed = host.resources.stats.totalBytes
        #expect(shed < held, "the GPU objects were released: \(held) → \(shed) bytes")
        try ChronoConstellatorTest.draw(session, frames: 1)
        let rebuilt = host.resources.stats.totalBytes
        #expect(rebuilt > shed, "the next frame rebuilt them: \(shed) → \(rebuilt) bytes")
        let again: [UInt8] = try ChronoConstellatorTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        ChronoConstellatorTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot),
                                          "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try ChronoConstellatorTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(try ChronoConstellatorTest.digest(shell) == before)
    }

    @Test func reduceMotionHoldsTheShimmerStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 0, reduceMotion: true)
        ChronoConstellatorTest.advance(shell)
        let first: [UInt8] = try ChronoConstellatorTest.still(session, time: 0.5)
        let firstSnapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0)
        try ChronoConstellatorTest.draw(session, frames: 5)
        let second: [UInt8] = try ChronoConstellatorTest.still(session, time: 2.75)
        let secondSnapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        ChronoConstellatorTest.checkFrame(second, snapshot: secondSnapshot, "Reduce Motion")
    }

    @Test func withoutReduceMotionTheShimmerMoves() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 0)
        ChronoConstellatorTest.advance(shell)
        ChronoConstellatorTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try ChronoConstellatorTest.still(session, time: 0.5)
        let firstSnapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0.5)
        let second: [UInt8] = try ChronoConstellatorTest.still(session, time: 1.25)
        let secondSnapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 1.25)
        // The shimmer scales the glow (star discs and ribbons) with the presentation time.
        #expect(first != second, "the shimmer moves with the presentation time")
        ChronoConstellatorTest.checkFrame(second, snapshot: secondSnapshot, "shimmer moving")
        session.qualityPin = 0
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ChronoConstellatorTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? ChronoConstellatorShaders.glowGainCap
                : ChronoConstellatorShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            ChronoConstellatorTest.advance(shell)
            ChronoConstellatorTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try ChronoConstellatorTest.still(session)
            means.append(ChronoConstellatorTest.meanLuminance(rgba))
            ChronoConstellatorTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                              "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        print("chrono-constellator glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(ChronoConstellatorShaders.glowLimit(reduceFlashing: true) == ChronoConstellatorShaders.glowGainCap)
        let tier0: ChronoConstellatorTier = ChronoConstellatorTier.of(0)
        let gain: Double = ChronoConstellatorShaders.glowGain(for: tier0)
        let capped: Double = ChronoConstellatorShaders.glowGain(
            gain: gain, limit: ChronoConstellatorShaders.glowLimit(reduceFlashing: true))
        let full: Double = ChronoConstellatorShaders.glowGain(
            gain: gain, limit: ChronoConstellatorShaders.glowLimit(reduceFlashing: false))
        #expect(capped <= ChronoConstellatorShaders.glowGainCap)
        #expect(capped < full)
    }

    @Test func theProbesAreTheFieldCornersAfterARealFrame() async throws {
        // None before a frame was drawn.
        let id: ExperienceID = ChronoConstellatorTest.id
        let bare: ExperienceShell<ChronoConstellatorPresenter> = ChronoConstellatorExperience.make(id: id)
        let opening: ChronoConstellatorExperienceCore = try ChronoConstellatorExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        // Two field corners after a real frame.
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try ChronoConstellatorTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names == ["field-top-left", "field-bottom-right"])
        // Their pixels in the check-size still are the field.
        let rgba: [UInt8] = try ChronoConstellatorTest.still(session)
        for probe in probes {
            let got = ChronoConstellatorTest.pixelAtFraction(rgba, probe.x, probe.y,
                                                             width: ChronoConstellatorTest.width,
                                                             height: ChronoConstellatorTest.height)
            #expect(ChronoConstellatorTest.channelDistance(got.colour, ChronoConstellatorPalette.field)
                        <= ChronoConstellatorTest.backgroundTolerance, "\(probe.name): \(got.colour)")
        }
    }
}
#endif
