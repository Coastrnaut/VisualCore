// HarmonicBridgesFallbackTests — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-003, 004, 007; SC-R02G1203-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a bridge program that does not
// compile (the presenter's seam `breakBridgeShader()`, before `setup`) draws the level-2 geometry unlit with the shared
// mesh renderer (the ground-coloured corners, the copper island tops, the cyan membranes, the gauge), keeps the reason
// at every tier, declares no frame probes and leaves the digest of the same actions untouched; a live resize and a
// zero-size view draw nothing wrong, throw nothing and recover, and every reference point (island tops, string
// midpoints, membrane check points, the gauge's first bar, the first step pip) stays inside the 5 % margin for aspects
// 0.4 … 2.5; a memory warning releases the scene's GPU objects (`liveObjectCount` 0) and the next frame rebuilds them and
// draws the same image; Reduce Motion draws the resting step with the strings at rest, so frames at different times
// are identical (while without it the strings swing, the shells grow and the shown step cycles); Reduce Flashing lowers
// the scene's glow limit to `HarmonicBridgesShaders.glowGainCap`. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import HarmonicBridgesCore
import Testing
import UIKit
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct HarmonicBridgesFallbackTests {
    /// A bridge program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier.
    @Test func aBrokenBridgeProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 40) { $0.breakBridgeShader() }
        let presenter: HarmonicBridgesPresenter = shell.presenter
        try HarmonicBridgesTest.tune(shell)
        let before: String = try HarmonicBridgesTest.digest(shell)
        let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("harmonic-bridges fallback reason: \(reason)")
        #expect(reason.contains("harmonic-bridges shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(HarmonicBridgesTest.nonGroundPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the ground-coloured corners, the copper tops, the cyan membranes and the gauge.
        let snapshot: HarmonicBridgesSceneSnapshot = try #require(presenter.lastSnapshot)
        HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .fallback, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try HarmonicBridgesTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            HarmonicBridgesTest.pin(session, shell, tier: tier)
            try HarmonicBridgesTest.draw(session, frames: 2)
            let again: [UInt8] = try HarmonicBridgesTest.still(session)
            #expect(HarmonicBridgesTest.nonGroundPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry unlit with no time input, so every tier draws the same
            // picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try HarmonicBridgesTest.digest(shell) == before)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await HarmonicBridgesTest.open(session, seed: 10) {
                (presenter: HarmonicBridgesPresenter) in
                if broken { presenter.breakBridgeShader() }
            }
            try HarmonicBridgesTest.tune(shell)
            try HarmonicBridgesTest.draw(session, frames: 2)
            _ = try HarmonicBridgesTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try HarmonicBridgesTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 30)
        try HarmonicBridgesTest.tune(shell)
        let before: String = try HarmonicBridgesTest.digest(shell)
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
        // The CPU reference refuses a zero-size target.
        let snapshot0: HarmonicBridgesSceneSnapshot = try HarmonicBridgesTest.core(shell).snapshot(time: 0)
        #expect(HarmonicBridgesTest.pixel(SIMD3<Double>(0, 0, 0), snapshot0, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try HarmonicBridgesTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try HarmonicBridgesTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
        let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        // Live frames ran the step clock; the still's snapshot says which step it drew.
        HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0), require: false, "after a zero size")
        #expect(try HarmonicBridgesTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheBridgesInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 60)
        try HarmonicBridgesTest.tune(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try HarmonicBridgesTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try HarmonicBridgesTest.still(session, width: w, height: h)
            let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = HarmonicBridgesTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0), width: w, height: h,
                                           require: false, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 1)
        try HarmonicBridgesTest.tune(shell)
        let before: String = try HarmonicBridgesTest.digest(shell)
        let image: [UInt8] = try HarmonicBridgesTest.still(session)
        let scene: HarmonicBridgesBridgeScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try HarmonicBridgesTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try HarmonicBridgesTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        HarmonicBridgesTest.checkFrame(again, snapshot: snapshot, mode: .tier(0), "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try HarmonicBridgesTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try HarmonicBridgesTest.digest(shell) == before)
    }

    /// Reduce Motion: the resting step with the strings at rest, so frames at different times after a change are
    /// identical (and equal to level-2's resting frame); without it, the strings swing and the shown step cycles, so the
    /// same times differ.
    @Test func reduceMotionHoldsTheRestingStep() async throws {
        var stills: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await HarmonicBridgesTest.open(session, seed: 40, reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.reduceMotion == reduceMotion)
            HarmonicBridgesTest.pin(session, shell, tier: 0)
            try HarmonicBridgesTest.tune(shell)
            // The first draw after the last tuning starts the step clock at its frame time (0), so the next stills
            // are 0.4 s (strings swung by cos(π n / 2), shells grown) and 1.3 s (step 1 of 2 shown) after it.
            let start: [UInt8] = try HarmonicBridgesTest.still(session, time: 0)
            let startSnapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(startSnapshot.steps == 2, "level 41 has two steps")
            let mode: HarmonicBridgesDrawMode = .tier(0, reduceMotion: reduceMotion)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion"
            HarmonicBridgesTest.checkFrame(start, snapshot: startSnapshot, mode: mode, what)
            let swung: [UInt8] = try HarmonicBridgesTest.still(session, time: 0.4)
            let later: [UInt8] = try HarmonicBridgesTest.still(session, time: 1.3)
            let laterSnapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(laterSnapshot.shownStep == 1, "the shown step cycles with the time: \(laterSnapshot.time)")
            #expect(shell.presenter.scene.drawnStep(laterSnapshot, animate: true) == (reduceMotion ? 0 : 1))
            #expect(HarmonicBridgesSceneGeometry.drawnStep(laterSnapshot, reduceMotion: true) == 0)
            stills.append(start)
            stills.append(swung)
            stills.append(later)
            // At level-2 nothing moves either way; the resting frame at a later time.
            HarmonicBridgesTest.pin(session, shell, tier: 2)
            if reduceMotion {
                stills.append(try HarmonicBridgesTest.still(session, time: 1.3))
            } else {
                stills.append(try HarmonicBridgesTest.still(session, time: 0))
            }
            session.qualityPin = 0
        }
        #expect(stills[0] == stills[1], "Reduce Motion: the frames at 0 s and 0.4 s differ")
        #expect(stills[0] == stills[2], "Reduce Motion: the frame at 1.3 s left the resting step")
        #expect(stills[4] != stills[5], "full motion: the strings and shells do not move")
        #expect(stills[4] != stills[6], "full motion: the shown step does not cycle")
        // The Reduce Motion level-2 frame at 1.3 s is the resting step 0, as the full-motion level-2 frame at 0 s.
        #expect(stills[3] == stills[7], "the resting frame differs between the modes")
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await HarmonicBridgesTest.open(session, seed: 1, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? HarmonicBridgesShaders.glowGainCap
                : HarmonicBridgesShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            try HarmonicBridgesTest.tune(shell)
            HarmonicBridgesTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
            let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            // Since feature 416 Reduce Flashing also draws the strings at rest with the resting step and no wave shell,
            // so the reference is the Reduce Motion one.
            #expect(shell.presenter.scene.stringsAtRest == reduceFlashing)
            HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0, reduceMotion: reduceFlashing),
                                           "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        #expect(stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(HarmonicBridgesShaders.glowGainCap < HarmonicBridgesShaders.standardGlowLimit)
        #expect(HarmonicBridgesShaders.glowLimit(reduceFlashing: true) == HarmonicBridgesShaders.glowGainCap)
    }
}
#endif
