// ChainTests — feature 180 (A25-P01) T-A25-106 (FR-A25-102, FR-A25-103; clarification Q2; spec edge cases). The
// chain's caps and refusals: empty, full-length (8), all-disabled and duplicate-effect chains and values at exactly a
// range end are valid; a ninth node, an identifier outside 1…65,535, a duplicate identifier and an invalid value are
// refused; new nodes take the smallest unused identifier; edits refuse bad indices, the cap, unknown parameters and
// out-of-range values; move leaves the node at index `to`; the fingerprint follows order, values and flags.
import Foundation
import Testing
import VisualCoreExperience
@testable import EffectsComposerCore

@Suite struct ChainTests {
    /// The refusal of `chain.validate()`, or nil when valid.
    private func refusal(_ chain: EffectChain) -> ChainRefusal? {
        do throws(ChainRefusal) {
            try chain.validate()
            return nil
        } catch {
            return error
        }
    }

    /// A chain of `count` nodes cycling through the five effects, identifiers 1…count.
    private func chain(count: Int, enabled: Bool = true) -> EffectChain {
        EffectChain(nodes: (0..<count).map {
            EffectNode(id: $0 + 1, effect: EffectID.allCases[$0 % 5], enabled: enabled)
        })
    }

    @Test func edgeCaseChainsAreValid() {
        #expect(refusal(.empty) == nil)
        #expect(EffectChain.empty.nodes.isEmpty)
        #expect(refusal(chain(count: ChainLimits.maxNodes)) == nil)
        #expect(refusal(chain(count: 5, enabled: false)) == nil)
        let twice = EffectChain(nodes: [EffectNode(id: 1, effect: .blur), EffectNode(id: 2, effect: .blur)])
        #expect(refusal(twice) == nil)
        var ends = EffectNode(id: ChainLimits.maxNodeID, effect: .vignette)
        ends.values = ["amount": 1, "radius": 0.2, "softness": 0.05]
        #expect(refusal(EffectChain(nodes: [ends])) == nil)
    }

    @Test func capsAndRefusals() {
        #expect(refusal(chain(count: ChainLimits.maxNodes + 1)) == .tooManyNodes)
        #expect(refusal(EffectChain(nodes: [EffectNode(id: 0, effect: .grade)])) == .outOfRange("node.id"))
        #expect(refusal(EffectChain(nodes: [EffectNode(id: 65_536, effect: .grade)])) == .outOfRange("node.id"))
        let duplicate = EffectChain(nodes: [EffectNode(id: 4, effect: .grade), EffectNode(id: 4, effect: .blur)])
        #expect(refusal(duplicate) == .duplicateNode(4))
        var node = EffectNode(id: 1, effect: .posterize)
        node.values["levels"] = 33
        #expect(refusal(EffectChain(nodes: [node])) == .outOfRange("posterize.levels"))
        node.values["levels"] = .nan
        #expect(refusal(EffectChain(nodes: [node])) == .notFinite("posterize.levels"))
        node.values = [:]
        #expect(refusal(EffectChain(nodes: [node])) == .missingParameter("posterize.levels"))
        #expect(ChainLimits.maxNodes == 8 && ChainLimits.historyDepth == 64 && ChainLimits.maxFileBytes == 65_536)
    }

    @Test func refusalCodes() {
        let cases: [(ChainRefusal, String)] = [
            (.damaged, "damaged"), (.newerVersion, "newer-version"), (.tooLarge, "too-large"),
            (.notFinite("a.b"), "not-finite"), (.outOfRange("a.b"), "out-of-range"),
            (.unknownEffect("x"), "unknown-effect"), (.unknownParameter("a.b"), "unknown-parameter"),
            (.missingParameter("a.b"), "missing-parameter"), (.tooManyNodes, "too-many-nodes"),
            (.duplicateNode(1), "duplicate-node"), (.nothingToUndo, "nothing-to-undo"),
            (.nothingToRedo, "nothing-to-redo"), (.badIndex(3), "bad-index"),
        ]
        for (refusal, code) in cases { #expect(refusal.code == code) }
    }

    @Test func newNodesTakeTheSmallestUnusedID() {
        #expect(EffectChain.empty.nextNodeID == 1)
        let gap = EffectChain(nodes: [EffectNode(id: 1, effect: .grade), EffectNode(id: 3, effect: .blur)])
        #expect(gap.nextNodeID == 2)
        let added = ChainEdit.add(.vignette, at: 1).applied(to: gap)
        #expect(added.map { $0.nodes.map(\.id) } == .success([1, 2, 3]))
        #expect(added.map { $0.nodes[1] } == .success(EffectNode(id: 2, effect: .vignette)))
    }

    @Test func editsRefuseBadInput() {
        let base = chain(count: 3)
        #expect(ChainEdit.add(.grade, at: 4).applied(to: base) == .failure(.badIndex(4)))
        #expect(ChainEdit.add(.grade, at: -1).applied(to: base) == .failure(.badIndex(-1)))
        #expect(ChainEdit.add(.grade, at: 8).applied(to: chain(count: 8)) == .failure(.tooManyNodes))
        #expect(ChainEdit.remove(at: 3).applied(to: base) == .failure(.badIndex(3)))
        #expect(ChainEdit.move(from: 0, to: 3).applied(to: base) == .failure(.badIndex(3)))
        #expect(ChainEdit.setEnabled(at: 5, false).applied(to: base) == .failure(.badIndex(5)))
        #expect(ChainEdit.setValue(at: 0, name: "gamma", value: 1).applied(to: base)
                == .failure(.unknownParameter("grade.gamma")))
        #expect(ChainEdit.setValue(at: 0, name: "contrast", value: 3).applied(to: base)
                == .failure(.outOfRange("grade.contrast")))
        #expect(ChainEdit.setValue(at: 1, name: "radius", value: 1.5).applied(to: base)
                == .failure(.outOfRange("blur.radius")))
        #expect(ChainEdit.setValue(at: 2, name: "frequency", value: .infinity).applied(to: base)
                == .failure(.notFinite("distort.frequency")))
        #expect(ChainEdit.setValue(at: 0, name: "contrast", value: 2).applied(to: base).map { $0.nodes[0].values["contrast"] }
                == .success(2))
    }

    @Test func moveLeavesTheNodeAtTheTargetIndex() {
        let base = chain(count: 4)
        #expect(ChainEdit.move(from: 0, to: 2).applied(to: base).map { $0.nodes.map(\.id) } == .success([2, 3, 1, 4]))
        #expect(ChainEdit.move(from: 3, to: 0).applied(to: base).map { $0.nodes.map(\.id) } == .success([4, 1, 2, 3]))
        #expect(ChainEdit.move(from: 1, to: 1).applied(to: base) == .success(base))
    }

    @Test func fingerprintFollowsOrderValuesAndFlags() {
        let base = chain(count: 3)
        let print = base.fingerprint()
        #expect(base.fingerprint() == print)
        #expect(print.hex.count == 64)
        #expect(EffectChain.empty.fingerprint() != print)
        var swapped = base
        swapped.nodes.swapAt(0, 1)
        #expect(swapped.fingerprint() != print)
        var disabled = base
        disabled.nodes[0].enabled = false
        #expect(disabled.fingerprint() != print)
        var changed = base
        changed.nodes[0].values["contrast"] = 1.5
        #expect(changed.fingerprint() != print)
        var renumbered = base
        renumbered.nodes[2].id = 9
        #expect(renumbered.fingerprint() != print)
        var invalid = base
        invalid.nodes[0].values["contrast"] = .nan
        #expect(invalid.fingerprint() != print)
    }
}
