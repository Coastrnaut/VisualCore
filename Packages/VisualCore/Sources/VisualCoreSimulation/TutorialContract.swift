// TutorialContract — feature 224 (R02-F24) T-R02F24-005 (FR-R02F24-004, 005, 006; SC-R02F24-003; clarifications Q4,
// Q5). A tutorial is an ordered list of 1 … 64 steps, each naming a text key (localised by the consuming experience) and
// the condition that completes it: any move, a number of moves since the step began, any solved level, one named level
// solved, or an acknowledgement. `TutorialContractProgress` advances exactly when the current step's condition is met,
// ignores every other event and every event after the end or for another contract, can skip the current step and
// restart from the beginning. Its stored form is JSON schema 1 with sorted keys, decoded against its contract.
import Foundation

/// The condition that completes a tutorial step.
public enum TutorialCondition: Sendable, Equatable, Codable {
    /// Any move.
    case move
    /// `n` moves since the step began, `n` in 1 … ``TutorialContractStep/maxMoves``.
    case moves(Int)
    /// Any level solved.
    case solve
    /// The level with this identity solved; the identity is 1 … ``TutorialContractStep/maxIdentityLength`` characters.
    case solveLevel(String)
    /// The player acknowledged the step.
    case acknowledge
}

/// One step of a tutorial contract: an id, a text key and the condition that completes it.
public struct TutorialContractStep: Sendable, Equatable, Codable {
    /// The largest move count a `.moves(n)` condition may ask for.
    public static let maxMoves = 1_000
    /// The longest text key, in characters.
    public static let maxTextKeyLength = 128
    /// The longest level identity a `.solveLevel` condition may name, in characters.
    public static let maxIdentityLength = 128

    /// The step id, a lowercase slug unique within its contract.
    public let id: String
    /// The key of the text to show, localised by the consuming experience.
    public let textKey: String
    /// The condition that completes this step.
    public let condition: TutorialCondition

    /// Creates a step.
    ///
    /// - Throws: `.tutorial("stepID")` unless `id` is a lowercase slug of 1 … 64 characters; `.tutorial("textKey")`
    ///   unless `textKey` has 1 … ``maxTextKeyLength`` characters; `.tutorial("condition")` for a move count outside
    ///   1 … ``maxMoves`` or a level identity that is empty or longer than ``maxIdentityLength`` characters.
    public init(id: String, textKey: String, condition: TutorialCondition) throws(ContentError) {
        guard PuzzleError.isSlug(id) else { throw .tutorial("stepID") }
        guard !textKey.isEmpty, textKey.count <= Self.maxTextKeyLength else { throw .tutorial("textKey") }
        switch condition {
        case .moves(let n):
            guard n >= 1, n <= Self.maxMoves else { throw .tutorial("condition") }
        case .solveLevel(let identity):
            guard !identity.isEmpty, identity.count <= Self.maxIdentityLength else { throw .tutorial("condition") }
        case .move, .solve, .acknowledge:
            break
        }
        self.id = id
        self.textKey = textKey
        self.condition = condition
    }

    private enum CodingKeys: String, CodingKey {
        case id, textKey, condition
    }

    /// Decodes a step and re-runs every rule of ``init(id:textKey:condition:)``; a refusal becomes a decoding error.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        let textKey = try c.decode(String.self, forKey: .textKey)
        let condition = try c.decode(TutorialCondition.self, forKey: .condition)
        do {
            try self.init(id: id, textKey: textKey, condition: condition)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .id, in: c, debugDescription: "\(error.reasonCode): \(error)")
        }
    }
}

/// A tutorial: an id and 1 … ``maxSteps`` ordered steps with unique ids.
public struct TutorialContract: Sendable, Equatable, Codable {
    /// The most steps a contract may have.
    public static let maxSteps = 64

    /// The contract id, a lowercase slug.
    public let id: String
    /// The ordered steps.
    public let steps: [TutorialContractStep]

    /// Creates a contract.
    ///
    /// - Throws: `.tutorial("id")` unless `id` is a lowercase slug of 1 … 64 characters; `.tutorial("steps")` for no
    ///   steps or more than ``maxSteps``; `.tutorial("duplicateStep")` when two steps share an id.
    public init(id: String, steps: [TutorialContractStep]) throws(ContentError) {
        guard PuzzleError.isSlug(id) else { throw .tutorial("id") }
        guard !steps.isEmpty, steps.count <= Self.maxSteps else { throw .tutorial("steps") }
        var seen: Set<String> = []
        for step in steps {
            guard seen.insert(step.id).inserted else { throw .tutorial("duplicateStep") }
        }
        self.id = id
        self.steps = steps
    }

    private enum CodingKeys: String, CodingKey {
        case id, steps
    }

    /// Decodes a contract and re-runs every rule of ``init(id:steps:)``; a refusal becomes a decoding error.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        let steps = try c.decode([TutorialContractStep].self, forKey: .steps)
        do {
            try self.init(id: id, steps: steps)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .id, in: c, debugDescription: "\(error.reasonCode): \(error)")
        }
    }
}

/// Something the player did that may complete a tutorial step.
public enum TutorialEvent: Sendable, Equatable {
    /// The player made a move.
    case moved
    /// The player solved the level with this identity.
    case solved(String)
    /// The player acknowledged the shown step.
    case acknowledged
}

