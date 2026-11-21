// WaveKnotKeeperFallbackTests — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-003, 007; SC-R02G0303-002;
// clarification Q4; spec Edge Cases). Through the one app's session host, off screen: a rope program that does not
// compile (the presenter's seam, before `setup`) draws the minimal tier's tube with the shared mesh renderer in pearl
// (no sapphire glass, no handles, no gates), keeps the reason at every tier and leaves the digest untouched; a zero-size
// view draws nothing without error and recovers; for every aspect 0.4 … 2.5 the whole figure stays inside the view (CPU:
// every control point with its handle and glow margin, every segment midpoint and every gate corner within the 5 %
// margin; pixels: the outer 4 % band is night) and the frame matches the reference; a memory warning releases the GPU
// objects and the next frame rebuilds them and draws the same image; Reduce Motion holds the snapshot time at 0 so
// frames at different times are identical; Reduce Flashing caps the glow. Short runs only.
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct WaveKnotKeeperFallbackTests {
    @Test func aBrokenRopeProgramDrawsTheFallback() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 0) { $0.breakRopeShader() }
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let before: String = try WaveKnotKeeperTest.digest(shell)
        let rgba: [UInt8] = try WaveKnotKeeperTest.still(session)
        let reason: String = try #require(presenter.fallbackReason)
        print("wave-knot-keeper fallback reason: \(reason)")
        #expect(reason.contains("wave-knot-keeper shader"), "\(reason)")
        #expect(shell.state != .failed)
        #expect(WaveKnotKeeperTest.nonNightPixels(rgba) > 0, "the fallback frame draws something")
        // The fallback draws the tube: most control points and segment midpoints have a non-night pixel within 3 px.
        let snapshot: WaveKnotKeeperSceneSnapshot = try #require(presenter.lastSnapshot)
        let w: Int = WaveKnotKeeperTest.width
        let h: Int = WaveKnotKeeperTest.height
        var samples: Int = 0
        var drawn: Int = 0
        for p in WaveKnotKeeperTest.referencePixels(snapshot).prefix(2 * snapshot.points.count) {
            samples += 1
            guard let p else { continue }
            let found: Bool = WaveKnotKeeperTest.anyPixel(rgba, near: p.x, p.y, radius: WaveKnotKeeperTest.pointRadius,
                                                          width: w, height: h) { c in
                WaveKnotKeeperTest.channelDistance(c, WaveKnotKeeperPalette.night) > 0.05
            }
            if found { drawn += 1 }
        }
        print("wave-knot-keeper fallback: \(drawn) of \(samples) points drawn")
        #expect(samples > 0 && drawn * 3 >= samples * 2, "fallback tube drawn near \(drawn) of \(samples) points")
        // Unlit pearl: every drawn pixel is pearl scaled by the mesh renderer's light (no sapphire glass, no ember),
        // and the brightest is within 0.15 per channel of pearl.
        let pearl: SIMD3<Double> = WaveKnotKeeperPalette.pearl
        var offHue: Int = 0
        var nearest: Double = 1
        var y: Int = 0
        while y < h {
            var x: Int = 0
            while x < w {
                let c: SIMD3<Double> = WaveKnotKeeperTest.colour(rgba, x: x, y: y, width: w)
                if WaveKnotKeeperTest.channelDistance(c, WaveKnotKeeperPalette.night) > 0.05 {
                    let k: Double = c.x / pearl.x
                    if WaveKnotKeeperTest.channelDistance(c, pearl * k) > 0.03 { offHue += 1 }
                    nearest = Swift.min(nearest, WaveKnotKeeperTest.channelDistance(c, pearl))
                }
                x += 1
            }
            y += 1
        }
        #expect(offHue == 0, "\(offHue) fallback pixels are not shades of pearl")
        #expect(nearest <= WaveKnotKeeperTest.handleTolerance, "brightest fallback pixel \(nearest) from pearl")
        // The reason stays and nothing reaches the state, at every tier.
        for tier in 0..<3 {
            WaveKnotKeeperTest.pin(session, shell, tier: tier)
            try WaveKnotKeeperTest.draw(session, frames: 2)
            let again: [UInt8] = try WaveKnotKeeperTest.still(session)
            #expect(WaveKnotKeeperTest.nonNightPixels(again) > 0, "tier \(tier): fallback frame drawn")
            #expect(presenter.fallbackReason == reason)
        }
        session.qualityPin = 0
        #expect(try WaveKnotKeeperTest.digest(shell) == before)
    }

    @Test func aZeroSizeViewDrawsNothingWithoutErrorAndRecovers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 20)
        let before: String = try WaveKnotKeeperTest.digest(shell)
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
        let snapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let centre: SIMD3<Double> = WaveKnotKeeperSceneGeometry.bounds(snapshot).centre
        let camera = WaveKnotKeeperSceneGeometry.camera(for: snapshot, aspect: 1)
        #expect(WaveKnotKeeperSceneGeometry.pixel(centre, camera: camera, width: 0, height: 0) == nil)
        // The smallest off-screen picture draws too.
        let tiny: [UInt8] = try WaveKnotKeeperTest.still(session, width: 1, height: 1)
        #expect(tiny.count == 4)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        view.layoutIfNeeded()
        try WaveKnotKeeperTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        let rgba: [UInt8] = try WaveKnotKeeperTest.still(session)
        WaveKnotKeeperTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "after a zero size")
        #expect(try WaveKnotKeeperTest.digest(shell) == before)
    }

    @Test func everyAspectKeepsTheFigureInside() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 80)
        let host = try #require(session.renderHost)
        // A live resize to a tall view first (the scene's resize path).
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 50)
        host.view.layoutIfNeeded()
        try WaveKnotKeeperTest.draw(session, frames: 2)
        #expect(shell.state != .failed)
        // Aspects 0.4, 0.75, 1, 1.5 and 2.5, the short side 768 px (the check size's).
        let sizes: [(w: Int, h: Int)] = [(768, 1_920), (768, 1_024), (768, 768), (1_152, 768), (1_920, 768)]
        for size in sizes {
            let rgba: [UInt8] = try WaveKnotKeeperTest.still(session, width: size.w, height: size.h)
            let snapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "\(size.w) × \(size.h)"
            // CPU: every element lies inside the 5 % margin.
            let camera = WaveKnotKeeperTest.camera(snapshot, width: size.w, height: size.h)
            let lowX: Double = 0.05 * Double(size.w)
            let highX: Double = 0.95 * Double(size.w)
            let lowY: Double = 0.05 * Double(size.h)
            let highY: Double = 0.95 * Double(size.h)
            var outside: Int = 0
            for centre in WaveKnotKeeperSceneGeometry.worldPoints(snapshot) {
                guard let d = WaveKnotKeeperTest.disc(centre, radius: WaveKnotKeeperSceneGeometry.pointMargin,
                                                      camera: camera, width: size.w, height: size.h) else {
                    outside += 1
                    continue
                }
                if d.centre.x - d.radius < lowX || d.centre.x + d.radius > highX || d.centre.y - d.radius < lowY
                    || d.centre.y + d.radius > highY { outside += 1 }
            }
            var corners: [SIMD3<Double>] = WaveKnotKeeperSceneGeometry.segmentMidpoints(snapshot)
            for gate in snapshot.gates {
                let box = WaveKnotKeeperSceneGeometry.gateBox(gate)
                for corner in 0..<8 {
                    corners.append(SIMD3<Double>(corner & 1 == 0 ? box.low.x : box.high.x,
                                                 corner & 2 == 0 ? box.low.y : box.high.y,
                                                 corner & 4 == 0 ? box.low.z : box.high.z))
                }
            }
            for q in corners {
                guard let p = WaveKnotKeeperSceneGeometry.pixel(q, camera: camera, width: size.w, height: size.h) else {
                    outside += 1
                    continue
                }
                if p.x < lowX || p.x > highX || p.y < lowY || p.y > highY { outside += 1 }
            }
            #expect(outside == 0, "\(what): \(outside) elements outside the 5 % margin")
            // Pixels: the outer 4 % band is night, and the frame matches the reference.
            let border = WaveKnotKeeperTest.borderMisses(rgba, width: size.w, height: size.h)
            #expect(border.checked > 0 && border.misses.isEmpty, "\(what): border \(border.misses)")
            WaveKnotKeeperTest.checkFrame(rgba, snapshot: snapshot, width: size.w, height: size.h, what)
        }
    }

    @Test func reduceMotionHoldsThePulsesStill() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 60, reduceMotion: true)
        let first: [UInt8] = try WaveKnotKeeperTest.still(session, time: 0.5)
        let firstSnapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0)
        try WaveKnotKeeperTest.draw(session, frames: 5)
        let second: [UInt8] = try WaveKnotKeeperTest.still(session, time: 2.75)
        let secondSnapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 0)
        #expect(first == second, "Reduce Motion: the two frames differ")
        WaveKnotKeeperTest.checkFrame(second, snapshot: secondSnapshot, "Reduce Motion")
    }

    @Test func withoutReduceMotionThePulsesMove() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 60)
        WaveKnotKeeperTest.pin(session, shell, tier: 0)
        let first: [UInt8] = try WaveKnotKeeperTest.still(session, time: 0.5)
        let firstSnapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.time == 0.5)
        let second: [UInt8] = try WaveKnotKeeperTest.still(session, time: 2.75)
        let secondSnapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(secondSnapshot.time == 2.75)
        #expect(firstSnapshot.pulse != secondSnapshot.pulse)
        // The pulses run on over-strands at projected crossings, so a rope with crossings changes with the time.
        if !secondSnapshot.crossings.isEmpty {
            #expect(first != second, "the caustic pulses move with the presentation time")
        }
        session.qualityPin = 0
    }

    @Test func reduceFlashingCapsTheGlow() async throws {
        var means: [Double] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await WaveKnotKeeperTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            #expect(shell.presenter.scene.reducedFlash == reduceFlashing)
            WaveKnotKeeperTest.pin(session, shell, tier: 0)
            let rgba: [UInt8] = try WaveKnotKeeperTest.still(session)
            means.append(WaveKnotKeeperTest.meanLuminance(rgba))
            WaveKnotKeeperTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot),
                                          "Reduce Flashing \(reduceFlashing)")
            session.qualityPin = 0
        }
        print("wave-knot-keeper glow: mean luminance \(means[0]) without, \(means[1]) with Reduce Flashing")
        #expect(means[1] <= means[0] + 1e-9, "capped glow is not brighter: \(means)")
        #expect(WaveKnotKeeperShaders.gain(reduceFlashing: true) < WaveKnotKeeperShaders.gain(reduceFlashing: false))
        #expect(WaveKnotKeeperShaders.gain(reduceFlashing: false) <= WaveKnotKeeperShaders.maxGain)
    }

    @Test func aMemoryWarningReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 80)
        let before: String = try WaveKnotKeeperTest.digest(shell)
        let host = try #require(session.renderHost)
        try WaveKnotKeeperTest.draw(session, frames: 2)
        let image: [UInt8] = try WaveKnotKeeperTest.still(session)
        try WaveKnotKeeperTest.draw(session, frames: 1)
        let held = host.resources.stats.totalBytes
        shell.presenter.shedCaches()
        let shed = host.resources.stats.totalBytes
        #expect(shed < held, "the GPU objects were released: \(held) → \(shed) bytes")
        try WaveKnotKeeperTest.draw(session, frames: 1)
        let rebuilt = host.resources.stats.totalBytes
        #expect(rebuilt > shed, "the next frame rebuilt them: \(shed) → \(rebuilt) bytes")
        let again: [UInt8] = try WaveKnotKeeperTest.still(session)
        #expect(again == image, "the rebuilt scene draws the same image")
        WaveKnotKeeperTest.checkFrame(again, snapshot: try #require(shell.presenter.lastSnapshot),
                                      "after a memory warning")
        // The session's own memory-warning path sheds through the shell and keeps the experience running.
        session.handleMemoryWarning()
        try WaveKnotKeeperTest.draw(session, frames: 1)
        #expect(shell.state != .failed)
        #expect(try WaveKnotKeeperTest.digest(shell) == before)
    }
}
#endif
