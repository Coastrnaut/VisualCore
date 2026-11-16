// ParserRegressionTests — feature 110 (A15-P01) T-A15-103 (FR-A15-121; manual §9 Phase 01 regression fixture;
// SC-A15-102). The manual's three regression fixtures, each refused with its own reason and producing nothing: a
// negative atom count (`-3`, `bad-count` on line 1), a NaN coordinate (`nan`, `non-finite` on its line) and an
// oversized file (65,537 bytes, `too-large` before any decoding).
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct ParserRegressionTests {
    @Test func aNegativeAtomCountIsRefused() {
        let text = "-3\nnegative count\nO 0 0 0\nH 0.2774 0.8929 0.2544\nH 0.6068 -0.2383 -0.7169\n"
        #expect(XYZParser.parse(text) == .failure(XYZRefusal(.badCount, line: 1)))
    }

    @Test func aNaNCoordinateIsRefused() {
        let text = "3\nNaN coordinate\nO 0 0 0\nH 0.2774 nan 0.2544\nH 0.6068 -0.2383 -0.7169\n"
        #expect(XYZParser.parse(text) == .failure(XYZRefusal(.nonFinite, line: 4)))
    }

    @Test func anOversizedFileIsRefused() {
        let base = "3\noversized\nO 0 0 0\nH 0.2774 0.8929 0.2544\nH 0.6068 -0.2383 -0.7169\n"
        let padding = String(repeating: " ", count: 65_537 - base.utf8.count)
        let data = Data((base + padding).utf8)
        #expect(data.count == 65_537)
        #expect(XYZParser.parse(data) == .failure(XYZRefusal(.tooLarge)))
    }
}