/// A player's position in a tutorial contract.
public struct TutorialContractProgress: Sendable, Equatable {
    /// The current stored-form schema.
    public static var schema: Int { 1 }

    /// The id of the contract this progress belongs to.
    public let contractID: String
    /// The index of the current step; equal to the step count when finished.
    public private(set) var step: Int
    /// The moves counted since the current step began.
    public private(set) var movesInStep: Int
    /// The ids of the completed steps, in order.
    public private(set) var completed: [String]
    /// The ids of the skipped steps, in order.
    public private(set) var skipped: [String]
    /// Whether every step was completed or skipped.
    public private(set) var finished: Bool

    /// The progress at the start of `contract`.
    public init(contract: TutorialContract) {
        contractID = contract.id
        step = 0
        movesInStep = 0
        completed = []
        skipped = []
        finished = false
    }

    private init(contractID: String, step: Int, movesInStep: Int, completed: [String], skipped: [String], finished: Bool) {
        self.contractID = contractID
        self.step = step
        self.movesInStep = movesInStep
        self.completed = completed
        self.skipped = skipped
        self.finished = finished
    }

    /// The current step, or nil when finished or when `contract` is not this progress's contract.
    public func currentStep(in contract: TutorialContract) -> TutorialContractStep? {
        guard !finished, contract.id == contractID, step >= 0, step < contract.steps.count else { return nil }
        return contract.steps[step]
    }

    /// Applies an event: a move is always counted in the current step, and the step completes exactly when the
    /// event meets its condition. Events after the end or for another contract are ignored.
    ///
    /// - Returns: whether the progress moved to the next step.
    @discardableResult
    public mutating func apply(_ event: TutorialEvent, in contract: TutorialContract) -> Bool {
        guard let current = currentStep(in: contract) else { return false }
        let met: Bool
        switch event {
        case .moved:
            movesInStep += 1
            switch current.condition {
            case .move: met = true
            case .moves(let n): met = movesInStep >= n
            default: met = false
            }
        case .solved(let identity):
            switch current.condition {
            case .solve: met = true
            case .solveLevel(let wanted): met = identity == wanted
            default: met = false
            }
        case .acknowledged:
            met = current.condition == .acknowledge
        }
        guard met else { return false }
        completed.append(current.id)
        advance(in: contract)
        return true
    }

    /// Marks the current step skipped and moves to the next; does nothing when finished or for another contract.
    public mutating func skip(in contract: TutorialContract) {
        guard let current = currentStep(in: contract) else { return }
        skipped.append(current.id)
        advance(in: contract)
    }

    /// Returns to the first step with nothing completed or skipped.
    public mutating func restart() {
        step = 0
        movesInStep = 0
        completed = []
        skipped = []
        finished = false
    }

    private mutating func advance(in contract: TutorialContract) {
        step += 1
        movesInStep = 0
        finished = step == contract.steps.count
    }

    // MARK: - Stored form

    /// The stored form, schema 1.
    private struct StoredForm: Codable {
        var schema: Int
        var contractID: String
        var step: Int
        var movesInStep: Int
        var completed: [String]
        var skipped: [String]
        var finished: Bool
    }

    /// Only the schema, read before the rest so a newer layout is recognised.
    private struct SchemaProbe: Decodable {
        var schema: Int
    }

    /// The stored form as JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let stored = StoredForm(
            schema: Self.schema, contractID: contractID, step: step, movesInStep: movesInStep,
            completed: completed, skipped: skipped, finished: finished)
        do {
            return try encoder.encode(stored)
        } catch {
            // Only strings, integers and booleans are stored, so JSONEncoder cannot fail here.
            preconditionFailure("TutorialContractProgress.encoded: \(error)")
        }
    }

    /// Reads progress from its stored form and checks it against `contract`.
    ///
    /// - Throws: `.newerSchema(s)` for a schema above ``schema``; `.malformed(description)` for unreadable JSON,
    ///   missing or mistyped keys, a schema below 1, another contract's id, a step outside 0 … step count, a finished
    ///   flag that disagrees with the step, a negative move count, or completed and skipped ids that are not exactly
    ///   the ids of the steps before the current one, in order.
    public static func decode(_ data: Data, for contract: TutorialContract) throws(ContentError) -> TutorialContractProgress {
        let decoder = JSONDecoder()
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let s: StoredForm
        do {
            s = try decoder.decode(StoredForm.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        guard s.contractID == contract.id else { throw .malformed("contractID") }
        guard s.step >= 0, s.step <= contract.steps.count else { throw .malformed("step") }
        guard s.finished == (s.step == contract.steps.count) else { throw .malformed("finished") }
        guard s.movesInStep >= 0 else { throw .malformed("movesInStep") }
        guard s.completed.count + s.skipped.count == s.step else { throw .malformed("history") }
        var c = 0
        var k = 0
        for index in 0..<s.step {
            let id = contract.steps[index].id
            if c < s.completed.count, s.completed[c] == id {
                c += 1
            } else if k < s.skipped.count, s.skipped[k] == id {
                k += 1
            } else {
                throw .malformed("history")
            }
        }
        return TutorialContractProgress(
            contractID: s.contractID, step: s.step, movesInStep: s.movesInStep,
            completed: s.completed, skipped: s.skipped, finished: s.finished)
    }
}
