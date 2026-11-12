// ExperienceID — feature 187 T-U01-004 (FR-U01-001, FR-U01-002, FR-U01-005; data-model section 1; ADR-0009 D-06).
// The immutable identity of an experience of the unified app. Every derived name is computed here and nowhere else.
import Foundation

/// Why a code or an id text was rejected.
public enum ExperienceIDError: Error, Equatable, Sendable {
    /// The text is not a well-formed code or id; `reason` names the rule it broke.
    case malformed(text: String, reason: String)
}

/// The immutable catalog code of an experience: `A05` for an original creative experience, `R02-G01` for game 1 of
/// round 2. Two digits each; originals 01–99, rounds 02–99, games 01–99.
public struct ExperienceCode: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The code as written in the catalog, for example `A05` or `R02-G01`.
    public let text: String
    /// The round of a game (2 and above); `nil` for an original creative experience.
    public let round: Int?
    /// The number inside its collection: 5 for `A05`, 1 for `R02-G01`.
    public let number: Int

    /// Parses a code. Throws `ExperienceIDError.malformed` when the text is not exactly `A<nn>` or `R<rr>-G<gg>`.
    public init(_ text: String) throws(ExperienceIDError) {
        let bytes = Array(text.utf8)
        func digits(_ at: Int) -> Int? {
            guard at + 1 < bytes.count, (48...57).contains(bytes[at]), (48...57).contains(bytes[at + 1]) else { return nil }
            return Int(bytes[at] - 48) * 10 + Int(bytes[at + 1] - 48)
        }
        if bytes.count == 3, bytes[0] == UInt8(ascii: "A"), let number = digits(1) {
            guard number >= 1 else { throw .malformed(text: text, reason: "an original code is A01 to A99") }
            self.text = text
            self.round = nil
            self.number = number
        } else if bytes.count == 7, bytes[0] == UInt8(ascii: "R"), bytes[3] == UInt8(ascii: "-"), bytes[4] == UInt8(ascii: "G"),
                  let round = digits(1), let number = digits(5) {
            guard round >= 2 else { throw .malformed(text: text, reason: "a round is 02 to 99") }
            guard number >= 1 else { throw .malformed(text: text, reason: "a game is G01 to G99") }
            self.text = text
            self.round = round
            self.number = number
        } else {
            throw .malformed(text: text, reason: "a code is A<nn> or R<rr>-G<gg> with two digits each")
        }
    }

    /// Whether this is one of the original creative experiences (`A<nn>`).
    public var isOriginal: Bool { round == nil }
    /// The integration gate of the experience in the migration ledger: `X-<code>`.
    public var integrationGate: String { "X-" + text }
    /// The code as text.
    public var description: String { text }

    /// Codes order as their texts do, which is the catalog order: originals first, then rounds and games.
    public static func < (lhs: ExperienceCode, rhs: ExperienceCode) -> Bool { lhs.text < rhs.text }
}

/// The immutable runtime id of an experience: the code in lower case, a dot and the slug, for example
/// `a05.infinite-geometry`. Storage, accessibility identifiers, evidence files and ledger gates are named from it.
public struct ExperienceID: Hashable, Comparable, Sendable, RawRepresentable, Codable, CustomStringConvertible {
    /// The longest slug the catalog accepts.
    public static let maxSlugLength = 60

    /// The catalog code inside the id.
    public let code: ExperienceCode
    /// The part after the dot: lower-case letters and digits in groups joined by single hyphens.
    public let slug: String
    /// The id as text; identical to the text it was parsed from.
    public let rawValue: String

    /// Parses an id. Throws `ExperienceIDError.malformed` when the text is not `<code in lower case>.<slug>`.
    public init(_ text: String) throws(ExperienceIDError) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw .malformed(text: text, reason: "an id has exactly one dot between code and slug") }
        let codeText = String(parts[0]), slug = String(parts[1])
        guard codeText.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }) else {
            throw .malformed(text: text, reason: "the code part is written in lower case")
        }
        do {
            code = try ExperienceCode(codeText.uppercased())
        } catch {
            guard case let .malformed(_, reason) = error else { throw error }
            throw .malformed(text: text, reason: reason)
        }
        guard (1...Self.maxSlugLength).contains(slug.utf8.count) else {
            throw .malformed(text: text, reason: "a slug has 1 to \(Self.maxSlugLength) characters")
        }
        var previousWasHyphen = true
        for byte in slug.utf8 {
            if byte == 45 {
                guard !previousWasHyphen else { throw .malformed(text: text, reason: "hyphens in a slug stand between groups, one at a time") }
                previousWasHyphen = true
            } else if (97...122).contains(byte) || (48...57).contains(byte) {
                previousWasHyphen = false
            } else {
                throw .malformed(text: text, reason: "a slug holds lower-case letters, digits and hyphens only")
            }
        }
        guard !previousWasHyphen else { throw .malformed(text: text, reason: "a slug does not end with a hyphen") }
        self.slug = slug
        rawValue = text
    }

    /// Parses an id; `nil` when the text is malformed.
    public init?(rawValue: String) {
        guard let id = try? ExperienceID(rawValue) else { return nil }
        self = id
    }

    /// Decodes an id from its text; a malformed text is a decoding error.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        do {
            self = try ExperienceID(text)
        } catch {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "malformed experience id \(text)")
        }
    }

    /// Encodes the id as its text.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The integration gate of the experience in the migration ledger: `X-<code>`.
    public var integrationGate: String { code.integrationGate }
    /// The namespace of everything the experience stores: the id itself.
    public var storageNamespace: String { rawValue }
    /// The name of the experience's evidence files: the id itself.
    public var evidenceName: String { rawValue }
    /// The prefix of every accessibility identifier of the experience: `experience.<id>`.
    public var accessibilityPrefix: String { "experience." + rawValue }
    /// The id as text.
    public var description: String { rawValue }

    /// Ids order as their texts do.
    public static func < (lhs: ExperienceID, rhs: ExperienceID) -> Bool { lhs.rawValue < rhs.rawValue }
}
