// AcousticConstellatorFallbackTests — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-003, 004, 007;
// SC-R02G1303-002; clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a constellation
// program that does not compile (the presenter's seam `breakConstellationShader()`, before `setup`) draws the level-2
// geometry unlit with the shared mesh renderer (the sky-coloured corners, the white star centres, the teal links, the
// moves gauge), keeps `fallbackReason` at every tier, keeps running, declares no frame probes and leaves the digest of
// the same actions untouched; a live resize and a zero-size view draw nothing wrong, throw nothing and recover, and
// every reference point (star centres, link check points, the first coherence bar, the first hold pip, the first moves
// bar) stays inside the 5 % margin for aspects 0.4 … 2.5; a memory warning releases the scene's GPU objects
// (`liveObjectCount` 0) and the next frame rebuilds them and draws the same image; Reduce Motion draws tick 0 without
// the pulse and does not play the preview, so frames at different times are identical (while without it the stars
// pulse, the hands turn and the shown tick cycles); Reduce Flashing lowers the scene's glow limit to
// `AcousticConstellatorShaders.glowGainCap`. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import AcousticConstellatorCore
import Testing
import UIKit
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct AcousticConstellatorFallbackTests {
    /// A constellation program that does not compile draws the unlit level-2 fallback and keeps the reason at every
    /// tier.
    @Test func aBrokenConstellationProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 71) { $0.breakConstellationShader() }
        let presenter: AcousticConstellatorPresenter = shell.presenter
        try AcousticConstellatorTest.arrange(shell)
        let before: String = try AcousticConstellatorTest.digest(shell)
        let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("acoustic-constellator fallback reason: \(reason)")
        #expect(reason.contains("acoustic-constellator shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(AcousticConstellatorTest.nonSkyPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the sky-coloured corners, the white stars, the teal links and the moves gauge.
        let snapshot: AcousticConstellatorSceneSnapshot = try #require(presenter.lastSnapshot)
        AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .fallback, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try AcousticConstellatorTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            AcousticConstellatorTest.pin(session, shell, tier: tier)
            try AcousticConstellatorTest.draw(session, frames: 2)
            let again: [UInt8] = try AcousticConstellatorTest.still(session)
            #expect(AcousticConstellatorTest.nonSkyPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 geometry unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try AcousticConstellatorTest.digest(shell) == before)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AcousticConstellatorTest.open(session, seed: 43) {
                (presenter: AcousticConstellatorPresenter) in
                if broken { presenter.breakConstellationShader() }
            }
            try AcousticConstellatorTest.arrange(shell)
            try AcousticConstellatorTest.draw(session, frames: 2)
            _ = try AcousticConstellatorTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try AcousticConstellatorTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 23)
        try AcousticConstellatorTest.arrange(shell)
        let before: String = try AcousticConstellatorTest.digest(shell)
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
        let snapshot0: AcousticConstellatorSceneSnapshot = try AcousticConstellatorTest.core(shell).snapshot(time: 0)
        #expect(AcousticConstellatorTest.pixel(SIMD3<Double>(0, 0, 0), snapshot0, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try AcousticConstellatorTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try AcousticConstellatorTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
        let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        // Live frames ran the tick clock; the still's snapshot says which tick it drew.
        AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0), require: false,
                                            "after a zero size")
        #expect(try AcousticConstellatorTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheConstellationInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 81)
        try AcousticConstellatorTest.arrange(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try AcousticConstellatorTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try AcousticConstellatorTest.still(session, width: w, height: h)
            let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = AcousticConstellatorTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0), width: w, height: h,
                                                require: false, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 59)
        try AcousticConstellatorTest.arrange(shell)
        let before: String = try AcousticConstellatorTest.digest(shell)
        let image: [UInt8] = try AcousticConstellatorTest.still(session)
        let scene: AcousticConstellatorConstellationScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try AcousticConstellatorTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try AcousticConstellatorTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        AcousticConstellatorTest.checkFrame(again, snapshot: snapshot, mode: .tier(0), "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try AcousticConstellatorTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try AcousticConstellatorTest.digest(shell) == before)
    }

    /// Reduce Motion: tick 0 without the pulse and without the preview, so frames at different times after a change
    /// are identical (and equal to level-2's tick-0 frame); without it the stars pulse, the hands turn and the shown
    /// tick cycles, so the same times differ.
    @Test func reduceMotionHoldsTickZero() async throws {
        var stills: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AcousticConstellatorTest.open(session, seed: 43, reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.reduceMotion == reduceMotion)
            AcousticConstellatorTest.pin(session, shell, tier: 0)
            try AcousticConstellatorTest.arrange(shell)
            // The first draw after the last action starts the tick clock at its frame time (0), so the next stills
            // are 0.6 s (tick 2, other phases: the hands turn and the pulse changes) and 1.3 s (tick 5) after it.
            let start: [UInt8] = try AcousticConstellatorTest.still(session, time: 0)
            let startSnapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(startSnapshot.ticks > 5, "level 44's preview has more than five ticks: \(startSnapshot.ticks)")
            #expect(startSnapshot.phases(at: 2) != startSnapshot.phases(at: 0), "level 44's phases move by tick 2")
            let mode: AcousticConstellatorDrawMode = .tier(0, reduceMotion: reduceMotion)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion"
            AcousticConstellatorTest.checkFrame(start, snapshot: startSnapshot, mode: mode, what)
            let moved: [UInt8] = try AcousticConstellatorTest.still(session, time: 0.6)
            let later: [UInt8] = try AcousticConstellatorTest.still(session, time: 1.3)
            let laterSnapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(laterSnapshot.shownTick == 5, "the shown tick cycles with the time: \(laterSnapshot.time)")
            #expect(shell.presenter.scene.drawnTick(laterSnapshot, animate: true) == (reduceMotion ? 0 : 5))
            #expect(AcousticConstellatorSceneGeometry.drawnTick(laterSnapshot, reduceMotion: true) == 0)
            stills.append(start)
            stills.append(moved)
            stills.append(later)
            // At level-2 nothing pulses either way; the tick-0 frame at a later time under Reduce Motion.
            AcousticConstellatorTest.pin(session, shell, tier: 2)
            if reduceMotion {
                stills.append(try AcousticConstellatorTest.still(session, time: 1.3))
            } else {
                stills.append(try AcousticConstellatorTest.still(session, time: 0))
            }
            session.qualityPin = 0
        }
        #expect(stills[0] == stills[1], "Reduce Motion: the frames at 0 s and 0.6 s differ")
        #expect(stills[0] == stills[2], "Reduce Motion: the frame at 1.3 s left tick 0")
        #expect(stills[4] != stills[5], "full motion: the stars and hands do not move")
        #expect(stills[4] != stills[6], "full motion: the shown tick does not cycle")
        // The Reduce Motion level-2 frame at 1.3 s is tick 0, as the full-motion level-2 frame at 0 s.
        #expect(stills[3] == stills[7], "the tick-0 frame differs between the modes")
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AcousticConstellatorTest.open(session, seed: 59, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? AcousticConstellatorShaders.glowGainCap
                : AcousticConstellatorShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            try AcousticConstellatorTest.arrange(shell)
            AcousticConstellatorTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
            let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            // Since feature 426 Reduce Flashing also draws tick 0 without pulsing and with no wave shell, so the
            // reference is the Reduce Motion one.
            #expect(shell.presenter.scene.starsAtRest == reduceFlashing)
            AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0, reduceMotion: reduceFlashing),
                                                "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        #expect(stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(AcousticConstellatorShaders.glowGainCap < AcousticConstellatorShaders.standardGlowLimit)
        #expect(AcousticConstellatorShaders.glowLimit(reduceFlashing: true) == AcousticConstellatorShaders.glowGainCap)
    }
}
#endif
