// MyceliumArchitectFallbackTests — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-003, 004, 007; SC-R02G2203-002;
// clarifications Q1, Q3, Q4; spec Edge Cases). Through the one app's session host, off screen at the full shown pulse:
// a board program that does not compile (the presenter's seam `breakBoardShader()`, before `setup`) draws the level-2
// board unlit with the shared mesh renderer (the backdrop gradient, the root cap, the terminal caps in their flat
// colours within 0.1, the copper actions bars, the weight plate), keeps `fallbackReason` at every tier, keeps running,
// declares no frame probes and leaves the state unchanged and the digest of the same actions untouched; a live resize
// and a zero-size view draw nothing wrong, throw nothing and recover, and every reference point stays inside the 5 %
// margin for aspects 0.4 … 2.5; a memory warning (`shedCaches`) releases the scene's GPU objects (`liveObjectCount` 0)
// and the next frame rebuilds them (`boardBuilds` rises) and draws the same image; Reduce Motion keeps the frame still
// (frames at different times have identical pixels — compared pixel by pixel, not by `lastShaderTime`, which still
// advances — are not rebuilt and equal the full-motion frame at time 0), while with full motion the light pulses
// along the veins (and the ripples, fuzz and spores) move by time at every tier, rebuild nothing and move no reference
// point; Reduce Flashing lowers the scene's glow limit to `MyceliumArchitectBoardScene.glowGainCap`, which dims the
// always-present root glow at level-0. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
@testable import MyceliumArchitectCore
import Testing
import UIKit
@testable import MyceliumArchitectExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MyceliumArchitectFallbackTests {
    /// A board program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier;
    /// the state is unchanged.
    @Test func aBrokenBoardProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(61)
        let shell = try await MyceliumArchitectTest.open(session, seed: 60, setUp: plan) {
            (presenter: MyceliumArchitectPresenter) in
            presenter.breakBoardShader()
        }
        let presenter: MyceliumArchitectPresenter = shell.presenter
        let before: String = try MyceliumArchitectTest.digest(shell)
        let payload: Data = try MyceliumArchitectTest.core(shell).snapshotPayload()
        let rgba: [UInt8] = try MyceliumArchitectTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("mycelium-architect fallback reason: \(reason)")
        #expect(reason.contains("mycelium-architect shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(MyceliumArchitectTest.drawnPixels(rgba) > 0, "the fallback frame draws something")
        #expect(presenter.scene.liveObjectCount > 0, "the fallback holds its unlit renderer")
        // The unlit fallback keeps the backdrop gradient, the caps in their flat colours, the bars and the plate.
        let snapshot: MyceliumArchitectSceneSnapshot = try #require(presenter.lastSnapshot)
        #expect(snapshot.shownPulse == snapshot.pulsesRun, "the full growth")
        MyceliumArchitectTest.checkFrame(rgba, snapshot: snapshot, tier: 2, fallback: true, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try MyceliumArchitectTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            try MyceliumArchitectTest.draw(session, frames: 2)
            let again: [UInt8] = try MyceliumArchitectTest.still(session)
            #expect(MyceliumArchitectTest.drawnPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 board unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try MyceliumArchitectTest.digest(shell) == before, "the fallback leaves the state")
        #expect(try MyceliumArchitectTest.core(shell).snapshotPayload() == payload)
    }

    /// The same actions on a working and on a broken presenter end in the same digest and verdict.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(21)
        #expect(!plan.isEmpty, "level 21 has a certified plan")
        var digests: [String] = []
        var outcomes: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MyceliumArchitectTest.open(session, seed: 20) {
                (presenter: MyceliumArchitectPresenter) in
                if broken { presenter.breakBoardShader() }
            }
            #expect(MyceliumArchitectTest.issue(shell, plan + [.run]) == plan.count + 1)
            try MyceliumArchitectTest.draw(session, frames: 2)
            _ = try MyceliumArchitectTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try MyceliumArchitectTest.digest(shell))
            outcomes.append(try MyceliumArchitectTest.core(shell).outcome?.code ?? "none")
        }
        #expect(digests.count == 2 && digests[0] == digests[1])
        #expect(outcomes == [MyceliumArchitectExperienceCore.wonCode, MyceliumArchitectExperienceCore.wonCode],
                "\(outcomes)")
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(1)
        let shell = try await MyceliumArchitectTest.open(session, seed: 0, setUp: plan)
        let before: String = try MyceliumArchitectTest.digest(shell)
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
        let snapshot0: MyceliumArchitectSceneSnapshot = try MyceliumArchitectTest.core(shell).snapshot(time: 0)
        #expect(MyceliumArchitectTest.pixel(SIMD3<Double>(0, 0, 0), width: 0, height: 0) == nil)
        #expect(MyceliumArchitectTest.referencePixels(snapshot0, width: 0, height: 0).isEmpty)
        #expect(MyceliumArchitectTest.layout(snapshot0, width: 0, height: 0).order.isEmpty)
        #expect(MyceliumArchitectTest.backdrop(width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try MyceliumArchitectTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try MyceliumArchitectTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try MyceliumArchitectTest.still(session)
        let snapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        MyceliumArchitectTest.checkFrame(rgba, snapshot: snapshot, tier: 0, "after a zero size")
        #expect(try MyceliumArchitectTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheBoardInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(81)
        let shell = try await MyceliumArchitectTest.open(session, seed: 80, setUp: plan)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try MyceliumArchitectTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try MyceliumArchitectTest.still(session, width: w, height: h)
            let snapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = MyceliumArchitectTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(references.count == MyceliumArchitectTest.referenceCount(snapshot))
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            MyceliumArchitectTest.checkFrame(rgba, snapshot: snapshot, tier: 0, width: w, height: h, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(41)
        let shell = try await MyceliumArchitectTest.open(session, seed: 40, setUp: plan)
        let before: String = try MyceliumArchitectTest.digest(shell)
        let image: [UInt8] = try MyceliumArchitectTest.still(session)
        let scene: MyceliumArchitectBoardScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let builds: Int = scene.boardBuilds
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try MyceliumArchitectTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        #expect(scene.boardBuilds > builds, "the board mesh was rebuilt")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try MyceliumArchitectTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        MyceliumArchitectTest.checkFrame(again, snapshot: snapshot, tier: 0, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try MyceliumArchitectTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try MyceliumArchitectTest.digest(shell) == before)
    }

    /// Reduce Motion: with the certified plan made at level-0 (veins, fuzz and spores drawn), the frames at 0 s,
    /// 0.6 s and 1.3 s have identical pixels and the meshes are not rebuilt; that frame equals the full-motion frame at
    /// time 0.
    @Test func reduceMotionKeepsTheFrameStill() async throws {
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(61)
        var starts: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MyceliumArchitectTest.open(session, seed: 60, setUp: plan,
                                                             reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.motion == (reduceMotion ? 0 : 1))
            MyceliumArchitectTest.pin(session, shell, tier: 0)
            let start: [UInt8] = try MyceliumArchitectTest.still(session, time: 0)
            let startSnapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion at time 0"
            #expect(startSnapshot.time == 0)
            MyceliumArchitectTest.checkFrame(start, snapshot: startSnapshot, tier: 0, what)
            starts.append(start)
            guard reduceMotion else { continue }
            let boardBuilds: Int = shell.presenter.scene.boardBuilds
            let glowBuilds: Int = shell.presenter.scene.glowBuilds
            let times: [Double] = [0.6, 1.3]
            for time in times {
                let later: [UInt8] = try MyceliumArchitectTest.still(session, time: time)
                let laterSnapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(laterSnapshot.shownPulse == startSnapshot.shownPulse, "time never advances the shown pulse")
                let changed: Int = MyceliumArchitectTest.differingPixels(later, start)
                #expect(changed == 0, "Reduce Motion: \(changed) pixels of the frame at \(time) s differ from 0 s")
            }
            #expect(shell.presenter.scene.boardBuilds == boardBuilds, "no board rebuild while only the time moves")
            #expect(shell.presenter.scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
            session.qualityPin = 0
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            let changed: Int = MyceliumArchitectTest.differingPixels(starts[0], starts[1])
            #expect(changed == 0, "the Reduce Motion frame differs from the full-motion frame at time 0 in \(changed)")
        }
    }

    /// Full motion: the light pulses along the veins move by time at every tier (the certified plan grows veins); the
    /// meshes are not rebuilt, the shown pulse stays and no reference point moves.
    @Test func theVeinsPulseWithFullMotion() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(41)
        let shell = try await MyceliumArchitectTest.open(session, seed: 40, setUp: plan)
        let scene: MyceliumArchitectBoardScene = shell.presenter.scene
        for tier in [0, 2] {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            let start: [UInt8] = try MyceliumArchitectTest.still(session, time: 0)
            let startSnapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(startSnapshot.grown.count > 1, "tier \(tier): the certified plan grows veins")
            let boardBuilds: Int = scene.boardBuilds
            let glowBuilds: Int = scene.glowBuilds
            let later: [UInt8] = try MyceliumArchitectTest.still(session, time: 1.3)
            let laterSnapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(laterSnapshot.shownPulse == startSnapshot.shownPulse, "tier \(tier): the shown pulse stays")
            #expect(MyceliumArchitectTest.referencePixels(laterSnapshot)
                    == MyceliumArchitectTest.referencePixels(startSnapshot), "tier \(tier): no reference point moves")
            #expect(scene.boardBuilds == boardBuilds, "tier \(tier): no board rebuild while only the time moves")
            #expect(scene.glowBuilds == glowBuilds, "tier \(tier): no glow rebuild while only the time moves")
            #expect(scene.lastShaderTime > 0, "tier \(tier): u_time \(scene.lastShaderTime)")
            let changed: Int = MyceliumArchitectTest.differingPixels(later, start)
            print("mycelium-architect full motion tier \(tier): \(changed) pixels moved between 0 s and 1.3 s")
            #expect(changed > 0, "tier \(tier): the veins pulse by time")
            MyceliumArchitectTest.checkFrame(later, snapshot: laterSnapshot, tier: tier, "full motion at 1.3 s")
        }
        session.qualityPin = 0
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(41)
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await MyceliumArchitectTest.open(session, seed: 40, setUp: plan,
                                                             reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? MyceliumArchitectBoardScene.glowGainCap
                : MyceliumArchitectBoardScene.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            MyceliumArchitectTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try MyceliumArchitectTest.still(session)
            let snapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            MyceliumArchitectTest.checkFrame(rgba, snapshot: snapshot, tier: 0, "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        // The root always glows at level-0 (gain 1.5 above the cap 0.5), so the capped glow draws a dimmer frame.
        #expect(stills.count == 2 && stills[0] != stills[1], "the capped glow draws a dimmer frame")
        #expect(MyceliumArchitectBoardScene.glowGainCap < MyceliumArchitectBoardScene.standardGlowLimit)
        #expect(MyceliumArchitectBoardScene.glowLimit(reduceFlashing: true) == MyceliumArchitectBoardScene.glowGainCap)
    }
}
#endif
