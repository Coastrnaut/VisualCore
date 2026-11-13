// ExperienceOutcome — feature 195 T-U09-003 (UA-F09; FR-U09-004; research R1). The outcome an experience's state
// has reached, as a stable code such as `level-solved`, `work-saved` or `target-reached`. A core derives it from its
// domain state when asked (`ExperienceCore.outcome`); the engine and the diagnostics pass it on, and a scenario
// manifest can only expect it. Part of the release build.
import Foundation

/// The outcome an experience has reached, named by a stable code.
///
/// The code has 1 to 64 characters, each an ASCII lowercase letter `a`–`z`, a digit `0`–`9` or a hyphen `-`. The
/// encoded form is the code as a single JSON string, for example `"target-reached"`; decoding a string that is not
/// a valid code fails with `DecodingError.dataCorrupted`.
public struct ExperienceOutcome: Sendable, Equatable, Hashable, Codable {
    /// The largest number of characters of a code.
    public static let maxCodeLength = 64

    /// The stable code of the outcome.
    public let code: String

    /// Creates an outcome; nil when `code` is empty, longer than 64 characters or contains anything but `a-z`,
    /// `0-9` and `-`.
    public init?(code: String) {
        guard Self.isValid(code) else { return nil }
        self.code = code
    }

    /// Whether `code` is a valid outcome code. Checks Unicode scalars, so no composed or non-ASCII character passes.
    public static func isValid(_ code: String) -> Bool {
        let scalars = code.unicodeScalars
        guard !scalars.isEmpty, scalars.count <= maxCodeLength else { return false }
        return scalars.allSatisfy { scalar in
            let value = scalar.value
            return (0x61...0x7A).contains(value) || (0x30...0x39).contains(value) || value == 0x2D
        }
    }

    /// Decodes an outcome from a single string value and validates it.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard Self.isValid(text) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "the outcome code is not 1 to 64 characters of a-z, 0-9 and -"))
        }
        code = text
    }

    /// Encodes the outcome as its code, a single string value.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code)
    }
}
