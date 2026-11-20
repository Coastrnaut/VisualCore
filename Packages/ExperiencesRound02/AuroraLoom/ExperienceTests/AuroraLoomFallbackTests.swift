// AuroraLoomFallbackTests — feature 303 (R02-G01-03) T-R02G0103-008 (FR-R02G0103-003, 007; SC-R02G0103-002;
// clarification Q4). Through the one app's session host, off screen: a ribbon program that does not compile (the
// presenter's seam, before `setup`) draws the minimal unlit fallback and keeps the reason, with the digest untouched; a
// zero-size view draws without error and recovers; a resize from 96 × 64 to 64 × 96 keeps the ribbons on the CPU
// reference; Reduce Motion holds the picture still; Reduce Flashing caps the glow; a memory warning releases the GPU
// objects and the next frame rebuilds them. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct AuroraLoomFallbackTests {
    @Test func aBrokenRibbonProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 0) { $0.breakRibbonShader() }
        let presenter = shell.presenter
        let before = try AuroraLoomTest.digest(shell)
        let rgba = try AuroraLoomTest.still(session)
        let reason = try #require(presenter.fallbackReason)
        print("aurora-loom fallback reason: \(reason)")
        #expect(reason.contains("aurora-loom shader"), "\(reason)")
        #expect(shell.state != .failed)
        // The fallback still draws the ribbons: most reference samples have a pixel that is not night within 2 px.
        let snapshot = try #require(presenter.lastSnapshot)
        let aspect = Double(AuroraLoomTest.width) / Double(AuroraLoomTest.height)
        let reference = AuroraLoomSceneGeometry.referenceSamples(snapshot: snapshot, aspect: aspect,
                                                                 width: AuroraLoomTest.width,
                                                                 height: AuroraLoomTest.height, segments: 32)
        var samples = 0
        var drawn = 0
        for line in reference {
            for p in line {
                samples += 1
                let found = AuroraLoomTest.anyPixel(rgba, near: p.x, p.y, radius: AuroraLoomTest.sampleRadius,
                                                    width: AuroraLoomTest.width,
                                                    height: AuroraLoomTest.height) { c in
                    AuroraLoomTest.channelDistance(c, AuroraLoomPalette.night) > 0.05
                }
                if found { drawn += 1 }
            }
        }
        print("aurora-loom fallback: \(drawn) of \(samples) samples drawn")
        #expect(samples == 99 && drawn * 3 >= samples * 2, "fallback ribbons drawn near \(drawn) of \(samples) samples")
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            AuroraLoomTest.pin(session, shell, tier: tier)
            try AuroraLoomTest.draw(session, frames: 2)
            _ = try AuroraLoomTest.still(session)
            #expect(presenter.fallbackReason == reason)
        }
        session.qualityPin = 0
        #expect(try AuroraLoomTest.digest(shell) == before)
    }

    @Test func aZeroSizeViewDrawsWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 20)
        let before = try AuroraLoomTest.digest(shell)
        let host = try #require(session.renderHost)
        let view = host.view
        view.frame = .zero
        view.layoutIfNeeded()
        var tries = 0
        for _ in 0..<3 {
            _ = host.renderOneFrame(present: false)   // false without a valid surface; never an error
            tries += 1
        }
        #expect(tries == 3)
        #expect(shell.state != .failed)
        // The smallest off-screen picture draws too.
        let tiny = try AuroraLoomTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try AuroraLoomTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba = try AuroraLoomTest.still(session)
        AuroraLoomTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "after a zero size")
        #expect(try AuroraLoomTest.digest(shell) == before)
    }

    @Test func aResizeKeepsTheRibbonsOnTheReference() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 40)
        let wide = try AuroraLoomTest.still(session, width: 96, height: 64)
        AuroraLoomTest.checkFrame(wide, snapshot: try #require(shell.presenter.lastSnapshot), width: 96, height: 64,
                                  "96 × 64")
        let host = try #require(session.renderHost)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 48)
        host.view.layoutIfNeeded()
        try AuroraLoomTest.draw(session, frames: 2)
        let tall = try AuroraLoomTest.still(session, width: 64, height: 96)
        let snapshot = try #require(shell.presenter.lastSnapshot)
        let ribbons = AuroraLoomTest.ribbonMisses(tall, snapshot: snapshot, width: 64, height: 96)
        #expect(ribbons.samples == 99)
        #expect(ribbons.misses.isEmpty, "64 × 96: \(ribbons.misses.count) misses: \(ribbons.misses.prefix(6))")
        let markers = AuroraLoomTest.markerMisses(tall, snapshot: snapshot, width: 64, height: 96)
        #expect(markers.misses.isEmpty, "64 × 96: \(markers.misses)")
    }

    @Test func reduceMotionHoldsThePictureStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 60, reduceMotion: true)
        let first = try AuroraLoomTest.still(session, time: 0.5)
        #expect(try #require(shell.presenter.lastSnapshot).time == 0)
        try AuroraLoomTest.draw(session, frames: 5)
        let second = try AuroraLoomTest.still(session, time: 2.75)
        #expect(try #require(shell.presenter.lastSnapshot).time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        AuroraLoomTest.checkFrame(second, snapshot: try #require(shell.presenter.lastSnapshot), "Reduce Motion")
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AuroraLoomTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            AuroraLoomTest.pin(session, shell, tier: 0)
            let rgba = try AuroraLoomTest.still(session)
            means.append(AuroraLoomTest.meanLuminance(rgba))
            AuroraLoomTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                      "Reduce Flashing \(reduceFlashing)")
        }
        print("aurora-loom glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(AuroraLoomRibbonScene.reducedGlowGain < AuroraLoomRibbonScene.glowGain)
        #expect(AuroraLoomRibbonScene.glowGain <= AuroraLoomShaders.maxGlowGain)
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 80)
        let before = try AuroraLoomTest.digest(shell)
        let host = try #require(session.renderHost)
        try AuroraLoomTest.draw(session, frames: 2)
        let held = host.resources.stats.totalBytes
        shell.presenter.shedCaches()
        let shed = host.resources.stats.totalBytes
        #expect(shed < held, "the GPU objects were released: \(held) → \(shed) bytes")
        try AuroraLoomTest.draw(session, frames: 1)
        let rebuilt = host.resources.stats.totalBytes
        #expect(rebuilt > shed, "the next frame rebuilt them: \(shed) → \(rebuilt) bytes")
        let rgba = try AuroraLoomTest.still(session)
        AuroraLoomTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try AuroraLoomTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(try AuroraLoomTest.digest(shell) == before)
    }
}
#endif
