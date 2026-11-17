// PaletteTests — feature 145 (A20-P01) T-A20-105 (FR-A20-104; clarifications Q1, Q3). The palette's counts, unique
// ids, ranges and opacity; the tray's aspect and field; the two rake styles differ; lookups and defaults.
import Foundation
import Testing
@testable import DigitalZenGardenCore

@Suite struct PaletteTests {
    @Test func theTrayIsDocumented() {
        let tray = GardenPalette.smallTray
        #expect(GardenPalette.trays.count == 1)
        #expect(tray.id == "small-tray")
        #expect(abs(tray.aspect - 4.0 / 3.0) < 1e-12)
        #expect(tray.fieldColumns == 160)
        #expect(tray.fieldRows == 120)
        #expect(tray.yScale == 0.75)
        #expect(GardenPalette.tray(id: "small-tray") == tray)
        #expect(GardenPalette.tray(id: "large-tray") == nil)
    }

    @Test func theTonesAreOpaqueAndInRange() {
        let ids = GardenPalette.tones.map(\.id)
        #expect(ids == ["pale", "warm", "grey"])
        #expect(Set(ids).count == ids.count)
        for tone in GardenPalette.tones {
            for component in [tone.red, tone.green, tone.blue] {
                #expect(component.isFinite)
                #expect((0...1).contains(component))
            }
            #expect(GardenPalette.tone(id: tone.id) == tone)
        }
        #expect(GardenPalette.defaultToneID == "pale")
        #expect(GardenPalette.defaultTone.id == "pale")
        #expect(GardenPalette.tone(id: "black") == nil)
    }

    @Test func theTwoRakesDiffer() throws {
        #expect(GardenPalette.rakes.count == 2)
        let fine = try #require(GardenPalette.rake(id: "fine-rake"))
        let wide = try #require(GardenPalette.rake(id: "wide-rake"))
        #expect(fine.tines == 5)
        #expect(fine.width == 0.06)
        #expect(fine.depth == 0.6)
        #expect(wide.tines == 3)
        #expect(wide.width == 0.10)
        #expect(wide.depth == 1.0)
        #expect(fine.tines != wide.tines)
        #expect(fine.width != wide.width)
        #expect(fine.depth != wide.depth)
        #expect(GardenPalette.defaultRakeID == "fine-rake")
        #expect(GardenPalette.defaultRake == fine)
        #expect(GardenPalette.rake(id: "comb") == nil)
    }

    @Test func theStoneKindsAreFiveWithRadiiInRange() {
        let ids = GardenPalette.stones.map(\.id)
        #expect(ids == ["river-pebble", "flat-slate", "round-granite", "tall-basalt", "moss-boulder"])
        #expect(Set(ids).count == 5)
        var shapes = Set<[Double]>()
        for kind in GardenPalette.stones {
            #expect(GardenPalette.stoneRadiusRange.contains(kind.radiusX))
            #expect(GardenPalette.stoneRadiusRange.contains(kind.radiusY))
            #expect(GardenPalette.stone(id: kind.id) == kind)
            shapes.insert([kind.radiusX, kind.radiusY])
        }
        #expect(shapes.count == 5)
        #expect(GardenPalette.stone(id: "brick") == nil)
    }
}
