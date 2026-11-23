// BackwardsAuroraFallbackTests — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-003, 004, 007; SC-R02G1003-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: an aurora program that does not
// compile (the presenter's seam, before `setup`) draws the level-2 geometry unlit with the shared mesh renderer (the
// ground-coloured corners, the cyan ribbon, the gauge), keeps the reason at every tier, declares no frame probes and
// leaves the digest of the same actions untouched; a live resize and a zero-size view draw nothing wrong and recover,
// and every reference point (sample points, ring centres, the gauge's first bar) stays inside the 5 % margin for
// aspects 0.4 … 2.5; a memory warning releases the scene's GPU objects (`liveObjectCount` 0) and the next frame rebuilds
// them and draws the same image; Reduce Motion holds the snapshot time at 0, so frames at different times are
// identical; Reduce Flashing lowers the scene's glow limit to `BackwardsAuroraShaders.glowGainCap`; a reversal that
// tears (found by a deterministic search over the certified levels) names the seam in the description and marks it
// with the tear cross (red − blue at least 0.2 at the seam's sample point). Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import BackwardsAuroraCore
import Testing
import UIKit
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct BackwardsAuroraFallbackTests {
    @Test func aBrokenAuroraProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 0) { $0.breakAuroraShader() }
        let presenter: BackwardsAuroraPresenter = shell.presenter
        try BackwardsAuroraTest.advance(shell)
        let before: String = try BackwardsAuroraTest.digest(shell)
        let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("backwards-aurora fallback reason: \(reason)")
        #expect(reason.contains("backwards-aurora shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(BackwardsAuroraTest.nonGroundPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the ground-coloured corners, the cyan ribbon and the gauge (the ghost check is left
        // out: the fallback has no emissive light).
        let snapshot: BackwardsAuroraSceneSnapshot = try #require(presenter.lastSnapshot)
        BackwardsAuroraTest.checkFrame(rgba, snapshot: snapshot, ghost: false, "fallback")
        // The ribbon pixel is not ground.
        let clear = try #require(BackwardsAuroraTest.firstClearSample(snapshot))
        #expect(BackwardsAuroraTest.anyPixel(rgba, near: clear.p, radius: BackwardsAuroraTest.pointRadius,
                                             width: BackwardsAuroraTest.width, height: BackwardsAuroraTest.height,
                                             where: { (c: SIMD3<Double>) -> Bool in
                                                 BackwardsAuroraTest.channelDistance(c, BackwardsAuroraPalette.ground)
                                                     > BackwardsAuroraTest.backgroundTolerance
                                             }), "fallback ribbon at sample \(clear.k)")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try BackwardsAuroraTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            BackwardsAuroraTest.pin(session, shell, tier: tier)
            try BackwardsAuroraTest.draw(session, frames: 2)
            let again: [UInt8] = try BackwardsAuroraTest.still(session)
            #expect(BackwardsAuroraTest.nonGroundPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try BackwardsAuroraTest.digest(shell) == before)
    }

    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        // The same actions on a working and on a broken presenter end in the same digest.
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await BackwardsAuroraTest.open(session, seed: 20) { (presenter: BackwardsAuroraPresenter) in
                if broken { presenter.breakAuroraShader() }
            }
            try BackwardsAuroraTest.advance(shell)
            try BackwardsAuroraTest.draw(session, frames: 2)
            _ = try BackwardsAuroraTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try BackwardsAuroraTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 20)
        try BackwardsAuroraTest.advance(shell)
        let before: String = try BackwardsAuroraTest.digest(shell)
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
        let snapshot0: BackwardsAuroraSceneSnapshot = try BackwardsAuroraTest.core(shell).snapshot(
            sectionStart: 0, sectionEnd: 1, time: 0)
        #expect(BackwardsAuroraTest.pixel(SIMD3<Double>(0, 0, 0), snapshot0, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try BackwardsAuroraTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try BackwardsAuroraTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
        BackwardsAuroraTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "after a zero size")
        #expect(try BackwardsAuroraTest.digest(shell) == before)
    }

    @Test func aResizeKeepsTheAuroraInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 40)
        try BackwardsAuroraTest.advance(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try BackwardsAuroraTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try BackwardsAuroraTest.still(session, width: w, height: h)
            let snapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = BackwardsAuroraTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            BackwardsAuroraTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 0)
        try BackwardsAuroraTest.advance(shell)
        let before: String = try BackwardsAuroraTest.digest(shell)
        try BackwardsAuroraTest.draw(session, frames: 2)
        let image: [UInt8] = try BackwardsAuroraTest.still(session)
        try BackwardsAuroraTest.draw(session, frames: 1)
        let scene: BackwardsAuroraAuroraScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try BackwardsAuroraTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        let again: [UInt8] = try BackwardsAuroraTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        BackwardsAuroraTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot),
                                       "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try BackwardsAuroraTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try BackwardsAuroraTest.digest(shell) == before)
    }

    /// Reduce Motion: the snapshot time is held at 0, so two frames at different times are identical (the pulses and
    /// the shimmer stand still).
    @Test func reduceMotionHoldsTheAuroraStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 0, reduceMotion: true)
        #expect(shell.presenter.reduceMotion)
        #expect(shell.presenter.scene.reduceMotion)
        try BackwardsAuroraTest.advance(shell)
        BackwardsAuroraTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try BackwardsAuroraTest.still(session, time: 0.5)
        let firstSnapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0)
        try BackwardsAuroraTest.draw(session, frames: 5)
        let second: [UInt8] = try BackwardsAuroraTest.still(session, time: 2.75)
        let secondSnapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        BackwardsAuroraTest.checkFrame(second, snapshot: secondSnapshot, "Reduce Motion")
        session.qualityPin = 0
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await BackwardsAuroraTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? BackwardsAuroraShaders.glowGainCap
                : BackwardsAuroraShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            try BackwardsAuroraTest.advance(shell)
            BackwardsAuroraTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
            BackwardsAuroraTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                           "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        #expect(BackwardsAuroraShaders.glowGainCap < BackwardsAuroraShaders.standardGlowLimit)
        #expect(BackwardsAuroraShaders.glowLimit(reduceFlashing: true) == BackwardsAuroraShaders.glowGainCap)
    }

    /// A reversal that tears (found by `BackwardsAuroraTest.tearFailure`) names the seam in the description and marks
    /// the seam with the tear cross.
    @Test func aTearMarksItsSeam() async throws {
        let found = try #require(try BackwardsAuroraTest.tearFailure(), "a reversal of some level tears")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: UInt64(found.level - 1))
        let issued = BackwardsAuroraTest.control(found.action)
        #expect(shell.handle(control: issued.control, values: issued.values) == .accepted,
                "\(issued.control) \(issued.values)")
        let core: BackwardsAuroraExperienceCore = try BackwardsAuroraTest.core(shell)
        #expect(core.play.stage == .failed)
        #expect(core.play.failure == .tear(0, found.seam))
        #expect(core.outcome?.code == BackwardsAuroraExperienceCore.failedCode)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The aurora tore at seam \(found.seam) on reversal 1."), "\(text)")
        #expect(shell.presenter.mirror.status.hasPrefix("Failed: "), "\(shell.presenter.mirror.status)")
        // Level-2 draws no glow shells, so nothing additive lies over the cross.
        BackwardsAuroraTest.pin(session, shell, tier: 2)
        let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
        let snapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.tear == found.seam)
        let seamPoint: SIMD3<Double> = BackwardsAuroraSceneGeometry.samplePoint(found.seam, snapshot)
        let centre: SIMD3<Double> = SIMD3<Double>(seamPoint.x, seamPoint.y, BackwardsAuroraSceneGeometry.crossZ)
        let p = try #require(BackwardsAuroraTest.pixel(centre, snapshot), "the seam projects")
        let warmth: Double = BackwardsAuroraTest.tearWarmth
        let marked: Bool = BackwardsAuroraTest.anyPixel(
            rgba, near: p, radius: BackwardsAuroraTest.pointRadius, width: BackwardsAuroraTest.width,
            height: BackwardsAuroraTest.height, where: { (c: SIMD3<Double>) -> Bool in c.x - c.z >= warmth })
        let seen: SIMD3<Double> = BackwardsAuroraTest.centre(rgba, p, width: BackwardsAuroraTest.width,
                                                             height: BackwardsAuroraTest.height)
        #expect(marked, "level \(found.level) seam \(found.seam) at (\(p.x), \(p.y)) is \(seen)")
        BackwardsAuroraTest.checkFrame(rgba, snapshot: snapshot, "tear level \(found.level)")
        session.qualityPin = 0
        print("backwards-aurora tear: level \(found.level), \(found.action), seam \(found.seam)")
    }
}
#endif
