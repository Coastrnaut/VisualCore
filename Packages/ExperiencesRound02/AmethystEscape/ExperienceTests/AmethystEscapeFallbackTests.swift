// AmethystEscapeFallbackTests — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-003, 007; SC-R02G0703-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a crystal program that does not
// compile (the presenter's seam, before `setup`) draws the level-2 geometry unlit with the shared mesh renderer (the
// backdrop-coloured corners and something lit at the pearl), keeps the reason at every tier, declares no frame probes and
// leaves the digest untouched; a live resize and a zero-size view draw nothing wrong and recover, and the pearl, the exit
// and every wedge top stay inside the 5 % margin for aspects 0.4 … 2.5; a memory warning releases the GPU objects and the
// next frame rebuilds them and draws the same image; Reduce Motion holds the snapshot time at 0 so frames at different
// times are identical, while without it the facet highlights move; Reduce Flashing lowers the scene's glow limit to
// `AmethystEscapeShaders.glowGainCap`; the frame probes are the two backdrop corners after a real frame. Short runs only.
#if os(iOS)
import AmethystEscapeCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct AmethystEscapeFallbackTests {
    @Test func aBrokenCrystalProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0) { $0.breakCrystalShader() }
        let presenter: AmethystEscapePresenter = shell.presenter
        AmethystEscapeTest.advance(shell)
        let before: String = try AmethystEscapeTest.digest(shell)
        let rgba: [UInt8] = try AmethystEscapeTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("amethyst-escape fallback reason: \(reason)")
        #expect(reason.contains("amethyst-escape shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(AmethystEscapeTest.nonBackdropPixels(rgba) > 0, "the fallback frame draws something")
        // The unlit fallback keeps the backdrop-coloured corners and the lit pearl.
        let snapshot: AmethystEscapeSceneSnapshot = try #require(presenter.lastSnapshot)
        AmethystEscapeTest.checkFrame(rgba, snapshot: snapshot, wedges: false, exit: false, "fallback")
        // No frame probes in the fallback (the verification runner checks only the real scene).
        #expect(presenter.probes(try AmethystEscapeTest.core(shell)).isEmpty)
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            AmethystEscapeTest.pin(session, shell, tier: tier)
            try AmethystEscapeTest.draw(session, frames: 2)
            let again: [UInt8] = try AmethystEscapeTest.still(session)
            #expect(AmethystEscapeTest.nonBackdropPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
            // The fallback always draws the level-2 geometry, so every tier draws the same picture.
            #expect(again == rgba, "tier \(tier): the fallback frame is the level-2 frame")
        }
        session.qualityPin = 0
        #expect(try AmethystEscapeTest.digest(shell) == before)
    }

    @Test func aBrokenProgramLeavesTheDigestOfTheSameActions() async throws {
        // The same actions on a working and on a broken presenter end in the same digest.
        var digests: [String] = []
        for broken in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AmethystEscapeTest.open(session, seed: 20) { presenter in
                if broken { presenter.breakCrystalShader() }
            }
            AmethystEscapeTest.advance(shell)
            try AmethystEscapeTest.draw(session, frames: 2)
            _ = try AmethystEscapeTest.still(session, width: 96, height: 64)
            #expect((shell.presenter.fallbackReason != nil) == broken)
            digests.append(try AmethystEscapeTest.digest(shell))
        }
        #expect(digests[0] == digests[1])
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 20)
        AmethystEscapeTest.advance(shell)
        let before: String = try AmethystEscapeTest.digest(shell)
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
        let snapshot0: AmethystEscapeSceneSnapshot = try AmethystEscapeTest.core(shell).snapshot(time: 0)
        let camera: AmethystEscapeCamera = AmethystEscapeSceneGeometry.camera(snapshot0, aspect: 1)
        #expect(AmethystEscapeSceneGeometry.pixel(SIMD3<Double>(0, 0, 0), camera: camera, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try AmethystEscapeTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try AmethystEscapeTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try AmethystEscapeTest.still(session)
        AmethystEscapeTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "after a zero size")
        #expect(try AmethystEscapeTest.digest(shell) == before)
    }

    @Test func aResizeKeepsTheCrystalInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 40)
        AmethystEscapeTest.advance(shell)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try AmethystEscapeTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 1 and 2.5, the short side 768 px (the check size's), then the check size itself.
        let widths: [Int] = [768, 768, 1_920, 1_152]
        let heights: [Int] = [1_920, 768, 768, 768]
        for index in 0..<widths.count {
            let w: Int = widths[index]
            let h: Int = heights[index]
            let rgba: [UInt8] = try AmethystEscapeTest.still(session, width: w, height: h)
            let snapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(w) × \(h)"
            // CPU: the pearl, the exit and every wedge top centre lie inside the 5 % margin.
            let lowX: Double = 0.05 * Double(w)
            let highX: Double = 0.95 * Double(w)
            let lowY: Double = 0.05 * Double(h)
            let highY: Double = 0.95 * Double(h)
            var outside: Int = 0
            for reference in AmethystEscapeTest.referencePixels(snapshot, width: w, height: h) {
                guard let p = reference else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) reference points outside the 5 % margin")
            AmethystEscapeTest.checkFrame(rgba, snapshot: snapshot, width: w, height: h, what)
        }
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0)
        AmethystEscapeTest.advance(shell)
        let before: String = try AmethystEscapeTest.digest(shell)
        let host = try #require(session.renderHost)
        try AmethystEscapeTest.draw(session, frames: 2)
        let image: [UInt8] = try AmethystEscapeTest.still(session)
        try AmethystEscapeTest.draw(session, frames: 1)
        let held = host.resources.stats.totalBytes
        shell.presenter.shedCaches()
        let shed = host.resources.stats.totalBytes
        #expect(shed < held, "the GPU objects were released: \(held) → \(shed) bytes")
        try AmethystEscapeTest.draw(session, frames: 1)
        let rebuilt = host.resources.stats.totalBytes
        #expect(rebuilt > shed, "the next frame rebuilt them: \(shed) → \(rebuilt) bytes")
        let again: [UInt8] = try AmethystEscapeTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        AmethystEscapeTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot),
                                      "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try AmethystEscapeTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(try AmethystEscapeTest.digest(shell) == before)
    }

    @Test func reduceMotionHoldsTheHighlightsStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0, reduceMotion: true)
        AmethystEscapeTest.advance(shell)
        let first: [UInt8] = try AmethystEscapeTest.still(session, time: 0.5)
        let firstSnapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0)
        try AmethystEscapeTest.draw(session, frames: 5)
        let second: [UInt8] = try AmethystEscapeTest.still(session, time: 2.75)
        let secondSnapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        AmethystEscapeTest.checkFrame(second, snapshot: secondSnapshot, "Reduce Motion")
    }

    @Test func withoutReduceMotionTheHighlightsMove() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0)
        AmethystEscapeTest.advance(shell)
        AmethystEscapeTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try AmethystEscapeTest.still(session, time: 0.5)
        let firstSnapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0.5)
        let second: [UInt8] = try AmethystEscapeTest.still(session, time: 1.25)
        let secondSnapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 1.25)
        // The facet highlights follow the presentation time.
        #expect(first != second, "the highlights move with the presentation time")
        AmethystEscapeTest.checkFrame(second, snapshot: secondSnapshot, "highlights moving")
        session.qualityPin = 0
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AmethystEscapeTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            let want: Double = reduceFlashing ? AmethystEscapeShaders.glowGainCap
                : AmethystEscapeShaders.standardGlowLimit
            #expect(shell.presenter.scene.glowLimit == want)
            AmethystEscapeTest.advance(shell)
            AmethystEscapeTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try AmethystEscapeTest.still(session)
            means.append(AmethystEscapeTest.meanLuminance(rgba))
            AmethystEscapeTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                          "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        print("amethyst-escape glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(AmethystEscapeShaders.glowGainCap < AmethystEscapeShaders.standardGlowLimit)
        #expect(AmethystEscapeShaders.glowLimit(reduceFlashing: true) == AmethystEscapeShaders.glowGainCap)
        let tier0: AmethystEscapeTier = AmethystEscapeTier.of(0)
        let gain: Double = AmethystEscapeShaders.glowGain(for: tier0)
        let capped: Double = AmethystEscapeShaders.glowGain(
            gain: gain, limit: AmethystEscapeShaders.glowLimit(reduceFlashing: true))
        let full: Double = AmethystEscapeShaders.glowGain(
            gain: gain, limit: AmethystEscapeShaders.glowLimit(reduceFlashing: false))
        #expect(capped <= AmethystEscapeShaders.glowGainCap)
        #expect(capped < full)
    }

    @Test func theProbesAreTheBackdropCornersAfterARealFrame() async throws {
        // None before a frame was drawn.
        let id: ExperienceID = AmethystEscapeTest.id
        let bare: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: id)
        let opening: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 1)
        #expect(bare.presenter.probes(opening).isEmpty)
        // Two backdrop corners after a real frame.
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0)
        let probes: [FrameProbe] = shell.presenter.probes(try AmethystEscapeTest.core(shell))
        var names: [String] = []
        for probe in probes {
            names.append(probe.name)
            #expect(probe.expected == FrameColorClass.dark.rawValue)
        }
        #expect(names == ["backdrop-top-left", "backdrop-bottom-right"])
        // Their pixels in the check-size still are the backdrop.
        let rgba: [UInt8] = try AmethystEscapeTest.still(session)
        for probe in probes {
            let got = AmethystEscapeTest.pixelAtFraction(rgba, probe.x, probe.y, width: AmethystEscapeTest.width,
                                                         height: AmethystEscapeTest.height)
            #expect(AmethystEscapeTest.channelDistance(got.colour, AmethystEscapePalette.backdrop)
                        <= AmethystEscapeTest.backgroundTolerance, "\(probe.name): \(got.colour)")
        }
    }
}
#endif
