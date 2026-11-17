// ReducedMotionTests — feature 149 (A20-P05) T-A20-504 (FR-A20-502, FR-A20-503; SC-A20-501, SC-A20-504;
// contracts/quiet.md "Reduced motion"; the phase's regression fixture "the reduced-motion state disables incidental
// animations"). Two renders at different frame times are identical with the drift off and with the drift on under
// Reduce Motion, and differ with the drift on otherwise; only the grain moves (level-1, without grain, stays the same);
// Reduce Motion turned on while the drift runs stops it at once; Reduce Flashing leaves the picture the same; two drift
// frames 1/30 s apart differ in mean luminance by less than `SandScene.maxFrameLuminanceStep`. The frame time is moved
// through the presenter's `driftTime` (seconds of drift frame time), so no test waits.
import CoreGraphics
import Foundation
import Testing
import UIKit
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct ReducedMotionTests {
    /// A session with a raked stroke and a placed stone, opened at level 0 (the grain is drawn).
    private func garden(reduceMotion: Bool = false) async throws
        -> (session: ExperienceSession, shell: ExperienceShell<GardenPresenter>) {
        let session = ExperienceSession()
        let shell = try await GardenTest.open(session, reduceMotion: reduceMotion)
        GardenTest.rake(shell, from: Vec2(0.15, 0.4), to: Vec2(0.85, 0.55))
        GardenTest.accept(shell, "stone.place", [2, 0.6, 0.4])
        try GardenTest.draw(session)
        return (session, shell)
    }

    /// The picture drawn with `seconds` of drift frame time behind it (the draw itself adds one frame's delta).
    private func picture(_ session: ExperienceSession, _ shell: ExperienceShell<GardenPresenter>,
                         at seconds: Double) throws -> GardenFrame {
        shell.presenter.driftTime = seconds - 1.0 / 60
        return try GardenTest.picture(session)
    }

    /// The mean luminance of `frame` as a share of full scale (Rec. 709 weights on the 8-bit values).
    private func meanLuminance(_ frame: GardenFrame) -> Double {
        var sum = 0.0
        var count = 0
        var i = 0
        while i + 3 < frame.rgba.count {
            sum += 0.2126 * Double(frame.rgba[i]) + 0.7152 * Double(frame.rgba[i + 1]) + 0.0722 * Double(frame.rgba[i + 2])
            count += 1
            i += 4
        }
        return count == 0 ? 0 : sum / Double(count) / 255
    }

    @Test func withTheDriftOffTwoFramesAreIdenticalAndTheStillFrameIsReused() async throws {
        let (session, shell) = try await garden()
        #expect(try !GardenTest.core(shell).calm.drift)
        let cache = try #require(shell.presenter.cache)
        let first = try picture(session, shell, at: 1)
        let draws = cache.childDrawCount
        let later = try picture(session, shell, at: 9)
        #expect(later.rgba == first.rgba, "identical without the drift")
        #expect(cache.childDrawCount == draws, "the cached still frame is reused")
        #expect(shell.presenter.grainOffset == 0 && shell.presenter.driftTime == 0)
    }

    @Test func withTheDriftOnUnderReduceMotionTwoFramesAreIdentical() async throws {
        let (session, shell) = try await garden(reduceMotion: true)
        GardenTest.accept(shell, "calm.drift", [1])
        let cache = try #require(shell.presenter.cache)
        let first = try picture(session, shell, at: 1)
        let draws = cache.childDrawCount
        let later = try picture(session, shell, at: 9)
        #expect(later.rgba == first.rgba, "Reduce Motion keeps the sand still")
        #expect(cache.childDrawCount == draws, "and reuses the still frame")
        #expect(try GardenTest.core(shell).calm.drift, "the switch itself stays on")
    }

    @Test func withTheDriftOnTheGrainMovesAndNothingElse() async throws {
        let (session, shell) = try await garden()
        let still = try picture(session, shell, at: 1)
        GardenTest.accept(shell, "calm.drift", [1])
        let cache = try #require(shell.presenter.cache)
        let first = try picture(session, shell, at: 1)
        let draws = cache.childDrawCount
        let later = try picture(session, shell, at: 9)
        #expect(GardenTest.differingPixels(later.rgba, first.rgba) > 0, "the grain drifts")
        #expect(cache.childDrawCount > draws, "each draw draws a new frame")
        #expect(abs(shell.presenter.grainOffset - 0.09) < 1e-9, "0.01 tray widths per second")
        #expect(GardenTest.differingPixels(first.rgba, still.rgba) > 0, "the offset after 1 s differs from 0")

        // Without grain (level-1) the drift changes nothing: the relief, the stones and the shadows never move.
        try shell.setQualityTier(1)
        let plainFirst = try picture(session, shell, at: 2)
        let plainLater = try picture(session, shell, at: 20)
        #expect(plainLater.rgba == plainFirst.rgba, "only the grain moves")
        try shell.setQualityTier(0)

        // Reduce Motion turned on while the drift runs stops it at once: the next frame is the still picture.
        shell.presenter.reduceMotion = true
        let stopped = try picture(session, shell, at: 30)
        #expect(stopped.rgba == still.rgba, "the drift stops at the next draw")
        let after = try picture(session, shell, at: 40)
        #expect(after.rgba == stopped.rgba)
    }

    @Test func twoDriftFramesStayBelowTheLuminanceStep() async throws {
        let (session, shell) = try await garden()
        GardenTest.accept(shell, "calm.drift", [1])
        var largest = 0.0
        var previous = try picture(session, shell, at: 10)
        for frame in 1...4 {
            let next = try picture(session, shell, at: 10 + Double(frame) / 30)
            largest = max(largest, abs(meanLuminance(next) - meanLuminance(previous)))
            previous = next
        }
        print("ZG drift: largest mean-luminance step between frames 1/30 s apart = \(largest)")
        #expect(SandScene.maxFrameLuminanceStep == 0.02)
        #expect(largest < SandScene.maxFrameLuminanceStep, "step \(largest)")
    }

    @Test func reduceFlashingLeavesThePictureTheSame() async throws {
        var pictures: [[UInt8]] = []
        var sessions: [ExperienceSession] = []
        for reduceFlashing in [false, true] {
            let place = try GardenStoragePlace("calm-flashing-" + String(reduceFlashing))
            defer { place.remove() }
            let session = ExperienceSession()
            session.qualityPin = 0
            let id = GardenTest.id
            let storage = place.storage
            let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
                DigitalZenGardenExperience.make(id: id, storage: storage, reduceMotion: false,
                                                reduceFlashing: reduceFlashing)
            }
            let opened = await session.open(request)
            #expect(opened == .running)
            let view = try #require(session.renderHost?.view)
            view.frame = CGRect(origin: .zero, size: CGSize(width: 160, height: 120))
            view.layoutIfNeeded()
            try GardenTest.draw(session)
            pictures.append(try GardenTest.picture(session).rgba)
            sessions.append(session)
        }
        #expect(pictures.count == 2 && pictures[0] == pictures[1], "nothing flashes, so Reduce Flashing changes nothing")
    }
}
