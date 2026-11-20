// AssistiveStep — feature 222 (R02-F22) T-R02F22-006 (FR-R02F22-005, 007; SC-R02F22-005; clarification Q5; research R6).
// A discrete, gesture-free control for one numeric property: the value is start + k · step for an integer k, so n steps
// up then n steps down return exactly to the start, and a step past a limit does nothing. Each step reports the
// (before, after) pair that a `ControlHistory` records; `description` is the locale-independent spoken value.

import Foundation

/// A discrete increment and decrement control for one numeric property, the assistive alternative to a drag.
///
/// The value is `start + Double(index) * step` with an integer `index`, never an accumulated sum, so stepping up n
/// times and down n times (staying inside the range) returns bit for bit to `start`.
public struct AssistiveStep: Sendable, Equatable, Codable {
    /// The spoken name of the property, never empty.
    public let name: String
    /// The value at index 0, finite and inside ``range``.
    public let start: Double
    /// The size of one step, finite and greater than zero.
    public let step: Double
    /// The limits of the value, both finite, at most 1e9 steps wide.
    public let range: ClosedRange<Double>
    /// The number of steps taken from ``start`` (negative below it).
    public private(set) var index: Int

    /// The current value, `start + Double(index) * step` (exactly `start` at index 0).
    public var value: Double {
        Self.value(start: start, step: step, index: index)
    }

    /// The spoken description, "<name>, <value>", with the value printed locale-independently with as many decimals as
    /// the step needs (at most 6) and never as negative zero.
    public var description: String {
        "\(name), \(Self.format(value, decimals: Self.decimals(for: step)))"
    }

    /// Creates a control at `start`.
    ///
    /// - Throws: ``SpatialControlError/parameter(_:)`` with `"name"` for an empty name, `"step"` unless the step is
    ///   finite and positive, `"range"` unless both bounds are finite and the range is at most 1e9 steps wide, and
    ///   `"start"` unless the start is finite and inside the range.
    public init(name: String, start: Double, step: Double, range: ClosedRange<Double>) throws(SpatialControlError) {
        guard !name.isEmpty else { throw .parameter("name") }
        guard step.isFinite, step > 0 else { throw .parameter("step") }
        guard range.lowerBound.isFinite, range.upperBound.isFinite,
              range.upperBound - range.lowerBound <= 1e9 * step else { throw .parameter("range") }
        guard start.isFinite, range.contains(start) else { throw .parameter("start") }
        self.name = name
        self.start = start
        self.step = step
        self.range = range
        self.index = 0
    }

    /// Takes one step up.
    ///
    /// - Returns: The values before and after the step, or `nil` (with nothing changed) when the step would leave the
    ///   range.
    public mutating func increment() -> (before: Double, after: Double)? {
        move(by: 1)
    }

    /// Takes one step down.
    ///
    /// - Returns: The values before and after the step, or `nil` (with nothing changed) when the step would leave the
    ///   range.
    public mutating func decrement() -> (before: Double, after: Double)? {
        move(by: -1)
    }

    /// Returns to ``start`` (index 0).
    public mutating func reset() {
        index = 0
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case name, start, step, lower, upper, index
    }

    /// Decodes a control and re-validates it; a form that breaks a rule throws `DecodingError.dataCorrupted` whose
    /// description carries the reason code.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .name)
        let start: Double = try container.decode(Double.self, forKey: .start)
        let step: Double = try container.decode(Double.self, forKey: .step)
        let lower: Double = try container.decode(Double.self, forKey: .lower)
        let upper: Double = try container.decode(Double.self, forKey: .upper)
        let index: Int = try container.decode(Int.self, forKey: .index)
        guard lower <= upper else {
            throw Self.corrupted(.parameter("range"), path: decoder.codingPath)
        }
        do {
            self = try AssistiveStep(name: name, start: start, step: step, range: lower...upper)
        } catch {
            throw Self.corrupted(error, path: decoder.codingPath)
        }
        let candidate: Double = Self.value(start: start, step: step, index: index)
        guard candidate.isFinite, range.contains(candidate) else {
            throw Self.corrupted(.parameter("index"), path: decoder.codingPath)
        }
        self.index = index
    }

    /// Encodes the name, start, step, range bounds and index.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(start, forKey: .start)
        try container.encode(step, forKey: .step)
        try container.encode(range.lowerBound, forKey: .lower)
        try container.encode(range.upperBound, forKey: .upper)
        try container.encode(index, forKey: .index)
    }

    // MARK: - Private

    private mutating func move(by delta: Int) -> (before: Double, after: Double)? {
        let (next, overflow) = index.addingReportingOverflow(delta)
        guard !overflow else { return nil }
        let candidate: Double = Self.value(start: start, step: step, index: next)
        guard range.contains(candidate) else { return nil }
        let before: Double = value
        index = next
        return (before: before, after: candidate)
    }

    private static func value(start: Double, step: Double, index: Int) -> Double {
        index == 0 ? start : start + Double(index) * step
    }

    private static func corrupted(_ error: SpatialControlError, path: [any CodingKey]) -> DecodingError {
        var detail: String = ""
        if case .parameter(let parameter) = error { detail = " (\(parameter))" }
        return DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: path, debugDescription: "\(error.reasonCode)\(detail)"))
    }

    /// The smallest d in 0 … 6 for which step · 10^d is an integer (within 1e-9 relative), else 6.
    static func decimals(for step: Double) -> Int {
        var scale: Double = 1
        for d in 0...6 {
            let scaled: Double = step * scale
            if abs(scaled - scaled.rounded()) < 1e-9 * max(1, scaled) { return d }
            scale *= 10
        }
        return 6
    }

    /// Prints `value` with `decimals` decimals, independent of the current locale, never as negative zero.
    static func format(_ value: Double, decimals: Int) -> String {
        var power: UInt64 = 1
        for _ in 0..<decimals { power *= 10 }
        let scaled: Double = (value * Double(power)).rounded()
        if abs(scaled) < 1e18 {
            let magnitude: UInt64 = UInt64(abs(scaled))
            let whole: UInt64 = magnitude / power
            var text: String = magnitude != 0 && scaled < 0 ? "-" : ""
            text += String(whole)
            if decimals > 0 {
                let fraction: String = String(magnitude % power)
                text += "." + String(repeating: "0", count: decimals - fraction.count) + fraction
            }
            return text
        }
        // Beyond 1e18 no fraction digit is meaningful; the POSIX form (nil locale) is used.
        return String(format: "%.\(decimals)f", locale: nil, value)
    }
}
