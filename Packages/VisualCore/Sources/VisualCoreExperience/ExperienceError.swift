// ExperienceError — feature 188 T-U02-005 (FR-U02-063; contract specs/188-ua-f02-experience-sdk/contracts/
// experience-core-api.md). The typed errors of the experience contract. Every case has a stable code: codes are part
// of the API and never change once released, because evidence files and failure reports carry them.
import Foundation

/// A failure of an experience in a form that can be stored and shown: a stable code and a text for people.
public struct ExperienceFailure: Error, Sendable, Equatable, Codable {
    /// The code used when a given code is not well formed.
    public static let unspecifiedCode = "experience.unspecified"
    /// The longest code, in characters.
    public static let maxCodeLength = 64
    /// The longest message, in characters; longer text is cut.
    public static let maxMessageLength = 500

    /// The stable code: 1 to 64 characters of `a-z`, `0-9`, `.` and `-`.
    public let code: String
    /// A text for people; at most 500 characters.
    public let message: String

    /// Creates a failure. A code that is not well formed becomes `experience.unspecified`; a longer message is cut.
    public init(code: String, message: String) {
        self.code = Self.isValidCode(code) ? code : Self.unspecifiedCode
        self.message = message.count > Self.maxMessageLength ? String(message.prefix(Self.maxMessageLength)) : message
    }

    /// Whether `code` has 1 to 64 characters of `a-z`, `0-9`, `.` and `-`.
    public static func isValidCode(_ code: String) -> Bool {
        let bytes = code.utf8
        return (1...maxCodeLength).contains(bytes.count)
            && bytes.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 46 || $0 == 45 }
    }

    private enum CodingKeys: String, CodingKey { case code, message }

    /// Decodes a failure and applies the same rules as `init(code:message:)`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(code: try container.decode(String.self, forKey: .code),
                  message: try container.decode(String.self, forKey: .message))
    }
}

/// Why a value could not enter a state digest.
public enum DigestError: Error, Sendable, Equatable {
    /// The field with this zero-based index is NaN or infinite.
    case nonFinite(field: Int)

    /// The stable code of the error.
    public var code: String { "digest.non-finite" }
}

/// Why a snapshot was refused.
public enum SnapshotError: Error, Sendable, Equatable {
    /// The snapshot belongs to another experience.
    case wrongExperience(found: String)
    /// The envelope format is not one this build reads.
    case unknownFormat(Int)
    /// The payload was written by a newer schema version of the experience.
    case newerSchema(found: Int, current: Int)
    /// No migration step leads on from this schema version.
    case missingMigration(from: Int)
    /// The snapshot or its payload cannot be read; `reason` names what is wrong.
    case corrupt(reason: String)
    /// The payload does not match its checksum.
    case checksumMismatch
    /// The encoded snapshot is larger than the limit.
    case tooLarge(bytes: Int)
    /// The restored state has another digest than the one recorded at capture.
    case stateMismatch(expected: String, found: String)

    /// The stable code of the error.
    public var code: String {
        switch self {
        case .wrongExperience: "snapshot.wrong-experience"
        case .unknownFormat: "snapshot.unknown-format"
        case .newerSchema: "snapshot.newer-schema"
        case .missingMigration: "snapshot.missing-migration"
        case .corrupt: "snapshot.corrupt"
        case .checksumMismatch: "snapshot.checksum-mismatch"
        case .tooLarge: "snapshot.too-large"
        case .stateMismatch: "snapshot.state-mismatch"
        }
    }
}

/// Why an action was not carried out.
public enum ActionRejection: Error, Sendable, Equatable, Codable {
    /// The experience declared no control with this id.
    case unknownControl(String)
    /// The control takes another number of values.
    case wrongValueCount(expected: Int, found: Int)
    /// The value with this index is NaN or infinite.
    case nonFinite(index: Int)
    /// The value with this index lies outside the range the control declared.
    case outOfRange(index: Int)
    /// Actions are carried out only while the experience is active.
    case notActive(ExperienceLifecycleState)
    /// The action was made for another step than the current one.
    case wrongStep(expected: Int, found: Int)
    /// The rules of the experience do not allow the action now; `code` is defined by the experience.
    case rule(code: String)

