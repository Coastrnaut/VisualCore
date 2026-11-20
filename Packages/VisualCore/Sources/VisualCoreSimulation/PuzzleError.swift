// PuzzleError — feature 223 (R02-F23) T-R02F23-002 (FR-R02F23-008; clarification Q5). The refusals of the puzzle
// contract, each with a stable reason code `r2-f23.*` that consumers log with their experience id and seed. Whether a
// level is valid is not an error: it is the verdict of a ``PuzzleCertificate``.

/// A refusal of a puzzle contract request.
public enum PuzzleError: Error, Equatable, Sendable {
    /// A rules id is not a lowercase slug of 1 … 64 characters (a … z, 0 … 9, single hyphens inside).
    case rulesID
    /// A solution has more than ``FairnessBudget/maxLength`` moves.
    case solutionLength
    /// A fairness budget value is outside its range; the payload names it.
    case budget(String)
    /// An attempt budget is outside 1 … ``PuzzleGenerator/maxAttempts``.
    case attempts
    /// No attempt produced a certified level; the payload is the number of attempts made.
    case generationFailed(Int)
    /// A stored level has a schema newer than the current one; the payload is that schema.
    case newerSchema(Int)
    /// A stored level is damaged or breaks a rule; the payload describes the damage.
    case malformed(String)
    /// A stored level's identity does not match its content.
    case edited

    /// The stable reason code, `r2-f23.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .rulesID: "r2-f23.rules-id"
        case .solutionLength: "r2-f23.solution-length"
        case .budget: "r2-f23.budget"
        case .attempts: "r2-f23.attempts"
        case .generationFailed: "r2-f23.generation-failed"
        case .newerSchema: "r2-f23.newer-schema"
        case .malformed: "r2-f23.malformed"
        case .edited: "r2-f23.edited"
        }
    }

    /// Whether `id` is a lowercase slug of 1 … 64 characters: a … z and 0 … 9, with single hyphens between them.
    static func isSlug(_ id: String) -> Bool {
        let scalars = Array(id.unicodeScalars)
        guard !scalars.isEmpty, scalars.count <= 64, scalars.first != "-", scalars.last != "-" else { return false }
        var previousHyphen = false
        for s in scalars {
            let isHyphen = s == "-"
            guard isHyphen || ("a"..."z").contains(s) || ("0"..."9").contains(s) else { return false }
            if isHyphen && previousHyphen { return false }
            previousHyphen = isHyphen
        }
        return true
    }
}
