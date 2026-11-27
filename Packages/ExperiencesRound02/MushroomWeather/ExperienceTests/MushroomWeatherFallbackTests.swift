// MushroomWeatherFallbackTests — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-003, 004, 007; SC-R02G2003-002;
// clarifications Q1, Q4; spec Edge Cases). Through the one app's session host, off screen at the shown cycle half the
// cycles run: a forest program that does not compile (the presenter's seam `breakForestShader()`, before `setup`)
// draws the level-2 geometry unlit with the shared mesh renderer (the backdrop gradient, the moon, the caps, the amber
// actions bars, the gauge tracks), keeps `fallbackReason` at every tier, keeps running, declares no frame probes and
// leaves the state unchanged and the digest of the same actions untouched; a live resize and a zero-size view draw
// nothing wrong, throw nothing and recover, and every reference point stays inside the 5 % margin for aspects
// 0.4 … 2.5; a memory warning (`shedCaches`) releases the scene's GPU objects (`liveObjectCount` 0) and the next frame
// rebuilds them (`forestBuilds` rises) and draws the same image; Reduce Motion keeps the frame still (frames at
// different times have identical pixels — compared pixel by pixel, not by `lastShaderTime`, which still advances — are
// not rebuilt and equal the full-motion frame at time 0), while with full motion only the droplets and motes move (the
// level-0 frames at different times differ, the level-2 frames, which draw neither, do not, and no reference point
// moves); Reduce Flashing lowers the scene's glow limit to `MushroomWeatherShaders.glowGainCap`. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import MushroomWeatherCore
import Testing
import UIKit
@testable import MushroomWeatherExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MushroomWeatherFallbackTests {
    /// A forest program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier;
    /// the state is unchanged.
    @Test func aBrokenForestProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(61)
        let shell = try await MushroomWeatherTest.open(session, seed: 60, setUp: plan) { $0.breakForestShader() }
        let presenter: MushroomWeatherPresenter = shell.presenter
        let before: String = try MushroomWeatherTest.digest(shell)
        let payload: Data = try MushroomWeatherTest.core(shell).snapshotPayload()
        let rgba: [UInt8] = try MushroomWeatherTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("mushroom-weather fallback reason: \(reason)")
        #expect(reason.contains("mushroom-weather shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(MushroomWeatherTest.drawnPixels(rgba) > 0, "the fallback frame draws something")
        #expect(presenter.scene.liveObjectCount > 0, "the fallback holds its unlit renderers")
        // The unlit fallback keeps the backdrop gradient, the moon, the caps, the bars and the tracks (level-2).
        let snapshot: MushroomWeatherSceneSnapshot = try #require(presenter.lastSnapshot)
        #expect(snapshot.shownCycle == MushroomWeatherTest.halfCycle(snapshot.cyclesRun), "the half cycle")
        MushroomWeatherTest.checkFrame(rgba, snapshot: snapshot, tier: 2, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try MushroomWeatherTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            MushroomWeatherTest.pin(session, shell, tier: tier)
            try MushroomWeatherTest.draw(session, frames: 2)
            let again: [UInt8] = try MushroomWeatherTest.still(session)
            #expect(MushroomWeatherTest.drawnPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 geometry unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try MushroomWeatherTest.digest(shell) == before, "the fallback leaves the state")
        #expect(try MushroomWeatherTest.core(shell).snapshotPayload() == payload)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(21)
        #expect(!plan.isEmpty, "level 21 has a certified plan")
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MushroomWeatherTest.open(session, seed: 20) {
                (presenter: MushroomWeatherPresenter) in
                if broken { presenter.breakForestShader() }
            }
            #expect(MushroomWeatherTest.issue(shell, plan) == plan.count)
            try MushroomWeatherTest.draw(session, frames: 2)
            _ = try MushroomWeatherTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try MushroomWeatherTest.digest(shell))
        }
        #expect(digests.count == 2 && digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(1)
        let shell = try await MushroomWeatherTest.open(session, seed: 0, setUp: plan)
        let before: String = try MushroomWeatherTest.digest(shell)
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
        let snapshot0: MushroomWeatherSceneSnapshot = try MushroomWeatherTest.core(shell).snapshot(time: 0)
        #expect(MushroomWeatherTest.pixel(SIMD3<Double>(0, 0, 0), width: 0, height: 0) == nil)
        #expect(MushroomWeatherTest.referencePixels(snapshot0, width: 0, height: 0).isEmpty)
        #expect(MushroomWeatherTest.layout(snapshot0, width: 0, height: 0).order.isEmpty)
        #expect(MushroomWeatherTest.backdrop(width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try MushroomWeatherTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try MushroomWeatherTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try MushroomWeatherTest.still(session)
        let snapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        MushroomWeatherTest.checkFrame(rgba, snapshot: snapshot, tier: 0, "after a zero size")
        #expect(try MushroomWeatherTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheForestInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(81)
        let shell = try await MushroomWeatherTest.open(session, seed: 80, setUp: plan)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try MushroomWeatherTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try MushroomWeatherTest.still(session, width: w, height: h)
            let snapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = MushroomWeatherTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(references.count == MushroomWeatherTest.referenceCount(snapshot))
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            MushroomWeatherTest.checkFrame(rgba, snapshot: snapshot, tier: 0, width: w, height: h, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(41)
        let shell = try await MushroomWeatherTest.open(session, seed: 40, setUp: plan)
        let before: String = try MushroomWeatherTest.digest(shell)
        let image: [UInt8] = try MushroomWeatherTest.still(session)
        let scene: MushroomWeatherForestScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let builds: Int = scene.forestBuilds
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try MushroomWeatherTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        #expect(scene.forestBuilds > builds, "the forest mesh was rebuilt")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try MushroomWeatherTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        MushroomWeatherTest.checkFrame(again, snapshot: snapshot, tier: 0, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try MushroomWeatherTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try MushroomWeatherTest.digest(shell) == before)
    }

    /// Reduce Motion: with the certified plan placed (pods, so droplets) at level-0 (droplets and motes drawn), the
    /// frames at 0 s, 0.6 s and 1.3 s have identical pixels and the meshes are not rebuilt; that frame equals the
    /// full-motion frame at time 0.
    @Test func reduceMotionKeepsTheFrameStill() async throws {
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(61)
        var starts: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MushroomWeatherTest.open(session, seed: 60, setUp: plan,
                                                           reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.motion == (reduceMotion ? 0 : 1))
            MushroomWeatherTest.pin(session, shell, tier: 0)
            let start: [UInt8] = try MushroomWeatherTest.still(session, time: 0)
            let startSnapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion at time 0"
            #expect(startSnapshot.time == 0)
            MushroomWeatherTest.checkFrame(start, snapshot: startSnapshot, tier: 0, what)
            starts.append(start)
            guard reduceMotion else { continue }
            let forestBuilds: Int = shell.presenter.scene.forestBuilds
            let glowBuilds: Int = shell.presenter.scene.glowBuilds
            let times: [Double] = [0.6, 1.3]
            for time in times {
                let later: [UInt8] = try MushroomWeatherTest.still(session, time: time)
                let laterSnapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(laterSnapshot.shownCycle == startSnapshot.shownCycle, "time never advances the shown cycle")
                let changed: Int = MushroomWeatherTest.differingPixels(later, start)
                #expect(changed == 0, "Reduce Motion: \(changed) pixels of the frame at \(time) s differ from 0 s")
            }
            #expect(shell.presenter.scene.forestBuilds == forestBuilds, "no forest rebuild while only time moves")
            #expect(shell.presenter.scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
            session.qualityPin = 0
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            let changed: Int = MushroomWeatherTest.differingPixels(starts[0], starts[1])
            #expect(changed == 0, "the Reduce Motion frame differs from the full-motion frame at time 0 in \(changed)")
        }
    }

    /// Full motion: only the droplets and motes move by time. At level-0 the frame at 1.3 s differs from the frame
    /// at 0 s; at level-2 (no droplets, no motes) it does not; the meshes are not rebuilt, the shown cycle stays and no
    /// reference point moves.
    @Test func onlyTheDropletsAndMotesMoveWithFullMotion() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(41)
        let shell = try await MushroomWeatherTest.open(session, seed: 40, setUp: plan)
        let scene: MushroomWeatherForestScene = shell.presenter.scene
        for tier in [0, 2] {
            MushroomWeatherTest.pin(session, shell, tier: tier)
            let start: [UInt8] = try MushroomWeatherTest.still(session, time: 0)
            let startSnapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let forestBuilds: Int = scene.forestBuilds
            let glowBuilds: Int = scene.glowBuilds
            let later: [UInt8] = try MushroomWeatherTest.still(session, time: 1.3)
            let laterSnapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(laterSnapshot.shownCycle == startSnapshot.shownCycle, "tier \(tier): the shown cycle stays")
            #expect(MushroomWeatherTest.referencePixels(laterSnapshot)
                    == MushroomWeatherTest.referencePixels(startSnapshot), "tier \(tier): no reference point moves")
            #expect(scene.forestBuilds == forestBuilds, "tier \(tier): no forest rebuild while only the time moves")
            #expect(scene.glowBuilds == glowBuilds, "tier \(tier): no glow rebuild while only the time moves")
            let changed: Int = MushroomWeatherTest.differingPixels(later, start)
            print("mushroom-weather full motion tier \(tier): \(changed) pixels moved between 0 s and 1.3 s")
            if tier == 0 {
                #expect(changed > 0, "level-0: the droplets and motes move by time")
            } else {
                #expect(changed == 0, "level-2: nothing that moves by time is drawn")
            }
            MushroomWeatherTest.checkFrame(later, snapshot: laterSnapshot, tier: tier, "full motion at 1.3 s")
        }
        session.qualityPin = 0
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(41)
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MushroomWeatherTest.open(session, seed: 40, setUp: plan,
                                                           reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? MushroomWeatherShaders.glowGainCap
                : MushroomWeatherShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            MushroomWeatherTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try MushroomWeatherTest.still(session)
            let snapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            MushroomWeatherTest.checkFrame(rgba, snapshot: snapshot, tier: 0, "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        // The caps always glow at level-0 (gain 1.5 above the cap 0.5), so the capped glow draws a dimmer frame.
        #expect(stills.count == 2 && stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(MushroomWeatherShaders.glowGainCap < MushroomWeatherShaders.standardGlowLimit)
        #expect(MushroomWeatherShaders.glowLimit(reduceFlashing: true) == MushroomWeatherShaders.glowGainCap)
    }
}
#endif