    /// The stable code of the rejection; a rule's code follows `action.rule.`.
    public var code: String {
        switch self {
        case .unknownControl: "action.unknown-control"
        case .wrongValueCount: "action.wrong-value-count"
        case .nonFinite: "action.non-finite"
        case .outOfRange: "action.out-of-range"
        case .notActive: "action.not-active"
        case .wrongStep: "action.wrong-step"
        case .rule(let code): "action.rule." + code
        }
    }
}

/// The answer to an action.
public enum ActionResult: Sendable, Equatable, Codable {
    /// The action was carried out.
    case accepted
    /// The action was not carried out and changed nothing.
    case rejected(ActionRejection)

    /// Whether the action was carried out.
    public var isAccepted: Bool { self == .accepted }
    /// `accepted`, or the code of the rejection.
    public var code: String {
        switch self {
        case .accepted: "accepted"
        case .rejected(let rejection): rejection.code
        }
    }
}

/// An error of the experience contract.
public enum ExperienceError: Error, Sendable, Equatable {
    /// The operation is not legal in this lifecycle state.
    case illegalOperation(ExperienceOperation, in: ExperienceLifecycleState)
    /// The experience has no prepared state.
    case notPrepared
    /// The preparation was cancelled.
    case cancelled
    /// The preparation took longer than its time limit.
    case preparationTimedOut
    /// The preparation result belongs to a preparation that is no longer current.
    case stalePreparation
    /// The experience itself failed.
    case failed(ExperienceFailure)
    /// The experience did not declare this quality tier.
    case invalidTier(Int, tiers: Int)
    /// GPU objects were still live or leaked when deactivation ended.
    case gpuLeak(live: Int, leaked: Int)
    /// A snapshot was refused.
    case snapshot(SnapshotError)
    /// The state could not be reduced to a digest.
    case digest(DigestError)

    /// The stable code of the error.
    public var code: String {
        switch self {
        case .illegalOperation: "experience.illegal-operation"
        case .notPrepared: "experience.not-prepared"
        case .cancelled: "experience.cancelled"
        case .preparationTimedOut: "experience.preparation-timeout"
        case .stalePreparation: "experience.stale-preparation"
        case .failed(let failure): failure.code
        case .invalidTier: "experience.invalid-tier"
        case .gpuLeak: "experience.gpu-leak"
        case .snapshot(let error): error.code
        case .digest(let error): error.code
        }
    }

    /// The error as a storable failure: its code and a text for people.
    public var failure: ExperienceFailure {
        switch self {
        case .failed(let failure): failure
        case .illegalOperation(let operation, let state):
            ExperienceFailure(code: code, message: "\(operation.rawValue) is not legal while the experience is \(state.rawValue)")
        case .notPrepared: ExperienceFailure(code: code, message: "the experience has no prepared state")
        case .cancelled: ExperienceFailure(code: code, message: "the preparation was cancelled")
        case .preparationTimedOut: ExperienceFailure(code: code, message: "the preparation took longer than its time limit")
        case .stalePreparation: ExperienceFailure(code: code, message: "the preparation result is no longer current")
        case .invalidTier(let tier, let tiers):
            ExperienceFailure(code: code, message: "quality tier \(tier) is not one of the \(tiers) declared tiers")
        case .gpuLeak(let live, let leaked):
            ExperienceFailure(code: code, message: "\(live) GPU objects still live and \(leaked) leaked after deactivation")
        case .snapshot(let error): ExperienceFailure(code: code, message: "snapshot refused: \(error)")
        case .digest(let error): ExperienceFailure(code: code, message: "digest refused: \(error)")
        }
    }
}
