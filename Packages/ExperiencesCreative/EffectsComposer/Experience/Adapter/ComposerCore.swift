// ComposerCore — feature 181 (A25-P02) T-A25-205 (FR-A25-203; clarification Q3; data-model.md "ComposerCore";
// contracts/experience.md "Actions"). The state of Effects Composer as an experience: the chain of effect nodes and
// its undo and redo history. The core never draws and reads no clock; the presenter compiles and draws the chain.
//
// Actions (the engine refuses a value outside the declared range, a non-finite value and a wrong value count before
// the core sees it; called directly, the core refuses them itself with the same reasons):
//   chain.add [effect 0…4, position 0…8]          adds the effect (index into `EffectID.allCases`) at the position;
//   chain.remove [index 0…7]                       removes the node at the index;
//   chain.move [from 0…7, to 0…7]                  moves the node so that it ends at `to`;
//   chain.enable [index 0…7, on 0…1]               enables (1) or disables (0) the node;
//   chain.set [index 0…7, parameter 0…3, v 0…1]    sets the parameter (index into the effect's parameters) to
//                                                  lower + v·(upper − lower), rounded for a whole parameter;
//   edit.undo [], edit.redo []                     undo and redo through the `EditHistory`.
// A fraction where a whole number is needed (every value but `v`) is refused with `a25.not-whole`; a refused edit gives
// its `ChainRefusal` code as `a25.<code>` (`a25.bad-index`, `a25.too-many-nodes`, `a25.nothing-to-undo`,
// `a25.nothing-to-redo`, …); a parameter index the node's effect does not have is `a25.unknown-parameter`. A refused
// action changes nothing.
//
// Digest ("a25.effects-composer.v1"): the domain, then the hex text of the chain's fingerprint (`EffectChain.fingerprint`).
// The history is neither digested nor stored. Snapshot schema 1: the chain file's body, `{"nodes": [...]}`, exactly
// the bytes `ChainDocument.encode` writes for the body (choice recorded here: the body is cut from the encoded file
// and wrapped in the same envelope again on restore, so `ChainDocument` stays the only reader and writer of nodes and
// every number is read back exactly as written). Restoring a payload `ChainDocument` refuses throws that
// `ChainRefusal`; a restored core starts with an empty history.
// Feature 182 (A25-P03) T-A25-304, T-A25-305 (clarifications Q1, Q3):
//   view.compare [on 0…1]                          shows the source (1) or the result (0); not an edit (no history),
//                                                  neither stored nor digested, so a restored core shows the result;
//   chain.stage [index 0…7, id 1…65535, effect 0…4, on 0…1, v0…v3 −65535…65535]
//                                                  holds node `index` of a chain to replace the current one with: its
//                                                  identifier, effect, enabled flag and the raw values of its
//                                                  parameters in definition order (the slots beyond the effect's
//                                                  parameters are ignored); staging changes neither the chain nor the
//                                                  history, and the staged nodes are neither stored nor digested;
//   chain.replace [count 0…8]                      replaces the chain by the staged nodes 0..<count as one edit
//                                                  (`ChainEdit.replace`, undone by replacing back the earlier chain)
//                                                  and clears the staging; a position not staged is refused with
//                                                  `a25.not-staged`, an invalid chain with its `ChainRefusal`.
// Choice recorded here: an action carries at most 24 numbers (`ExperienceControl.maxValues`) and a chain needs up to
// 8 × 7, so a preset is handed to the core node by node and committed by `chain.replace`; the raw values travel
// exactly (no fraction conversion), so the opened chain equals the saved one with the same fingerprint.
// Outcome (choice recorded here: the completion scenario needs one): nil for an empty chain, else `effects-<k>` with k
// the number of enabled nodes. Quality: one tier, `level-0`.
import EffectsComposerCore
import Foundation
import VisualCoreExperience
import VisualCorePersistence

/// The rule ids of Effects Composer's refusals (feature 181).
public enum ComposerRule {
    /// The prefix of every rule id.
    public static let prefix = "a25."
    /// A value that must be whole is a fraction.
    public static let notWhole = "a25.not-whole"
    /// `chain.replace` names a position no `chain.stage` filled.
    public static let notStaged = "a25.not-staged"

    /// The rule id of a refused edit: `a25.<code>`.
    public static func id(_ refusal: ChainRefusal) -> String { prefix + refusal.code }
}

