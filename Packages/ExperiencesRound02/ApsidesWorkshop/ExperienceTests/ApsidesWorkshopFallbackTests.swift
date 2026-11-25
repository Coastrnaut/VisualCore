// ApsidesWorkshopFallbackTests — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-003, 004, 007; SC-R02G1803-002;
// clarifications Q1, Q4; spec Edge Cases). Through the one app's session host, off screen at the shown tick T/2: a
// compass program that does not compile (the presenter's seam `breakCompassShader()`, before `setup`) draws the level-2
// geometry unlit with the shared mesh renderer (the backdrop gradient, the star and orbiter discs, the deep rose
// actions bars, the gauge tracks), keeps `fallbackReason` at every tier, keeps running, declares no frame probes and
// leaves the state unchanged and the digest of the same actions untouched; a live resize and a zero-size view draw
// nothing wrong, throw nothing and recover, and every reference point stays inside the 5 % margin for aspects 0.4 …
// 2.5; a memory warning (`shedCaches`) releases the scene's GPU objects (`liveObjectCount` 0) and the next frame
// rebuilds them (`compassBuilds` rises) and draws the same image; Reduce Motion holds the star's pulse (`lastPulse` 1),
// so frames at different times are identical, are not rebuilt and equal the full-motion frame at time 0; with full
// motion the pulse follows `ApsidesWorkshopShaders.starPulse` while the meshes are not rebuilt as long as only the time
// moves; Reduce Flashing lowers the scene's glow limit to `ApsidesWorkshopShaders.glowGainCap`. Short runs only.
#if os(iOS)
import ApsidesWorkshopCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import ApsidesWorkshopExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct ApsidesWorkshopFallbackTests {
    /// A compass program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier;
    /// the state is unchanged.
    @Test func aBrokenCompassProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 60) { $0.breakCompassShader() }
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        let before: String = try ApsidesWorkshopTest.digest(shell)
        let payload: Data = try ApsidesWorkshopTest.core(shell).snapshotPayload()
        let rgba: [UInt8] = try ApsidesWorkshopTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("apsides-workshop fallback reason: \(reason)")
        #expect(reason.contains("apsides-workshop shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(ApsidesWorkshopTest.drawnPixels(rgba) > 0, "the fallback frame draws something")
        #expect(presenter.scene.liveObjectCount > 0, "the fallback holds its unlit renderers")
        // The unlit fallback keeps the backdrop gradient, the bright star and orbiter, the bars and the tracks.
        let snapshot: ApsidesWorkshopSceneSnapshot = try #require(presenter.lastSnapshot)
        #expect(snapshot.shownTick == ApsidesWorkshopTest.halfTick(snapshot.period), "the tick T/2")
        ApsidesWorkshopTest.checkFrame(rgba, snapshot: snapshot, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try ApsidesWorkshopTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            ApsidesWorkshopTest.pin(session, shell, tier: tier)
            try ApsidesWorkshopTest.draw(session, frames: 2)
            let again: [UInt8] = try ApsidesWorkshopTest.still(session)
            #expect(ApsidesWorkshopTest.drawnPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 geometry unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try ApsidesWorkshopTest.digest(shell) == before, "the fallback leaves the state")
        #expect(try ApsidesWorkshopTest.core(shell).snapshotPayload() == payload)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(21)
        let first: [ApsidesWorkshopAction] = Array(plan.prefix(2))
        #expect(!first.isEmpty, "level 21 has a certified tuning")
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ApsidesWorkshopTest.open(session, seed: 20) {
                (presenter: ApsidesWorkshopPresenter) in
                if broken { presenter.breakCompassShader() }
            }
            #expect(ApsidesWorkshopTest.issue(shell, first) == first.count)
            try ApsidesWorkshopTest.draw(session, frames: 2)
            _ = try ApsidesWorkshopTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try ApsidesWorkshopTest.digest(shell))
        }
        #expect(digests.count == 2 && digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 0)
        let before: String = try ApsidesWorkshopTest.digest(shell)
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
        let snapshot0: ApsidesWorkshopSceneSnapshot = try ApsidesWorkshopTest.core(shell).snapshot(time: 0)
        #expect(ApsidesWorkshopTest.pixel(SIMD3<Double>(0, 0, 0), width: 0, height: 0) == nil)
        #expect(ApsidesWorkshopTest.referencePixels(snapshot0, width: 0, height: 0).isEmpty)
        #expect(ApsidesWorkshopTest.layout(snapshot0, width: 0, height: 0).order.isEmpty)
        #expect(ApsidesWorkshopTest.backdrop(width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try ApsidesWorkshopTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try ApsidesWorkshopTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try ApsidesWorkshopTest.still(session)
        let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        ApsidesWorkshopTest.checkFrame(rgba, snapshot: snapshot, "after a zero size")
        #expect(try ApsidesWorkshopTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheCompassInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 80)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try ApsidesWorkshopTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try ApsidesWorkshopTest.still(session, width: w, height: h)
            let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = ApsidesWorkshopTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(references.count == ApsidesWorkshopTest.referenceCount(snapshot))
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            ApsidesWorkshopTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 40)
        let before: String = try ApsidesWorkshopTest.digest(shell)
        let image: [UInt8] = try ApsidesWorkshopTest.still(session)
        let scene: ApsidesWorkshopCompassScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let builds: Int = scene.compassBuilds
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try ApsidesWorkshopTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        #expect(scene.compassBuilds > builds, "the compass mesh was rebuilt")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try ApsidesWorkshopTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        ApsidesWorkshopTest.checkFrame(again, snapshot: snapshot, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try ApsidesWorkshopTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try ApsidesWorkshopTest.digest(shell) == before)
    }

    /// Reduce Motion: after a tuning the star's pulse is held at 1, so the frames at 0 s, 0.6 s and 1.3 s are
    /// identical and the meshes are not rebuilt; that frame equals the full-motion frame at time 0.
    @Test func reduceMotionHoldsTheStarPulse() async throws {
        let change: ApsidesWorkshopAction = try #require(try ApsidesWorkshopTest.certifiedPlan(61).first,
                                                         "level 61 has a certified tuning")
        var starts: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ApsidesWorkshopTest.open(session, seed: 60, reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.reduceMotion == reduceMotion)
            ApsidesWorkshopTest.pin(session, shell, tier: 0)
            #expect(ApsidesWorkshopTest.issue(shell, [change]) == 1)
            let start: [UInt8] = try ApsidesWorkshopTest.still(session, time: 0)
            let startSnapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion at time 0"
            #expect(startSnapshot.time == 0)
            #expect(shell.presenter.scene.lastPulse == 1, "\(what): the pulse at time 0")
            ApsidesWorkshopTest.checkFrame(start, snapshot: startSnapshot, what)
            starts.append(start)
            guard reduceMotion else { continue }
            let compassBuilds: Int = shell.presenter.scene.compassBuilds
            let glowBuilds: Int = shell.presenter.scene.glowBuilds
            let times: [Double] = [0.6, 1.3]
            for time in times {
                let later: [UInt8] = try ApsidesWorkshopTest.still(session, time: time)
                #expect(shell.presenter.scene.lastPulse == 1, "Reduce Motion: the pulse held at \(time) s")
                let laterSnapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(laterSnapshot.positions == startSnapshot.positions)
                #expect(laterSnapshot.shownTick == startSnapshot.shownTick, "time never advances the shown tick")
                #expect(later == start, "Reduce Motion: the frame at \(time) s differs from the frame at 0 s")
            }
            #expect(shell.presenter.scene.compassBuilds == compassBuilds, "no compass rebuild while only time moves")
            #expect(shell.presenter.scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
            session.qualityPin = 0
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            #expect(starts[0] == starts[1], "the Reduce Motion frame differs from the full-motion frame at time 0")
        }
    }

    /// Full motion: the star's pulse follows the frame time (`starPulse`) while the compass and glow meshes are not
    /// rebuilt and the shown tick stays; the pulsing star glow (level-0 always has it) draws a different frame.
    @Test func theMeshesAreNotRebuiltWhileOnlyTimeMoves() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 40)
        ApsidesWorkshopTest.pin(session, shell, tier: 0)
        let start: [UInt8] = try ApsidesWorkshopTest.still(session, time: 0)
        let scene: ApsidesWorkshopCompassScene = shell.presenter.scene
        #expect(scene.lastPulse == 1)
        let tick: Int = try #require(shell.presenter.lastSnapshot).shownTick
        let compassBuilds: Int = scene.compassBuilds
        let glowBuilds: Int = scene.glowBuilds
        let times: [Double] = [0.6, 1.3, 50, 150]
        var differing: Int = 0
        for time in times {
            let frame: [UInt8] = try ApsidesWorkshopTest.still(session, time: time)
            let want: Double = ApsidesWorkshopShaders.starPulse(time: time, reduceMotion: false)
            #expect(Swift.abs(scene.lastPulse - want) < 1e-12, "pulse at \(time) s")
            if frame != start { differing += 1 }
            let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.shownTick == tick, "time never advances the shown tick")
            ApsidesWorkshopTest.checkFrame(frame, snapshot: snapshot, "pulse at \(time) s")
        }
        #expect(ApsidesWorkshopShaders.starPulse(time: 0.6, reduceMotion: false) < 1, "the pulse moves")
        #expect(scene.compassBuilds == compassBuilds, "no compass rebuild while only the time moves")
        #expect(scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
        print("apsides-workshop pulse: frames differing \(differing) of \(times.count)")
        #expect(differing > 0, "the pulsing star glow draws no different frame at \(times) s")
        session.qualityPin = 0
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ApsidesWorkshopTest.open(session, seed: 40, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? ApsidesWorkshopShaders.glowGainCap
                : ApsidesWorkshopShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            ApsidesWorkshopTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try ApsidesWorkshopTest.still(session)
            let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            ApsidesWorkshopTest.checkFrame(rgba, snapshot: snapshot, "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        // The star, the orbit loop and the orbiter always glow at level-0, so the capped glow draws a dimmer frame.
        #expect(stills.count == 2 && stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(ApsidesWorkshopShaders.glowGainCap < ApsidesWorkshopShaders.standardGlowLimit)
        #expect(ApsidesWorkshopShaders.glowLimit(reduceFlashing: true) == ApsidesWorkshopShaders.glowGainCap)
    }
}
#endif
