// SoundChoiceTests — feature 154 (A21-P03) T-A21-306 (FR-A21-305, FR-A21-306; SC-A21-303; clarification Q5;
// contracts/experience.md "Sound choice"). The regression fixture of the manual: the sound choice (on/off and volume)
// belongs to the person, not to the drawing. Through the one app's session host with a real storage: set through the
// presenter (what the `sound` toggle and the `volume` slider call), it sends no action (the port's revision, the
// snapshot and the digest do not change) and is kept in `prefs.v1`; it is unchanged after a context recreation (setup
// again), a resize, a suspension and a resumption (scene phases), and after the teardown at close and a setup in a new
// session. The controls have spoken labels; no action exists for the sound, so nothing plays. Short runs only.
import CoreGraphics
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct SoundChoiceTests {
    /// Checks that `presenter` and `storage` keep sound on at volume 0.7 after `event`.
    private func expectKept(_ presenter: AuroraPresenter, _ storage: ExperienceStorage, after event: String,
                            sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(presenter.preferences.soundOn && presenter.preferences.volume == 0.7, "\(event)",
                sourceLocation: sourceLocation)
        #expect(presenter.mirror.soundOn && presenter.mirror.volume == 0.7, "\(event): the controls",
                sourceLocation: sourceLocation)
        let data = try #require(storage.value(for: SkyPreferences.storageKey), sourceLocation: sourceLocation)
        let kept = try SkyPreferences.decode(data).get()
        #expect(kept.soundOn && kept.volume == 0.7, "\(event): saved", sourceLocation: sourceLocation)
    }

    @Test func theSoundChoiceOutlivesEveryLifecycleEvent() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let session = ExperienceSession()
        let shell = try await AuroraTest.open(session, storage: place.storage)
        let presenter = shell.presenter
        #expect(!presenter.mirror.soundOn && presenter.mirror.volume == 0.5, "off at volume 0.5 by default")
        let snapshot = try shell.snapshot()
        let digest = try shell.engine.digest()
        let revision = shell.port.revision
        presenter.setSound(on: true)
        presenter.setVolume(0.7)
        #expect(shell.port.revision == revision, "no action was sent")
        #expect(try shell.snapshot().payload == snapshot.payload, "not in the snapshot")
        #expect(try shell.engine.digest() == digest, "nor in the digest")
        try expectKept(presenter, place.storage, after: "setting it")

        let host = try #require(session.renderHost)
        let setups = presenter.setupCount
        host.recreateContext()
        try AuroraTest.draw(session)
        #expect(presenter.setupCount == setups + 1)
        try expectKept(presenter, place.storage, after: "recreateContext")

        let view = host.view
        view.frame = CGRect(x: 0, y: 0, width: 48, height: 36)
        view.layoutIfNeeded()
        try AuroraTest.draw(session)
        try expectKept(presenter, place.storage, after: "resize")

        session.setScenePhase(.background)
        #expect(shell.state == .suspended)
        try expectKept(presenter, place.storage, after: "suspend")
        session.setScenePhase(.active)
        #expect(shell.state == .active)
        try AuroraTest.draw(session)
        try expectKept(presenter, place.storage, after: "resume")

        AuroraTest.accept(shell, "preset.select", [2])
        try AuroraTest.draw(session, frames: 10)
        try expectKept(presenter, place.storage, after: "a change of sky")
        #expect(try shell.snapshot().payload != snapshot.payload)

        session.close()   // teardown
        try expectKept(presenter, place.storage, after: "teardown")
        let next = ExperienceSession()
        defer { next.close() }
        let reopened = try await AuroraTest.open(next, storage: place.storage)   // setup of a new presenter
        try expectKept(reopened.presenter, place.storage, after: "setup")
        #expect(try AuroraTest.core(reopened).scene.preset == "dawn-haze")
    }

    @Test func theSoundControlsHaveSpokenLabelsAndSendNothing() async throws {
        let shell = try await AuroraTest.shell()
        let presenter = shell.presenter
        var byName = Dictionary(uniqueKeysWithValues: AuroraControls.labels(presenter.mirror).map { ($0.name, $0.text) })
        #expect(byName["sound"] == "Sound, Off" && byName["volume"] == "Volume, 50 %")
        presenter.setSound(on: true)
        presenter.setVolume(1.4)   // clamped
        presenter.setVolume(.nan)  // ignored
        byName = Dictionary(uniqueKeysWithValues: AuroraControls.labels(presenter.mirror).map { ($0.name, $0.text) })
        #expect(byName["sound"] == "Sound, On" && byName["volume"] == "Volume, 100 %")
        #expect(shell.port.identifier("sound") == "experience.a21.aurora.sound")
        #expect(shell.port.identifier("volume") == "experience.a21.aurora.volume")
        #expect(AuroraControls.actionOfControl["sound"] == nil && AuroraControls.actionOfControl["volume"] == nil)
        #expect(!SkyCore.actionIDs.contains { $0.contains("sound") || $0.contains("volume") }, "no sound action")
        #expect(presenter.nativeActions == Set(SkyCore.actionIDs))
        #expect(presenter.preferences.soundOn && presenter.preferences.volume == 1, "kept without storage too")
    }
}
