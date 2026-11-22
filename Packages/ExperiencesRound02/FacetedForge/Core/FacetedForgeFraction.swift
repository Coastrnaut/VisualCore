// FacetedForgeFraction — feature 371 (R02-G08-01) T-R02G0801-002 (FR-R02G0801-002, 005, 014; clarification Q3; research
// R1). An exact fraction of two 64-bit integers, always reduced with a positive denominator. Every operation is
// checked: an overflow throws `.action("overflow")`, so the kernel refuses the action rather than decide it wrongly.
// The kernel's bounds (directions in {−1, 0, 1}, depths −24 … 24, a crystal inside −6 … 6) keep every value far below
// the limit. Stored as the text "n/d" (or "n" when the denominator is 1).

/// An exact, reduced fraction of 64-bit integers.
public struct FacetedForgeFraction: Sendable, Hashable, Comparable {
    /// The numerator; carries the sign.
    public let numerator: Int64
    /// The denominator, always positive.
    public let denominator: Int64

    /// Zero.
    public static let zero = FacetedForgeFraction(unchecked: 0, 1)
    /// One.
    public static let one = FacetedForgeFraction(unchecked: 1, 1)

    /// The reduced fraction `n / d`.
    ///
    /// - Throws: `.action("overflow")` when `d` is zero or the reduction overflows.
    public init(_ n: Int64, _ d: Int64 = 1) throws(FacetedForgeError) {
        guard d != 0, n != Int64.min, d != Int64.min else { throw .action("overflow") }
        let g: Int64 = Self.gcd(abs(n), abs(d))
        let sign: Int64 = d < 0 ? -1 : 1
        self.numerator = sign * n / max(g, 1)
        self.denominator = sign * d / max(g, 1)
    }

    /// A fraction already reduced with a positive denominator (internal constants only).
    init(unchecked n: Int64, _ d: Int64) {
        numerator = n
        denominator = d
    }

    /// The greatest common divisor of two non-negative integers.
    static func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        var x: Int64 = a
        var y: Int64 = b
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    /// `a × b`, or `.action("overflow")`.
    static func mul(_ a: Int64, _ b: Int64) throws(FacetedForgeError) -> Int64 {
        let (r, o) = a.multipliedReportingOverflow(by: b)
        guard !o else { throw .action("overflow") }
        return r
    }

    /// `a + b`, or `.action("overflow")`.
    static func add(_ a: Int64, _ b: Int64) throws(FacetedForgeError) -> Int64 {
        let (r, o) = a.addingReportingOverflow(b)
        guard !o else { throw .action("overflow") }
        return r
    }

    /// `self + other`.
    public func adding(_ other: Self) throws(FacetedForgeError) -> Self {
        let left: Int64 = try Self.mul(numerator, other.denominator)
        let n: Int64 = try Self.add(left, try Self.mul(other.numerator, denominator))
        return try Self(n, try Self.mul(denominator, other.denominator))
    }

    /// `self − other`.
    public func subtracting(_ other: Self) throws(FacetedForgeError) -> Self {
        try adding(Self(unchecked: -other.numerator, other.denominator))
    }

    /// `self × other`.
    public func multiplying(_ other: Self) throws(FacetedForgeError) -> Self {
        try Self(try Self.mul(numerator, other.numerator), try Self.mul(denominator, other.denominator))
    }

    /// `self ÷ other`.
    ///
    /// - Throws: `.action("overflow")` for a zero divisor or an overflow.
    public func dividing(by other: Self) throws(FacetedForgeError) -> Self {
        guard other.numerator != 0 else { throw .action("overflow") }
        return try Self(try Self.mul(numerator, other.denominator), try Self.mul(denominator, other.numerator))
    }

    /// The sign: −1, 0 or 1.
    public var sign: Int { numerator < 0 ? -1 : (numerator > 0 ? 1 : 0) }

    /// The text "n/d", or "n" when the denominator is 1.
    public var text: String { denominator == 1 ? "\(numerator)" : "\(numerator)/\(denominator)" }

    /// Parses "n/d" or "n"; nil for anything else.
    public init?(text: String) {
        let parts: [Substring] = text.split(separator: "/", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), let n = Int64(parts[0]) else { return nil }
        let d: Int64 = parts.count == 2 ? (Int64(parts[1]) ?? 0) : 1
        guard d > 0, let value = try? Self(n, d), value.numerator == n, value.denominator == d else { return nil }
        self = value
    }

    /// Compared exactly (cross-multiplied in 128-bit-safe steps: both products are checked).
    public static func < (lhs: Self, rhs: Self) -> Bool {
        let (l, lo) = lhs.numerator.multipliedFullWidth(by: rhs.denominator)
        let (r, ro) = rhs.numerator.multipliedFullWidth(by: lhs.denominator)
        return l < r || (l == r && lo < ro)
    }
}

extension FacetedForgeFraction: Codable {
    /// Decodes the text form "n/d".
    public init(from decoder: any Decoder) throws {
        let text: String = try decoder.singleValueContainer().decode(String.self)
        guard let value = Self(text: text) else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "fraction \(text)")
            throw DecodingError.dataCorrupted(context)
        }
        self = value
    }

    /// Encodes the text form "n/d".
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(text)
    }
}
