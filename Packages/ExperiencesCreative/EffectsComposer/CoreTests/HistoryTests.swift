// HistoryTests — feature 180 (A25-P01) T-A25-106 (FR-A25-103; SC-A25-102; clarification Q2; research R3). A
// recorded sequence of every edit kind undone to the start equals the start with the same fingerprint, and redone
// to the end equals the end; undoing a remove re-inserts the same node with its identifier at its old position; a
// swap undone gives the original; undo or redo with nothing to do, and redo after a new edit, are refused; a refused
// edit leaves the chain and the history unchanged; at the depth cap the oldest edit is dropped and counted.
// Feature 182 (A25-P03) T-A25-304 (clarification Q3): a replace undone returns the earlier chain exactly (same
// fingerprint) and redone the new one; an invalid replacement is refused without change.
import Foundation
import Testing
import VisualCoreExperience
@testable import EffectsComposerCore

@Suite struct HistoryTests {
    /// The success value of `result`, recorded as a failure of the test otherwise.
    private func value(_ result: Result<EffectChain, ChainRefusal>,
                       sourceLocation: SourceLocation = #_sourceLocation) throws -> EffectChain {
        switch result {
        case let .success(chain): return chain
        case let .failure(refusal):
            Issue.record("refused: \(refusal)", sourceLocation: sourceLocation)
            throw refusal
        }
    }

    /// Every edit kind, in an order that is valid from the empty chain.
    private static let sequence: [ChainEdit] = [
        .add(.grade, at: 0), .add(.posterize, at: 1), .add(.blur, at: 0), .add(.vignette, at: 3),
        .setValue(at: 1, name: "contrast", value: 2), .setValue(at: 2, name: "levels", value: 4),
        .move(from: 1, to: 2), .setEnabled(at: 0, false), .remove(at: 1), .add(.distort, at: 1),
        .setValue(at: 1, name: "amplitude", value: 0.05), .move(from: 3, to: 0), .remove(at: 3),
    ]

    @Test func everyEditUndoesToTheStartAndRedoesToTheEnd() throws {
        var history = EditHistory()
        let start = EffectChain.empty
        var chain = start
        var states = [start]
        for edit in Self.sequence {
            chain = try value(history.apply(edit, to: chain))
            states.append(chain)
        }
        let end = chain
        #expect(history.undoCount == Self.sequence.count)
        for expected in states.dropLast().reversed() {
            chain = try value(history.undo(chain))
            #expect(chain == expected)
            #expect(chain.fingerprint() == expected.fingerprint())
        }
        #expect(chain == start && chain.fingerprint() == start.fingerprint())
        #expect(history.canUndo == false && history.redoCount == Self.sequence.count)
        for expected in states.dropFirst() {
            chain = try value(history.redo(chain))
            #expect(chain == expected)
        }
        #expect(chain == end && chain.fingerprint() == end.fingerprint())
        #expect(history.canRedo == false)
    }

    @Test func undoingARemoveRestoresTheSameNode() throws {
        var history = EditHistory()
        var chain = EffectChain.empty
        for effect in [EffectID.grade, .blur, .posterize] {
            chain = try value(history.apply(.add(effect, at: chain.nodes.count), to: chain))
        }
        chain = try value(history.apply(.setValue(at: 1, name: "radius", value: 5), to: chain))
        let before = chain
        chain = try value(history.apply(.remove(at: 1), to: chain))
        // A new add after the remove would take the freed identifier; the undo must not.
        #expect(chain.nextNodeID == 2)
        chain = try value(history.undo(chain))
        #expect(chain == before)
        #expect(chain.nodes[1] == EffectNode(id: 2, effect: .blur, enabled: true, values: ["radius": 5]))
    }

    @Test func swapUndoneEqualsTheOriginal() throws {
        var history = EditHistory()
        let original = EffectChain(nodes: [EffectNode(id: 1, effect: .grade), EffectNode(id: 2, effect: .posterize)])
        let swapped = try value(history.apply(.move(from: 0, to: 1), to: original))
        #expect(swapped.nodes.map(\.id) == [2, 1])
        let undone = try value(history.undo(swapped))
        #expect(undone == original && undone.fingerprint() == original.fingerprint())
    }

    @Test func nothingToUndoOrRedoIsRefused() throws {
        var history = EditHistory()
        #expect(history.undo(.empty) == .failure(.nothingToUndo))
        #expect(history.redo(.empty) == .failure(.nothingToRedo))
        var chain = try value(history.apply(.add(.grade, at: 0), to: .empty))
        chain = try value(history.undo(chain))
        #expect(history.canRedo)
        // A new edit clears the redo stack.
        chain = try value(history.apply(.add(.blur, at: 0), to: chain))
        #expect(history.canRedo == false)
        #expect(history.redo(chain) == .failure(.nothingToRedo))
    }

