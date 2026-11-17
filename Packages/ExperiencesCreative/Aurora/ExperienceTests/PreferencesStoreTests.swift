// PreferencesStoreTests — feature 154 (A21-P03) T-A21-305 (FR-A21-303, FR-A21-304; SC-A21-302; clarifications Q3, Q4;
// data-model.md "Preferences and the session snapshot", "Messages"; contracts/experience.md "Preferences"). Through
// the one app's session host with a real `ExperienceStorage` in a temporary folder: changed choices survive a close
// and a reopen (every field, the sky drawn from the first frame without a change); a damaged, a newer and an
// out-of-range value open with the defaults, keep their code, show the message and are saved over only after the next
// accepted change; a failed save (the storage's value quota full) is shown once and the choices stay in memory; a
// restored session snapshot wins for the sky, never for the sound choice. Short runs only.
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct PreferencesStoreTests {
    /// The saved preferences of `storage`, decoded.
    private func kept(_ storage: ExperienceStorage) throws -> SkyPreferences {
        let data = try #require(storage.value(for: SkyPreferences.storageKey))
        return try SkyPreferences.decode(data).get()
    }

    @Test func closingAndReopeningKeepsEveryChoice() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        var wanted = SkyPresets.dawnHaze.scene
        do {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AuroraTest.open(session, storage: place.storage)
            #expect(shell.presenter.preferences == .defaults && shell.presenter.mirror.message == nil)
            #expect(place.storage.value(for: SkyPreferences.storageKey) == nil, "nothing is written at open")
            AuroraTest.accept(shell, "preset.select", [2])
            AuroraTest.accept(shell, "colour.hue", [0.2])
            AuroraTest.accept(shell, "motion.speed", [1.4])
            AuroraTest.accept(shell, "motion.turbulence", [0.7])
            AuroraTest.accept(shell, "sky.ribbons", [2])
            AuroraTest.accept(shell, "sky.stars", [140])
            AuroraTest.accept(shell, "sky.clouds", [0.5])
            AuroraTest.accept(shell, "light.limit", [0.35])
            shell.presenter.setSound(on: true)
            shell.presenter.setVolume(0.8)
            wanted = try AuroraTest.core(shell).scene
            let saved = try kept(place.storage)
            #expect(saved == SkyPreferences(scene: wanted, hue: 0.2, limit: 0.35, soundOn: true, volume: 0.8),
                    "written after every accepted change")
            try AuroraTest.draw(session, frames: 130)
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, storage: place.storage)
        let presenter = shell.presenter
        let core = try AuroraTest.core(shell)
        #expect(core == SkyCore(scene: wanted, hue: 0.2, limit: 0.35), "every sky field")
        #expect(core.scene.preset == "dawn-haze" && core.scene.speed == 1.4 && core.scene.turbulence == 0.7)
        #expect(core.scene.ribbons == 2 && core.scene.stars == 140 && core.scene.cloudiness == 0.5)
        #expect(presenter.preferences == SkyPreferences(scene: wanted, hue: 0.2, limit: 0.35, soundOn: true,
                                                        volume: 0.8))
        #expect(presenter.mirror.soundOn && presenter.mirror.volume == 0.8 && presenter.mirror.message == nil)
        #expect(!presenter.transition.isChanging, "the saved sky is there from the first frame")
        let uniforms = try #require(presenter.lastUniforms)
        #expect(uniforms.palette == SkyInputs(scene: wanted, hue: 0.2).palette && abs(uniforms.limit - 0.35) < 1e-6)
        let diff = AuroraTest.difference(try AuroraTest.still(session), try AuroraTest.reference(shell))
        #expect(diff.mean <= 2 && diff.max <= 8, "\(diff)")
    }

    @Test func damagedNewerAndOutOfRangeValuesOpenWithTheDefaults() async throws {
        let defaults = SkyPreferences.defaults.encoded()
        let newer = try #require(String(data: defaults, encoding: .utf8)?
            .replacingOccurrences(of: "\"version\":1", with: "\"version\":2"))
        var outOfRange = SkyPreferences(scene: SkyPresets.dawnHaze.scene, hue: 0.1, limit: 0.5, soundOn: true)
        outOfRange.limit = 0.9
        let samples: [(String, Data)] = [("damaged", Data("{\"kind\":\"a21.prefer".utf8)),
                                         ("newer-version", Data(newer.utf8)),
                                         ("out-of-range", outOfRange.encoded())]
        for (code, data) in samples {
            let place = try AuroraTest.storage()
            defer { place.cleanUp() }
            try place.storage.setValue(data, for: SkyPreferences.storageKey)
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AuroraTest.open(session, storage: place.storage)
            let presenter = shell.presenter
            #expect(presenter.preferencesRefusal?.code == code, "\(code)")
            #expect(presenter.preferences == .defaults, "\(code)")
            #expect(presenter.mirror.message == AuroraPresenter.readFailedMessage, "\(code)")
            #expect(AuroraPresenter.readFailedMessage
                    == "Your saved choices could not be read, so the default sky is shown.")
            #expect(try AuroraTest.core(shell) == SkyCore(), "\(code): the default sky")
            #expect(!presenter.mirror.soundOn && presenter.mirror.volume == 0.5, "\(code): sound off, volume 0.5")
            #expect(SkyPresets.defaultPreset.id == "polar-night")
            try AuroraTest.draw(session, frames: 3)
            #expect(place.storage.value(for: SkyPreferences.storageKey) == data, "\(code): kept until a change")
            AuroraTest.accept(shell, "sky.stars", [60])
            var expected = SkyPreferences.defaults
            expected.stars = 60
            #expect(try kept(place.storage) == expected, "\(code): the defaults saved over it after a change")
        }
    }

    @Test func aFailedSaveIsReportedOnceAndTheChoicesStay() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        for i in 0..<StorageQuota.maxValues {
            try place.storage.setValue(Data([1]), for: "filler-\(i)")
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, storage: place.storage)
        let presenter = shell.presenter
        #expect(presenter.mirror.message == nil)
        AuroraTest.accept(shell, "preset.select", [1])
        #expect(presenter.failedSaves == 1 && presenter.saveFailureReported)
        #expect(presenter.mirror.message == AuroraPresenter.saveFailedMessage)
        #expect(AuroraPresenter.saveFailedMessage == "Your choices could not be saved.")
        presenter.mirror.message = nil   // the person read it
        AuroraTest.accept(shell, "light.limit", [0.4])
        presenter.setSound(on: true)
        #expect(presenter.failedSaves == 3)
        #expect(presenter.mirror.message == nil, "reported once")
        #expect(presenter.preferences == SkyPreferences(scene: SkyPresets.violetVeil.scene, limit: 0.4, soundOn: true),
                "the choices stay in memory")
        #expect(place.storage.value(for: SkyPreferences.storageKey) == nil)
        try AuroraTest.draw(session, frames: 3)
        #expect(try AuroraTest.core(shell).limit == 0.4, "the experience runs on")
    }

    @Test func aRestoredSnapshotWinsForTheSkyNeverForTheSound() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let saved = SkyPreferences(scene: SkyPresets.dawnHaze.scene, hue: 0.3, limit: 0.5, soundOn: true, volume: 0.3)
        try place.storage.setValue(saved.encoded(), for: SkyPreferences.storageKey)
        let source = try await AuroraTest.shell()
        AuroraTest.accept(source, "preset.select", [1])
        AuroraTest.accept(source, "colour.hue", [-0.1])
        let snapshot = try source.snapshot()
        let restored = try AuroraTest.core(source)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, storage: place.storage, snapshot: snapshot)
        let presenter = shell.presenter
        let core = try AuroraTest.core(shell)
        #expect(core == restored && core.isRestored, "the snapshot's sky")
        #expect(presenter.lastUniforms?.palette == SkyInputs(scene: SkyPresets.violetVeil.scene, hue: -0.1).palette)
        #expect(presenter.preferences.soundOn && presenter.preferences.volume == 0.3, "the saved sound choice")
        #expect(presenter.mirror.soundOn && presenter.mirror.volume == 0.3)
        try AuroraTest.draw(session, frames: 3)
        #expect(try AuroraTest.core(shell) == restored, "not seeded over")
        #expect(try kept(place.storage) == saved, "kept until the next accepted change")
        AuroraTest.accept(shell, "sky.stars", [100])
        let after = try AuroraTest.core(shell)
        #expect(try kept(place.storage) == SkyPreferences(scene: after.scene, hue: -0.1, limit: restored.limit,
                                                           soundOn: true, volume: 0.3))
        // A fresh open (no snapshot) is seeded from the preferences.
        let fresh = ExperienceSession()
        defer { fresh.close() }
        let reopened = try await AuroraTest.open(fresh, storage: place.storage)
        #expect(try AuroraTest.core(reopened) == SkyCore(scene: after.scene, hue: -0.1, limit: restored.limit))
    }
}
