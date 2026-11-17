// TransitionTests — feature 154 (A21-P03) T-A21-303 (FR-A21-301, FR-A21-302; SC-A21-301; clarifications Q1, Q2;
// contracts/experience.md "Transition"). Through the one app's session host, drawn off screen at 64 × 48: a change
// between presets runs through a crossfade of two moving skies over 2.0 s of frame time with smoothstep; at the mix
// steps 0, 0.1, …, 1 (read at one frame time, so both skies hold still between the reads) no pixel's Rec. 709
// luminance of the sRGB-decoded pixel is above the limit + 1/255, each frame matches the mix of both skies'
// references, and the mean absolute difference from the incoming sky alone never increases. A context loss and a
// resize during a change keep the picture and the progress; a new choice during a change restarts from the current mix
// (nothing jumps); under Reduce Motion the change is immediate. Short runs only (frames of 1/60 s at 32 × 24 points).
import CoreGraphics
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct TransitionTests {
    /// Reads the picture at the mix steps 0, 0.1, …, 1 of a change from `from` to `to` at `limit`; checks the limit,
    /// the references and that the difference from the incoming sky never grows. Returns the largest luminance and the
    /// mean differences.
    private func steps(from: Int, to: Int, limit: Double) async throws -> (largest: Float, means: [Double]) {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        if from != 0 { AuroraTest.accept(shell, "preset.select", [Double(from)]) }
        AuroraTest.accept(shell, "light.limit", [limit])
        try AuroraTest.draw(session, frames: 130)
        #expect(!presenter.transition.isChanging)
        AuroraTest.accept(shell, "preset.select", [Double(to)])
        try AuroraTest.draw(session, frames: 20)   // both skies move
        let transition = presenter.transition
        #expect(transition.isChanging && transition.outgoing != nil)
        var pictures: [[UInt8]] = []
        var largest: Float = 0
        let mixes = (0...10).map { Double($0) / 10 }
        for mix in mixes {
            transition.seek(mix: mix)
            let still = try AuroraTest.still(session)
            if mix < 1 {
                #expect(abs((presenter.lastMix ?? -1) - mix) < 1e-9, "the mix drawn is \(mix)")
            } else {
                #expect(!transition.isChanging && presenter.lastMix == nil, "the change ends at 1")
            }
            let lum = AuroraTest.luminance(still)
            #expect(lum.max <= Float(limit) + 1 / 255, "\(from)→\(to) mix \(mix): brightest \(lum.max)")
            largest = max(largest, lum.max)
            let diff = AuroraTest.difference(still, try AuroraTest.reference(shell))
            #expect(diff.mean <= 2 && diff.max <= 8, "\(from)→\(to) mix \(mix): \(diff)")
            pictures.append(still)
        }
        let incoming = try #require(pictures.last)
        let means = pictures.map { AuroraTest.difference($0, incoming).mean }
        for i in 1..<means.count {
            #expect(means[i] <= means[i - 1], "\(from)→\(to): the difference grew at \(mixes[i]): \(means)")
        }
        #expect(means[0] > 1, "the two skies differ")
        let uniforms = try #require(presenter.lastUniforms)
        #expect(uniforms.palette == SkyInputs(scene: SkyPresets.all[to].scene, hue: 0).palette)
        return (largest, means)
    }

    @Test func everyStepIsUnderTheLimitAndMovesTowardsTheNewSky() async throws {
        var largest: Float = 0
        for (from, to, limit) in [(0, 1, 0.6), (1, 2, 0.2), (2, 0, 0.72)] {
            let result = try await steps(from: from, to: to, limit: limit)
            largest = max(largest, result.largest)
            let means = result.means.map { String(format: "%.2f", $0) }.joined(separator: " ")
            print("aurora-transition \(from)→\(to) limit \(limit): max luminance \(result.largest); mean differences "
                  + means)
        }
        #expect(largest <= 0.72 + 1 / 255)
    }

    @Test func aChangeTakesTwoSecondsEasedWithBothSkiesMoving() async throws {
        #expect(SkyTransition.duration == 2.0)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        let before = try AuroraTest.still(session)
        AuroraTest.accept(shell, "preset.select", [1])
        let start = try AuroraTest.still(session)
        #expect(presenter.transition.isChanging && presenter.transition.progress == 0)
        #expect(AuroraTest.difference(start, before).max == 0, "the change starts at the old sky")
        try AuroraTest.draw(session, frames: 30)
        let phase = try #require(presenter.lastOutgoingUniforms?.phase)
        #expect(abs(presenter.transition.progress - 0.25) < 1e-9)
        #expect(abs(try #require(presenter.lastMix) - 0.15625) < 1e-9, "smoothstep(0.25)")
        try AuroraTest.draw(session, frames: 30)
        #expect(abs(presenter.transition.progress - 0.5) < 1e-9 && abs((presenter.lastMix ?? 0) - 0.5) < 1e-9)
        let outgoing = try #require(presenter.lastOutgoingUniforms)
        #expect(outgoing.phase != phase, "the outgoing sky moves")
        #expect(outgoing.phase == presenter.lastUniforms?.phase, "both skies at one time")
        #expect(outgoing.palette == SkyInputs(scene: SkyPresets.polarNight.scene, hue: 0).palette)
        try AuroraTest.draw(session, frames: 59)
        #expect(presenter.transition.isChanging)
        try AuroraTest.draw(session, frames: 1)
        #expect(!presenter.transition.isChanging, "done after 2.0 s of frames")
        let end = try AuroraTest.still(session)
        let diff = AuroraTest.difference(end, try AuroraTest.reference(shell))
        #expect(diff.mean <= 2 && diff.max <= 8, "the new sky alone: \(diff)")
        #expect(presenter.lastUniforms?.palette == SkyInputs(scene: SkyPresets.violetVeil.scene, hue: 0).palette)
        let host = try #require(session.renderHost)
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func aContextLossAndAResizeDuringAChangeKeepThePicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        AuroraTest.accept(shell, "preset.select", [2])
        try AuroraTest.draw(session, frames: 50)
        let progress = presenter.transition.progress
        #expect(presenter.transition.isChanging && progress > 0.3 && progress < 0.5)
        let before = try AuroraTest.still(session)
        let setups = presenter.setupCount
        let host = try #require(session.renderHost)
        host.recreateContext()
        let afterLoss = try AuroraTest.still(session)
        #expect(presenter.setupCount == setups + 1, "the skies were set up again")
        #expect(presenter.transition.isChanging && presenter.transition.progress == progress)
        #expect(AuroraTest.difference(before, afterLoss).max <= 1, "the same picture after the context loss")
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 36)
        view.layoutIfNeeded()
        let resized = try AuroraTest.still(session)
        view.frame = CGRect(x: 0, y: 0, width: 32, height: 24)
        view.layoutIfNeeded()
        let afterResize = try AuroraTest.still(session)
        #expect(presenter.transition.progress == progress)
        #expect(AuroraTest.difference(before, resized).max <= 1 && AuroraTest.difference(before, afterResize).max <= 1,
                "the same picture after the resize")
        try AuroraTest.draw(session, frames: 80)
        #expect(!presenter.transition.isChanging, "the change continues and ends")
        let diff = AuroraTest.difference(try AuroraTest.still(session), try AuroraTest.reference(shell))
        #expect(diff.mean <= 2 && diff.max <= 8, "\(diff)")
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func aNewChoiceDuringAChangeRestartsFromTheCurrentMix() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        AuroraTest.accept(shell, "light.limit", [0.3])
        AuroraTest.accept(shell, "preset.select", [1])
        try AuroraTest.draw(session, frames: 61)   // the first frame starts the change
        let shown = try AuroraTest.still(session)
        #expect(abs((presenter.lastMix ?? 0) - 0.5) < 1e-9)
        AuroraTest.accept(shell, "preset.select", [2])
        let restarted = try AuroraTest.still(session)
        let transition = presenter.transition
        #expect(transition.isChanging && transition.progress == 0 && transition.restarts == 1)
        #expect(transition.outgoing == nil, "the outgoing picture is the captured mix")
        #expect(AuroraTest.difference(shown, restarted).max <= 1, "nothing jumps")
        var previous = restarted
        var largest: Float = AuroraTest.luminance(restarted).max
        for _ in 0..<4 {
            try AuroraTest.draw(session, frames: 30)
            let still = try AuroraTest.still(session)
            largest = max(largest, AuroraTest.luminance(still).max)
            #expect(AuroraTest.difference(previous, still).max > 0, "the change goes on")
            previous = still
        }
        #expect(!transition.isChanging, "the restarted change ends after 2.0 s")
        #expect(presenter.lastUniforms?.palette == SkyInputs(scene: SkyPresets.dawnHaze.scene, hue: 0).palette)
        #expect(largest <= 0.3 + 1 / 255, "brightest \(largest)")
        // A lower limit than the captured picture's ends the change at once.
        AuroraTest.accept(shell, "preset.select", [0])
        try AuroraTest.draw(session, frames: 10)
        AuroraTest.accept(shell, "preset.select", [1])
        try AuroraTest.draw(session)
        #expect(transition.stillLimit == 0.3)
        AuroraTest.accept(shell, "light.limit", [0.2])
        let lowered = try AuroraTest.still(session)
        #expect(!transition.isChanging)
        #expect(AuroraTest.luminance(lowered).max <= 0.2 + 1 / 255)
        let host = try #require(session.renderHost)
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func underReduceMotionAChangeIsImmediate() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, reduceMotion: true)
        let presenter = shell.presenter
        AuroraTest.accept(shell, "preset.select", [1])
        let first = try AuroraTest.still(session)
        #expect(!presenter.transition.isChanging && presenter.lastMix == nil)
        #expect(presenter.lastUniforms?.palette == SkyInputs(scene: SkyPresets.violetVeil.scene, hue: 0).palette)
        let diff = AuroraTest.difference(first, try AuroraTest.reference(shell))
        #expect(diff.mean <= 2 && diff.max <= 8, "\(diff)")
        // Reduce Motion turned on during a change ends it.
        presenter.reduceMotion = false
        AuroraTest.accept(shell, "preset.select", [2])
        try AuroraTest.draw(session, frames: 10)
        #expect(presenter.transition.isChanging)
        presenter.reduceMotion = true
        try AuroraTest.draw(session)
        #expect(!presenter.transition.isChanging)
        #expect(presenter.lastUniforms?.palette == SkyInputs(scene: SkyPresets.dawnHaze.scene, hue: 0).palette)
    }
}
