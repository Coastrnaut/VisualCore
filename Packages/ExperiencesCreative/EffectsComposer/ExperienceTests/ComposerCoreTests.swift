// ComposerCoreTests — feature 181 (A25-P02) T-A25-207 (FR-A25-203; SC-A25-202; clarifications Q3 and Q5). The core
// adapter of Effects Composer: the seven controls and their ranges, every action and every refusal (a refused action
// changes nothing), the value mapping of `chain.set`, the digest and the snapshot (the chain file's body; a restored
// core has an empty history), the outcome, and the spoken labels of a node row and a value control.
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
@testable import EffectsComposerExperience

/// `core` after each of `actions` applied in turn, recording an issue unless each is accepted.
private func playing(_ core: ComposerCore, _ actions: [(String, [Double])],
                     sourceLocation: SourceLocation = #_sourceLocation) -> ComposerCore {
    var current = core
    for (control, values) in actions {
        let (next, result) = ComposerTest.applied(current, control, values)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        current = next
    }
    return current
}

/// Expects `control` with `values` on `core` to be refused with `code` and to change nothing.
private func expectRefused(_ core: ComposerCore, _ control: String, _ values: [Double], _ code: String,
                           sourceLocation: SourceLocation = #_sourceLocation) throws {
    let (next, result) = ComposerTest.applied(core, control, values)
    #expect(result.code == code, "\(control) \(values)", sourceLocation: sourceLocation)
    #expect(next.chain == core.chain, sourceLocation: sourceLocation)
    #expect(next.history.undoCount == core.history.undoCount, sourceLocation: sourceLocation)
    #expect(next.history.redoCount == core.history.redoCount, sourceLocation: sourceLocation)
    #expect(try ComposerTest.digest(next) == ComposerTest.digest(core), sourceLocation: sourceLocation)
}

