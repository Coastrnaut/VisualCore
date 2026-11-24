// VoxelOrigamiFallbackTests — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-003, 004, 007; SC-R02G1503-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a voxel program that does not
// compile (the presenter's seam `breakVoxelShader()`, before `setup`) draws the level-2 geometry unlit with the shared
// mesh renderer (night corners, the ivory cube centres, the hot-pink chosen hinge, the moves gauge), keeps
// `fallbackReason` at every tier, keeps running, declares no frame probes and leaves the digest of the same actions
// untouched; a live resize and a zero-size view draw nothing wrong, throw nothing and recover, and every reference
// point (cube centres, hinge centres, the first covered pip, the first moves bar) stays inside the 5 % margin for
// aspects 0.4 … 2.5; a memory warning releases the scene's GPU objects (`liveObjectCount` 0) and the next frame
// rebuilds them and draws the same image; Reduce Motion draws presentation time 0, so frames at different times after a
// change are identical (and the voxel mesh is not rebuilt while only the time moves); Reduce Flashing lowers the
// scene's glow limit to `VoxelOrigamiShaders.glowGainCap`. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import VoxelOrigamiExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VoxelOrigamiCore

@MainActor
@Suite(.serialized) struct VoxelOrigamiFallbackTests {
    /// A voxel program that does not compile draws the unlit level-2 fallback and keeps the reason at every tier.
    @Test func aBrokenVoxelProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 60) { $0.breakVoxelShader() }
        let presenter: VoxelOrigamiPresenter = shell.presenter
        let before: String = try VoxelOrigamiTest.digest(shell)
        let rgba: [UInt8] = try VoxelOrigamiTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("voxel-origami fallback reason: \(reason)")
        #expect(reason.contains("voxel-origami shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(VoxelOrigamiTest.nonNightPixels(rgba) > 0, "the fallback frame draws something")
        #expect(presenter.scene.liveObjectCount > 0, "the fallback holds its unlit renderers")
        // The unlit fallback keeps the night corners, the ivory cubes, the hot-pink hinge and the moves gauge.
        let snapshot: VoxelOrigamiSceneSnapshot = try #require(presenter.lastSnapshot)
        VoxelOrigamiTest.checkFrame(rgba, snapshot: snapshot, require: false, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try VoxelOrigamiTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            VoxelOrigamiTest.pin(session, shell, tier: tier)
            try VoxelOrigamiTest.draw(session, frames: 2)
            let again: [UInt8] = try VoxelOrigamiTest.still(session)
            #expect(VoxelOrigamiTest.nonNightPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            #expect(shell.state != .failed, "tier \(tier): the experience keeps running")
            // The fallback always draws the level-2 geometry unlit, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try VoxelOrigamiTest.digest(shell) == before)
    }

    /// The same actions on a working and on a broken presenter end in the same digest.
    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(21)
        let first: [VoxelOrigamiAction] = Array(turns.prefix(2))
        #expect(!first.isEmpty, "level 21 has a certified turn")
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await VoxelOrigamiTest.open(session, seed: 20) {
                (presenter: VoxelOrigamiPresenter) in
                if broken { presenter.breakVoxelShader() }
            }
            #expect(VoxelOrigamiTest.issue(shell, first) == first.count)
            try VoxelOrigamiTest.draw(session, frames: 2)
            _ = try VoxelOrigamiTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try VoxelOrigamiTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    /// A zero-size view draws nothing, throws nothing and recovers on the next real size.
    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 0)
        let before: String = try VoxelOrigamiTest.digest(shell)
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
        let snapshot0: VoxelOrigamiSceneSnapshot = try VoxelOrigamiTest.core(shell).snapshot(time: 0)
        #expect(VoxelOrigamiTest.pixel(SIMD3<Double>(0, 0, 0), snapshot0, width: 0, height: 0) == nil)
        #expect(VoxelOrigamiTest.referencePixels(snapshot0, width: 0, height: 0).isEmpty)
        #expect(VoxelOrigamiTest.layout(snapshot0, width: 0, height: 0).order.isEmpty)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try VoxelOrigamiTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try VoxelOrigamiTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try VoxelOrigamiTest.still(session)
        let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        VoxelOrigamiTest.checkFrame(rgba, snapshot: snapshot, require: false, "after a zero size")
        #expect(try VoxelOrigamiTest.digest(shell) == before)
    }

    /// A live resize keeps every reference point inside the 5 % margin for aspects 0.4 … 2.5.
    @Test func aResizeKeepsTheChainInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 99)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try VoxelOrigamiTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try VoxelOrigamiTest.still(session, width: w, height: h)
            let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: every reference point lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            let references: [SIMD2<Double>?] = VoxelOrigamiTest.referencePixels(snapshot, width: w, height: h)
            for reference in references {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(!references.isEmpty)
            #expect(outside == 0, "\(what): \(outside) of \(references.count) reference points outside the margin")
            VoxelOrigamiTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, require: false, what)
        }
    }

    /// A memory warning releases the GPU objects; the next frame rebuilds them and draws the same image.
    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 40)
        let before: String = try VoxelOrigamiTest.digest(shell)
        let image: [UInt8] = try VoxelOrigamiTest.still(session)
        let scene: VoxelOrigamiVoxelScene = shell.presenter.scene
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        let builds: Int = scene.voxelBuilds
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "the GPU objects were released")
        try VoxelOrigamiTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt them")
        #expect(scene.voxelBuilds > builds, "the voxel mesh was rebuilt")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0)
        let again: [UInt8] = try VoxelOrigamiTest.still(session)
        #expect(scene.liveObjectCount > 0, "the next still rebuilt them")
        #expect(again == image, "the rebuilt scene draws the same image")
        let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        VoxelOrigamiTest.checkFrame(again, snapshot: snapshot, require: false, "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try VoxelOrigamiTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(scene.liveObjectCount > 0)
        #expect(try VoxelOrigamiTest.digest(shell) == before)
    }

    /// Reduce Motion: presentation time 0, so after a turn the frames at 0 s, 0.6 s and 1.3 s are identical and the
    /// meshes are not rebuilt while only the time moves; the Reduce Motion frame equals the full-motion frame at time 0
    /// (the geometry never previews a turn).
    @Test func reduceMotionDrawsTheSameFrameAtEveryTime() async throws {
        let turn: VoxelOrigamiAction = try #require(try VoxelOrigamiTest.certifiedTurns(61).first,
                                                    "level 61 has a certified turn")
        var starts: [[UInt8]] = []
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await VoxelOrigamiTest.open(session, seed: 60, reduceMotion: reduceMotion)
            #expect(shell.presenter.reduceMotion == reduceMotion)
            #expect(shell.presenter.scene.reduceMotion == reduceMotion)
            VoxelOrigamiTest.pin(session, shell, tier: 0)
            #expect(VoxelOrigamiTest.issue(shell, [turn]) == 1)
            let start: [UInt8] = try VoxelOrigamiTest.still(session, time: 0)
            let startSnapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(startSnapshot.time == 0)
            let what: String = reduceMotion ? "Reduce Motion" : "full motion"
            VoxelOrigamiTest.checkFrame(start, snapshot: startSnapshot, require: false, what)
            starts.append(start)
            guard reduceMotion else { continue }
            let voxelBuilds: Int = shell.presenter.scene.voxelBuilds
            let glowBuilds: Int = shell.presenter.scene.glowBuilds
            let times: [Double] = [0.6, 1.3]
            for time in times {
                let later: [UInt8] = try VoxelOrigamiTest.still(session, time: time)
                let laterSnapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(laterSnapshot.time == 0, "Reduce Motion presents time 0 at \(time) s")
                #expect(laterSnapshot.cells == startSnapshot.cells)
                #expect(later == start, "Reduce Motion: the frame at \(time) s differs from the frame at 0 s")
            }
            #expect(shell.presenter.scene.voxelBuilds == voxelBuilds, "no voxel rebuild while only the time moves")
            #expect(shell.presenter.scene.glowBuilds == glowBuilds, "no glow rebuild while only the time moves")
            session.qualityPin = 0
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            #expect(starts[0] == starts[1], "the Reduce Motion frame differs from the full-motion frame at time 0")
        }
    }

    /// Reduce Flashing lowers the scene's glow limit to the glow gain cap.
    @Test func reduceFlashingCapsTheGlow() async throws {
        var stills: [[UInt8]] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await VoxelOrigamiTest.open(session, seed: 40, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? VoxelOrigamiShaders.glowGainCap
                : VoxelOrigamiShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            VoxelOrigamiTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try VoxelOrigamiTest.still(session)
            let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            VoxelOrigamiTest.checkFrame(rgba, snapshot: snapshot, require: false, "Reduce Flashing \(reduceFlashing)")
            stills.append(rgba)
            session.qualityPin = 0
        }
        #expect(stills[0] != stills[1], "the capped glow draws a dimmer target glow")
        #expect(VoxelOrigamiShaders.glowGainCap < VoxelOrigamiShaders.standardGlowLimit)
        #expect(VoxelOrigamiShaders.glowLimit(reduceFlashing: true) == VoxelOrigamiShaders.glowGainCap)
    }
}
#endif
