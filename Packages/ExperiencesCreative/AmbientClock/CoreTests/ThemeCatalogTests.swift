// ThemeCatalogTests — feature 133 (A18-P03) T-A18-303 (FR-A18-301, FR-A18-304; SC-A18-301; clarification Q2). The
// catalog holds four themes with unique ids, three palettes of four sRGB colours each and the documented per-level
// budgets; white text reaches at least 4.5 : 1 against all 48 colours; palette 0 of theme 0 is the A18-P02 noise
// palette; the contrast math gives the WCAG reference values.
import Foundation
import Testing
@testable import AmbientClockCore

@Suite struct ThemeCatalogTests {
    /// The A18-P02 noise palette, copied from `NoiseGradientTheme.encodedPalette` (the experience tests compare the
    /// two directly).
    private static let noisePalette: [SIMD3<Double>] = [
        SIMD3(0.04, 0.06, 0.18), SIMD3(0.14, 0.06, 0.18), SIMD3(0.02, 0.14, 0.15), SIMD3(0.10, 0.12, 0.15),
    ]

    @Test func theCatalogHasFourThemesOfThreePalettesOfFourColours() {
        #expect(ThemeCatalog.themes.count == 4)
        for info in ThemeCatalog.themes {
            #expect(info.palettes.count == 3, "\(info.id)")
            for palette in info.palettes {
                #expect(palette.colors.count == 4, "\(info.id) \(palette.name)")
                #expect(!palette.name.isEmpty)
                for color in palette.colors {
                    for channel in [color.x, color.y, color.z] { #expect((0...0.2).contains(channel)) }
                }
            }
            #expect(Set(info.palettes.map(\.name)).count == 3, "\(info.id)")
            #expect(!info.name.isEmpty)
        }
        #expect(ThemeCatalog.themes.flatMap { $0.palettes.flatMap(\.colors) }.count == 48)
    }

    @Test func theIdsAreUniqueAndInOrder() {
        let ids = ThemeCatalog.themes.map(\.id)
        #expect(ids == ["noise-gradient", "particle-drift", "wave-field", "sdf-shapes"])
        #expect(Set(ids).count == ids.count)
        #expect(ThemeCatalog.themes.map(\.countName) == ["octaves", "cells", "waves", "shapes"])
    }

    @Test func theBudgetsPerLevelAreDocumented() {
        let expected = [[5, 3], [48, 24], [6, 3], [8, 4]]
        for theme in 0..<4 {
            #expect(ThemeCatalog.themes[theme].counts == expected[theme])
            for tier in 0..<2 {
                #expect(ThemeCatalog.budget(theme: theme, tier: tier) == expected[theme][tier], "\(theme) \(tier)")
            }
        }
        #expect(ThemeCatalog.budget(theme: 9, tier: 9) == 4)
        #expect(ThemeCatalog.budget(theme: -1, tier: -1) == 5)
    }

    @Test func themeZeroPaletteZeroIsTheNoisePalette() {
        #expect(ThemeCatalog.themes[0].palettes[0].colors == Self.noisePalette)
        #expect(ThemeCatalog.palette(theme: 0, palette: 0).colors == Self.noisePalette)
    }

    @Test func whiteTextReachesTheRequiredContrastOnEveryColour() {
        #expect(ThemeCatalog.requiredContrast == 4.5)
        #expect(ThemeCatalog.contrastProblems().isEmpty)
        #expect(ThemeCatalog.contrastProblems(text: SIMD3(1, 1, 1)).isEmpty)
        for info in ThemeCatalog.themes {
            for palette in info.palettes {
                for color in palette.colors {
                    #expect(ThemeCatalog.contrastRatio(ThemeCatalog.white, color) >= 4.5, "\(info.id) \(palette.name)")
                }
            }
        }
        #expect(ThemeCatalog.minimumContrast() >= 4.5)
    }

    @Test func aDarkTextColourIsReportedOnEveryColour() {
        let problems = ThemeCatalog.contrastProblems(text: SIMD3(0.1, 0.1, 0.1))
        #expect(problems.count == 48)
        #expect(problems.first?.contains("noise-gradient") == true)
        #expect(problems.allSatisfy { $0.hasSuffix(".") })
        #expect(ThemeCatalog.minimumContrast(text: SIMD3(0.1, 0.1, 0.1)) < 4.5)
    }

    @Test func theContrastMathGivesTheWCAGReferenceValues() {
        #expect(abs(ThemeCatalog.contrastRatio(SIMD3(1, 1, 1), SIMD3(0, 0, 0)) - 21) < 1e-9)
        #expect(abs(ThemeCatalog.contrastRatio(SIMD3(0.5, 0.5, 0.5), SIMD3(0.5, 0.5, 0.5)) - 1) < 1e-12)
        // #767676 on white is the classic 4.54 : 1 AA boundary.
        let grey = 118.0 / 255.0
        #expect(abs(ThemeCatalog.contrastRatio(SIMD3(1, 1, 1), SIMD3(grey, grey, grey)) - 4.54) < 0.01)
        let a = SIMD3(0.2, 0.4, 0.6), b = SIMD3(0.9, 0.1, 0.3)
        #expect(ThemeCatalog.contrastRatio(a, b) == ThemeCatalog.contrastRatio(b, a))
        #expect(abs(ThemeCatalog.relativeLuminance(SIMD3(0.04045, 0, 0)) - 0.2126 * 0.04045 / 12.92) < 1e-15)
    }
}
