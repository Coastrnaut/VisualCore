// FacetedForgeFallbackTests — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-003, 004, 007; SC-R02G0803-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a crystal program that does not
// compile (the presenter's seam, before `setup`) draws the level-2 geometry unlit with the shared mesh renderer (the
// ground-coloured corners, the pieces, the preview and the cut mark), keeps the reason at every tier, declares no frame
// probes and leaves the digest untouched; a live resize and a zero-size view draw nothing wrong and recover, and every
// reference point (piece centres, cut face centres, preview, mark bars) stays inside the 5 % margin for aspects
// 0.4 … 2.5; a memory warning releases the GPU objects and the next frame rebuilds them and draws the same image;
// Reduce Motion holds the snapshot time at 0 (the shimmer still, frames at different times identical) and shows the
// opening at its full distance at once, while without it the opening eases over 0.4 s and the shimmer moves; Reduce
// Flashing lowers the scene's glow limit to `FacetedForgeShaders.glowGainCap`; the frame probes are the two ground
// corners after a real frame. Short runs only.
#if os(iOS)
import CoreGraphics
import FacetedForgeCore
import Foundation
import Testing
import UIKit
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct FacetedForgeFallbackTests {
    @Test func aBrokenCrystalProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0) { $0.breakCrystalShader() }
        let presenter: FacetedForgePresenter = shell.presenter
        try FacetedForgeTest.advance(shell)
        let before: String = try FacetedForgeTest.digest(shell)
        let rgba: [UInt8] = try FacetedForgeTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("faceted-forge fallback reason: \(reason)")
        #expect(reason.contains("faceted-forge shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(FacetedForgeTest.nonGroundPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the ground-coloured corners, the pieces, the preview and the mark (the cut-face
        // check is left out: the shared mesh renderer's culling differs from the crystal program's).
        let snapshot: FacetedForgeSceneSnapshot = try #require(presenter.lastSnapshot)
        FacetedForgeTest.checkFrame(rgba, snapshot: snapshot, reduceMotion: presenter.reduceMotion, cutFaces: false,
                                    "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try FacetedForgeTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            FacetedForgeTest.pin(session, shell, tier: tier)
            try FacetedForgeTest.draw(session, frames: 2)
            let again: [UInt8] = try FacetedForgeTest.still(session)
            #expect(FacetedForgeTest.nonGroundPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try FacetedForgeTest.digest(shell) == before)
    }

    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        // The same actions on a working and on a broken presenter end in the same digest.
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await FacetedForgeTest.open(session, seed: 20) { (presenter: FacetedForgePresenter) in
                if broken { presenter.breakCrystalShader() }
            }
            try FacetedForgeTest.advance(shell)
            try FacetedForgeTest.draw(session, frames: 2)
            _ = try FacetedForgeTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try FacetedForgeTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 20)
        try FacetedForgeTest.advance(shell)
        let before: String = try FacetedForgeTest.digest(shell)
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
        let snapshot0: FacetedForgeSceneSnapshot = try FacetedForgeTest.core(shell).snapshot(time: 0)
        let camera: FacetedForgeCamera = FacetedForgeSceneGeometry.camera(snapshot0, aspect: 1)
        #expect(FacetedForgeSceneGeometry.pixel(SIMD3<Double>(0, 0, 0), camera: camera, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try FacetedForgeTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try FacetedForgeTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try FacetedForgeTest.still(session)
        FacetedForgeTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                    reduceMotion: shell.presenter.reduceMotion, expectCutFace: true,
                                    "after a zero size")
        #expect(try FacetedForgeTest.digest(shell) == before)
    }

    @Test func aResizeKeepsTheCrystalInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 40)
        let reduceMotion: Bool = shell.presenter.reduceMotion
        try FacetedForgeTest.advance(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try FacetedForgeTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself; opened.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try FacetedForgeTest.still(session, width: w, height: h, time: 1)
            let snapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [Vec2?] = FacetedForgeTest.referencePixels(snapshot, reduceMotion: reduceMotion,
                                                                       width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            FacetedForgeTest.checkFrame(rgba, snapshot: snapshot, reduceMotion: reduceMotion, width: w, height: h,
                                        expectCutFace: true, what)
        }
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0)
        try FacetedForgeTest.advance(shell)
        let before: String = try FacetedForgeTest.digest(shell)
        let host = try #require(session.renderHost)
        try FacetedForgeTest.draw(session, frames: 2)
        let image: [UInt8] = try FacetedForgeTest.still(session)
        try FacetedForgeTest.draw(session, frames: 1)
        let held = host.resources.stats.totalBytes
        shell.presenter.shedCaches()
        let shed = host.resources.stats.totalBytes
        #expect(shed < held, "the GPU objects were released: \(held) → \(shed) bytes")
        try FacetedForgeTest.draw(session, frames: 1)
        let rebuilt = host.resources.stats.totalBytes
        #expect(rebuilt > shed, "the next frame rebuilt them: \(shed) → \(rebuilt) bytes")
        let again: [UInt8] = try FacetedForgeTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        FacetedForgeTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot),
                                    reduceMotion: shell.presenter.reduceMotion, expectCutFace: true,
                                    "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try FacetedForgeTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(try FacetedForgeTest.digest(shell) == before)
    }

    /// Reduce Motion: the snapshot time is held at 0, so two frames at different times are identical (the shimmer is
    /// still), and the opening is at its full distance at once.
    @Test func reduceMotionHoldsTheShimmerAndOpensAtOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0, reduceMotion: true)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.scene.reduceMotion)
        try FacetedForgeTest.advance(shell)
        FacetedForgeTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try FacetedForgeTest.still(session, time: 0.05)
        let firstSnapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0)
        try FacetedForgeTest.draw(session, frames: 5)
        let second: [UInt8] = try FacetedForgeTest.still(session, time: 2.75)
        let secondSnapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        // The opening is full although the snapshot time is 0.
        let full: Double = secondSnapshot.won ? FacetedForgeSceneGeometry.wonOpeningDistance
            : FacetedForgeSceneGeometry.openingDistance
        #expect(FacetedForgeSceneGeometry.opening(secondSnapshot, reduceMotion: true) == full)
        #expect(FacetedForgeSceneGeometry.opening(secondSnapshot, reduceMotion: false) == 0)
        var moved: Int = 0
        for index in secondSnapshot.pieces.indices {
            let opened: SIMD3<Double> = FacetedForgeSceneGeometry.pieceCentre(index, secondSnapshot, reduceMotion: true)
            if opened != secondSnapshot.pieces[index].centroid { moved += 1 }
        }
        #expect(moved > 0, "the pieces are drawn opened")
        FacetedForgeTest.checkFrame(second, snapshot: secondSnapshot, reduceMotion: true, expectCutFace: true,
                                    "Reduce Motion")
        session.qualityPin = 0
    }

    /// Without Reduce Motion the opening eases in over 0.4 s and the dispersion shimmer follows the presentation time.
    @Test func withoutReduceMotionTheOpeningEasesAndTheShimmerMoves() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0)
        try FacetedForgeTest.advance(shell)
        FacetedForgeTest.pin(session, shell, tier: 0)
        let easing: [UInt8] = try FacetedForgeTest.still(session, time: 0.2)
        let easingSnapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(easingSnapshot.time == 0.2)
        let half: Double = FacetedForgeSceneGeometry.opening(easingSnapshot)
        #expect(half > 0 && half < FacetedForgeSceneGeometry.openingDistance, "half-way opening \(half)")
        FacetedForgeTest.checkFrame(easing, snapshot: easingSnapshot, reduceMotion: false, expectCutFace: true,
                                    "opening easing")
        let first: [UInt8] = try FacetedForgeTest.still(session, time: 1.0)
        let firstSnapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 1.0)
        #expect(FacetedForgeSceneGeometry.opening(firstSnapshot) == FacetedForgeSceneGeometry.openingDistance)
        #expect(first != easing, "the opening moves the pieces")
        let second: [UInt8] = try FacetedForgeTest.still(session, time: 1.7)
        let secondSnapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 1.7)
        // The opening is complete at both times; only the shimmer moved.
        #expect(first != second, "the shimmer moves with the presentation time")
        FacetedForgeTest.checkFrame(second, snapshot: secondSnapshot, reduceMotion: false, expectCutFace: true,
                                    "shimmer moving")
        session.qualityPin = 0
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await FacetedForgeTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? FacetedForgeShaders.glowGainCap
                : FacetedForgeShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            try FacetedForgeTest.advance(shell)
            FacetedForgeTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try FacetedForgeTest.still(session)
            means.append(FacetedForgeTest.meanLuminance(rgba))
            FacetedForgeTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                        reduceMotion: shell.presenter.reduceMotion, expectCutFace: true,
                                        "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        print("faceted-forge glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(FacetedForgeShaders.glowGainCap < FacetedForgeShaders.standardGlowLimit)
        #expect(FacetedForgeShaders.glowLimit(reduceFlashing: true) == FacetedForgeShaders.glowGainCap)
        let tier0: FacetedForgeTier = FacetedForgeTier.of(0)
        let gain: Double = FacetedForgeShaders.glowGain(for: tier0)
        let capped: Double = FacetedForgeShaders.glowGain(
            gain: gain, limit: FacetedForgeShaders.glowLimit(reduceFlashing: true))
        let full: Double = FacetedForgeShaders.glowGain(
            gain: gain, limit: FacetedForgeShaders.glowLimit(reduceFlashing: false))
        #expect(capped <= FacetedForgeShaders.glowGainCap)
        #expect(capped < full)
    }

    @Test func theProbesAreTheGroundCornersAfterARealFrame() async throws {
        // None before a frame was drawn.
        let id: ExperienceID = FacetedForgeTest.id
        let bare: ExperienceShell<FacetedForgePresenter> = FacetedForgeExperience.make(id: id)
        let opening: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        // Two ground corners after a real frame.
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try FacetedForgeTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names == ["ground-top-left", "ground-bottom-right"])
        // Their pixels in the check-size still are the ground.
        let rgba: [UInt8] = try FacetedForgeTest.still(session)
        for probe in probes {
            let got = FacetedForgeTest.pixelAtFraction(rgba, probe.x, probe.y, width: FacetedForgeTest.width,
                                                       height: FacetedForgeTest.height)
            #expect(FacetedForgeTest.channelDistance(got.colour, FacetedForgePalette.ground)
                        <= FacetedForgeTest.backgroundTolerance, "\(probe.name): \(got.colour)")
        }
    }
}
#endif
