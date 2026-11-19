// ChainEditing — feature 180 (A25-P01) T-A25-105 (FR-A25-103; SC-A25-102; clarification Q2; research R3;
// data-model.md "ChainEdit", "EditHistory"). The five edits of a chain (add an effect at a position with its
// defaults, remove, move, set enabled, set a value) and the bounded undo and redo history. Each edit is resolved
// against the chain it applies to into a forward step and its exact inverse, recorded together (R3): add's inverse
// removes the new node; remove's inverse re-inserts the same node, with its identifier, at its old position; move
// (from, to) leaves the node at index `to` of the resulting chain and its inverse is move (to, from); set enabled and
// set value record the old flag and the old value. Every step's result is validated as a whole chain before it is
// accepted, so a refused edit, undo or redo changes neither the chain nor the history.
// Choices recorded here: an index is checked before the cap (add accepts 0…count, the others 0..<count, refused as
// `bad-index` with the offending index); a move to its own position is a valid edit; undo applies the inverse and
// moves the record to the redo stack, redo applies the forward step and moves it back; a new edit clears the redo
// stack; past 64 records the oldest is dropped and counted in `droppedCount`. Pure Foundation; no UI, GPU or clock.
// Feature 182 (A25-P03) T-A25-304 (clarification Q3): `replace(chain)` swaps the whole chain for another (opening a
// preset) as one edit; its inverse replaces back the chain it replaced, exactly. The new chain is validated as a whole
// like every other result.
import Foundation

/// One edit of a chain.
public enum ChainEdit: Equatable, Sendable {
    /// Inserts a new node of the effect, with its default values and enabled, at the position (0…count); it takes the
    /// chain's ``EffectChain/nextNodeID``.
    case add(EffectID, at: Int)
    /// Removes the node at the position.
    case remove(at: Int)
    /// Moves the node at `from` so that it ends at index `to` of the resulting chain.
    case move(from: Int, to: Int)
    /// Enables or disables the node at the position.
    case setEnabled(at: Int, Bool)
    /// Sets the named parameter of the node at the position.
    case setValue(at: Int, name: String, value: Double)
    /// Replaces the whole chain by another (opening a preset); undone by replacing back the earlier chain.
    case replace(EffectChain)

    /// The chain after this edit, or why it was refused; the result is validated as a whole chain.
    public func applied(to chain: EffectChain) -> Result<EffectChain, ChainRefusal> {
        do throws(ChainRefusal) {
            let record = try ChainStep.resolve(self, against: chain)
            return .success(try record.forward.perform(on: chain))
        } catch {
            return .failure(error)
        }
    }
}

/// A primitive change of a chain, the form in which edits and their inverses are recorded.
enum ChainStep: Equatable, Sendable {
    /// Inserts the node (with its identifier) at the position.
    case insert(EffectNode, at: Int)
    /// Removes the node at the position.
    case remove(at: Int)
    /// Moves the node at `from` to index `to` of the result.
    case move(from: Int, to: Int)
    /// Sets the enabled flag of the node at the position.
    case setEnabled(at: Int, Bool)
    /// Sets the named value of the node at the position.
    case setValue(at: Int, name: String, value: Double)
    /// Replaces the whole chain.
    case replace(EffectChain)

    /// An edit resolved against a chain: the step that applies it and the step that undoes it exactly.
    struct Record: Equatable, Sendable {
        /// The step that applies the edit.
        let forward: ChainStep
        /// The step that undoes it.
        let inverse: ChainStep
    }

    /// Checks that `index` is one of `positions`, else refuses it as ``ChainRefusal/badIndex(_:)``.
    static func check(_ index: Int, in positions: Range<Int>) throws(ChainRefusal) {
        guard positions.contains(index) else { throw .badIndex(index) }
    }

    /// Resolves `edit` against `chain` into its forward step and exact inverse. Refuses a bad index, an add beyond
    /// the length cap and a value for a parameter the node's effect does not have; the rest is refused when the
    /// forward step is performed.
    static func resolve(_ edit: ChainEdit, against chain: EffectChain) throws(ChainRefusal) -> Record {
        let nodes = chain.nodes
        switch edit {
        case let .add(effect, at):
            try check(at, in: 0..<(nodes.count + 1))
            guard nodes.count < ChainLimits.maxNodes else { throw .tooManyNodes }
            let node = EffectNode(id: chain.nextNodeID, effect: effect)
            return Record(forward: .insert(node, at: at), inverse: .remove(at: at))
        case let .remove(at):
            try check(at, in: nodes.indices)
            return Record(forward: .remove(at: at), inverse: .insert(nodes[at], at: at))
        case let .move(from, to):
            try check(from, in: nodes.indices)
            try check(to, in: nodes.indices)
            return Record(forward: .move(from: from, to: to), inverse: .move(from: to, to: from))
        case let .setEnabled(at, flag):
            try check(at, in: nodes.indices)
            return Record(forward: .setEnabled(at: at, flag), inverse: .setEnabled(at: at, nodes[at].enabled))
        case let .setValue(at, name, value):
            try check(at, in: nodes.indices)
            let node = nodes[at]
            guard let old = node.values[name], node.definition.parameter(named: name) != nil else {
                throw .unknownParameter(node.definition.field(name))
            }
            return Record(forward: .setValue(at: at, name: name, value: value),
                          inverse: .setValue(at: at, name: name, value: old))
        case let .replace(next):
            return Record(forward: .replace(next), inverse: .replace(chain))
        }
    }

