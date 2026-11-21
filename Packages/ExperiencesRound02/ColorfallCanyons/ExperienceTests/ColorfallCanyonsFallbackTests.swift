// ColorfallCanyonsFallbackTests — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-003, 007; SC-R02G0503-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a fluid program that does not
// compile (the presenter's seam, before `setup`) draws the level-2 geometry unlit with the shared mesh renderer (still
// not all night, the same frame checks), keeps the reason at every tier, declares no frame probes and leaves the digest
// untouched; a live resize and a zero-size view draw nothing wrong and recover; a memory warning releases the GPU
// objects and the next frame rebuilds them and draws the same image; Reduce Motion holds the snapshot time at 0 so
// frames at different times are identical, while without it the flow bands move; Reduce Flashing caps the glow at
// `ColorfallCanyonsShaders.glowGainCap`; the frame probes are the two night corners after a real frame. Short runs
// only.
#if os(iOS)
import ColorfallCanyonsCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct ColorfallCanyonsFallbackTests {
    @Test func aBrokenFluidProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 0) { $0.breakFluidShader() }
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        try ColorfallCanyonsTest.flow(shell)
        let before: String = try ColorfallCanyonsTest.digest(shell)
        let rgba: [UInt8] = try ColorfallCanyonsTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("colorfall-canyons fallback reason: \(reason)")
        #expect(reason.contains("colorfall-canyons shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(ColorfallCanyonsTest.nonNightPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the lit emitters, the sandstone tops and the night background: the same checks.
        let snapshot: ColorfallCanyonsSceneSnapshot = try #require(presenter.lastSnapshot)
        ColorfallCanyonsTest.checkFrame(rgba, snapshot: snapshot, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try ColorfallCanyonsTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            ColorfallCanyonsTest.pin(session, shell, tier: tier)
            try ColorfallCanyonsTest.draw(session, frames: 2)
            let again: [UInt8] = try ColorfallCanyonsTest.still(session)
            #expect(ColorfallCanyonsTest.nonNightPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try ColorfallCanyonsTest.digest(shell) == before)
    }

    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        // The same actions on a working and on a broken presenter end in the same digest.
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ColorfallCanyonsTest.open(session, seed: 20) { presenter in
                if broken { presenter.breakFluidShader() }
            }
            try ColorfallCanyonsTest.flow(shell)
            try ColorfallCanyonsTest.draw(session, frames: 2)
            _ = try ColorfallCanyonsTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try ColorfallCanyonsTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 20)
        try ColorfallCanyonsTest.flow(shell)
        let before: String = try ColorfallCanyonsTest.digest(shell)
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
        // The CPU projection refuses a zero-size viewport.
        let snapshot0: ColorfallCanyonsSceneSnapshot = try ColorfallCanyonsTest.core(shell).snapshot(time: 0)
        let camera = ColorfallCanyonsSceneGeometry.camera(snapshot0, aspect: 1)
        #expect(ColorfallCanyonsSceneGeometry.pixel(SIMD3<Double>(0, 0, 0), camera: camera, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try ColorfallCanyonsTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try ColorfallCanyonsTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try ColorfallCanyonsTest.still(session)
        ColorfallCanyonsTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "after a zero size")
        #expect(try ColorfallCanyonsTest.digest(shell) == before)
    }

    @Test func aResizeKeepsTheFigureInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 40)
        try ColorfallCanyonsTest.flow(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try ColorfallCanyonsTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let sizes: [(w: Int, h: Int)] = [(768, 1_920), (768, 768), (1_920, 768), (1_152, 768)]
        for size in sizes {
            let rgba: [UInt8] = try ColorfallCanyonsTest.still(session, width: size.w, height: size.h)
            let snapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(size.w) × \(size.h)"
            // CPU: every cell top, emitter top and basin centre lies inside the 5 % margin.
            let lowX: Double = 0.05 * Double(size.w)
            let highX: Double = 0.95 * Double(size.w)
            let lowY: Double = 0.05 * Double(size.h)
            let highY: Double = 0.95 * Double(size.h)
            var outside: Int = 0
            for reference in ColorfallCanyonsTest.referencePixels(snapshot, width: size.w, height: size.h) {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) reference points outside the 5 % margin")
            ColorfallCanyonsTest.checkFrame(rgba, snapshot: snapshot, width: size.w, height: size.h, what)
        }
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 0)
        try ColorfallCanyonsTest.flow(shell)
        let before: String = try ColorfallCanyonsTest.digest(shell)
        let host = try #require(session.renderHost)
        try ColorfallCanyonsTest.draw(session, frames: 2)
        let image: [UInt8] = try ColorfallCanyonsTest.still(session)
        try ColorfallCanyonsTest.draw(session, frames: 1)
        let held = host.resources.stats.totalBytes
        shell.presenter.shedCaches()
        let shed = host.resources.stats.totalBytes
        #expect(shed < held, "the GPU objects were released: \(held) → \(shed) bytes")
        try ColorfallCanyonsTest.draw(session, frames: 1)
        let rebuilt = host.resources.stats.totalBytes
        #expect(rebuilt > shed, "the next frame rebuilt them: \(shed) → \(rebuilt) bytes")
        let again: [UInt8] = try ColorfallCanyonsTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        ColorfallCanyonsTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot),
                                        "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try ColorfallCanyonsTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(try ColorfallCanyonsTest.digest(shell) == before)
    }

    @Test func reduceMotionHoldsTheFlowBandsStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 0, reduceMotion: true)
        try ColorfallCanyonsTest.flow(shell)
        let first: [UInt8] = try ColorfallCanyonsTest.still(session, time: 0.5)
        let firstSnapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0)
        try ColorfallCanyonsTest.draw(session, frames: 5)
        let second: [UInt8] = try ColorfallCanyonsTest.still(session, time: 2.75)
        let secondSnapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        ColorfallCanyonsTest.checkFrame(second, snapshot: secondSnapshot, "Reduce Motion")
    }

    @Test func withoutReduceMotionTheFlowBandsMove() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 0)
        try ColorfallCanyonsTest.flow(shell)
        ColorfallCanyonsTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try ColorfallCanyonsTest.still(session, time: 0.5)
        let firstSnapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0.5)
        let second: [UInt8] = try ColorfallCanyonsTest.still(session, time: 1.25)
        let secondSnapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 1.25)
        // The bands move with the presentation time wherever wet fluid has a downhill direction.
        var moving: Int = 0
        for cell in 0..<secondSnapshot.cellCount {
            if secondSnapshot.volume(cell) > 0 && ColorfallCanyonsSceneGeometry.flowCode(cell, secondSnapshot) != 0 {
                moving += 1
            }
        }
        print("colorfall-canyons flow bands: \(moving) wet cells with a downhill direction")
        if moving > 0 { #expect(first != second, "the flow bands move with the presentation time") }
        ColorfallCanyonsTest.checkFrame(second, snapshot: secondSnapshot, "flow bands moving")
        session.qualityPin = 0
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ColorfallCanyonsTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? ColorfallCanyonsShaders.glowGainCap
                : ColorfallCanyonsShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            try ColorfallCanyonsTest.flow(shell)
            ColorfallCanyonsTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try ColorfallCanyonsTest.still(session)
            means.append(ColorfallCanyonsTest.meanLuminance(rgba))
            ColorfallCanyonsTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                            "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        print("colorfall-canyons glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(ColorfallCanyonsShaders.glowLimit(reduceFlashing: true) == ColorfallCanyonsShaders.glowGainCap)
        let tier0: ColorfallCanyonsTier = ColorfallCanyonsTier.of(0)
        let gain: Double = ColorfallCanyonsShaders.glowGain(for: tier0)
        let capped: Double = ColorfallCanyonsShaders.glowGain(
            gain: gain, limit: ColorfallCanyonsShaders.glowLimit(reduceFlashing: true))
        let full: Double = ColorfallCanyonsShaders.glowGain(
            gain: gain, limit: ColorfallCanyonsShaders.glowLimit(reduceFlashing: false))
        #expect(capped <= ColorfallCanyonsShaders.glowGainCap)
        #expect(capped < full)
    }

    @Test func theProbesAreTheNightCornersAfterARealFrame() async throws {
        // None before a frame was drawn.
        let id: ExperienceID = ColorfallCanyonsTest.id
        let bare: ExperienceShell<ColorfallCanyonsPresenter> = ColorfallCanyonsExperience.make(id: id)
        let opening: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        // Two night corners after a real frame.
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try ColorfallCanyonsTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names == ["night-top-left", "night-bottom-right"])
        // Their pixels in the check-size still are night.
        let rgba: [UInt8] = try ColorfallCanyonsTest.still(session)
        for probe in probes {
            let px: Double = probe.x * Double(ColorfallCanyonsTest.width)
            let py: Double = probe.y * Double(ColorfallCanyonsTest.height)
            let c: SIMD3<Double> = ColorfallCanyonsTest.pixelAt(rgba, px, py, width: ColorfallCanyonsTest.width,
                                                               height: ColorfallCanyonsTest.height)
            #expect(ColorfallCanyonsTest.channelDistance(c, ColorfallCanyonsPalette.night)
                        <= ColorfallCanyonsTest.backgroundTolerance, "\(probe.name): \(c)")
        }
    }
}
#endif
