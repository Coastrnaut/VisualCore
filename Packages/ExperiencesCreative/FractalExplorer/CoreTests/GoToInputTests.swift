// GoToInputTests — feature 028 T-A03-308 (FR-A03-305; US4 AC1–AC2; research R4).
import Foundation
import Testing
import VisualCoreMath
@testable import FractalExplorerCore

@Suite struct GoToInputTests {
    let us = Locale(identifier: "en_US"), de = Locale(identifier: "de_DE")

    @Test func validEntryAndFraming() throws {
        let t = try GoToInput.parse(real: " -0.743643887 ", imaginary: "0.131825904", zoom: "1000", locale: us).get()
        #expect(t.center == Vec2(-0.743643887, 0.131825904))
        #expect(t.zoom == 1000)
        #expect(t.framing(for: .mandelbrot).span == 0.004)
        var s = FractalState(size: Vec2(300, 400))
        s.viewport = t.framing(for: .mandelbrot).viewport(size: Vec2(300, 400))
        #expect(s.spokenDescription.hasSuffix("zoom 1000×"))
    }

    @Test func separatorsAndMinusSign() {
        #expect(GoToInput.number("\u{2212}0.5", locale: us) == -0.5)
        #expect(GoToInput.number("-0,25", locale: de) == -0.25)
        #expect(GoToInput.number("0.25", locale: de) == 0.25)
        #expect(GoToInput.number("1e3", locale: us) == 1000)
    }

    @Test func rejectsBadInput() {
        #expect(GoToInput.parse(real: "abc", imaginary: "0", zoom: "1", locale: us) == .failure(GoToError(field: .real, message: "Enter a number")))
        #expect(GoToInput.parse(real: "", imaginary: "0", zoom: "1", locale: us) == .failure(GoToError(field: .real, message: "Enter a number")))
        #expect(GoToInput.parse(real: "0", imaginary: "nan", zoom: "1", locale: us) == .failure(GoToError(field: .imaginary, message: "Enter a number")))
        #expect(GoToInput.parse(real: "0", imaginary: "inf", zoom: "1", locale: us) == .failure(GoToError(field: .imaginary, message: "Enter a number")))
        #expect(GoToInput.parse(real: "4.5", imaginary: "0", zoom: "1", locale: us) == .failure(GoToError(field: .real, message: "Use a value between −4 and 4")))
        #expect(GoToInput.parse(real: "0", imaginary: "-5", zoom: "1", locale: us) == .failure(GoToError(field: .imaginary, message: "Use a value between −4 and 4")))
        #expect(GoToInput.parse(real: "0", imaginary: "0", zoom: "0", locale: us) == .failure(GoToError(field: .zoom, message: "Zoom must be above 0 and at most 1e15")))
        #expect(GoToInput.parse(real: "0", imaginary: "0", zoom: "2e15", locale: us) == .failure(GoToError(field: .zoom, message: "Zoom must be above 0 and at most 1e15")))
        #expect(GoToInput.parse(real: "0", imaginary: "0", zoom: "x", locale: us) == .failure(GoToError(field: .zoom, message: "Enter a number")))
    }

    @Test func boundariesAccepted() throws {
        #expect(try GoToInput.parse(real: "4", imaginary: "-4", zoom: "1e15", locale: us).get().zoom == 1e15)
    }
}
