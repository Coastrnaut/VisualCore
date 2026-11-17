// SkyRecoveryDrawTests — feature 157 (A21-P06) T-A21-604 (FR-A21-603; SC-A21-602; clarification Q4; contracts/
// release.md "Recovery"). Short runs only (well under 10 s, no sleep, no wall-clock assertion). Through the one app's
// session host on the simulator, over a temporary experience storage (`AuroraTest.storage()`, its folder and defaults
// suite removed afterwards) and with a fake loop (``FakeLoops``; no audio plays): Violet veil is selected and the sound
// turned on, which writes `prefs.v1`; a drawing failure injected with the presenter's seam (`failNextDraw`, which
// throws `SkyDrawError.injected` once) fails the session with that error's message and leaves `prefs.v1` byte for
// byte, also after the session is closed. A new session over the same storage opens on Violet veil with the sound on,
// and opening writes nothing (the value stays byte for byte).
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct SkyRecoveryDrawTests {
    @Test func aFailedDrawLeavesThePreferencesAndANewSessionOpensOnThem() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let loops = FakeLoops()

        let first = ExperienceSession()
        let shell = try await AuroraTest.open(first, storage: place.storage, loopFactory: loops.factory)
        #expect(place.storage.value(for: SkyPreferences.storageKey) == nil, "nothing is written at open")
        AuroraTest.accept(shell, "preset.select", [1])
        shell.presenter.setSound(on: true)
        try AuroraTest.draw(first, frames: 3)
        #expect(try AuroraTest.core(shell).scene.preset == SkyPresets.violetVeil.id)
        let bytes = try #require(place.storage.value(for: SkyPreferences.storageKey), "prefs.v1 is written")
        let saved = try SkyPreferences.decode(bytes).get()
        #expect(saved == SkyPreferences(scene: SkyPresets.violetVeil.scene, soundOn: true))

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        #expect(first.state == .failed, "a drawing failure fails the session (FR-A21-603)")
        let failure = try #require(first.failure)
        #expect(failure.message == String(describing: SkyDrawError.injected), "the injected error's message")
        #expect(failure.message == "The Aurora draw failed: the test seam injected a failure.")
        #expect(failure.stage == .draw)
        #expect(!shell.presenter.failNextDraw, "the seam clears itself")
        #expect(place.storage.value(for: SkyPreferences.storageKey) == bytes, "prefs.v1 is unchanged by the failure")
        first.close()
        #expect(first.hostsAlive == 0)
        #expect(place.storage.value(for: SkyPreferences.storageKey) == bytes, "prefs.v1 is unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await AuroraTest.open(second, storage: place.storage, loopFactory: loops.factory)
        try AuroraTest.draw(second, frames: 2)
        #expect(second.failure == nil)
        #expect(second.state == .running, "the new session opens and draws")
        let presenter = reopened.presenter
        #expect(presenter.preferencesRefusal == nil && presenter.mirror.message == nil)
        #expect(try AuroraTest.core(reopened).scene.preset == SkyPresets.violetVeil.id, "it opens on Violet veil")
        #expect(presenter.preferences == saved)
        #expect(presenter.preferences.soundOn && presenter.mirror.soundOn, "with the sound on")
        #expect(place.storage.value(for: SkyPreferences.storageKey) == bytes, "opening writes nothing")
    }
}