/// The state of Effects Composer (see the file header). Snapshot schema 1.
public struct ComposerCore: ExperienceCore {
    /// The experience's id in the catalog.
    public static let experienceID = "a25.effects-composer"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "a25.effects-composer.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["chain.add", "chain.remove", "chain.move", "chain.enable", "chain.set",
                                   "edit.undo", "edit.redo", "view.compare", "chain.stage", "chain.replace"]
    /// The effects in the order of `chain.add`'s first value.
    public static let effects: [EffectID] = EffectID.allCases
    /// The prefix of the outcome code (`effects-2`).
    public static let outcomePrefix = "effects-"
    /// The highest node index an action names (the chain holds at most 8 nodes).
    static let maxIndex = Double(ChainLimits.maxNodes - 1)
    /// The most parameters an effect has.
    static let maxParameters = 4
    /// The magnitude bound of a staged raw value (`chain.stage`'s value slots).
    static let maxStagedValue = 65_535.0

    /// The chain being edited.
    public private(set) var chain: EffectChain
    /// The undo and redo history of the chain's edits (not stored, not digested).
    public private(set) var history: EditHistory
    /// Whether the preview shows the source instead of the result (`view.compare`; not stored, not digested).
    public private(set) var compare = false
    /// The nodes staged by `chain.stage` for the next `chain.replace`, by position (not stored, not digested).
    public private(set) var staged: [Int: EffectNode] = [:]

    /// The opening state: an empty chain and an empty history.
    public init() {
        self.init(chain: .empty)
    }

    /// A state holding `chain` with an empty history (the chain is not checked; ``restore(payload:seed:)`` checks).
    public init(chain: EffectChain) {
        self.chain = chain
        self.history = EditHistory()
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "chain.add", ranges: [0...Double(EffectID.allCases.count - 1),
                                                    0...Double(ChainLimits.maxNodes)]),
        ExperienceControl(id: "chain.remove", ranges: [0...maxIndex]),
        ExperienceControl(id: "chain.move", ranges: [0...maxIndex, 0...maxIndex]),
        ExperienceControl(id: "chain.enable", ranges: [0...maxIndex, 0...1]),
        ExperienceControl(id: "chain.set", ranges: [0...maxIndex, 0...Double(maxParameters - 1), 0...1]),
        ExperienceControl(id: "edit.undo", ranges: []),
        ExperienceControl(id: "edit.redo", ranges: []),
        ExperienceControl(id: "view.compare", ranges: [0...1]),
        ExperienceControl(id: "chain.stage", ranges: [0...maxIndex, Double(ChainLimits.nodeIDs.lowerBound)...Double(
            ChainLimits.maxNodeID), 0...Double(EffectID.allCases.count - 1), 0...1]
            + Array(repeating: -maxStagedValue...maxStagedValue, count: maxParameters)),
        ExperienceControl(id: "chain.replace", ranges: [0...Double(ChainLimits.maxNodes)]),
    ]

    /// The ten with their declared ranges (see the file header).
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state; nothing depends on the seed and no clock is read.
    public static func prepare(seed: UInt64) async throws -> ComposerCore {
        try Task.checkCancellation()
        return ComposerCore()
    }

    /// A host step changes nothing: the state changes only by actions.
    public mutating func update(step: Int) {}

    /// The whole number `value` stands for, or nil for a fraction.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded(), abs(value) < 1e9 else { return nil }
        return Int(value)
    }

    /// The value `fraction` (0…1) stands for in `parameter`'s range: lower + fraction·(upper − lower), clamped to the
    /// range and rounded for a whole parameter.
    public static func value(of parameter: ParameterSpec, fraction: Double) -> Double {
        let lower = parameter.range.lowerBound, upper = parameter.range.upperBound
        var value = min(max(lower + fraction * (upper - lower), lower), upper)
        if parameter.whole { value = value.rounded() }
        return value
    }

    /// The fraction (0…1) of `value` in `parameter`'s range.
    public static func fraction(of parameter: ParameterSpec, value: Double) -> Double {
        let span = parameter.range.upperBound - parameter.range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - parameter.range.lowerBound) / span, 0), 1)
    }

    /// The chain edit an action asks for, or the rule id that refuses it; nil for undo and redo.
    private func edit(for control: String, _ values: [Double]) -> Result<ChainEdit?, ActionRejection> {
        let notWhole = Result<ChainEdit?, ActionRejection>.failure(.rule(code: ComposerRule.notWhole))
        switch control {
        case "chain.add":
            guard let effect = Self.whole(values[0]), let at = Self.whole(values[1]) else { return notWhole }
            guard Self.effects.indices.contains(effect) else { return .failure(.outOfRange(index: 0)) }
            return .success(.add(Self.effects[effect], at: at))
        case "chain.remove":
            guard let at = Self.whole(values[0]) else { return notWhole }
            return .success(.remove(at: at))
        case "chain.move":
            guard let from = Self.whole(values[0]), let to = Self.whole(values[1]) else { return notWhole }
            return .success(.move(from: from, to: to))
        case "chain.enable":
            guard let at = Self.whole(values[0]), let on = Self.whole(values[1]) else { return notWhole }
            return .success(.setEnabled(at: at, on == 1))
        case "chain.set":
            guard let at = Self.whole(values[0]), let index = Self.whole(values[1]) else { return notWhole }
            guard chain.nodes.indices.contains(at) else {
                return .failure(.rule(code: ComposerRule.id(.badIndex(at))))
            }
            let definition = chain.nodes[at].definition
            guard definition.parameters.indices.contains(index) else {
                return .failure(.rule(code: ComposerRule.id(.unknownParameter(definition.field("#\(index)")))))
            }
            let parameter = definition.parameters[index]
            return .success(.setValue(at: at, name: parameter.name,
                                      value: Self.value(of: parameter, fraction: values[2])))
        default:
            return .success(nil)
        }
    }

    /// The node `chain.stage` with `values` describes, with its position, or the rejection of a fraction where a
    /// whole number is needed.
    static func stagedNode(_ values: [Double]) -> Result<(index: Int, node: EffectNode), ActionRejection> {
        guard let index = whole(values[0]), let id = whole(values[1]), let effect = whole(values[2]),
              let on = whole(values[3]) else { return .failure(.rule(code: ComposerRule.notWhole)) }
        guard effects.indices.contains(effect) else { return .failure(.outOfRange(index: 2)) }
        let definition = EffectLibrary.definition(effects[effect])
        var parameters: [String: Double] = [:]
        for (slot, parameter) in definition.parameters.enumerated() where slot < maxParameters {
            parameters[parameter.name] = values[4 + slot]
        }
        return .success((index, EffectNode(id: id, effect: effects[effect], enabled: on == 1, values: parameters)))
    }

    /// The edit `chain.replace [count]` asks for: the staged nodes 0..<count, or `a25.not-staged`.
    private func replacement(_ values: [Double]) -> Result<ChainEdit?, ActionRejection> {
        guard let count = Self.whole(values[0]) else { return .failure(.rule(code: ComposerRule.notWhole)) }
        var nodes: [EffectNode] = []
        for index in 0..<count {
            guard let node = staged[index] else { return .failure(.rule(code: ComposerRule.notStaged)) }
            nodes.append(node)
        }
        return .success(.replace(EffectChain(nodes: nodes)))
    }

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        var history = self.history
        let result: Result<EffectChain, ChainRefusal>
        switch action.control {
        case "view.compare":
            guard let on = Self.whole(action.values[0]) else { return .rejected(.rule(code: ComposerRule.notWhole)) }
            compare = on == 1
            return .accepted
        case "chain.stage":
            switch Self.stagedNode(action.values) {
            case .failure(let rejection): return .rejected(rejection)
            case .success(let staging):
                staged[staging.index] = staging.node
                return .accepted
            }
        case "chain.replace":
            switch replacement(action.values) {
            case .failure(let rejection): return .rejected(rejection)
            case .success(let edit):
                result = history.apply(edit ?? .replace(chain), to: chain)
            }
            if case .success = result { staged = [:] }
        case "edit.undo":
            result = history.undo(chain)
        case "edit.redo":
            result = history.redo(chain)
        default:
            switch edit(for: action.control, action.values) {
            case .failure(let rejection):
                return .rejected(rejection)
            case .success(nil):
                return .accepted
            case .success(let edit?):
                result = history.apply(edit, to: chain)
            }
        }
        switch result {
        case .failure(let refusal):
            return .rejected(.rule(code: ComposerRule.id(refusal)))
        case .success(let next):
            chain = next
            self.history = history
            return .accepted
        }
    }

    /// Back to the opening state.
    public mutating func reset() {
        self = ComposerCore()
    }

    /// `effects-<k>` with k the enabled nodes; nil for an empty chain.
    public var outcome: ExperienceOutcome? {
        guard !chain.nodes.isEmpty else { return nil }
        return ExperienceOutcome(code: Self.outcomePrefix + "\(chain.nodes.filter(\.enabled).count)")
    }

    /// "a25.effects-composer.v1", then the hex text of the chain's fingerprint (not the history).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(chain.fingerprint().hex)
    }

    // MARK: Snapshot

    /// The start of an encoded chain file, before its body.
    static let envelopeHead = Data("{\"body\":".utf8)
    /// The end of an encoded chain file, after its body.
    static let envelopeTail = Data(",\"kind\":\"\(ChainDocument.kind)\",\"version\":\(ChainDocument.schemaVersion)}".utf8)

    /// Why a snapshot payload could not be written.
    public enum SnapshotError: Error, Equatable, Sendable {
        /// The encoded chain file did not have the expected envelope.
        case unexpectedEnvelope
    }

    /// The chain file's body, `{"nodes": [...]}`, as `ChainDocument.encode` writes it (see the file header).
    public func snapshotPayload() throws -> Data {
        let file = ChainDocument.encode(chain)
        guard file.count > Self.envelopeHead.count + Self.envelopeTail.count,
              file.starts(with: Self.envelopeHead), file.suffix(Self.envelopeTail.count) == Self.envelopeTail else {
            throw SnapshotError.unexpectedEnvelope
        }
        return Data(file.dropFirst(Self.envelopeHead.count).dropLast(Self.envelopeTail.count))
    }

    /// The core of `payload` with an empty history; throws the `ChainRefusal` of `ChainDocument.decode`. The seed
    /// changes nothing.
    public static func restore(payload: Data, seed: UInt64) throws -> ComposerCore {
        switch ChainDocument.decode(envelopeHead + payload + envelopeTail) {
        case .success(let chain): return ComposerCore(chain: chain)
        case .failure(let refusal): throw refusal
        }
    }
}
