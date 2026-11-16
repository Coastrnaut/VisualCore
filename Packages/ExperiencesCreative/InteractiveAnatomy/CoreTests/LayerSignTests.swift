// LayerSignTests — feature 127 (A17-P04) T-A17-403 (FR-A17-404; SC-A17-403; clarification Q3). The layer signs,
// host-free and short: one per layer with the stated glyph, words and colour; they pass `stateSignProblems`.
import Foundation
import Testing
import VisualCoreSimulation
@testable import InteractiveAnatomyCore

@Suite struct LayerSignTests {
    @Test func everyLayerHasItsSignWordsAndColour() {
        #expect(AnatomyLayerSign.all.map(\.layer) == AnatomyLayer.allCases)
        #expect(AnatomyLayerSign.of(.bones) == AnatomyLayerSign(layer: .bones, sign: "●", words: "bones", colorHex: "#E6DBC2"))
        #expect(AnatomyLayerSign.of(.cartilage).sign == "◆")
        #expect(AnatomyLayerSign.of(.cartilage).words == "cartilage and menisci")
        #expect(AnatomyLayerSign.of(.cartilage).colorHex == "#8CB3D9")
        #expect(AnatomyLayerSign.of(.ligaments).sign == "▲")
        #expect(AnatomyLayerSign.of(.ligaments).words == "ligaments and tendons")
        #expect(AnatomyLayerSign.of(.ligaments).colorHex == "#CC7373")
    }

    @Test func theSignsPassTheStateSignCheck() {
        let signs = AnatomyLayerSign.all.map(\.stateSign)
        #expect(stateSignProblems(signs).isEmpty)
        #expect(signs.map(\.id) == ["bones", "cartilage", "ligaments"])
        let shared = signs + [StateSign(id: "extra", colorHex: "#000000", sign: "●")]
        #expect(!stateSignProblems(shared).isEmpty)
    }
}
