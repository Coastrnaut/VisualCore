// ComposerRecoveryTests — feature 185 (A25-P06) T-A25-604 (clarification Q4; data-model.md "Seam"; contracts/release.md
// "Recovery"). Short runs only (well under 10 s, no sleep, no wall-clock assertion). Through the one app's session host
// on the simulator, over a temporary experience storage (`PresetStoragePlace`, its folder and defaults suite removed
// afterwards): two looks are saved through the presenter, which writes `preset-1.json`, `preset-2.json` and
// `presets.json`; a drawing failure injected with the presenter's seam (`failNextDraw`, which throws
// `ComposerDrawError.injected` once) fails the session with that error's message, "The picture could not be drawn.",
// and leaves every storage file byte for byte, also after the session is closed. A new session over the same storage
// lists both looks and opens each equal to the saved chain; listing, opening and drawing write nothing.
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

/// A drawing failure fails the session, keeps every stored look and a new session reopens both.
@MainActor
@Suite(.serialized) struct ComposerRecoveryTests {
    @Test func aFailedDrawLeavesTheLooksAndANewSessionOpensThem() async throws {
        let place = try PresetStoragePlace("recovery-draw")
        defer { place.remove() }

        let first = ExperienceSession()
        let shell = try await ComposerTest.open(first, storage: place.storage)
        #expect(place.storage.list().isEmpty, "nothing is written at open")
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.set", [0, 0, 0.75])
        let warm = try ComposerTest.core(shell).chain
        let one = try shell.presenter.save(name: "Warm look").get()
        ComposerTest.accept(shell, "chain.add", [3, 1])
        ComposerTest.accept(shell, "chain.enable", [0, 0])
        let cool = try ComposerTest.core(shell).chain
        #expect(cool != warm)
        let two = try shell.presenter.save(name: "Cool look").get()
        try ComposerTest.draw(first)
        let saved = try place.contents()
        #expect(Set(saved.keys) == [one.file, two.file, LookLibrary.indexFile], "two looks and the index")
        #expect(Set([one.file, two.file]) == ["preset-1.json", "preset-2.json"])

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        #expect(first.state == .failed, "a drawing failure fails the session")
        let failure = try #require(first.failure)
        #expect(failure.message == String(describing: ComposerDrawError.injected), "the injected error's message")
        #expect(failure.message == "The picture could not be drawn.")
        #expect(failure.stage == .draw)
        let cleared = shell.presenter.failNextDraw
        #expect(!cleared, "the seam clears itself")
        #expect(try place.contents() == saved, "every file is unchanged by the failure")
        first.close()
        #expect(first.hostsAlive == 0)
        #expect(try place.contents() == saved, "every file is unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await ComposerTest.open(second, storage: place.storage)
        try ComposerTest.draw(second)
        #expect(second.failure == nil && second.state == .running, "the new session opens and draws")
        let presenter = reopened.presenter
        #expect(presenter.mirror.presets.map(\.file) == [two.file, one.file], "both looks are listed, newest first")
        #expect(presenter.mirror.presets.map(\.name) == ["Cool look", "Warm look"])
        #expect(presenter.mirror.presets.allSatisfy(\.isReadable) && !presenter.mirror.presetsReadOnly)
        _ = try presenter.open(file: one.file).get()
        #expect(try ComposerTest.core(reopened).chain == warm, "the first look opens equal to the saved chain")
        try ComposerTest.draw(second)
        _ = try presenter.open(file: two.file).get()
        #expect(try ComposerTest.core(reopened).chain == cool, "the second look opens equal to the saved chain")
        try ComposerTest.draw(second)
        #expect(second.state == .running && second.failure == nil)
        #expect(try place.contents() == saved, "listing, opening and drawing write nothing")
    }
}
