// TargetReleaseTests — feature 155 (A21-P04) T-A21-408 (FR-A21-404; SC-A21-403; clarification Q5; contracts/lowpower.md
// "Target release"). Through the one app's session host: the live bytes of textures, buffers, framebuffers and
// renderbuffers (the render targets) after the first drawn frame are the baseline; after ten preset changes, each run
// to its end (2.0 s of frames), they equal the baseline, with nothing leaked. The same holds with the still view on and
// for changes restarted during a change. Short runs only.
import CoreGraphics
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct TargetReleaseTests {
    @Test func tenFinishedPresetChangesReturnToTheBaseline() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        let baseline = try AuroraTest.targetBytes(session)
        var peak = 0
        for change in 1...10 {
            AuroraTest.accept(shell, "preset.select", [Double(change % 3)])
            try AuroraTest.draw(session, frames: 10)
            #expect(presenter.transition.isChanging, "change \(change) runs")
            peak = max(peak, try AuroraTest.targetBytes(session).values.reduce(0, +))
            try AuroraTest.draw(session, frames: 112)
            #expect(!presenter.transition.isChanging, "change \(change) finished")
        }
        let after = try AuroraTest.targetBytes(session)
        #expect(after == baseline, "baseline \(baseline), after ten changes \(after)")
        #expect(peak > baseline.values.reduce(0, +), "a change holds its targets while it runs")
        let stats = try #require(session.renderHost).resources.stats
        #expect(stats.leaked == 0)
        print("aurora-targets: baseline \(baseline.values.reduce(0, +)) bytes \(baseline); peak during a change \(peak); "
              + "after ten changes \(after.values.reduce(0, +)) bytes")
    }

    @Test func restartedChangesAndTheStillViewReturnToTheBaseline() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        let baseline = try AuroraTest.targetBytes(session)
        for change in 1...5 {
            AuroraTest.accept(shell, "preset.select", [Double(change % 3)])
            try AuroraTest.draw(session, frames: 20)
            AuroraTest.accept(shell, "preset.select", [Double((change + 1) % 3)])   // restarts from the mix
            try AuroraTest.draw(session, frames: 122)
            #expect(!presenter.transition.isChanging)
        }
        #expect(try AuroraTest.targetBytes(session) == baseline, "after restarted changes")
        presenter.setStillView(true)
        try AuroraTest.draw(session, frames: 3)
        let held = try AuroraTest.targetBytes(session)
        #expect(held.values.reduce(0, +) > baseline.values.reduce(0, +), "the held picture has its target")
        AuroraTest.accept(shell, "preset.select", [1])
        try AuroraTest.draw(session, frames: 130)
        #expect(try AuroraTest.targetBytes(session) == held, "a change in the still view releases its targets")
        presenter.setStillView(false)
        try AuroraTest.draw(session)
        #expect(try AuroraTest.targetBytes(session) == baseline, "the still view's target is released")
    }
}
