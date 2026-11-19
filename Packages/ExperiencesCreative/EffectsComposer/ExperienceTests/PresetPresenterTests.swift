// PresetPresenterTests — feature 182 (A25-P03) T-A25-304 (FR-A25-302; clarification Q3; User Story 2). The presenter's
// library actions over a temporary storage (`PresetStoragePlace`): saving the chain, opening it again as one undoable
// edit (undo returns the chain before opening, redo the opened one, with the same fingerprint), renaming and removing,
// each with its sentence; the core's staging refuses a position not staged; without storage every action is refused
// as unavailable. Short runs; no clock, no sleep.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct PresetPresenterTests {
    @Test func openingAPresetIsOneUndoableEdit() async throws {
        let place = try PresetStoragePlace("presenter-open")
        defer { place.remove() }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session, storage: place.storage)
        let presenter = shell.presenter
        #expect(presenter.mirror.hasLibrary && presenter.mirror.presets.isEmpty)
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.set", [0, 1, 0.37])
        ComposerTest.accept(shell, "chain.add", [3, 1])
        ComposerTest.accept(shell, "chain.enable", [1, 0])
        ComposerTest.accept(shell, "chain.add", [4, 0])
        ComposerTest.accept(shell, "chain.remove", [0])
        let saved = try ComposerTest.core(shell).chain
        let entry = try presenter.save(name: "  Warm look ").get()
        #expect(entry.name == "Warm look")
        #expect(presenter.mirror.libraryMessage == "Saved Warm look.")
        #expect(presenter.mirror.presets.map(\.file) == [entry.file])

        ComposerTest.accept(shell, "chain.add", [1, 0])
        ComposerTest.accept(shell, "chain.move", [0, 2])
        try ComposerTest.draw(session)
        let before = try ComposerTest.core(shell).chain
        let undoCount = try ComposerTest.core(shell).history.undoCount
        #expect(before != saved)

        let opened = try presenter.open(file: entry.file).get()
        #expect(opened == entry)
        var core = try ComposerTest.core(shell)
        #expect(core.chain == saved && core.chain.fingerprint() == saved.fingerprint())
        #expect(core.history.undoCount == undoCount + 1, "one edit")
        #expect(core.staged.isEmpty)
        #expect(presenter.mirror.libraryMessage == "Opened Warm look.")
        try ComposerTest.draw(session)
        #expect(try ComposerTest.difference(shell, saved) <= ComposerTest.tolerance(saved))

        ComposerTest.accept(shell, "edit.undo")
        core = try ComposerTest.core(shell)
        #expect(core.chain == before && core.chain.fingerprint() == before.fingerprint())
        ComposerTest.accept(shell, "edit.redo")
        #expect(try ComposerTest.core(shell).chain == saved)

        let renamed = try presenter.rename(file: entry.file, to: "Cool look").get()
        #expect(renamed.name == "Cool look")
        #expect(presenter.mirror.libraryMessage == "Renamed Warm look to Cool look.")
        #expect(presenter.mirror.presets.map(\.name) == ["Cool look"])
        _ = try presenter.remove(file: entry.file).get()
        #expect(presenter.mirror.libraryMessage == "Removed Cool look.")
        #expect(presenter.mirror.presets.isEmpty)
        #expect(try ComposerTest.core(shell).chain == saved, "removing keeps the chain")
        #expect(presenter.open(file: entry.file) == .failure(.missing))
        #expect(presenter.mirror.libraryMessage == LookLibraryFailure.missing.message)
    }

    @Test func aRefusedSaveShowsItsMessageAndChangesNothing() async throws {
        let place = try PresetStoragePlace("presenter-refused")
        defer { place.remove() }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session, storage: place.storage)
        let presenter = shell.presenter
        #expect(presenter.save(name: "   ") == .failure(.badName))
        #expect(presenter.mirror.libraryMessage == "A name has 1 to 40 characters.")
        _ = try presenter.save(name: "Plain").get()
        guard case .failure(.taken) = presenter.save(name: "PLAIN") else {
            Issue.record("a name another preset has, ignoring case, is refused")
            return
        }
        #expect(presenter.mirror.libraryMessage?.hasPrefix("A preset is already called ") == true)
        #expect(presenter.mirror.presets.count == 1)
    }

    @Test func withoutStorageEveryLibraryActionIsUnavailable() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let presenter = shell.presenter
        #expect(presenter.library == nil && presenter.mirror.hasLibrary == false)
        #expect(presenter.save(name: "A") == .failure(.unavailable))
        #expect(presenter.open(file: "preset-1.json") == .failure(.unavailable))
        #expect(presenter.rename(file: "preset-1.json", to: "B") == .failure(.unavailable))
        #expect(presenter.remove(file: "preset-1.json") == .failure(.unavailable))
        #expect(presenter.mirror.libraryMessage == LookLibraryFailure.unavailable.message)
    }

    @Test func replacingNeedsEveryPositionStaged() throws {
        let node = EffectNode(id: 9, effect: .blur, enabled: false, values: ["radius": 5])
        var (core, result) = ComposerTest.applied(ComposerCore(), "chain.stage",
                                                  ComposerPresenter.stageValues(node, at: 1))
        #expect(result == .accepted && core.chain == .empty && core.history.undoCount == 0)
        #expect(try ComposerTest.digest(core) == ComposerTest.digest(ComposerCore()), "staging is not digested")
        (core, result) = ComposerTest.applied(core, "chain.replace", [2])
        #expect(result.code == "action.rule." + ComposerRule.notStaged)
        (core, result) = ComposerTest.applied(core, "chain.stage",
                                              ComposerPresenter.stageValues(EffectNode(id: 4, effect: .grade), at: 0))
        (core, result) = ComposerTest.applied(core, "chain.replace", [2])
        #expect(result == .accepted)
        #expect(core.chain == EffectChain(nodes: [EffectNode(id: 4, effect: .grade), node]))
        #expect(core.staged.isEmpty && core.history.undoCount == 1)
        // An invalid chain is refused with its code and the staging kept.
        (core, result) = ComposerTest.applied(core, "chain.stage",
                                              ComposerPresenter.stageValues(EffectNode(id: 4, effect: .grade), at: 0))
        (core, result) = ComposerTest.applied(core, "chain.stage",
                                              ComposerPresenter.stageValues(EffectNode(id: 4, effect: .blur), at: 1))
        let (refused, code) = ComposerTest.applied(core, "chain.replace", [2])
        #expect(code.code == "action.rule.a25.duplicate-node")
        #expect(refused.chain == core.chain && refused.staged.count == 2)
    }
}
