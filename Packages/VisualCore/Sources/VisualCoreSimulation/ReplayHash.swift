// ReplayHash.swift — a SHA-256 chain over the simulation checksum at every step
// (feature 214 R02-F14 T-R02F14-002; FR-R02F14-005; clarification Q4; research R3).
// SHA-256 is FIPS 180-4 (Secure Hash Standard), computed by `StableHash.sha256` in VisualCoreMath.
import VisualCoreMath

/// A 32-byte replay hash: h₀ = SHA-256("vc.replay.v1" ‖ checksum₀ LE64) and
/// hₙ = SHA-256(hₙ₋₁ ‖ n LE64 ‖ checksumₙ LE64), with checksumₙ the state's checksum after n steps (FIPS 180-4
/// SHA-256). Identical runs give identical hashes on every platform; any changed checksum changes every later hash.
/// Encoded as a 64-digit lower-case hexadecimal string.
public struct ReplayHash: Sendable, Equatable, Hashable, Codable {
    /// The 32 hash bytes.
    public let bytes: [UInt8]

    internal init(bytes: [UInt8]) { self.bytes = bytes }

    /// The hash before any step: SHA-256 of UTF-8 "vc.replay.v1" followed by `checksum` as 8 little-endian bytes.
    public static func start(checksum: UInt64) -> ReplayHash {
        var message = Array("vc.replay.v1".utf8)
        appendLittleEndian(checksum, to: &message)
        return ReplayHash(bytes: StableHash.sha256(message))
    }

    /// The hash after step `step`: SHA-256 of these bytes, `step` and `checksum`, each as 8 little-endian bytes.
    public func next(step: Int, checksum: UInt64) -> ReplayHash {
        var message = bytes
        message.reserveCapacity(48)
        appendLittleEndian(UInt64(truncatingIfNeeded: step), to: &message)
        appendLittleEndian(checksum, to: &message)
        return ReplayHash(bytes: StableHash.sha256(message))
    }

    /// The bytes as 64 lower-case hexadecimal digits.
    public var hex: String {
        let digits = Array("0123456789abcdef".utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        for b in bytes { out.append(digits[Int(b >> 4)]); out.append(digits[Int(b & 0x0f)]) }
        return String(decoding: out, as: UTF8.self)
    }

    /// Parses 64 hexadecimal digits (either case); nil for any other length or character.
    public init?(hex: String) {
        let chars = Array(hex.utf8)
        guard chars.count == 64 else { return nil }
        var result: [UInt8] = []
        result.reserveCapacity(32)
        for i in stride(from: 0, to: 64, by: 2) {
            guard let high = Self.nibble(chars[i]), let low = Self.nibble(chars[i + 1]) else { return nil }
            result.append(high << 4 | low)
        }
        bytes = result
    }

    /// Decodes a 64-digit hexadecimal string.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let parsed = ReplayHash(hex: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "replay hash is not 64 hex digits")
        }
        self = parsed
    }

    /// Encodes the hash as its `hex` string.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 0x30...0x39: return c - 0x30
        case 0x61...0x66: return c - 0x61 + 10
        case 0x41...0x46: return c - 0x41 + 10
        default: return nil
        }
    }
}

@inline(__always) private func appendLittleEndian(_ value: UInt64, to message: inout [UInt8]) {
    for i in 0..<8 { message.append(UInt8(truncatingIfNeeded: value >> (UInt64(i) * 8))) }
}
