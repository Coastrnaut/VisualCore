// MusicLabPaletteTests — feature 051 (A06-P05) T-A06-504 (FR-A06-512; data-model "MusicLabPalette"; research D5).
// The three palettes with their indices and names, components in range, palettes that differ pairwise, Aurora equal to
// the presenter colours before palettes, grey Mono colours, and the Codable round trip.
import Foundation
import Testing
import VisualCoreMusicLabCore

@Suite struct MusicLabPaletteTests {
    @Test func thereAreThreePalettesWithIndicesAndNames() {
        #expect(MusicLabPalette.allCases == [.aurora, .ember, .mono])
        #expect(MusicLabPalette.allCases.map(\.rawValue) == [0, 1, 2])
        #expect(MusicLabPalette.allCases.map(\.displayName) == ["Aurora", "Ember", "Mono"])
        #expect(MusicLabPalette(rawValue: 3) == nil)
        #expect(MusicLabPalette(rawValue: -1) == nil)
    }

    @Test func everyComponentIsWithinZeroToOne() {
        for palette in MusicLabPalette.allCases {
            #expect(palette.colors.count == 7)
            for color in palette.colors {
                for component in [color.r, color.g, color.b, color.a] {
                    #expect((0.0...1.0).contains(component), "\(palette) has \(component)")
                }
                #expect(color.a == 1)
            }
        }
    }

    @Test func palettesDifferPairwiseInBarAndWave() {
        let all = MusicLabPalette.allCases
        for i in all.indices {
            for j in all.indices where j > i {
                #expect(all[i].bar != all[j].bar)
                #expect(all[i].wave != all[j].wave)
                #expect(all[i].colors != all[j].colors)
            }
        }
    }

    @Test func auroraEqualsThePresenterColoursExactly() {
        let aurora = MusicLabPalette.aurora
        #expect(aurora.bar == PaletteColor(0.45, 0.6, 1.0, 1))
        #expect(aurora.wave == PaletteColor(0.35, 0.85, 1.0, 1))
        #expect(aurora.level == PaletteColor(0.4, 0.95, 0.55, 1))
        #expect(aurora.peak == PaletteColor(1.0, 0.9, 0.4, 1))
        #expect(aurora.beat == PaletteColor(1.0, 0.45, 0.6, 1))
        #expect(aurora.sphere == PaletteColor(1.0, 0.45, 0.6, 1))
        #expect(aurora.cube == PaletteColor(0.45, 0.6, 1.0, 1))
    }

    @Test func monoColoursAreGrey() {
        for color in MusicLabPalette.mono.colors {
            #expect(color.r == color.g && color.g == color.b)
        }
        let mono = MusicLabPalette.mono
        #expect(mono.bar.r != mono.wave.r)
        #expect(mono.level.r != mono.peak.r)
    }

    @Test func emberIsWarm() {
        for color in MusicLabPalette.ember.colors {
            #expect(color.r >= color.g && color.r > color.b)
        }
    }

    @Test func codableRoundTripKeepsEveryPalette() throws {
        let encoded = try JSONEncoder().encode(MusicLabPalette.allCases)
        #expect(String(decoding: encoded, as: UTF8.self) == "[0,1,2]")
        let decoded = try JSONDecoder().decode([MusicLabPalette].self, from: encoded)
        #expect(decoded == MusicLabPalette.allCases)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MusicLabPalette.self, from: Data("3".utf8))
        }
    }
}