    /// The chain after this step, validated as a whole (``EffectChain/validate()``); refuses a bad index, a node
    /// beyond the cap and any invalid result.
    func perform(on chain: EffectChain) throws(ChainRefusal) -> EffectChain {
        var nodes = chain.nodes
        switch self {
        case let .insert(node, at):
            try Self.check(at, in: 0..<(nodes.count + 1))
            guard nodes.count < ChainLimits.maxNodes else { throw .tooManyNodes }
            nodes.insert(node, at: at)
        case let .remove(at):
            try Self.check(at, in: nodes.indices)
            nodes.remove(at: at)
        case let .move(from, to):
            try Self.check(from, in: nodes.indices)
            try Self.check(to, in: nodes.indices)
            let node = nodes.remove(at: from)
            nodes.insert(node, at: to)
        case let .setEnabled(at, flag):
            try Self.check(at, in: nodes.indices)
            nodes[at].enabled = flag
        case let .setValue(at, name, value):
            try Self.check(at, in: nodes.indices)
            guard nodes[at].values[name] != nil else { throw .unknownParameter(nodes[at].definition.field(name)) }
            nodes[at].values[name] = value
        case let .replace(next):
            try next.validate()
            return next
        }
        let result = EffectChain(nodes: nodes)
        try result.validate()
        return result
    }
}

/// The undo and redo history of a chain's edits, at most ``ChainLimits/historyDepth`` deep. The history does not
/// hold the chain: each call takes the current chain and returns the next one, so the caller keeps both together.
/// Every method that changes the history is `mutating`, and a refused call leaves the history unchanged.
public struct EditHistory: Sendable {
    /// The applied edits, oldest first.
    private var undoStack: [ChainStep.Record] = []
    /// The undone edits, the most recently undone last.
    private var redoStack: [ChainStep.Record] = []

    /// The number of oldest edits dropped because the history was at its depth cap.
    public private(set) var droppedCount = 0

    /// An empty history.
    public init() {}

    /// True when there is an edit to undo.
    public var canUndo: Bool { undoStack.isEmpty == false }
    /// True when there is an undone edit to redo.
    public var canRedo: Bool { redoStack.isEmpty == false }
    /// The number of edits that can be undone (at most ``ChainLimits/historyDepth``).
    public var undoCount: Int { undoStack.count }
    /// The number of undone edits that can be redone.
    public var redoCount: Int { redoStack.count }

    /// Applies `edit` to `chain`. On success the edit is recorded with its inverse, the redo stack is cleared and,
    /// past the depth cap, the oldest record is dropped; on refusal nothing changes.
    public mutating func apply(_ edit: ChainEdit, to chain: EffectChain) -> Result<EffectChain, ChainRefusal> {
        let record: ChainStep.Record
        let result: EffectChain
        do throws(ChainRefusal) {
            record = try ChainStep.resolve(edit, against: chain)
            result = try record.forward.perform(on: chain)
        } catch {
            return .failure(error)
        }
        undoStack.append(record)
        if undoStack.count > ChainLimits.historyDepth {
            undoStack.removeFirst()
            droppedCount += 1
        }
        redoStack.removeAll()
        return .success(result)
    }

    /// Undoes the latest edit on `chain` (the chain that edit produced): applies its inverse and moves it to the redo
    /// stack. Refuses ``ChainRefusal/nothingToUndo`` with no edit, or the inverse's refusal when `chain` is not the
    /// chain the edit produced; a refusal changes nothing.
    public mutating func undo(_ chain: EffectChain) -> Result<EffectChain, ChainRefusal> {
        guard let record = undoStack.last else { return .failure(.nothingToUndo) }
        let result: EffectChain
        do throws(ChainRefusal) {
            result = try record.inverse.perform(on: chain)
        } catch {
            return .failure(error)
        }
        undoStack.removeLast()
        redoStack.append(record)
        return .success(result)
    }

    /// Redoes the most recently undone edit on `chain`: applies its forward step and moves it back to the undo
    /// stack. Refuses ``ChainRefusal/nothingToRedo`` with no undone edit (a new edit clears them), or the step's
    /// refusal when `chain` is not the chain the undo produced; a refusal changes nothing.
    public mutating func redo(_ chain: EffectChain) -> Result<EffectChain, ChainRefusal> {
        guard let record = redoStack.last else { return .failure(.nothingToRedo) }
        let result: EffectChain
        do throws(ChainRefusal) {
            result = try record.forward.perform(on: chain)
        } catch {
            return .failure(error)
        }
        redoStack.removeLast()
        undoStack.append(record)
        return .success(result)
    }
}
