// NumericHygiene.swift — feature 203 R02-F03 T-R02F03-016 (story 5, FR-R02F03-050..054): pure, Foundation-free
// helpers that keep values finite, normalize angles, wrap values into a range and quantize them onto an integer grid.

/// Why a numeric hygiene helper refused its input.
public enum NumericError: Error, Equatable, Sendable {
    /// The value to process was NaN or infinite.
    case nonFinite
    /// The modulus was zero, negative, infinite or NaN.
    case nonPositiveModulus
    /// The grid step was zero, negative, infinite or NaN.
    case nonPositiveStep
    /// The quantized count does not fit into `Int64`.
    case outOfRange
}

/// Pure helpers for IEEE 754 hygiene: the same input always gives the same output.
public enum NumericHygiene {
    /// Returns `x` when it is finite, otherwise `fallback`.
    ///
    /// - Parameters:
    ///   - x: The value to check.
    ///   - fallback: The value returned for NaN and ±∞.
    public static func finite(_ x: Double, or fallback: Double) -> Double {
        x.isFinite ? x : fallback
    }

    /// Maps a finite angle into [−π, π), differing from `radians` by a whole number of turns.
    ///
    /// π maps to −π. A non-finite input (NaN, ±∞) has no defined angle and is returned unchanged; combine with
    /// ``finite(_:or:)`` when a finite result is required.
    ///
    /// - Parameter radians: The angle in radians.
    public static func normalizedAngle(_ radians: Double) -> Double {
        guard radians.isFinite else { return radians }
        let turn = 2 * Double.pi
        var result = radians - turn * ((radians + .pi) / turn).rounded(.down)
        if result >= .pi { result -= turn }
        if result < -.pi { result += turn }
        return result + 0.0
    }

    /// Wraps `x` into [0, `modulus`).
    ///
    /// The result is `x − modulus · ⌊x / modulus⌋`; a rounding result equal to `modulus` becomes 0 and −0 becomes 0.
    ///
    /// - Parameters:
    ///   - x: The value to wrap; it must be finite.
    ///   - modulus: The length of the range; it must be finite and greater than 0.
    /// - Throws: ``NumericError/nonPositiveModulus`` for a modulus that is not finite and positive (checked first),
    ///   ``NumericError/nonFinite`` for a non-finite `x`.
    public static func wrapped(_ x: Double, modulus: Double) throws(NumericError) -> Double {
        guard modulus.isFinite, modulus > 0 else { throw .nonPositiveModulus }
        guard x.isFinite else { throw .nonFinite }
        let result = x - modulus * (x / modulus).rounded(.down)
        if result >= modulus || result < 0 { return 0 }
        return result + 0.0
    }

    /// The number of grid steps nearest to `x`: `(x / step)` rounded to nearest, ties to even.
    ///
    /// −0 is written as 0.
    ///
    /// - Parameters:
    ///   - x: The value to quantize; it must be finite.
    ///   - step: The grid step; it must be finite and greater than 0.
    /// - Throws: ``NumericError/nonPositiveStep`` for a step that is not finite and positive (checked first),
    ///   ``NumericError/nonFinite`` for a non-finite `x`, ``NumericError/outOfRange`` when |x / step| ≥ 2^63.
    public static func quantized(_ x: Double, step: Double) throws(NumericError) -> Int64 {
        guard step.isFinite, step > 0 else { throw .nonPositiveStep }
        guard x.isFinite else { throw .nonFinite }
        let count = (x / step).rounded(.toNearestOrEven)
        guard count.isFinite, count.magnitude < 9.223372036854775807e18 else { throw .outOfRange }
        return Int64(count)
    }
}
