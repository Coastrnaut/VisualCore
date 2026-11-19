// EffectChain — feature 180 (A25-P01) T-A25-105 (FR-A25-102, FR-A25-106; clarifications Q2 and Q3; data-model.md
// "EffectNode", "EffectChain", "Chain file" refusals). A chain is an ordered list of at most 8 effect nodes; each node
// has an identifier 1…65,535 unique in the chain, an effect, an enabled flag and a value for every parameter of its
// effect. The fingerprint is a `StateDigest` of domain `a25.effect-chain.v1` over the nodes in order: identifier,
// effect raw value and version, enabled, and the values in name order (name, value).
// Choices recorded here: validation checks, in order, the length cap (`too-many-nodes`), then each node in order: its
// identifier range (`out-of-range` of `node.id`), its uniqueness (`duplicate-node` with the identifier), then its
// values as `EffectDefinition.validate(values:)` checks them. A new node takes the smallest identifier not in use;
// among 1…count + 1 one is always free. The fingerprint is total: a value that is not finite (only an invalid chain
// holds one) is digested by its bit pattern as an unsigned field, so it can never collide with a finite value.
// Pure Foundation; no UI, GPU or clock.
import Foundation
import VisualCoreExperience

/// Why a chain, an edit or a chain file was refused. Fields are named `<effect>.<parameter>` or `node.id`.
public enum ChainRefusal: Error, Equatable, Sendable {
    /// The file is not a JSON object of the chain kind, misses or mistypes a field, or has a version below 1.
    case damaged
    /// The file was written by a newer version.
    case newerVersion
    /// The file is above ``ChainLimits/maxFileBytes``.
    case tooLarge
    /// The named value is NaN or infinite.
    case notFinite(String)
    /// The named value is outside its range, or a fraction where only whole numbers are allowed.
    case outOfRange(String)
    /// The file names an effect that is not built in (the raw text).
    case unknownEffect(String)
    /// A value names a parameter its effect does not have.
    case unknownParameter(String)
    /// A parameter of the effect has no value.
    case missingParameter(String)
    /// The chain would hold more than ``ChainLimits/maxNodes`` nodes.
    case tooManyNodes
    /// Two nodes share the identifier.
    case duplicateNode(Int)
    /// Undo was asked with nothing to undo.
    case nothingToUndo
    /// Redo was asked with nothing to redo.
    case nothingToRedo
    /// An edit named a position outside the chain.
    case badIndex(Int)

    /// The stable code: `damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range`, `unknown-effect`,
    /// `unknown-parameter`, `missing-parameter`, `too-many-nodes`, `duplicate-node`, `nothing-to-undo`,
    /// `nothing-to-redo` or `bad-index`.
    public var code: String {
        switch self {
        case .damaged: "damaged"
        case .newerVersion: "newer-version"
        case .tooLarge: "too-large"
        case .notFinite: "not-finite"
        case .outOfRange: "out-of-range"
        case .unknownEffect: "unknown-effect"
        case .unknownParameter: "unknown-parameter"
        case .missingParameter: "missing-parameter"
        case .tooManyNodes: "too-many-nodes"
        case .duplicateNode: "duplicate-node"
        case .nothingToUndo: "nothing-to-undo"
        case .nothingToRedo: "nothing-to-redo"
        case .badIndex: "bad-index"
        }
    }
}

/// The caps of a chain, its history and its file.
public enum ChainLimits {
    /// The most nodes a chain holds.
    public static let maxNodes = 8
    /// The largest node identifier; identifiers run 1…``maxNodeID``.
    public static let maxNodeID = 65_535
    /// The allowed node identifiers.
    public static let nodeIDs: ClosedRange<Int> = 1...maxNodeID
    /// The most edits an ``EditHistory`` keeps; the oldest is dropped beyond it.
    public static let historyDepth = 64
    /// The largest chain file accepted, in bytes.
    public static let maxFileBytes = 65_536
}