    @Test func refusedEditChangesNothing() throws {
        var history = EditHistory()
        var chain = EffectChain.empty
        for index in 0..<ChainLimits.maxNodes {
            chain = try value(history.apply(.add(.vignette, at: index), to: chain))
        }
        chain = try value(history.undo(chain))
        chain = try value(history.apply(.add(.grade, at: 0), to: chain))
        chain = try value(history.undo(chain))
        let (undoCount, redoCount) = (history.undoCount, history.redoCount)
        let refusedEdits: [(ChainEdit, ChainRefusal)] = [
            (.setValue(at: 0, name: "amount", value: 1.5), .outOfRange("vignette.amount")),
            (.setValue(at: 0, name: "levels", value: 4), .unknownParameter("vignette.levels")),
            (.remove(at: 9), .badIndex(9)),
        ]
        for (edit, refusal) in refusedEdits {
            let before = chain
            #expect(history.apply(edit, to: chain) == .failure(refusal))
            #expect(chain == before)
            #expect(history.undoCount == undoCount && history.redoCount == redoCount)
        }
        // Back at the cap: one effect too many is refused without change.
        chain = try value(history.redo(chain))
        #expect(chain.nodes.count == ChainLimits.maxNodes)
        let full = (history.undoCount, history.redoCount)
        #expect(history.apply(.add(.blur, at: 0), to: chain) == .failure(.tooManyNodes))
        #expect(history.undoCount == full.0 && history.redoCount == full.1)
    }

    @Test func depthCapDropsTheOldest() throws {
        var history = EditHistory()
        var chain = try value(history.apply(.add(.grade, at: 0), to: .empty))
        let afterAdd = chain
        for step in 0..<ChainLimits.historyDepth {
            chain = try value(history.apply(.setEnabled(at: 0, step % 2 == 0 ? false : true), to: chain))
        }
        #expect(history.undoCount == ChainLimits.historyDepth)
        #expect(history.droppedCount == 1)
        for _ in 0..<ChainLimits.historyDepth { chain = try value(history.undo(chain)) }
        // The add was dropped: the oldest kept edit is undone and the node stays.
        #expect(chain == afterAdd)
        #expect(history.undo(chain) == .failure(.nothingToUndo))
    }

    @Test func replaceUndoesToTheEarlierChainAndRedoesToTheNewOne() throws {
        var history = EditHistory()
        var chain = EffectChain.empty
        chain = try value(history.apply(.add(.grade, at: 0), to: chain))
        chain = try value(history.apply(.add(.blur, at: 1), to: chain))
        chain = try value(history.apply(.setValue(at: 0, name: "contrast", value: 1.75), to: chain))
        chain = try value(history.apply(.setEnabled(at: 1, false), to: chain))
        let earlier = chain
        let opened = EffectChain(nodes: [
            EffectNode(id: 7, effect: .posterize, enabled: true, values: ["levels": 5]),
            EffectNode(id: 3, effect: .vignette, enabled: false,
                       values: ["amount": 0.25, "radius": 0.5, "softness": 0.125]),
        ])
        chain = try value(history.apply(.replace(opened), to: chain))
        #expect(chain == opened && chain.fingerprint() == opened.fingerprint())
        #expect(history.undoCount == 5)
        chain = try value(history.undo(chain))
        #expect(chain == earlier && chain.fingerprint() == earlier.fingerprint())
        chain = try value(history.redo(chain))
        #expect(chain == opened && chain.fingerprint() == opened.fingerprint())
        // Undoing past the replace still reaches the start.
        for _ in 0..<5 { chain = try value(history.undo(chain)) }
        #expect(chain == .empty)
        #expect(ChainEdit.replace(opened).applied(to: earlier) == .success(opened))
    }

    @Test func anInvalidReplacementIsRefusedWithoutChange() throws {
        var history = EditHistory()
        let chain = try value(history.apply(.add(.grade, at: 0), to: .empty))
        let duplicate = EffectChain(nodes: [EffectNode(id: 1, effect: .blur), EffectNode(id: 1, effect: .grade)])
        #expect(history.apply(.replace(duplicate), to: chain) == .failure(.duplicateNode(1)))
        let tooMany = EffectChain(nodes: (1...(ChainLimits.maxNodes + 1)).map { EffectNode(id: $0, effect: .grade) })
        #expect(history.apply(.replace(tooMany), to: chain) == .failure(.tooManyNodes))
        #expect(history.undoCount == 1 && history.redoCount == 0)
    }
}
