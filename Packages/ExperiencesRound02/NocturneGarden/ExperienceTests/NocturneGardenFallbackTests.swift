// NocturneGardenFallbackTests — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-003, 004, 007; SC-R02G0903-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a garden program that does not
// compile (the presenter's seam, before `setup`) draws the level-2 geometry unlit with the shared mesh renderer (the
// ground-coloured corners, the dark shadow on the mist, the gauge), keeps the reason at every tier, declares no frame
// probes and leaves the digest of the same actions untouched; a live resize and a zero-size view draw nothing wrong and
// recover, and every reference point (bed cell centres, gauge bars, lantern) stays inside the 5 % margin for aspects
// 0.4 … 2.5; a memory warning releases the scene's GPU objects (`liveObjectCount` 0) and the next frame rebuilds them
// and draws the same image; Reduce Motion holds the snapshot time at 0, so frames at different times are identical,
// while without it the mist drifts; Reduce Flashing lowers the scene's glow limit to `NocturneGardenShaders.glowGainCap`;
// the frame probes are the two ground corners after a real frame and none before. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import NocturneGardenCore
import Testing
import UIKit
@testable import NocturneGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct NocturneGardenFallbackTests {
    @Test func aBrokenGardenProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0) { $0.breakGardenShader() }
        let presenter: NocturneGardenPresenter = shell.presenter
        try NocturneGardenTest.advance(shell)
        let before: String = try NocturneGardenTest.digest(shell)
        let rgba: [UInt8] = try NocturneGardenTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("nocturne-garden fallback reason: \(reason)")
        #expect(reason.contains("nocturne-garden shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(NocturneGardenTest.nonGroundPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the ground-coloured corners, the shadow darker than the mist and the gauge (the
        // forbidden and target checks are left out: the fallback has no hatch pattern or emissive light).
        let snapshot: NocturneGardenSceneSnapshot = try #require(presenter.lastSnapshot)
        NocturneGardenTest.checkFrame(rgba, snapshot: snapshot, cells: false, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try NocturneGardenTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            NocturneGardenTest.pin(session, shell, tier: tier)
            try NocturneGardenTest.draw(session, frames: 2)
            let again: [UInt8] = try NocturneGardenTest.still(session)
            #expect(NocturneGardenTest.nonGroundPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try NocturneGardenTest.digest(shell) == before)
    }

    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        // The same actions on a working and on a broken presenter end in the same digest.
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await NocturneGardenTest.open(session, seed: 20) { (presenter: NocturneGardenPresenter) in
                if broken { presenter.breakGardenShader() }
            }
            try NocturneGardenTest.advance(shell)
            try NocturneGardenTest.draw(session, frames: 2)
            _ = try NocturneGardenTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try NocturneGardenTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 20)
        try NocturneGardenTest.advance(shell)
        let before: String = try NocturneGardenTest.digest(shell)
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
        let snapshot0: NocturneGardenSceneSnapshot = try NocturneGardenTest.core(shell).snapshot(time: 0)
        let camera: NocturneGardenCamera = NocturneGardenSceneGeometry.camera(snapshot0, aspect: 1)
        #expect(NocturneGardenSceneGeometry.pixel(SIMD3<Double>(0, 0, 0), camera: camera, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try NocturneGardenTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try NocturneGardenTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try NocturneGardenTest.still(session)
        NocturneGardenTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "after a zero size")
        #expect(try NocturneGardenTest.digest(shell) == before)
    }

    @Test func aResizeKeepsTheGardenInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 40)
        try NocturneGardenTest.advance(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try NocturneGardenTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try NocturneGardenTest.still(session, width: w, height: h)
            let snapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [Vec2?] = NocturneGardenTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            NocturneGardenTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0)
        try NocturneGardenTest.advance(shell)
        let before: String = try NocturneGardenTest.digest(shell)
        try NocturneGardenTest.draw(session, frames: 2)
        let image: [UInt8] = try NocturneGardenTest.still(session)
        try NocturneGardenTest.draw(session, frames: 1)
        let scene: NocturneGardenGardenScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try NocturneGardenTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        let again: [UInt8] = try NocturneGardenTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        NocturneGardenTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot),
                                      "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try NocturneGardenTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try NocturneGardenTest.digest(shell) == before)
    }

    /// Reduce Motion: the snapshot time is held at 0, so two frames at different times are identical (the mist does not
    /// drift and the blooms do not sway).
    @Test func reduceMotionHoldsTheGardenStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0, reduceMotion: true)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.scene.reduceMotion)
        try NocturneGardenTest.advance(shell)
        NocturneGardenTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try NocturneGardenTest.still(session, time: 0.5)
        let firstSnapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0)
        try NocturneGardenTest.draw(session, frames: 5)
        let second: [UInt8] = try NocturneGardenTest.still(session, time: 2.75)
        let secondSnapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        NocturneGardenTest.checkFrame(second, snapshot: secondSnapshot, "Reduce Motion")
        session.qualityPin = 0
    }

    /// Without Reduce Motion the mist drifts with the presentation time: frames at different times differ, and both
    /// pass the checks.
    @Test func withoutReduceMotionTheMistDrifts() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0)
        try NocturneGardenTest.advance(shell)
        NocturneGardenTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try NocturneGardenTest.still(session, time: 0.5)
        let firstSnapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0.5)
        let second: [UInt8] = try NocturneGardenTest.still(session, time: 2.75)
        let secondSnapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 2.75)
        #expect(first != second, "the mist drifts with the presentation time")
        NocturneGardenTest.checkFrame(first, snapshot: firstSnapshot, "mist at 0.5 s")
        NocturneGardenTest.checkFrame(second, snapshot: secondSnapshot, "mist at 2.75 s")
        session.qualityPin = 0
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await NocturneGardenTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? NocturneGardenShaders.glowGainCap
                : NocturneGardenShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            try NocturneGardenTest.advance(shell)
            NocturneGardenTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try NocturneGardenTest.still(session)
            means.append(NocturneGardenTest.meanLuminance(rgba))
            NocturneGardenTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                          "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        print("nocturne-garden glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(NocturneGardenShaders.glowGainCap < NocturneGardenShaders.standardGlowLimit)
        #expect(NocturneGardenShaders.glowLimit(reduceFlashing: true) == NocturneGardenShaders.glowGainCap)
        let gain: Double = NocturneGardenShaders.glowGain(for: NocturneGardenTier.of(0))
        let capped: Double = NocturneGardenShaders.glowGain(
            gain: gain, limit: NocturneGardenShaders.glowLimit(reduceFlashing: true))
        let full: Double = NocturneGardenShaders.glowGain(
            gain: gain, limit: NocturneGardenShaders.glowLimit(reduceFlashing: false))
        #expect(capped <= NocturneGardenShaders.glowGainCap)
        #expect(capped < full)
    }

    @Test func theProbesAreTheGroundCornersAfterARealFrame() async throws {
        // None before a frame was drawn.
        let id: ExperienceID = NocturneGardenTest.id
        let bare: ExperienceShell<NocturneGardenPresenter> = NocturneGardenExperience.make(id: id)
        let opening: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        // Two ground corners after a real frame.
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try NocturneGardenTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names == ["ground-top-left", "ground-bottom-right"])
        // Their pixels in the check-size still are the ground.
        let rgba: [UInt8] = try NocturneGardenTest.still(session)
        for probe in probes {
            let got = NocturneGardenTest.pixelAtFraction(rgba, probe.x, probe.y, width: NocturneGardenTest.width,
                                                         height: NocturneGardenTest.height)
            #expect(NocturneGardenTest.channelDistance(got.colour, NocturneGardenPalette.ground)
                        <= NocturneGardenTest.backgroundTolerance, "\(probe.name): \(got.colour)")
        }
    }
}
#endif
