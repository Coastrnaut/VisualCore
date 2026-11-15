// ContrastTests — feature 079 (A10-P05) T-A10-502 (FR-A10-502; clarification 2; research D2; SC-A10-503). Colour
// contrast, host-free and short: the relative luminance and ratio of known colour pairs (black and white 21 : 1,
// equal colours 1 : 1, mid grey against black, order-free); straight-alpha compositing (opaque top, transparent top,
// half over black and white); and every bundled catalog item against the field (the presenter's field colour): each
// hazard's core ≥ 4.5 and the player's and the orb's cores ≥ 3, and each hazard's core against its own glow
// composited over the field at every level's opacity cap ≥ 3 (the glow taken at the full cap, its own alpha replaced,
// the worst case of what the presenter draws).
import Foundation
import Testing
import VisualCoreMath
import NeonArcadeCore

@Suite struct ContrastTests {
    private let black = Vec4(0, 0, 0, 1), white = Vec4(1, 1, 1, 1)

    @Test func knownPairsHaveKnownRatios() {
        #expect(Contrast.luminance(black) == 0)
        #expect(abs(Contrast.luminance(white) - 1) < 1e-12)
        #expect(abs(Contrast.ratio(black, white) - 21) < 1e-9)
        #expect(abs(Contrast.ratio(white, black) - 21) < 1e-9)
        #expect(Contrast.ratio(Vec4(0.3, 0.6, 0.9, 1), Vec4(0.3, 0.6, 0.9, 0.2)) == 1)
        // sRGB 0.5 grey: linear ((0.555 / 1.055)^2.4) ≈ 0.2140, ratio to black ≈ 5.28.
        let grey = Vec4(0.5, 0.5, 0.5, 1)
        #expect(abs(Contrast.luminance(grey) - 0.21404) < 1e-4)
        #expect(abs(Contrast.ratio(grey, black) - 5.2808) < 1e-3)
        // Pure primaries weigh by the WCAG coefficients.
        #expect(abs(Contrast.luminance(Vec4(1, 0, 0, 1)) - 0.2126) < 1e-12)
        #expect(abs(Contrast.luminance(Vec4(0, 1, 0, 1)) - 0.7152) < 1e-12)
        #expect(abs(Contrast.luminance(Vec4(0, 0, 1, 1)) - 0.0722) < 1e-12)
    }

    @Test func compositingFollowsStraightAlphaOver() {
        let field = Contrast.field
        #expect(Contrast.composite(Vec4(1, 0, 0, 1), over: field) == Vec4(1, 0, 0, 1))
        #expect(Contrast.composite(Vec4(1, 0, 0, 0), over: field) == field)
        let half = Contrast.composite(Vec4(1, 1, 1, 0.5), over: black)
        #expect(half == Vec4(0.5, 0.5, 0.5, 1))
        let quarter = Contrast.composite(Vec4(0, 0, 0, 0.25), over: white)
        #expect(quarter == Vec4(0.75, 0.75, 0.75, 1))
        #expect(Contrast.composite(Vec4(1, 1, 1, 0), over: Vec4(0, 0, 0, 0)) == .zero)
    }

    @Test func theFieldIsThePresentersField() {
        #expect(Contrast.field == Vec4(0.027, 0.024, 0.102, 1))
    }

    @Test func everyCoreIsReadableAgainstTheField() {
        let catalog = ArcadeCatalog.bundled
        #expect(!catalog.hazards.isEmpty && !catalog.orbs.isEmpty && catalog.player != nil)
        for item in catalog.items {
            let ratio = Contrast.ratio(Contrast.vector(item.color), Contrast.field)
            let least = item.role == .hazard ? Contrast.hazardVsField : Contrast.playerAndOrbVsField
            #expect(ratio >= least, "\(item.id) core against the field: \(ratio)")
        }
    }

    @Test func everyHazardIsReadableAgainstItsGlowAtEveryLevel() {
        for budget in ArcadeBudget.all {
            for item in ArcadeCatalog.bundled.hazards {
                let background = Contrast.glowOverField(item, opacity: budget.glowOpacityCap)
                let ratio = Contrast.ratio(Contrast.vector(item.color), background)
                #expect(ratio >= Contrast.hazardVsGlow, "\(item.id) at level \(budget.level): \(ratio)")
            }
        }
    }
}
