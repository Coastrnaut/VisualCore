// EchoCartographerFallbackTests — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-003, 004, 007; SC-R02G1103-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a chamber program that does not
// compile (the presenter's seam `breakChamberShader()`, before `setup`) draws the level-2 geometry unlit with the
// shared mesh renderer (the ground-coloured corners, the floor tiles, the wall tops, the gauge), keeps the reason at
// every tier, declares no frame probes and leaves the digest of the same actions untouched; a live resize and a
// zero-size view draw nothing wrong, throw nothing and recover, and every reference point (floor-tile centres, wall
// tops, the entry, markers, the gauge's first bar) stays inside the 5 % margin for aspects 0.4 … 2.5; a memory warning
// releases the scene's GPU objects (`liveObjectCount` 0) and the next frame rebuilds them and draws the same image;
// Reduce Motion draws the rings and flares at rest, so frames at different times are identical (while without it the
// pulse ring moves); Reduce Flashing lowers the scene's glow limit to `EchoCartographerShaders.glowGainCap`; an energy
// failure (pulses from the entry until the energy runs out, as `fixture-budget-out`) leaves the gauge's first bar
// unlit (its centre the unlit colour) and the description names the failing action. Short runs only.
#if os(iOS)
import CoreGraphics
import EchoCartographerCore
import Foundation
import Testing
import UIKit
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct EchoCartographerFallbackTests {
    /// A chamber program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier.
    @Test func aBrokenChamberProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0) { $0.breakChamberShader() }
        let presenter: EchoCartographerPresenter = shell.presenter
        try EchoCartographerTest.advance(shell)
        let before: String = try EchoCartographerTest.digest(shell)
        let rgba: [UInt8] = try EchoCartographerTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("echo-cartographer fallback reason: \(reason)")
        #expect(reason.contains("echo-cartographer shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(EchoCartographerTest.nonGroundPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the ground-coloured corners, the floor tiles, the dark mint wall tops and the gauge.
        let snapshot: EchoCartographerSceneSnapshot = try #require(presenter.lastSnapshot)
        EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, "fallback")
        // A floor-tile pixel is not ground.
        let clear = try #require(EchoCartographerTest.firstClearFloor(snapshot))
        let tolerance: Double = EchoCartographerTest.backgroundTolerance
        let notGround: Bool = EchoCartographerTest.anyPixel(
            rgba, near: clear.p, radius: EchoCartographerTest.pointRadius, width: EchoCartographerTest.width,
            height: EchoCartographerTest.height, where: { (c: SIMD3<Double>) -> Bool in
                EchoCartographerTest.channelDistance(c, EchoCartographerPalette.ground) > tolerance
            })
        #expect(notGround, "fallback floor \(clear.index)")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try EchoCartographerTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            EchoCartographerTest.pin(session, shell, tier: tier)
            try EchoCartographerTest.draw(session, frames: 2)
            let again: [UInt8] = try EchoCartographerTest.still(session)
            #expect(EchoCartographerTest.nonGroundPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry unlit and has no time input, so every tier draws the
            // same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try EchoCartographerTest.digest(shell) == before)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        // The same actions on a working and on a broken presenter end in the same digest.
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await EchoCartographerTest.open(session, seed: 20) {
                (presenter: EchoCartographerPresenter) in
                if broken { presenter.breakChamberShader() }
            }
            try EchoCartographerTest.advance(shell)
            try EchoCartographerTest.draw(session, frames: 2)
            _ = try EchoCartographerTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try EchoCartographerTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 20)
        try EchoCartographerTest.advance(shell)
        let before: String = try EchoCartographerTest.digest(shell)
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
        let snapshot0: EchoCartographerSceneSnapshot = try EchoCartographerTest.core(shell).snapshot(time: 0)
        #expect(EchoCartographerTest.pixel(SIMD3<Double>(0, 0, 0), snapshot0, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try EchoCartographerTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try EchoCartographerTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try EchoCartographerTest.still(session)
        let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, "after a zero size")
        #expect(try EchoCartographerTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheChamberInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 40)
        try EchoCartographerTest.advance(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try EchoCartographerTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try EchoCartographerTest.still(session, width: w, height: h)
            let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = EchoCartographerTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0)
        try EchoCartographerTest.advance(shell)
        let before: String = try EchoCartographerTest.digest(shell)
        try EchoCartographerTest.draw(session, frames: 2)
        let image: [UInt8] = try EchoCartographerTest.still(session)
        try EchoCartographerTest.draw(session, frames: 1)
        let scene: EchoCartographerChamberScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try EchoCartographerTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        let again: [UInt8] = try EchoCartographerTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        EchoCartographerTest.checkFrame(again, snapshot: snapshot, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try EchoCartographerTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try EchoCartographerTest.digest(shell) == before)
    }

    /// Reduce Motion: the rings and flares are drawn at rest, so two frames at different times after a pulse are
    /// identical; without it, the pulse ring is visible early and gone later, so the same two times differ.
    @Test func reduceMotionHoldsTheRingsAtRest() async throws {
        var stills: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await EchoCartographerTest.open(session, seed: 0, reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.reduceMotion == reduceMotion)
            try EchoCartographerTest.advance(shell)
            EchoCartographerTest.pin(session, shell, tier: 0)
            // The first draw after the pulse starts the rings' clock at its frame time (0), so the next stills are
            // 0.15 s (pulse ring 1.5 cells out, fading) and 2.75 s (long gone) after the pulse.
            _ = try EchoCartographerTest.still(session, time: 0)
            let early: [UInt8] = try EchoCartographerTest.still(session, time: 0.15)
            let earlySnapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let late: [UInt8] = try EchoCartographerTest.still(session, time: 2.75)
            let lateSnapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(earlySnapshot.time < lateSnapshot.time, "\(earlySnapshot.time) \(lateSnapshot.time)")
            let what: String = reduceMotion ? "Reduce Motion" : "full motion"
            EchoCartographerTest.checkFrame(late, snapshot: lateSnapshot, what)
            stills.append(early)
            stills.append(late)
            session.qualityPin = 0
        }
        #expect(stills[0] == stills[1], "Reduce Motion: the two frames differ")
        #expect(stills[2] != stills[3], "full motion: the pulse ring does not move")
        // At rest the late frame is the same with or without Reduce Motion (the ring has faded, the flare ended).
        #expect(stills[1] == stills[3], "the resting frame differs between the modes")
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await EchoCartographerTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? EchoCartographerShaders.glowGainCap
                : EchoCartographerShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            try EchoCartographerTest.advance(shell)
            EchoCartographerTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try EchoCartographerTest.still(session)
            let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        #expect(EchoCartographerShaders.glowGainCap < EchoCartographerShaders.standardGlowLimit)
        #expect(EchoCartographerShaders.glowLimit(reduceFlashing: true) == EchoCartographerShaders.glowGainCap)
    }

    /// An energy failure (pulses from the entry until the energy runs out, as `fixture-budget-out`): the play fails on
    /// the last pulse, the gauge's first bar is unlit (its centre the unlit colour), the description and the mirror
    /// name the failing action, and undo returns the play to playing with the bar lit again.
    @Test func anEnergyFailureEmptiesTheGauge() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0)
        let budget: Int = try EchoCartographerTest.core(shell).play.level.energy
        #expect(budget == 9, "level 1 has 9 energy")
        let pulses: Int = try EchoCartographerTest.pulseUntilEmpty(shell)
        #expect(pulses == budget, "every pulse until the energy ran out was accepted")
        let core: EchoCartographerExperienceCore = try EchoCartographerTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage.rawValue)")
        #expect(core.play.failure == .energy(budget - 1))
        #expect(core.outcome?.code == EchoCartographerExperienceCore.failedCode)
        let text: String = shell.presenter.describe(core)
        let named: String = "The energy ran out on action \(budget)."
        #expect(text.contains(named), "\(text)")
        #expect(text.contains("0 energy left"), "\(text)")
        let status: String = shell.presenter.mirror.status
        #expect(status.hasPrefix("Failed: "), "\(status)")
        #expect(status.contains(named), "\(status)")
        // A refused pulse after the failure changes nothing.
        let digest: String = try EchoCartographerTest.digest(shell)
        let entry: EchoCartographerCell = core.play.level.entry
        #expect(shell.handle(control: "cell.pulse", values: [Double(entry.x), Double(entry.y)]) != .accepted)
        #expect(try EchoCartographerTest.digest(shell) == digest)
        // The frame: every bar unlit; the gauge's first bar is the unlit colour, not the lit one.
        let rgba: [UInt8] = try EchoCartographerTest.still(session)
        let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.energy == 0)
        #expect(snapshot.stage == .failed)
        #expect(EchoCartographerSceneGeometry.litBars(snapshot) == 0)
        EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, "energy failure")
        let p: SIMD2<Double> = try #require(EchoCartographerTest.gaugePixel(snapshot))
        let c: SIMD3<Double> = EchoCartographerTest.centre(rgba, p, width: EchoCartographerTest.width,
                                                           height: EchoCartographerTest.height)
        let unlit: Double = EchoCartographerTest.luminance(EchoCartographerPalette.gaugeUnlit)
        let lit: Double = EchoCartographerTest.luminance(EchoCartographerPalette.gaugeLit)
        let seen: Double = EchoCartographerTest.luminance(c)
        #expect(Swift.abs(seen - unlit) <= EchoCartographerTest.gaugeUnlitTolerance, "gauge bar 0 is \(c)")
        #expect(lit - seen >= 0.3, "gauge bar 0 is still lit: \(c)")
        // Undo returns the failed play to playing with one energy: the first bar is lit again.
        #expect(shell.handle(control: "play.undo") == .accepted)
        let undone: [UInt8] = try EchoCartographerTest.still(session)
        let undoneSnapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(undoneSnapshot.energy == 1)
        #expect(undoneSnapshot.stage == .playing)
        let back: SIMD3<Double> = EchoCartographerTest.centre(undone, p, width: EchoCartographerTest.width,
                                                              height: EchoCartographerTest.height)
        #expect(Swift.abs(EchoCartographerTest.luminance(back) - lit) <= 0.05, "gauge bar 0 after undo is \(back)")
    }
}
#endif