@Suite struct ComposerCoreTests {
    @Test func theSevenControlsHaveTheirRanges() {
        let controls = ComposerCore.controls
        #expect(controls.map(\.id) == ComposerCore.actionIDs)
        #expect(controls.map(\.id) == ["chain.add", "chain.remove", "chain.move", "chain.enable", "chain.set",
                                       "edit.undo", "edit.redo"])
        #expect(controls[0].ranges == [0...4, 0...8])
        #expect(controls[1].ranges == [0...7])
        #expect(controls[2].ranges == [0...7, 0...7])
        #expect(controls[3].ranges == [0...7, 0...1])
        #expect(controls[4].ranges == [0...7, 0...3, 0...1])
        #expect(controls[5].ranges.isEmpty && controls[6].ranges.isEmpty)
        #expect(ComposerCore.qualityTiers == 1)
        #expect(ComposerCore.migrations.currentVersion == 1)
    }

    @Test func theOpeningStateIsAnEmptyChainWithoutOutcome() async throws {
        let core = try await ComposerCore.prepare(seed: 7)
        #expect(core.chain == .empty)
        #expect(!core.history.canUndo && !core.history.canRedo)
        #expect(core.outcome == nil)
        #expect(try ComposerTest.digest(core) == ComposerTest.digest(ComposerCore()))
    }

    @Test func addRemoveMoveAndEnableEditTheChain() {
        var core = playing(ComposerCore(), [("chain.add", [0, 0]), ("chain.add", [1, 1]), ("chain.add", [4, 0])])
        #expect(core.chain.nodes.map(\.effect) == [.posterize, .grade, .blur])
        #expect(core.chain.nodes.map(\.id) == [3, 1, 2])
        #expect(core.chain.nodes.filter(\.enabled).count == 3)
        #expect(core.outcome?.code == "effects-3")
        core = playing(core, [("chain.move", [0, 2])])
        #expect(core.chain.nodes.map(\.effect) == [.grade, .blur, .posterize])
        core = playing(core, [("chain.enable", [1, 0])])
        #expect(core.chain.nodes[1].enabled == false)
        #expect(core.outcome?.code == "effects-2")
        core = playing(core, [("chain.enable", [1, 1]), ("chain.remove", [0])])
        #expect(core.chain.nodes.map(\.effect) == [.blur, .posterize])
        #expect(core.history.undoCount == 7)
    }

    @Test func setMapsTheFractionToTheRangeAndRoundsWholeParameters() {
        var core = playing(ComposerCore(), [("chain.add", [0, 0]), ("chain.add", [1, 1]), ("chain.add", [4, 2])])
        core = playing(core, [("chain.set", [0, 0, 0.75]), ("chain.set", [0, 1, 1]), ("chain.set", [0, 2, 0])])
        #expect(core.chain.nodes[0].values == ["exposure": 1, "contrast": 2, "saturation": 0])
        core = playing(core, [("chain.set", [1, 0, 0.3])])
        #expect(core.chain.nodes[1].values["radius"] == 2, "0 + 0.3·8 = 2.4 rounds to 2")
        core = playing(core, [("chain.set", [1, 0, 0.32])])
        #expect(core.chain.nodes[1].values["radius"] == 3, "2.56 rounds to 3")
        core = playing(core, [("chain.set", [2, 0, 0.5])])
        #expect(core.chain.nodes[2].values["levels"] == 17, "2 + 0.5·30 = 17")
        let vignette = EffectLibrary.definition(.vignette).parameters[1]
        #expect(abs(ComposerCore.value(of: vignette, fraction: 0.5) - 0.6) < 1e-12)
        #expect(abs(ComposerCore.fraction(of: vignette, value: 0.6) - 0.5) < 1e-12)
    }

    @Test func undoAndRedoFollowTheHistory() throws {
        let start = playing(ComposerCore(), [("chain.add", [0, 0])])
        let edited = playing(start, [("chain.set", [0, 0, 1]), ("chain.add", [2, 1])])
        var core = playing(edited, [("edit.undo", []), ("edit.undo", [])])
        #expect(core.chain == start.chain)
        #expect(core.history.redoCount == 2)
        core = playing(core, [("edit.redo", []), ("edit.redo", [])])
        #expect(core.chain == edited.chain)
        #expect(try ComposerTest.digest(core) == ComposerTest.digest(edited))
        try expectRefused(core, "edit.redo", [], "action.rule.a25.nothing-to-redo")
        core = playing(core, [("edit.undo", []), ("chain.enable", [0, 0])])
        #expect(!core.history.canRedo, "a new edit clears the redo stack")
    }

    @Test func everyRefusalNamesItsRuleAndChangesNothing() throws {
        let empty = ComposerCore()
        try expectRefused(empty, "edit.undo", [], "action.rule.a25.nothing-to-undo")
        try expectRefused(empty, "edit.redo", [], "action.rule.a25.nothing-to-redo")
        try expectRefused(empty, "chain.remove", [0], "action.rule.a25.bad-index")
        try expectRefused(empty, "chain.add", [0, 1], "action.rule.a25.bad-index")
        try expectRefused(empty, "chain.move", [0, 0], "action.rule.a25.bad-index")
        try expectRefused(empty, "chain.enable", [0, 1], "action.rule.a25.bad-index")
        try expectRefused(empty, "chain.set", [0, 0, 0.5], "action.rule.a25.bad-index")
        let one = playing(empty, [("chain.add", [1, 0])])
        try expectRefused(one, "chain.add", [0.5, 0], "action.rule.a25.not-whole")
        try expectRefused(one, "chain.add", [0, 0.5], "action.rule.a25.not-whole")
        try expectRefused(one, "chain.remove", [0.5], "action.rule.a25.not-whole")
        try expectRefused(one, "chain.move", [0, 0.5], "action.rule.a25.not-whole")
        try expectRefused(one, "chain.enable", [0, 0.5], "action.rule.a25.not-whole")
        try expectRefused(one, "chain.set", [0.5, 0, 0], "action.rule.a25.not-whole")
        try expectRefused(one, "chain.set", [0, 0.5, 0], "action.rule.a25.not-whole")
        try expectRefused(one, "chain.set", [0, 1, 0], "action.rule.a25.unknown-parameter")
        try expectRefused(one, "chain.move", [0, 1], "action.rule.a25.bad-index")
        try expectRefused(one, "chain.add", [5, 0], "action.out-of-range")
        try expectRefused(one, "chain.add", [0, 9], "action.out-of-range")
        try expectRefused(one, "chain.set", [0, 0, 1.5], "action.out-of-range")
        try expectRefused(one, "chain.add", [0], "action.wrong-value-count")
        try expectRefused(one, "edit.undo", [1], "action.wrong-value-count")
        try expectRefused(one, "chain.remove", [.nan], "action.non-finite")
        var full = one
        for k in 1..<ChainLimits.maxNodes { full = playing(full, [("chain.add", [Double(k % 5), Double(k)])]) }
        #expect(full.chain.nodes.count == 8)
        try expectRefused(full, "chain.add", [0, 8], "action.rule.a25.too-many-nodes")
    }

    @Test func theDigestFollowsTheChainOnly() throws {
        let edited = playing(ComposerCore(), [("chain.add", [0, 0]), ("chain.enable", [0, 0])])
        let restored = ComposerCore(chain: edited.chain)
        #expect(try ComposerTest.digest(restored) == ComposerTest.digest(edited), "the history is not digested")
        #expect(try ComposerTest.digest(edited) != ComposerTest.digest(ComposerCore()))
        let expected = edited.chain.fingerprint().hex
        var builder = DigestBuilder(domain: ComposerCore.experienceID)
        builder.add(ComposerCore.digestDomain)
        builder.add(expected)
        #expect(builder.finish().hex == (try ComposerTest.digest(edited)))
    }

    @Test func theSnapshotRoundTripsTheChainAndARestoredCoreHasAnEmptyHistory() throws {
        let edited = playing(ComposerCore(), [("chain.add", [0, 0]), ("chain.add", [2, 1]), ("chain.set", [1, 0, 0.3]),
                                              ("chain.enable", [0, 0]), ("chain.move", [1, 0])])
        #expect(edited.history.canUndo)
        let payload = try edited.snapshotPayload()
        let text = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"nodes\":["), "\(text)")
        #expect(try edited.snapshotPayload() == payload, "the payload is deterministic")
        let restored = try ComposerCore.restore(payload: payload, seed: 1)
        #expect(restored.chain == edited.chain)
        #expect(!restored.history.canUndo && !restored.history.canRedo)
        #expect(try ComposerTest.digest(restored) == ComposerTest.digest(edited))
        let (after, result) = ComposerTest.applied(restored, "edit.undo")
        #expect(result.code == "action.rule.a25.nothing-to-undo")
        #expect(after.chain == edited.chain)
        let empty = try ComposerCore.restore(payload: ComposerCore().snapshotPayload(), seed: 1)
        #expect(empty.chain == .empty)
    }

    @Test func aDamagedPayloadIsRefused() {
        #expect(throws: ChainRefusal.damaged) { try ComposerCore.restore(payload: Data("{}".utf8), seed: 1) }
        #expect(throws: ChainRefusal.damaged) { try ComposerCore.restore(payload: Data("[1]".utf8), seed: 1) }
        let unknown = Data("{\"nodes\":[{\"effect\":\"sparkle\",\"enabled\":true,\"id\":1,\"values\":{}}]}".utf8)
        #expect(throws: ChainRefusal.unknownEffect("sparkle")) { try ComposerCore.restore(payload: unknown, seed: 1) }
        let range = Data("{\"nodes\":[{\"effect\":\"blur\",\"enabled\":true,\"id\":1,\"values\":{\"radius\":9}}]}".utf8)
        #expect(throws: ChainRefusal.outOfRange("blur.radius")) { try ComposerCore.restore(payload: range, seed: 1) }
    }

    @Test func resetReturnsToTheOpeningState() throws {
        var core = playing(ComposerCore(), [("chain.add", [0, 0])])
        core.reset()
        #expect(core.chain == .empty && !core.history.canUndo)
    }

    @Test func theSpokenLabelsNameTheEffectItsPositionAndTheValue() {
        let core = playing(ComposerCore(), [("chain.add", [0, 0]), ("chain.add", [1, 1]), ("chain.set", [0, 0, 0.625]),
                                            ("chain.enable", [1, 0])])
        let rows = core.chain.nodes.enumerated().map { NodeRow(node: $1, index: $0) }
        #expect(ComposerLabels.nodeLabel(rows[0], count: 2)
                    == "Color grade, effect 1 of 2, on, exposure 0.5, contrast 1, saturation 1")
        #expect(ComposerLabels.nodeLabel(rows[1], count: 2) == "Blur, effect 2 of 2, off, radius 2")
        let radius = rows[1].parameters[0]
        #expect(ComposerLabels.valueLabel(rows[1], radius, count: 2, up: true)
                    == "Raise radius of Blur, effect 2 of 2, now 2")
        #expect(ComposerLabels.valueLabel(rows[0], rows[0].parameters[0], count: 2, up: false)
                    == "Lower exposure of Color grade, effect 1 of 2, now 0.5")
        #expect(ComposerLabels.enableLabel(rows[1], count: 2) == "Turn on Blur, effect 2 of 2, now off")
        #expect(ComposerLabels.moveLabel(rows[1], count: 2, up: true) == "Move Blur, effect 2 of 2, earlier")
        #expect(ComposerLabels.removeLabel(rows[0], count: 2) == "Remove Color grade, effect 1 of 2")
        #expect(ComposerLabels.addLabel(.posterize, count: 2) == "Add Posterize as effect 3")
        #expect(ComposerLabels.number(0.01, whole: false) == "0.01")
        #expect(abs(ComposerLabels.stepFraction(radius, up: true) - 0.35) < 1e-12, "2 + 0.8 = 2.8 of 0…8")
        #expect(abs(ComposerLabels.stepFraction(radius, up: false) - 0.15) < 1e-12)
    }

    @Test func refusalsReadAsSentences() {
        #expect(ComposerPresenter.message(for: "accepted") == "Ready")
        #expect(ComposerPresenter.message(for: "action.rule.a25.too-many-nodes") == "The chain holds at most 8 effects.")
        #expect(ComposerPresenter.message(for: "action.rule.a25.nothing-to-undo") == "There is nothing to undo.")
        #expect(ComposerPresenter.message(for: "action.rule.a25.not-whole") == "Only whole numbers are allowed here.")
        #expect(ComposerPresenter.message(for: "a25.pool-cap") == "The picture is larger than the preview allows.")
    }
}
