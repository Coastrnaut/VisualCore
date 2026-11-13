// NumericHygieneTests — feature 203 R02-F03 T-R02F03-015: finite fallback, angle normalization, wrapping and
// quantization of NumericHygiene (story 5, FR-R02F03-050..054), including every NumericError case.
import Testing
import VisualCoreMath

@Suite struct NumericHygieneTests {
    @Test func finiteFallback() {
        #expect(NumericHygiene.finite(.nan, or: 1) == 1)
        #expect(NumericHygiene.finite(.infinity, or: 2) == 2)
        #expect(NumericHygiene.finite(-.infinity, or: 3) == 3)
        #expect(NumericHygiene.finite(4.5, or: 0) == 4.5)
    }

    @Test func normalizedAngle() {
        #expect(NumericHygiene.normalizedAngle(0) == 0)
        #expect(NumericHygiene.normalizedAngle(.pi) == -.pi)
        #expect(NumericHygiene.normalizedAngle(-.pi) == -.pi)
        #expect(NumericHygiene.normalizedAngle(3 * .pi) == -.pi)
        #expect(abs(NumericHygiene.normalizedAngle(-7 * .pi / 2) - .pi / 2) <= 1e-12)
        let large = 1e9
        let result = NumericHygiene.normalizedAngle(large)
        #expect(result >= -.pi && result < .pi)
        let turns = (large - result) / (2 * .pi)
        #expect(abs(turns - turns.rounded()) <= 1e-6)
    }

    @Test func normalizedAngleKeepsNonFiniteInput() {
        #expect(NumericHygiene.normalizedAngle(.nan).isNaN)
        #expect(NumericHygiene.normalizedAngle(.infinity) == .infinity)
    }

    @Test func wrapped() throws {
        #expect(try NumericHygiene.wrapped(-0.5, modulus: 2) == 1.5)
        #expect(try NumericHygiene.wrapped(2, modulus: 2) == 0)
        #expect(try NumericHygiene.wrapped(5.25, modulus: 2) == 1.25)
        let zero = try NumericHygiene.wrapped(-0.0, modulus: 2)
        #expect(zero == 0 && zero.sign == .plus)
        let tiny = try NumericHygiene.wrapped(-1e-20, modulus: 2)
        #expect(tiny >= 0 && tiny < 2)
    }

    @Test func wrappedErrors() {
        #expect(throws: NumericError.nonPositiveModulus) { try NumericHygiene.wrapped(1, modulus: 0) }
        #expect(throws: NumericError.nonPositiveModulus) { try NumericHygiene.wrapped(1, modulus: -1) }
        #expect(throws: NumericError.nonPositiveModulus) { try NumericHygiene.wrapped(1, modulus: .infinity) }
        #expect(throws: NumericError.nonPositiveModulus) { try NumericHygiene.wrapped(1, modulus: .nan) }
        #expect(throws: NumericError.nonFinite) { try NumericHygiene.wrapped(.nan, modulus: 2) }
        #expect(throws: NumericError.nonFinite) { try NumericHygiene.wrapped(.infinity, modulus: 2) }
    }

    @Test func quantized() throws {
        #expect(try NumericHygiene.quantized(0.26, step: 0.1) == 3)
        #expect(try NumericHygiene.quantized(-0.0, step: 0.1) == 0)
        #expect(try NumericHygiene.quantized(-0.26, step: 0.1) == -3)
        #expect(try NumericHygiene.quantized(0.25, step: 0.5) == 0)  // ties to even
    }

    @Test func quantizedErrors() {
        #expect(throws: NumericError.nonFinite) { try NumericHygiene.quantized(.nan, step: 0.1) }
        #expect(throws: NumericError.nonFinite) { try NumericHygiene.quantized(-.infinity, step: 0.1) }
        #expect(throws: NumericError.nonPositiveStep) { try NumericHygiene.quantized(1, step: 0) }
        #expect(throws: NumericError.nonPositiveStep) { try NumericHygiene.quantized(1, step: -0.1) }
        #expect(throws: NumericError.nonPositiveStep) { try NumericHygiene.quantized(1, step: .nan) }
        #expect(throws: NumericError.outOfRange) { try NumericHygiene.quantized(1e300, step: 0.1) }
        #expect(throws: NumericError.outOfRange) { try NumericHygiene.quantized(-1e300, step: 0.1) }
    }
}
