// BinaryGardensFallbackTests — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-003, 004, 007; SC-R02G2103-002;
// clarifications Q1, Q4; spec Edge Cases). Through the one app's session host, off screen at shown tick 24: a system
// program that does not compile (the presenter's seam `breakSystemShader()`, before `setup`) draws the level-2
// geometry unlit with the shared mesh renderer (the backdrop gradient, the worlds, the star discs, the vermilion
// actions bars, the gauge plates), keeps `fallbackReason` at every tier, keeps running, declares no frame probes and
// leaves the state unchanged and the digest of the same actions untouched; a live resize and a zero-size view draw
// nothing wrong, throw nothing and recover, and every reference point stays inside the 5 % margin for aspects
// 0.4 … 2.5; a memory warning (`shedCaches`) releases the scene's GPU objects (`liveObjectCount` 0) and the next frame
// rebuilds them (`systemBuilds` rises) and draws the same image; Reduce Motion keeps the frame still (frames at
// different times have identical pixels — compared pixel by pixel, not by `lastShaderTime`, which still advances — are
// not rebuilt and equal the full-motion frame at time 0), while with full motion only the coronas and motes move (the
// level-0 frames at different times differ, since every star has corona rays there; the level-2 frames, which draw
// neither, do not, and no reference point moves); Reduce Flashing lowers the scene's glow limit to
// `BinaryGardensShaders.glowGainCap`, which dims the always-present star glow at level-0. Short runs only.
#if os(iOS)
import BinaryGardensCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct BinaryGardensFallbackTests {
    /// A system program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier;
    /// the state is unchanged.
    @Test func aBrokenSystemProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(61)
        let shell = try await BinaryGardensTest.open(session, seed: 60, setUp: plan) { $0.breakSystemShader() }
        let presenter: BinaryGardensPresenter = shell.presenter
        let before: String = try BinaryGardensTest.digest(shell)
        let payload: Data = try BinaryGardensTest.core(shell).snapshotPayload()
        let rgba: [UInt8] = try BinaryGardensTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("binary-gardens fallback reason: \(reason)")
        #expect(reason.contains("binary-gardens shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(BinaryGardensTest.drawnPixels(rgba) > 0, "the fallback frame draws something")
        #expect(presenter.scene.liveObjectCount > 0, "the fallback holds its unlit renderers")
        // The unlit fallback keeps the backdrop gradient, the worlds, the stars, the bars and the plates (level-2).
        let snapshot: BinaryGardensSceneSnapshot = try #require(presenter.lastSnapshot)
        #expect(snapshot.shownTick == BinaryGardensTest.checkTick, "tick 24")
        BinaryGardensTest.checkFrame(rgba, snapshot: snapshot, tier: 2, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try BinaryGardensTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            BinaryGardensTest.pin(session, shell, tier: tier)
            try BinaryGardensTest.draw(session, frames: 2)
            let again: [UInt8] = try BinaryGardensTest.still(session)
            #expect(BinaryGardensTest.drawnPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 geometry unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try BinaryGardensTest.digest(shell) == before, "the fallback leaves the state")
        #expect(try BinaryGardensTest.core(shell).snapshotPayload() == payload)
    }

    /// The same actions on a working and on a broken presenter end in the same digest and verdict.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(21)
        #expect(!plan.isEmpty, "level 21 has a certified plan")
        var digests: [String] = []
        var outcomes: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await BinaryGardensTest.open(session, seed: 20) {
                (presenter: BinaryGardensPresenter) in
                if broken { presenter.breakSystemShader() }
            }
            #expect(BinaryGardensTest.issue(shell, plan + [.run]) == plan.count + 1)
            try BinaryGardensTest.draw(session, frames: 2)
            _ = try BinaryGardensTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try BinaryGardensTest.digest(shell))
            outcomes.append(try BinaryGardensTest.core(shell).outcome?.code ?? "none")
        }
        #expect(digests.count == 2 && digests[0] == digests[1])
        #expect(outcomes == [BinaryGardensExperienceCore.wonCode, BinaryGardensExperienceCore.wonCode], "\(outcomes)")
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(1)
        let shell = try await BinaryGardensTest.open(session, seed: 0, setUp: plan)
        let before: String = try BinaryGardensTest.digest(shell)
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
        let snapshot0: BinaryGardensSceneSnapshot = try BinaryGardensTest.core(shell).snapshot(time: 0)
        #expect(BinaryGardensTest.pixel(SIMD3<Double>(0, 0, 0), width: 0, height: 0) == nil)
        #expect(BinaryGardensTest.referencePixels(snapshot0, width: 0, height: 0).isEmpty)
        #expect(BinaryGardensTest.layout(snapshot0, width: 0, height: 0).order.isEmpty)
        #expect(BinaryGardensTest.backdrop(width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try BinaryGardensTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try BinaryGardensTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try BinaryGardensTest.still(session)
        let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        BinaryGardensTest.checkFrame(rgba, snapshot: snapshot, tier: 0, "after a zero size")
        #expect(try BinaryGardensTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheSystemInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(81)
        let shell = try await BinaryGardensTest.open(session, seed: 80, setUp: plan)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try BinaryGardensTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try BinaryGardensTest.still(session, width: w, height: h)
            let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = BinaryGardensTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(references.count == BinaryGardensTest.referenceCount(snapshot))
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            BinaryGardensTest.checkFrame(rgba, snapshot: snapshot, tier: 0, width: w, height: h, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(41)
        let shell = try await BinaryGardensTest.open(session, seed: 40, setUp: plan)
        let before: String = try BinaryGardensTest.digest(shell)
        let image: [UInt8] = try BinaryGardensTest.still(session)
        let scene: BinaryGardensSystemScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let builds: Int = scene.systemBuilds
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try BinaryGardensTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        #expect(scene.systemBuilds > builds, "the system mesh was rebuilt")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try BinaryGardensTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        BinaryGardensTest.checkFrame(again, snapshot: snapshot, tier: 0, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try BinaryGardensTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try BinaryGardensTest.digest(shell) == before)
    }

    /// Reduce Motion: with the certified plan made at level-0 (coronas, trails and motes drawn), the frames at 0 s,
    /// 0.6 s and 1.3 s have identical pixels and the meshes are not rebuilt; that frame equals the full-motion frame at
    /// time 0.
    @Test func reduceMotionKeepsTheFrameStill() async throws {
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(61)
        var starts: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await BinaryGardensTest.open(session, seed: 60, setUp: plan, reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.motion == (reduceMotion ? 0 : 1))
            BinaryGardensTest.pin(session, shell, tier: 0)
            let start: [UInt8] = try BinaryGardensTest.still(session, time: 0)
            let startSnapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion at time 0"
            #expect(startSnapshot.time == 0)
            BinaryGardensTest.checkFrame(start, snapshot: startSnapshot, tier: 0, what)
            starts.append(start)
            guard reduceMotion else { continue }
            let systemBuilds: Int = shell.presenter.scene.systemBuilds
            let glowBuilds: Int = shell.presenter.scene.glowBuilds
            let times: [Double] = [0.6, 1.3]
            for time in times {
                let later: [UInt8] = try BinaryGardensTest.still(session, time: time)
                let laterSnapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(laterSnapshot.shownTick == startSnapshot.shownTick, "time never advances the shown tick")
                let changed: Int = BinaryGardensTest.differingPixels(later, start)
                #expect(changed == 0, "Reduce Motion: \(changed) pixels of the frame at \(time) s differ from 0 s")
            }
            #expect(shell.presenter.scene.systemBuilds == systemBuilds, "no system rebuild while only time moves")
            #expect(shell.presenter.scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
            session.qualityPin = 0
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            let changed: Int = BinaryGardensTest.differingPixels(starts[0], starts[1])
            #expect(changed == 0, "the Reduce Motion frame differs from the full-motion frame at time 0 in \(changed)")
        }
    }

    /// Full motion: only the coronas and motes move by time. At level-0 the frame at 1.3 s differs from the frame at
    /// 0 s; at level-2 (no coronas, no motes) it does not; the meshes are not rebuilt, the shown tick stays and no
    /// reference point moves.
    @Test func onlyTheCoronasAndMotesMoveWithFullMotion() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(41)
        let shell = try await BinaryGardensTest.open(session, seed: 40, setUp: plan)
        let scene: BinaryGardensSystemScene = shell.presenter.scene
        for tier in [0, 2] {
            BinaryGardensTest.pin(session, shell, tier: tier)
            let start: [UInt8] = try BinaryGardensTest.still(session, time: 0)
            let startSnapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let systemBuilds: Int = scene.systemBuilds
            let glowBuilds: Int = scene.glowBuilds
            let later: [UInt8] = try BinaryGardensTest.still(session, time: 1.3)
            let laterSnapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(laterSnapshot.shownTick == startSnapshot.shownTick, "tier \(tier): the shown tick stays")
            #expect(BinaryGardensTest.referencePixels(laterSnapshot)
                    == BinaryGardensTest.referencePixels(startSnapshot), "tier \(tier): no reference point moves")
            #expect(scene.systemBuilds == systemBuilds, "tier \(tier): no system rebuild while only the time moves")
            #expect(scene.glowBuilds == glowBuilds, "tier \(tier): no glow rebuild while only the time moves")
            let changed: Int = BinaryGardensTest.differingPixels(later, start)
            print("binary-gardens full motion tier \(tier): \(changed) pixels moved between 0 s and 1.3 s")
            if tier == 0 {
                #expect(changed > 0, "level-0: the coronas and motes move by time")
            } else {
                #expect(changed == 0, "level-2: nothing that moves by time is drawn")
            }
            BinaryGardensTest.checkFrame(later, snapshot: laterSnapshot, tier: tier, "full motion at 1.3 s")
        }
        session.qualityPin = 0
    }

    /// The star uniforms are both stars' centres at the shown tick, the light directions of the two-sun shading.
    @Test func theStarUniformsAreTheStarsAtTheShownTick() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(21)
        let shell = try await BinaryGardensTest.open(session, seed: 20, setUp: plan)
        _ = try BinaryGardensTest.still(session, width: 96, height: 64)
        let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let stars: (SIMD3<Double>, SIMD3<Double>) = try #require(shell.presenter.scene.lastStarUniforms)
        #expect(stars.0 == BinaryGardensSceneGeometry.starCentre(0, snapshot))
        #expect(stars.1 == BinaryGardensSceneGeometry.starCentre(1, snapshot))
        for value in [stars.0.x, stars.0.y, stars.0.z, stars.1.x, stars.1.y, stars.1.z] {
            #expect(value.isFinite)
        }
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(41)
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await BinaryGardensTest.open(session, seed: 40, setUp: plan,
                                                         reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? BinaryGardensShaders.glowGainCap
                : BinaryGardensShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            BinaryGardensTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try BinaryGardensTest.still(session)
            let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            BinaryGardensTest.checkFrame(rgba, snapshot: snapshot, tier: 0, "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        // The stars always glow at level-0 (gain 1.5 above the cap 0.5), so the capped glow draws a dimmer frame.
        #expect(stills.count == 2 && stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(BinaryGardensShaders.glowGainCap < BinaryGardensShaders.standardGlowLimit)
        #expect(BinaryGardensShaders.glowLimit(reduceFlashing: true) == BinaryGardensShaders.glowGainCap)
    }
}
#endif
