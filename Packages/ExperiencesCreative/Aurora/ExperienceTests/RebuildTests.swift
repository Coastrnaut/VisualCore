// RebuildTests — feature 153 (A21-P02) T-A21-204 (FR-A21-207; SC-A21-201; contracts/experience.md "Rebuild").
// Through the one app's session host: a tuned sky drawn off screen is the same picture after `recreateContext` (the
// presenter's `setup` runs again and the scene is rebuilt from the state) and after a resize of the view and back; it
// matches the reference within the A21-P01 tolerances; the presenter caps its frames at 30 per second and leaks no GPU
// object. The sky is held still by speed 0 (and, in the second test, by Reduce Motion), so frames drawn between the
// stills do not move it. Short runs only.
import CoreGraphics
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct RebuildTests {
    /// Draws `shell`'s sky off screen and checks it against the reference.
    private func checkedStill(_ session: ExperienceSession, _ shell: ExperienceShell<AuroraPresenter>,
                              sourceLocation: SourceLocation = #_sourceLocation) throws -> [UInt8] {
        let still = try AuroraTest.still(session)
        let diff = AuroraTest.difference(still, try AuroraTest.reference(shell))
        #expect(diff.mean <= 2 && diff.max <= 8, "\(diff)", sourceLocation: sourceLocation)
        return still
    }

    @Test func thePictureIsTheSameAfterAContextLossAndAResize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, reduceMotion: true)
        AuroraTest.accept(shell, "preset.select", [1])
        AuroraTest.accept(shell, "colour.hue", [0.15])
        AuroraTest.accept(shell, "sky.ribbons", [3])
        AuroraTest.accept(shell, "light.limit", [0.4])
        AuroraTest.accept(shell, "motion.speed", [0])
        try AuroraTest.draw(session)
        let presenter = shell.presenter
        #expect(presenter.maxFramesPerSecond == 30 && shell.maxFramesPerSecond == 30)
        let setups = presenter.setupCount
        let before = try checkedStill(session, shell)

        let host = try #require(session.renderHost)
        host.recreateContext()
        try AuroraTest.draw(session)
        #expect(presenter.setupCount == setups + 1, "the scene was rebuilt")
        let afterLoss = try checkedStill(session, shell)
        #expect(AuroraTest.difference(before, afterLoss).max == 0, "the same picture after the context loss")

        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 36)
        view.layoutIfNeeded()
        try AuroraTest.draw(session, frames: 3)
        view.frame = CGRect(x: 0, y: 0, width: 32, height: 24)
        view.layoutIfNeeded()
        try AuroraTest.draw(session)
        let afterResize = try checkedStill(session, shell)
        #expect(AuroraTest.difference(before, afterResize).max == 0, "the same picture after the resize")
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func aMovingSkyIsRebuiltAtTheSameTime() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        AuroraTest.accept(shell, "preset.select", [2])
        try AuroraTest.draw(session, frames: 100)
        let presenter = shell.presenter
        #expect(!presenter.blend.isBlending)
        let time = presenter.clock.time
        #expect(time > 0, "the sky moves")
        let before = try checkedStill(session, shell)
        let host = try #require(session.renderHost)
        host.recreateContext()
        let after = try checkedStill(session, shell)
        #expect(presenter.clock.time == time, "an off-screen still does not move the clock")
        #expect(AuroraTest.difference(before, after).max == 0)
    }
}
