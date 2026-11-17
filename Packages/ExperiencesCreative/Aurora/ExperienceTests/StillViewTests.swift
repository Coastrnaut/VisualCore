// StillViewTests — feature 155 (A21-P04) T-A21-406 (FR-A21-401; SC-A21-401; clarification Q3; contracts/lowpower.md
// "Still view"). Through the one app's session host: with "Still sky" on, the sky is drawn once over 100 frames and the
// clock holds; a control change draws it once more and it holds again; a change between skies runs to its end, then
// holds; with Reduce Motion on as well the still view wins (the change is immediate and the picture holds). The control
// is presentation only: no action is sent, the snapshot and the digest stay. Short runs only.
import CoreGraphics
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct StillViewTests {
    @Test func theStillSkyIsDrawnOnceAndOnceMoreAfterAChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        let revision = shell.port.revision
        let digest = try shell.engine.digest()
        let snapshot = try shell.snapshot()
        presenter.setStillView(true)
        #expect(presenter.mirror.stillView)
        #expect(shell.port.revision == revision, "no action was sent")
        let byName = Dictionary(uniqueKeysWithValues: AuroraControls.labels(presenter.mirror).map { ($0.name, $0.text) })
        #expect(byName["still"] == "Still sky, On")
        #expect(shell.port.identifier("still") == "experience.a21.aurora.still")
        let start = presenter.skyDrawCount
        let time = presenter.clock.time
        try AuroraTest.draw(session, frames: 100)
        let held = presenter.skyDrawCount - start
        #expect(held == 1, "drawn once over 100 frames: \(held)")
        #expect(presenter.clock.time == time, "the clock holds")
        #expect(try shell.snapshot().payload == snapshot.payload, "the still view is not in the snapshot")
        #expect(try shell.engine.digest() == digest, "nor in the digest")
        let host = try #require(session.renderHost)
        let first = host.readPixels()
        AuroraTest.accept(shell, "colour.hue", [0.2])
        let before = presenter.skyDrawCount
        try AuroraTest.draw(session, frames: 100)
        let again = presenter.skyDrawCount - before
        #expect(again == 1, "drawn once more after a control change: \(again)")
        #expect(host.readPixels() != first, "the new picture is shown")
        print("aurora-still: draws over 100 frames \(held); after a change \(again)")
        presenter.setStillView(false)
        let moving = presenter.skyDrawCount
        try AuroraTest.draw(session, frames: 10)
        #expect(presenter.skyDrawCount - moving == 10, "off again, the sky draws every frame")
    }

    @Test func aChangeBetweenSkiesCompletesThenHolds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        presenter.setStillView(true)
        try AuroraTest.draw(session, frames: 5)
        AuroraTest.accept(shell, "preset.select", [1])
        let start = presenter.skyDrawCount
        try AuroraTest.draw(session, frames: 60)
        #expect(presenter.transition.isChanging, "the change runs in the still view")
        try AuroraTest.draw(session, frames: 80)
        #expect(!presenter.transition.isChanging, "and completes")
        let duringChange = presenter.skyDrawCount - start
        #expect(duringChange >= 120 && duringChange <= 122, "one draw per frame of the change: \(duringChange)")
        let held = presenter.skyDrawCount
        try AuroraTest.draw(session, frames: 100)
        #expect(presenter.skyDrawCount == held, "then holds")
        #expect(presenter.lastUniforms?.palette == SkyInputs(scene: SkyPresets.violetVeil.scene, hue: 0).palette)
        let diff = AuroraTest.difference(try AuroraTest.still(session), try AuroraTest.reference(shell))
        #expect(diff.mean <= 2 && diff.max <= 8, "the new sky: \(diff)")
        print("aurora-still: draws during a change \(duringChange); after it 0 over 100 frames")
    }

    @Test func withReduceMotionTooTheStillViewWinsAndHolds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, reduceMotion: true)
        let presenter = shell.presenter
        presenter.setStillView(true)
        let start = presenter.skyDrawCount
        try AuroraTest.draw(session, frames: 100)
        #expect(presenter.skyDrawCount - start == 1)
        AuroraTest.accept(shell, "preset.select", [2])
        let before = presenter.skyDrawCount
        let time = presenter.clock.time
        try AuroraTest.draw(session, frames: 100)
        #expect(!presenter.transition.isChanging, "immediate under Reduce Motion")
        #expect(presenter.skyDrawCount - before == 1, "drawn once, then held")
        #expect(presenter.clock.time == time)
    }
}
