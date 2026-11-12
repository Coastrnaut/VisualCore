// StateDigest — feature 188 T-U02-007 (FR-U02-013, FR-U02-015; data-model section 3; contract "Digest").
// The digest of the domain state of an experience and the builder that reduces typed fields to it. Every field
// carries its type and every variable-length field its length, so two different field sequences never give the
// same bytes. Integers are big-endian; the hash is the SHA-256 of VisualCoreMath.
import Foundation
import VisualCoreMath

/// The digest of a domain state: the SHA-256 of its encoded fields as 64 lower-case hexadecimal digits.
public struct StateDigest: Hashable, Sendable, Codable, CustomStringConvertible {
    /// The number of hexadecimal digits of a digest.
    private static let hexLength = 64

    /// The digest as 64 lower-case hexadecimal digits.
    public let hex: String

    /// Takes a digest from its text; `nil` unless the text is exactly 64 digits of `0`–`9` and `a`–`f`.
    public init?(hex: String) {
        let bytes = hex.utf8
        guard bytes.count == Self.hexLength,
              bytes.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        self.hex = hex
    }

    /// Writes hash bytes as lower-case hexadecimal digits; the builder passes the 32 bytes of a SHA-256.
    init(bytes: [UInt8]) {
        let digits = Array("0123456789abcdef".utf8)
        var text: [UInt8] = []
        text.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            text.append(digits[Int(byte >> 4)])
            text.append(digits[Int(byte & 0x0f)])
        }
        hex = String(decoding: text, as: UTF8.self)
    }

    /// Decodes a digest from its text; a text that is not 64 lower-case hexadecimal digits is a decoding error.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let digest = StateDigest(hex: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "malformed state digest \(text)")
        }
        self = digest
    }

    /// Encodes the digest as one string: its hexadecimal text.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    /// The digest as text: its 64 hexadecimal digits.
    public var description: String { hex }
}

/// Reduces a sequence of typed fields to a `StateDigest`. The same fields in the same order give the same digest
/// in every process and on every platform; another type, order, length or domain gives another digest.
public struct DigestBuilder: Sendable {
    /// The tag byte that announces the type of a field.
    private enum Tag: UInt8 {
        case int = 0x01
        case uint64 = 0x02
        case bool = 0x03
        case string = 0x04
        case bytes = 0x05
        case double = 0x06
        case count = 0x07
    }

    /// The encoded fields so far.
    private var buffer: [UInt8] = []

    /// The number of fields added so far, the domain included; also the zero-based index of the next field.
    public private(set) var fieldCount: Int = 0

    /// Starts a digest. The domain text is written as the first field, so equal states of two domains differ.
    public init(domain: String) {
        add(domain)
    }

    /// Adds a signed integer: tag `0x01`, then the value as a signed 64-bit integer.
    public mutating func add(_ value: Int) {
        begin(.int)
        append(UInt64(bitPattern: Int64(value)))
    }

    /// Adds an unsigned 64-bit integer: tag `0x02`, then 8 bytes.
    public mutating func add(_ value: UInt64) {
        begin(.uint64)
        append(value)
    }

    /// Adds a truth value: tag `0x03`, then `0x00` for false or `0x01` for true.
    public mutating func add(_ value: Bool) {
        begin(.bool)
        buffer.append(value ? 0x01 : 0x00)
    }

    /// Adds a text: tag `0x04`, then the number of UTF-8 bytes as 8 bytes, then the UTF-8 bytes.
    public mutating func add(_ value: String) {
        begin(.string)
        let utf8 = Array(value.utf8)
        append(UInt64(utf8.count))
        buffer.append(contentsOf: utf8)
    }

    /// Adds raw bytes: tag `0x05`, then the count as 8 bytes, then the bytes.
    public mutating func add(_ bytes: [UInt8]) {
        begin(.bytes)
        append(UInt64(bytes.count))
        buffer.append(contentsOf: bytes)
    }

    /// Adds a floating-point value: tag `0x06`, then the IEEE 754 bit pattern; negative zero is written as zero.
    /// Throws `DigestError.nonFinite(field:)` with the zero-based index the field would have had when the value
    /// is NaN or infinite; nothing is added then.
    public mutating func add(_ value: Double) throws(DigestError) {
        guard value.isFinite else { throw .nonFinite(field: fieldCount) }
        begin(.double)
        append(value == 0 ? 0 : value.bitPattern)
    }

    /// Announces a sequence of `count` following fields: tag `0x07`, then the count as 8 bytes. It keeps
    /// neighbouring sequences apart: `[1, 2], [3]` and `[1], [2, 3]` give different digests.
    public mutating func add(count: Int) {
        begin(.count)
        append(UInt64(bitPattern: Int64(count)))
    }

    /// The digest of the fields added so far: the SHA-256 of their bytes. The builder can go on afterwards.
    public func finish() -> StateDigest {
        StateDigest(bytes: StableHash.sha256(buffer))
    }

    /// Opens a field: writes its tag and counts it.
    private mutating func begin(_ tag: Tag) {
        buffer.append(tag.rawValue)
        fieldCount += 1
    }

    /// Appends 64 bits, the most significant byte first.
    private mutating func append(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            buffer.append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }
}
