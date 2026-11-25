// CelestialEclipseLabFallbackTests — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-003, 004, 007;
// clarifications Q1, Q4; spec Edge Cases). Through the one app's session host, off screen: a sky program that does not
// compile (the presenter's seam `breakSkyShader()`, before `setup`) draws the level-2 geometry unlit with the shared
// mesh renderer (the backdrop gradient, the ivory body discs, the gold actions bars, the timeline strip), keeps
// `fallbackReason` at every tier, keeps running, declares no frame probes and leaves the state unchanged and the digest
// of the same actions untouched; a live resize and a zero-size view draw nothing wrong, throw nothing and recover, and
// every reference point stays inside the 5 % margin for aspects 0.4 … 2.5; a memory warning (`shedCaches`) releases the
// scene's GPU objects (`liveObjectCount` 0) and the next frame rebuilds them (`skyBuilds` rises) and draws the same
// image; Reduce Motion holds the halo pulse (`lastPulse` 1), so frames at different times are identical, are not
// rebuilt and equal the full-motion frame at time 0; with full motion the pulse follows
// `CelestialEclipseLabShaders.haloPulse` while the meshes are not rebuilt as long as only the time moves; Reduce
// Flashing lowers the scene's glow limit to `CelestialEclipseLabShaders.glowGainCap`. Short runs only.
#if os(iOS)
import CelestialEclipseLabCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import CelestialEclipseLabExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct CelestialEclipseLabFallbackTests {
    /// A sky program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier; the
    /// state is unchanged.
    @Test func aBrokenSkyProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 60) { $0.breakSkyShader() }
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        let before: String = try CelestialEclipseLabTest.digest(shell)
        let payload: Data = try CelestialEclipseLabTest.core(shell).snapshotPayload()
        let rgba: [UInt8] = try CelestialEclipseLabTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("celestial-eclipse-lab fallback reason: \(reason)")
        #expect(reason.contains("celestial-eclipse-lab shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(CelestialEclipseLabTest.drawnPixels(rgba) > 0, "the fallback frame draws something")
        #expect(presenter.scene.liveObjectCount > 0, "the fallback holds its unlit renderers")
        // The unlit fallback keeps the backdrop gradient, the ivory bodies, the gold bars and the timeline strip.
        let snapshot: CelestialEclipseLabSceneSnapshot = try #require(presenter.lastSnapshot)
        CelestialEclipseLabTest.checkFrame(rgba, snapshot: snapshot, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try CelestialEclipseLabTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            CelestialEclipseLabTest.pin(session, shell, tier: tier)
            try CelestialEclipseLabTest.draw(session, frames: 2)
            let again: [UInt8] = try CelestialEclipseLabTest.still(session)
            #expect(CelestialEclipseLabTest.drawnPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 geometry unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try CelestialEclipseLabTest.digest(shell) == before, "the fallback leaves the state")
        #expect(try CelestialEclipseLabTest.core(shell).snapshotPayload() == payload)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(21)
        let first: [CelestialEclipseLabAction] = Array(plan.prefix(2))
        #expect(!first.isEmpty, "level 21 has a certified change")
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await CelestialEclipseLabTest.open(session, seed: 20) {
                (presenter: CelestialEclipseLabPresenter) in
                if broken { presenter.breakSkyShader() }
            }
            #expect(CelestialEclipseLabTest.issue(shell, first) == first.count)
            try CelestialEclipseLabTest.draw(session, frames: 2)
            _ = try CelestialEclipseLabTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try CelestialEclipseLabTest.digest(shell))
        }
        #expect(digests.count == 2 && digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 0)
        let before: String = try CelestialEclipseLabTest.digest(shell)
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
        let snapshot0: CelestialEclipseLabSceneSnapshot = try CelestialEclipseLabTest.core(shell).snapshot(time: 0)
        #expect(CelestialEclipseLabTest.pixel(SIMD3<Double>(0, 0, 0), snapshot0, width: 0, height: 0) == nil)
        #expect(CelestialEclipseLabTest.referencePixels(snapshot0, width: 0, height: 0).isEmpty)
        #expect(CelestialEclipseLabTest.layout(snapshot0, width: 0, height: 0).order.isEmpty)
        #expect(CelestialEclipseLabTest.backdrop(snapshot0, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try CelestialEclipseLabTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try CelestialEclipseLabTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try CelestialEclipseLabTest.still(session)
        let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        CelestialEclipseLabTest.checkFrame(rgba, snapshot: snapshot, "after a zero size")
        #expect(try CelestialEclipseLabTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheSkyInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 80)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try CelestialEclipseLabTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try CelestialEclipseLabTest.still(session, width: w, height: h)
            let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = CelestialEclipseLabTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(!references.isEmpty)
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            CelestialEclipseLabTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 40)
        let before: String = try CelestialEclipseLabTest.digest(shell)
        let image: [UInt8] = try CelestialEclipseLabTest.still(session)
        let scene: CelestialEclipseLabSkyScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let builds: Int = scene.skyBuilds
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try CelestialEclipseLabTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        #expect(scene.skyBuilds > builds, "the sky mesh was rebuilt")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try CelestialEclipseLabTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        CelestialEclipseLabTest.checkFrame(again, snapshot: snapshot, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try CelestialEclipseLabTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try CelestialEclipseLabTest.digest(shell) == before)
    }

    /// Reduce Motion: after a phase change the halo pulse is held at 1, so the frames at 0 s, 0.6 s and 1.3 s are
    /// identical and the meshes are not rebuilt; that frame equals the full-motion frame at time 0.
    @Test func reduceMotionHoldsTheHaloPulse() async throws {
        let change: CelestialEclipseLabAction = try #require(try CelestialEclipseLabTest.certifiedPlan(61).first,
                                                             "level 61 has a certified change")
        var starts: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await CelestialEclipseLabTest.open(session, seed: 60, reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.reduceMotion == reduceMotion)
            CelestialEclipseLabTest.pin(session, shell, tier: 0)
            #expect(CelestialEclipseLabTest.issue(shell, [change]) == 1)
            let start: [UInt8] = try CelestialEclipseLabTest.still(session, time: 0)
            let startSnapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion at time 0"
            #expect(startSnapshot.time == 0)
            #expect(shell.presenter.scene.lastPulse == 1, "\(what): the pulse at time 0")
            CelestialEclipseLabTest.checkFrame(start, snapshot: startSnapshot, what)
            starts.append(start)
            guard reduceMotion else { continue }
            let skyBuilds: Int = shell.presenter.scene.skyBuilds
            let glowBuilds: Int = shell.presenter.scene.glowBuilds
            let times: [Double] = [0.6, 1.3]
            for time in times {
                let later: [UInt8] = try CelestialEclipseLabTest.still(session, time: time)
                #expect(shell.presenter.scene.lastPulse == 1, "Reduce Motion: the pulse held at \(time) s")
                let laterSnapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(laterSnapshot.positions == startSnapshot.positions)
                #expect(laterSnapshot.shownTick == startSnapshot.shownTick, "time never advances the shown tick")
                #expect(later == start, "Reduce Motion: the frame at \(time) s differs from the frame at 0 s")
            }
            #expect(shell.presenter.scene.skyBuilds == skyBuilds, "no sky rebuild while only the time moves")
            #expect(shell.presenter.scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
            session.qualityPin = 0
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            #expect(starts[0] == starts[1], "the Reduce Motion frame differs from the full-motion frame at time 0")
        }
    }

    /// Full motion: the halo pulse follows the frame time (`haloPulse`) while the sky and glow meshes are not rebuilt
    /// and the shown tick stays; a pulsing halo, when one is under way, draws a different frame.
    @Test func theMeshesAreNotRebuiltWhileOnlyTimeMoves() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 40)
        CelestialEclipseLabTest.pin(session, shell, tier: 0)
        let start: [UInt8] = try CelestialEclipseLabTest.still(session, time: 0)
        let scene: CelestialEclipseLabSkyScene = shell.presenter.scene
        #expect(scene.lastPulse == 1)
        let skyBuilds: Int = scene.skyBuilds
        let glowBuilds: Int = scene.glowBuilds
        let times: [Double] = [0.6, 1.3, 50, 150]
        var differing: Int = 0
        var halos: Int = 0
        for time in times {
            let frame: [UInt8] = try CelestialEclipseLabTest.still(session, time: time)
            let want: Double = CelestialEclipseLabShaders.haloPulse(time: time, reduceMotion: false)
            #expect(Swift.abs(scene.lastPulse - want) < 1e-12, "pulse at \(time) s")
            if frame != start { differing += 1 }
            let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.shownTick == 0, "time never advances the shown tick")
            halos = 0
            for eclipse in snapshot.eclipses where CelestialEclipseLabSceneGeometry.hasHalo(eclipse) { halos += 1 }
            CelestialEclipseLabTest.checkFrame(frame, snapshot: snapshot, "pulse at \(time) s")
        }
        #expect(CelestialEclipseLabShaders.haloPulse(time: 0.6, reduceMotion: false) < 1, "the pulse moves")
        #expect(scene.skyBuilds == skyBuilds, "no sky rebuild while only the time moves")
        #expect(scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
        print("celestial-eclipse-lab pulse: halos \(halos), frames differing \(differing) of \(times.count)")
        if halos > 0 {
            #expect(differing > 0, "the pulsing halo draws no different frame at \(times) s")
        }
        session.qualityPin = 0
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await CelestialEclipseLabTest.open(session, seed: 40, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? CelestialEclipseLabShaders.glowGainCap
                : CelestialEclipseLabShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            CelestialEclipseLabTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try CelestialEclipseLabTest.still(session)
            let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            CelestialEclipseLabTest.checkFrame(rgba, snapshot: snapshot, "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        // The chosen ring always glows at level-0, so the capped glow draws a dimmer frame.
        #expect(stills.count == 2 && stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(CelestialEclipseLabShaders.glowGainCap < CelestialEclipseLabShaders.standardGlowLimit)
        #expect(CelestialEclipseLabShaders.glowLimit(reduceFlashing: true) == CelestialEclipseLabShaders.glowGainCap)
    }
}
#endif
