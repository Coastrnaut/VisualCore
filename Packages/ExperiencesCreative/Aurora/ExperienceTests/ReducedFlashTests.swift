// ReducedFlashTests — feature 155 (A21-P04) T-A21-407 (FR-A21-402; SC-A21-402; clarification Q2; contracts/lowpower.md
// "Reduced flash"). With "Reduced flashing" on, or the system's Reduce Flashing given to the factory, the stars do not
// twinkle and a change between skies takes 4.0 s; drawn at 30 frames per second (frames of 1/30 s, read off screen at
// 64 × 48 without moving the clock), every consecutive frame's mean Rec. 709 luminance of the sRGB-decoded pixels
// changes by less than 0.02, also during a change between skies. Short runs only.
import CoreGraphics
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct ReducedFlashTests {
    /// The declared largest step of the mean luminance between consecutive frames.
    static let step: Float = 0.02

    /// Draws `frames` frames at 30 per second and returns the largest change in mean luminance between consecutive
    /// frames, starting from the frame shown now.
    private func largestStep(_ session: ExperienceSession, frames: Int) throws -> Float {
        var previous = AuroraTest.luminance(try AuroraTest.still(session)).mean
        var largest: Float = 0
        for _ in 0..<frames {
            try AuroraTest.drawAt30(session)
            let mean = AuroraTest.luminance(try AuroraTest.still(session)).mean
            largest = max(largest, abs(mean - previous))
            previous = mean
        }
        return largest
    }

    @Test func theControlTurnsTheTwinkleOffAndSlowsAChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        let revision = shell.port.revision
        #expect(presenter.transition.sky.shader.parameters[SkyShader.twinkleOffParameter] == nil, "twinkles by default")
        presenter.setReducedFlash(true)
        #expect(presenter.reducedFlashing && presenter.mirror.reducedFlash)
        let byName = Dictionary(uniqueKeysWithValues: AuroraControls.labels(presenter.mirror).map { ($0.name, $0.text) })
        #expect(byName["reduced-flash"] == "Reduced flashing, On")
        #expect(shell.port.revision == revision, "the control sends no action")
        try AuroraTest.draw(session)
        #expect(presenter.transition.sky.shader.parameters[SkyShader.twinkleOffParameter] == 1, "no twinkle")
        #expect(presenter.transition.length == SkyTransition.reducedFlashDuration)
        #expect(SkyTransition.reducedFlashDuration == 4.0)
        AuroraTest.accept(shell, "preset.select", [1])
        try AuroraTest.draw(session, frames: 121)
        #expect(presenter.transition.isChanging && abs(presenter.transition.progress - 0.5) < 0.01, "half way at 2 s")
        try AuroraTest.draw(session, frames: 120)
        #expect(!presenter.transition.isChanging, "done after 4.0 s")
    }

    @Test(arguments: [(0, 1), (1, 2), (2, 0)])
    func everyFrameStepIsSmallAlsoDuringAChange(from: Int, to: Int) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        AuroraTest.accept(shell, "light.limit", [0.72])
        if from != 0 {
            AuroraTest.accept(shell, "preset.select", [Double(from)])
            try AuroraTest.draw(session, frames: 122)   // a change of 2.0 s, before the mode is turned on
        }
        #expect(!shell.presenter.transition.isChanging)
        shell.presenter.setReducedFlash(true)
        let still = try largestStep(session, frames: 10)
        AuroraTest.accept(shell, "preset.select", [Double(to)])
        let change = try largestStep(session, frames: 122)   // 4.0 s at 30 frames per second, and after
        #expect(!shell.presenter.transition.isChanging)
        #expect(still < Self.step && change < Self.step, "\(from)→\(to): \(still) \(change)")
        print("aurora-reduced-flash \(from)→\(to): largest mean-luminance step \(still) still, \(change) changing "
              + "(declared < \(Self.step))")
    }

    @Test func theSystemsReduceFlashingTurnsTheModeOn() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, reduceFlashing: true)
        let presenter = shell.presenter
        #expect(presenter.systemReduceFlashing && presenter.reducedFlashing && !presenter.mirror.reducedFlash)
        #expect(presenter.transition.length == SkyTransition.reducedFlashDuration)
        #expect(presenter.transition.sky.shader.parameters[SkyShader.twinkleOffParameter] == 1)
        AuroraTest.accept(shell, "preset.select", [2])
        let change = try largestStep(session, frames: 125)
        #expect(change < Self.step, "\(change)")
        print("aurora-reduced-flash system: largest step \(change)")
    }
}
