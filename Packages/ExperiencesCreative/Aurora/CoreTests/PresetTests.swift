// PresetTests — feature 152 (A21-P01) T-A21-104 (FR-A21-103; SC-A21-101; clarification Q1). The three presets: ids
// unique and in catalog order, version 1, the attribution, each scene valid and naming its preset, each round-trips
// exactly through its file, the described character of each (stars, clouds, ribbon hues), lookups and the default.
import Foundation
import Testing
@testable import AuroraCore

@Suite struct PresetTests {
    @Test func theIdsAreUniqueAndInOrder() {
        let ids = SkyPresets.all.map(\.id)
        #expect(ids == ["polar-night", "violet-veil", "dawn-haze"])
        #expect(Set(ids).count == ids.count)
        #expect(Set(SkyPresets.all.map(\.name)).count == ids.count)
    }

    @Test func everyPresetIsVersionOneAndWrittenForVisualCore() {
        #expect(SkyPresets.attribution == "written for VisualCore")
        for preset in SkyPresets.all {
            #expect(preset.version == 1)
            #expect(preset.attribution == "written for VisualCore")
            #expect(!preset.name.isEmpty)
        }
    }

    @Test func everyPresetSceneIsValidAndNamesItsPreset() {
        for preset in SkyPresets.all {
            #expect(preset.scene.validate() == nil)
            #expect(preset.scene.preset == preset.id)
        }
    }

    @Test func everyPresetRoundTripsExactly() throws {
        for preset in SkyPresets.all {
            let data = preset.scene.encoded()
            #expect(data.count <= SkyScene.maxBytes)
            let decoded = try SkyScene.decode(data).get()
            #expect(decoded == preset.scene)
            #expect(decoded.encoded() == data)
        }
    }

    @Test func thePresetsHaveTheirDescribedCharacter() throws {
        let polar = SkyPresets.polarNight.scene
        let violet = SkyPresets.violetVeil.scene
        let dawn = SkyPresets.dawnHaze.scene
        // polar-night: a deep blue sky, green ribbons, the most stars.
        let polarSky = try #require(polar.palette.first)
        #expect(polarSky.blue > polarSky.red && polarSky.blue > polarSky.green && polarSky.blue < 0.3)
        let polarRibbon = polar.palette[1]
        #expect(polarRibbon.green > polarRibbon.red && polarRibbon.green > polarRibbon.blue)
        #expect(polar.stars > violet.stars && polar.stars > dawn.stars)
        // violet-veil: violet and rose ribbons, light clouds.
        let violetRibbon = violet.palette[1]
        let roseRibbon = violet.palette[2]
        #expect(violetRibbon.blue > violetRibbon.green && violetRibbon.red > violetRibbon.green)
        #expect(roseRibbon.red > roseRibbon.green && roseRibbon.red > roseRibbon.blue)
        #expect(violet.cloudiness > 0 && violet.cloudiness < dawn.cloudiness)
        // dawn-haze: warm colours, the fewest stars, the most clouds.
        for colour in dawn.palette.dropFirst() {
            #expect(colour.red > colour.blue)
        }
        #expect(dawn.stars < violet.stars && dawn.stars < polar.stars)
        #expect(dawn.cloudiness > polar.cloudiness && dawn.cloudiness > violet.cloudiness)
    }

    @Test func lookupsAndTheDefault() {
        for preset in SkyPresets.all {
            #expect(SkyPresets.preset(id: preset.id) == preset)
            #expect(SkyPresets.scene(id: preset.id) == preset.scene)
        }
        #expect(SkyPresets.preset(id: "midnight-sun") == nil)
        #expect(SkyPresets.scene(id: "") == nil)
        #expect(SkyPresets.defaultID == "polar-night")
        #expect(SkyPresets.defaultPreset == SkyPresets.polarNight)
    }
}
