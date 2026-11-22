// FacetedForgeFractionTests — feature 371 (R02-G08-01) T-R02G0801-002 (FR-R02G0801-002, 005; clarification Q3; research
// R1). The exact fraction: reduction and sign, the four checked operations against integer arithmetic, ordering, the
// text form and its round trip, and overflow refused. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import FacetedForgeCore

struct FacetedForgeFractionTests {
    /// Fractions are reduced with a positive denominator; zero is 0/1.
    @Test func fractionsAreReducedWithAPositiveDenominator() throws {
        let a: FacetedForgeFraction = try FacetedForgeFraction(6, -8)
        #expect(a.numerator == -3 && a.denominator == 4)
        let z: FacetedForgeFraction = try FacetedForgeFraction(0, -5)
        #expect(z == .zero)
        #expect(throws: FacetedForgeError.action("overflow")) { try FacetedForgeFraction(1, 0) }
    }

    /// The four operations agree with integer arithmetic on a grid of small fractions.
    @Test func operationsAgreeWithIntegerArithmetic() throws {
        for n1 in Int64(-6)...6 {
            for d1 in Int64(1)...4 {
                for n2 in Int64(-6)...6 {
                    for d2 in Int64(1)...4 {
                        let a: FacetedForgeFraction = try FacetedForgeFraction(n1, d1)
                        let b: FacetedForgeFraction = try FacetedForgeFraction(n2, d2)
                        #expect(try a.adding(b) == FacetedForgeFraction(n1 * d2 + n2 * d1, d1 * d2))
                        #expect(try a.subtracting(b) == FacetedForgeFraction(n1 * d2 - n2 * d1, d1 * d2))
                        #expect(try a.multiplying(b) == FacetedForgeFraction(n1 * n2, d1 * d2))
                        if n2 != 0 { #expect(try a.dividing(by: b) == FacetedForgeFraction(n1 * d2, d1 * n2)) }
                        #expect((a < b) == (n1 * d2 < n2 * d1))
                    }
                }
            }
        }
    }

    /// The text form round-trips and refuses non-canonical text.
    @Test func textRoundTripsAndRefusesNonCanonicalText() throws {
        let values: [FacetedForgeFraction] = [try FacetedForgeFraction(3, 16), .one, .zero,
                                              try FacetedForgeFraction(-5, 2)]
        for value in values {
            #expect(FacetedForgeFraction(text: value.text) == value)
            let data: Data = try JSONEncoder().encode([value])
            #expect(try JSONDecoder().decode([FacetedForgeFraction].self, from: data) == [value])
        }
        #expect(FacetedForgeFraction(text: "2/4") == nil)
        #expect(FacetedForgeFraction(text: "1/0") == nil)
        #expect(FacetedForgeFraction(text: "1/-2") == nil)
        #expect(FacetedForgeFraction(text: "x") == nil)
    }

    /// Overflow is refused, never wrapped.
    @Test func overflowIsRefused() throws {
        let big: FacetedForgeFraction = try FacetedForgeFraction(Int64.max / 2 + 1)
        #expect(throws: FacetedForgeError.action("overflow")) { try big.adding(big) }
        #expect(throws: FacetedForgeError.action("overflow")) { try big.multiplying(big) }
        #expect(throws: FacetedForgeError.action("overflow")) { try big.dividing(by: .zero) }
    }
}
