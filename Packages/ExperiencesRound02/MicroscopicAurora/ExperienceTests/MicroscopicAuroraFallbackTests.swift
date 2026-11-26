// MicroscopicAuroraFallbackTests — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-003, 004, 007;
// SC-R02G1903-002; clarifications Q1, Q4; spec Edge Cases). Through the one app's session host, off screen at the
// shown tick half the ticks swum: a dish program that does not compile (the presenter's seam `breakDishShader()`,
// before `setup`) draws the level-2 geometry unlit with the shared mesh renderer (the backdrop gradient, the bright
// swimmers, the rim, the heliotrope actions bars, the gauge tracks), keeps `fallbackReason` at every tier, keeps
// running, declares no frame probes and leaves the state unchanged and the digest of the same actions untouched; a
// live resize and a zero-size view draw nothing wrong, throw nothing and recover, and every reference point stays
// inside the 5 % margin for aspects 0.4 … 2.5; a memory warning (`shedCaches`) releases the scene's GPU objects
// (`liveObjectCount` 0) and the next frame rebuilds them (`dishBuilds` rises) and draws the same image; Reduce Motion
// keeps the frame still (frames at different times are identical, are not rebuilt and equal the full-motion frame
// at time 0), and with full motion nothing moves by time either; Reduce Flashing lowers the scene's glow limit to
// `MicroscopicAuroraShaders.glowGainCap`. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import MicroscopicAuroraCore
import Testing
import UIKit
@testable import MicroscopicAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MicroscopicAuroraFallbackTests {
    /// A dish program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier; the
    /// state is unchanged.
    @Test func aBrokenDishProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(61)
        let shell = try await MicroscopicAuroraTest.open(session, seed: 60, setUp: plan) { $0.breakDishShader() }
        let presenter: MicroscopicAuroraPresenter = shell.presenter
        let before: String = try MicroscopicAuroraTest.digest(shell)
        let payload: Data = try MicroscopicAuroraTest.core(shell).snapshotPayload()
        let rgba: [UInt8] = try MicroscopicAuroraTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("microscopic-aurora fallback reason: \(reason)")
        #expect(reason.contains("microscopic-aurora shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(MicroscopicAuroraTest.drawnPixels(rgba) > 0, "the fallback frame draws something")
        #expect(presenter.scene.liveObjectCount > 0, "the fallback holds its unlit renderers")
        // The unlit fallback keeps the backdrop gradient, the bright swimmers, the rim, the bars and the tracks.
        let snapshot: MicroscopicAuroraSceneSnapshot = try #require(presenter.lastSnapshot)
        #expect(snapshot.shownTick == MicroscopicAuroraTest.halfTick(snapshot.ticksSwum), "the half tick")
        MicroscopicAuroraTest.checkFrame(rgba, snapshot: snapshot, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try MicroscopicAuroraTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            MicroscopicAuroraTest.pin(session, shell, tier: tier)
            try MicroscopicAuroraTest.draw(session, frames: 2)
            let again: [UInt8] = try MicroscopicAuroraTest.still(session)
            #expect(MicroscopicAuroraTest.drawnPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 geometry unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try MicroscopicAuroraTest.digest(shell) == before, "the fallback leaves the state")
        #expect(try MicroscopicAuroraTest.core(shell).snapshotPayload() == payload)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(21)
        #expect(!plan.isEmpty, "level 21 has a certified plan")
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MicroscopicAuroraTest.open(session, seed: 20) {
                (presenter: MicroscopicAuroraPresenter) in
                if broken { presenter.breakDishShader() }
            }
            #expect(MicroscopicAuroraTest.issue(shell, plan) == plan.count)
            try MicroscopicAuroraTest.draw(session, frames: 2)
            _ = try MicroscopicAuroraTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try MicroscopicAuroraTest.digest(shell))
        }
        #expect(digests.count == 2 && digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        let shell = try await MicroscopicAuroraTest.open(session, seed: 0, setUp: plan)
        let before: String = try MicroscopicAuroraTest.digest(shell)
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
        let snapshot0: MicroscopicAuroraSceneSnapshot = try MicroscopicAuroraTest.core(shell).snapshot(time: 0)
        #expect(MicroscopicAuroraTest.pixel(SIMD3<Double>(0, 0, 0), width: 0, height: 0) == nil)
        #expect(MicroscopicAuroraTest.referencePixels(snapshot0, width: 0, height: 0).isEmpty)
        #expect(MicroscopicAuroraTest.layout(snapshot0, width: 0, height: 0).order.isEmpty)
        #expect(MicroscopicAuroraTest.backdrop(width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try MicroscopicAuroraTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try MicroscopicAuroraTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try MicroscopicAuroraTest.still(session)
        let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        MicroscopicAuroraTest.checkFrame(rgba, snapshot: snapshot, "after a zero size")
        #expect(try MicroscopicAuroraTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheDishInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(81)
        let shell = try await MicroscopicAuroraTest.open(session, seed: 80, setUp: plan)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try MicroscopicAuroraTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try MicroscopicAuroraTest.still(session, width: w, height: h)
            let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = MicroscopicAuroraTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(references.count == MicroscopicAuroraTest.referenceCount(snapshot))
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            MicroscopicAuroraTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(41)
        let shell = try await MicroscopicAuroraTest.open(session, seed: 40, setUp: plan)
        let before: String = try MicroscopicAuroraTest.digest(shell)
        let image: [UInt8] = try MicroscopicAuroraTest.still(session)
        let scene: MicroscopicAuroraDishScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let builds: Int = scene.dishBuilds
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try MicroscopicAuroraTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        #expect(scene.dishBuilds > builds, "the dish mesh was rebuilt")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try MicroscopicAuroraTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        MicroscopicAuroraTest.checkFrame(again, snapshot: snapshot, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try MicroscopicAuroraTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try MicroscopicAuroraTest.digest(shell) == before)
    }

    /// Reduce Motion: with the certified plan placed, the frames at 0 s, 0.6 s and 1.3 s are identical and the meshes
    /// are not rebuilt; that frame equals the full-motion frame at time 0.
    @Test func reduceMotionKeepsTheFrameStill() async throws {
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(61)
        var starts: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MicroscopicAuroraTest.open(session, seed: 60, setUp: plan,
                                                             reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            MicroscopicAuroraTest.pin(session, shell, tier: 0)
            let start: [UInt8] = try MicroscopicAuroraTest.still(session, time: 0)
            let startSnapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion at time 0"
            #expect(startSnapshot.time == 0)
            MicroscopicAuroraTest.checkFrame(start, snapshot: startSnapshot, what)
            starts.append(start)
            guard reduceMotion else { continue }
            let dishBuilds: Int = shell.presenter.scene.dishBuilds
            let glowBuilds: Int = shell.presenter.scene.glowBuilds
            let times: [Double] = [0.6, 1.3]
            for time in times {
                let later: [UInt8] = try MicroscopicAuroraTest.still(session, time: time)
                let laterSnapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(laterSnapshot.positions == startSnapshot.positions)
                #expect(laterSnapshot.shownTick == startSnapshot.shownTick, "time never advances the shown tick")
                #expect(later == start, "Reduce Motion: the frame at \(time) s differs from the frame at 0 s")
            }
            #expect(shell.presenter.scene.dishBuilds == dishBuilds, "no dish rebuild while only time moves")
            #expect(shell.presenter.scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
            session.qualityPin = 0
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            #expect(starts[0] == starts[1], "the Reduce Motion frame differs from the full-motion frame at time 0")
        }
    }

    /// Full motion: nothing moves by time either; the frames at later times equal the frame at time 0, the meshes
    /// are not rebuilt and the shown tick stays.
    @Test func nothingMovesByTimeWithFullMotion() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(41)
        let shell = try await MicroscopicAuroraTest.open(session, seed: 40, setUp: plan)
        MicroscopicAuroraTest.pin(session, shell, tier: 0)
        let start: [UInt8] = try MicroscopicAuroraTest.still(session, time: 0)
        let scene: MicroscopicAuroraDishScene = shell.presenter.scene
        let tick: Int = try #require(shell.presenter.lastSnapshot).shownTick
        let dishBuilds: Int = scene.dishBuilds
        let glowBuilds: Int = scene.glowBuilds
        let times: [Double] = [0.6, 1.3, 50, 150]
        for time in times {
            let frame: [UInt8] = try MicroscopicAuroraTest.still(session, time: time)
            let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.shownTick == tick, "time never advances the shown tick")
            #expect(frame == start, "the frame at \(time) s differs from the frame at 0 s")
        }
        #expect(scene.dishBuilds == dishBuilds, "no dish rebuild while only the time moves")
        #expect(scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
        session.qualityPin = 0
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(41)
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MicroscopicAuroraTest.open(session, seed: 40, setUp: plan,
                                                             reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? MicroscopicAuroraShaders.glowGainCap
                : MicroscopicAuroraShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            MicroscopicAuroraTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try MicroscopicAuroraTest.still(session)
            let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            MicroscopicAuroraTest.checkFrame(rgba, snapshot: snapshot, "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        // The swimmers and ribbons always glow at level-0, so the capped glow draws a dimmer frame.
        #expect(stills.count == 2 && stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(MicroscopicAuroraShaders.glowGainCap < MicroscopicAuroraShaders.standardGlowLimit)
        #expect(MicroscopicAuroraShaders.glowLimit(reduceFlashing: true) == MicroscopicAuroraShaders.glowGainCap)
    }
}
#endif