/// One effect in a chain: its identifier, effect, enabled flag and a value for every parameter of the effect.
public struct EffectNode: Equatable, Sendable, Codable {
    /// The identifier, 1…65,535 and unique in its chain; it stays with the node through moves, removal and undo.
    public var id: Int
    /// The effect the node applies.
    public var effect: EffectID
    /// False when the node is skipped (it then leaves the picture unchanged).
    public var enabled: Bool
    /// The value of each parameter of the effect, by name.
    public var values: [String: Double]

    /// A node with the given fields (not checked; see ``EffectChain/validate()``).
    public init(id: Int, effect: EffectID, enabled: Bool, values: [String: Double]) {
        self.id = id
        self.effect = effect
        self.enabled = enabled
        self.values = values
    }

    /// A node of `effect` with its default values, enabled unless `enabled` is false.
    public init(id: Int, effect: EffectID, enabled: Bool = true) {
        self.init(id: id, effect: effect, enabled: enabled, values: EffectLibrary.definition(effect).defaults)
    }

    /// The definition of the node's effect.
    public var definition: EffectDefinition { EffectLibrary.definition(effect) }
}

/// An ordered chain of effect nodes, applied first to last.
public struct EffectChain: Equatable, Sendable {
    /// The domain of the chain fingerprint.
    public static let fingerprintDomain = "a25.effect-chain.v1"

    /// The chain with no node; it draws the source unchanged.
    public static let empty = EffectChain()

    /// The nodes in the order they apply.
    public var nodes: [EffectNode]

    /// A chain of the given nodes (not checked; see ``validate()``).
    public init(nodes: [EffectNode] = []) {
        self.nodes = nodes
    }

    /// The identifier a new node takes: the smallest of 1…65,535 that no node uses. One of 1…count + 1 is always
    /// free, so it never runs out for a chain within its cap.
    public var nextNodeID: Int {
        let used = Set(nodes.map(\.id))
        var candidate = ChainLimits.nodeIDs.lowerBound
        while used.contains(candidate) { candidate += 1 }
        return candidate
    }

    /// Refuses a chain outside its caps. Checks, in order: more than ``ChainLimits/maxNodes`` nodes
    /// (``ChainRefusal/tooManyNodes``), then each node in order: an identifier outside 1…65,535
    /// (``ChainRefusal/outOfRange(_:)`` of `node.id`), an identifier already used by an earlier node
    /// (``ChainRefusal/duplicateNode(_:)``), then its values as ``EffectDefinition/validate(values:)`` checks them.
    public func validate() throws(ChainRefusal) {
        guard nodes.count <= ChainLimits.maxNodes else { throw .tooManyNodes }
        var seen = Set<Int>()
        for node in nodes {
            guard ChainLimits.nodeIDs.contains(node.id) else { throw .outOfRange("node.id") }
            guard seen.insert(node.id).inserted else { throw .duplicateNode(node.id) }
            try node.definition.validate(values: node.values)
        }
    }

    /// The fingerprint of the chain: a `StateDigest` of domain ``fingerprintDomain`` over the number of nodes and,
    /// for each node in order, its identifier, effect raw value, effect version, enabled flag, the number of values
    /// and each value in name order (name, then value). A value that is not finite is digested by its bit pattern.
    public func fingerprint() -> StateDigest {
        var builder = DigestBuilder(domain: Self.fingerprintDomain)
        builder.add(count: nodes.count)
        for node in nodes {
            builder.add(node.id)
            builder.add(node.effect.rawValue)
            builder.add(node.definition.version)
            builder.add(node.enabled)
            builder.add(count: node.values.count)
            for name in node.values.keys.sorted() {
                let value = node.values[name] ?? 0
                builder.add(name)
                do {
                    try builder.add(value)
                } catch {
                    builder.add(value.bitPattern)
                }
            }
        }
        return builder.finish()
    }
}
