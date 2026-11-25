// StarlitCartoucheFallbackTests — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-003, 004, 007; clarifications
// Q1, Q4; spec Edge Cases). Through the one app's session host, off screen: a chart program that does not compile (the
// presenter's seam `breakChartShader()`, before `setup`) draws the level-2 geometry unlit with the shared mesh renderer
// (the backdrop gradient, the pearl star centres, the sapphire ship, the actions gauge), keeps `fallbackReason` at
// every tier, keeps running, declares no frame probes and leaves the digest of the same actions untouched; a live
// resize and a zero-size view draw nothing wrong, throw nothing and recover, and every reference point stays inside
// the 5 % margin for aspects 0.4 … 2.5; a memory warning releases the scene's GPU objects (`liveObjectCount` 0) and the
// next frame rebuilds them and draws the same image; Reduce Motion stops the firmament (`lastFirmamentAngle` 0) and the
// glide (`lastGlide` 1 right after a leg), so frames at different times are identical and equal the full-motion frame
// at rest at time 0; with full motion the ship glides over `glideSeconds` and the firmament turns while the meshes are
// not rebuilt as long as only the time moves; Reduce Flashing lowers the scene's glow limit to
// `StarlitCartoucheShaders.glowGainCap`. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import StarlitCartoucheCore
import Testing
import UIKit
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct StarlitCartoucheFallbackTests {
    /// A chart program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier.
    @Test func aBrokenChartProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 60) { $0.breakChartShader() }
        let presenter: StarlitCartouchePresenter = shell.presenter
        let before: String = try StarlitCartoucheTest.digest(shell)
        let payload: Data = try StarlitCartoucheTest.core(shell).snapshotPayload()
        let rgba: [UInt8] = try StarlitCartoucheTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("starlit-cartouche fallback reason: \(reason)")
        #expect(reason.contains("starlit-cartouche shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(StarlitCartoucheTest.drawnPixels(rgba) > 0, "the fallback frame draws something")
        #expect(presenter.scene.liveObjectCount > 0, "the fallback holds its unlit renderers")
        // The unlit fallback keeps the backdrop gradient, the pearl stars, the sapphire ship and the actions gauge.
        let snapshot: StarlitCartoucheSceneSnapshot = try #require(presenter.lastSnapshot)
        StarlitCartoucheTest.checkFrame(rgba, snapshot: snapshot, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try StarlitCartoucheTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            StarlitCartoucheTest.pin(session, shell, tier: tier)
            try StarlitCartoucheTest.draw(session, frames: 2)
            let again: [UInt8] = try StarlitCartoucheTest.still(session)
            #expect(StarlitCartoucheTest.drawnPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 geometry unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try StarlitCartoucheTest.digest(shell) == before, "the fallback leaves the state")
        #expect(try StarlitCartoucheTest.core(shell).snapshotPayload() == payload)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(21)
        let first: [StarlitCartoucheAction] = Array(legs.prefix(2))
        #expect(!first.isEmpty, "level 21 has a certified leg")
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await StarlitCartoucheTest.open(session, seed: 20) {
                (presenter: StarlitCartouchePresenter) in
                if broken { presenter.breakChartShader() }
            }
            #expect(StarlitCartoucheTest.issue(shell, first) == first.count)
            try StarlitCartoucheTest.draw(session, frames: 2)
            _ = try StarlitCartoucheTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try StarlitCartoucheTest.digest(shell))
        }
        #expect(digests.count == 2 && digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 0)
        let before: String = try StarlitCartoucheTest.digest(shell)
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
        let snapshot0: StarlitCartoucheSceneSnapshot = try StarlitCartoucheTest.core(shell).snapshot(time: 0)
        #expect(StarlitCartoucheTest.pixel(SIMD3<Double>(0, 0, 0), snapshot0, width: 0, height: 0) == nil)
        #expect(StarlitCartoucheTest.referencePixels(snapshot0, width: 0, height: 0).isEmpty)
        #expect(StarlitCartoucheTest.layout(snapshot0, width: 0, height: 0).order.isEmpty)
        #expect(StarlitCartoucheTest.backdrop(snapshot0, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try StarlitCartoucheTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try StarlitCartoucheTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try StarlitCartoucheTest.still(session)
        let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        StarlitCartoucheTest.checkFrame(rgba, snapshot: snapshot, "after a zero size")
        #expect(try StarlitCartoucheTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheChartInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 80)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try StarlitCartoucheTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try StarlitCartoucheTest.still(session, width: w, height: h)
            let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = StarlitCartoucheTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(!references.isEmpty)
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            StarlitCartoucheTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 40)
        let before: String = try StarlitCartoucheTest.digest(shell)
        let image: [UInt8] = try StarlitCartoucheTest.still(session)
        let scene: StarlitCartoucheChartScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let builds: Int = scene.chartBuilds
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try StarlitCartoucheTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        #expect(scene.chartBuilds > builds, "the chart mesh was rebuilt")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try StarlitCartoucheTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        StarlitCartoucheTest.checkFrame(again, snapshot: snapshot, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try StarlitCartoucheTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try StarlitCartoucheTest.digest(shell) == before)
    }

    /// Reduce Motion: right after a leg the ship is at rest (glide 1) and the firmament still (angle 0), so the frames
    /// at 0 s, 0.6 s and 1.3 s are identical and the meshes are not rebuilt; that frame equals the full-motion frame
    /// at rest at time 0.
    @Test func reduceMotionStopsTheFirmamentAndTheGlide() async throws {
        let leg: StarlitCartoucheAction = try #require(try StarlitCartoucheTest.certifiedLegs(61).first,
                                                       "level 61 has a certified leg")
        var starts: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await StarlitCartoucheTest.open(session, seed: 60, reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.reduceMotion == reduceMotion)
            StarlitCartoucheTest.pin(session, shell, tier: 0)
            #expect(StarlitCartoucheTest.issue(shell, [leg]) == 1)
            if !reduceMotion { try StarlitCartoucheTest.prime(session) }
            let start: [UInt8] = try StarlitCartoucheTest.still(session, time: 0)
            let startSnapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion at rest"
            #expect(startSnapshot.time == 0)
            #expect(shell.presenter.lastGlide == 1, "\(what): the ship rests at its star")
            #expect(shell.presenter.scene.lastFirmamentAngle == 0, "\(what): the firmament at time 0")
            StarlitCartoucheTest.checkFrame(start, snapshot: startSnapshot, what)
            starts.append(start)
            guard reduceMotion else { continue }
            let chartBuilds: Int = shell.presenter.scene.chartBuilds
            let glowBuilds: Int = shell.presenter.scene.glowBuilds
            let times: [Double] = [0.6, 1.3]
            for time in times {
                let later: [UInt8] = try StarlitCartoucheTest.still(session, time: time)
                #expect(shell.presenter.lastGlide == 1, "Reduce Motion: glide at \(time) s")
                #expect(shell.presenter.scene.lastFirmamentAngle == 0, "Reduce Motion: firmament still at \(time) s")
                let laterSnapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(laterSnapshot.positions == startSnapshot.positions)
                #expect(later == start, "Reduce Motion: the frame at \(time) s differs from the frame at 0 s")
            }
            #expect(shell.presenter.scene.chartBuilds == chartBuilds, "no chart rebuild while only the time moves")
            #expect(shell.presenter.scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
            session.qualityPin = 0
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            #expect(starts[0] == starts[1], "the Reduce Motion frame differs from the full-motion frame at rest")
        }
    }

    /// Full motion: the firmament turns with the frame time (`firmamentAngle`) while the chart and glow meshes are not
    /// rebuilt; a turned firmament draws a different frame.
    @Test func theMeshesAreNotRebuiltWhileOnlyTimeMoves() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 40)
        StarlitCartoucheTest.pin(session, shell, tier: 0)
        let start: [UInt8] = try StarlitCartoucheTest.still(session, time: 0)
        let scene: StarlitCartoucheChartScene = shell.presenter.scene
        #expect(scene.lastFirmamentAngle == 0)
        let chartBuilds: Int = scene.chartBuilds
        let glowBuilds: Int = scene.glowBuilds
        let times: [Double] = [0.6, 1.3, 50, 150]
        var differing: Int = 0
        for time in times {
            let frame: [UInt8] = try StarlitCartoucheTest.still(session, time: time)
            let want: Double = StarlitCartoucheShaders.firmamentAngle(time: time, reduceMotion: false)
            #expect(Swift.abs(scene.lastFirmamentAngle - want) < 1e-12, "angle at \(time) s")
            #expect(shell.presenter.lastGlide == 1, "no glide before the first leg")
            if frame != start { differing += 1 }
            let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            StarlitCartoucheTest.checkFrame(frame, snapshot: snapshot, angle: want, "firmament at \(time) s")
        }
        #expect(scene.chartBuilds == chartBuilds, "no chart rebuild while only the time moves")
        #expect(scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
        #expect(differing > 0, "the turned firmament draws no different frame at \(times) s")
        session.qualityPin = 0
    }

    /// Full motion: after a leg the ship glides along its new trail over `glideSeconds` from the first frame that shows
    /// it (glide 0, 0.5, 1, 1), rebuilding the meshes while it moves and not after.
    @Test func theShipGlidesOverHalfASecond() async throws {
        let leg: StarlitCartoucheAction = try #require(try StarlitCartoucheTest.certifiedLegs(21).first)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 20)
        StarlitCartoucheTest.pin(session, shell, tier: 1)
        #expect(StarlitCartouchePresenter.glideSeconds == 0.5)
        #expect(StarlitCartoucheTest.issue(shell, [leg]) == 1)
        let scene: StarlitCartoucheChartScene = shell.presenter.scene
        let times: [Double] = [0, 0.25, 0.5, 0.9]
        let glides: [Double] = [0, 0.5, 1, 1]
        var frames: [[UInt8]] = []
        var builds: [Int] = []
        for (index, time) in times.enumerated() {
            frames.append(try StarlitCartoucheTest.still(session, width: 192, height: 128, time: time))
            builds.append(scene.chartBuilds)
            let glide: Double = shell.presenter.lastGlide
            #expect(Swift.abs(glide - glides[index]) < 1e-9, "glide at \(time) s is \(glide)")
        }
        #expect(frames[0] != frames[2], "the ship moved along its trail")
        #expect(builds[1] > builds[0] && builds[2] > builds[1], "the meshes follow the gliding ship \(builds)")
        #expect(builds[3] == builds[2], "no rebuild once the ship rests \(builds)")
        session.qualityPin = 0
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await StarlitCartoucheTest.open(session, seed: 40, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? StarlitCartoucheShaders.glowGainCap
                : StarlitCartoucheShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            StarlitCartoucheTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try StarlitCartoucheTest.still(session)
            let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            StarlitCartoucheTest.checkFrame(rgba, snapshot: snapshot, "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        #expect(stills.count == 2 && stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(StarlitCartoucheShaders.glowGainCap < StarlitCartoucheShaders.standardGlowLimit)
        #expect(StarlitCartoucheShaders.glowLimit(reduceFlashing: true) == StarlitCartoucheShaders.glowGainCap)
    }
}
#endif
