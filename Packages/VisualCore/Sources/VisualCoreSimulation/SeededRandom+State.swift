// SeededRandom+State.swift — feature 203 R02-F03 T-R02F03-009 (FR-R02F03-030..033; data-model "SeededRandom.State
// (version 1)"). Saves and restores the full generator: the seed (part of equality) and the four xoshiro256** words,
// each as exactly 16 lower-case hexadecimal digits, so a restored generator is `==` the saved one and continues it.

/// Why a saved `SeededRandom.State` was refused.
public enum RandomStateError: Error, Equatable, Sendable {
    /// The state's `version` is not 1.
    case unsupportedVersion(Int)
    /// The state does not carry exactly four words.
    case wrongWordCount
    /// The given seed or word text is not exactly 16 lower-case hexadecimal digits.
    case malformedWord(String)
    /// All four state words are zero, which xoshiro256** can never leave.
    case allZero
}

extension SeededRandom {
    /// A versioned, JSON-encodable snapshot of a generator: `{"version":1,"seed":"…","words":["…","…","…","…"]}`.
    public struct State: Codable, Sendable, Equatable {
        /// Format version; only 1 is understood.
        public let version: Int
        /// The generator's `seed` as 16 lower-case hexadecimal digits.
        public let seed: String
        /// The four xoshiro256** state words (s0…s3), each 16 lower-case hexadecimal digits.
        public let words: [String]

        /// Builds a state from its parts; validity is checked only by `SeededRandom(restoring:)`.
        public init(version: Int, seed: String, words: [String]) {
            self.version = version
            self.seed = seed
            self.words = words
        }
    }

    /// The current full state (version 1); restoring it gives an equal generator continuing the same sequence.
    public var state: State {
        State(version: 1, seed: Self.hex(seed), words: [s0, s1, s2, s3].map(Self.hex))
    }

    /// Restores a generator from `state`, refusing a version other than 1, a word count other than 4, any seed or
    /// word that is not exactly 16 lower-case hexadecimal digits, and all-zero words.
    public init(restoring state: State) throws(RandomStateError) {
        guard state.version == 1 else { throw .unsupportedVersion(state.version) }
        guard state.words.count == 4 else { throw .wrongWordCount }
        let seed = try Self.parse(state.seed)
        var w: [UInt64] = []
        for text in state.words { w.append(try Self.parse(text)) }
        guard w.contains(where: { $0 != 0 }) else { throw .allZero }
        self.init(seed: seed, s0: w[0], s1: w[1], s2: w[2], s3: w[3])
    }

    /// `value` as exactly 16 lower-case hexadecimal digits (zero padded).
    private static func hex(_ value: UInt64) -> String {
        let digits = String(value, radix: 16, uppercase: false)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }

    /// Parses exactly 16 lower-case hexadecimal digits; anything else is `.malformedWord(text)`.
    private static func parse(_ text: String) throws(RandomStateError) -> UInt64 {
        var value: UInt64 = 0
        var count = 0
        for byte in text.utf8 {
            let digit: UInt64
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = UInt64(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = UInt64(byte - UInt8(ascii: "a") + 10)
            default: throw .malformedWord(text)
            }
            count += 1
            guard count <= 16 else { throw .malformedWord(text) }
            value = value << 4 | digit
        }
        guard count == 16 else { throw .malformedWord(text) }
        return value
    }
}
