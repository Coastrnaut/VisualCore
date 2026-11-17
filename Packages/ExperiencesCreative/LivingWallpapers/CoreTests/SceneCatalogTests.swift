// SceneCatalogTests — feature 138 (A19-P01) T-A19-105 (FR-A19-101; SC-A19-101; clarification Q2). Four scenes in
// catalog order with unique ids; two or three parameters each with valid ranges and defaults; three presets of four
// colours with components in 0…1; lookup by id.
import Foundation
import Testing
@testable import LivingWallpapersCore

@Suite struct SceneCatalogTests {
    @Test func theCatalogHoldsFourScenesInOrder() {
        #expect(SceneCatalog.scenes.map(\.id) == ["aurora-bands", "ink-flow", "soft-cells", "ripple-dunes"])
        #expect(Set(SceneCatalog.scenes.map(\.id)).count == 4)
        for scene in SceneCatalog.scenes {
            #expect(!scene.name.isEmpty)
        }
    }

    @Test func everySceneHasTwoOrThreeParametersWithValidRanges() {
        for scene in SceneCatalog.scenes {
            #expect((2...3).contains(scene.parameters.count), "\(scene.id)")
            #expect(Set(scene.parameters.map(\.id)).count == scene.parameters.count, "\(scene.id)")
            for parameter in scene.parameters {
                #expect(parameter.minimum < parameter.maximum, "\(scene.id).\(parameter.id)")
                #expect(parameter.minimum <= parameter.defaultValue, "\(scene.id).\(parameter.id)")
                #expect(parameter.defaultValue <= parameter.maximum, "\(scene.id).\(parameter.id)")
                #expect(parameter.accepts(parameter.defaultValue))
                #expect(!parameter.accepts(parameter.maximum + 1))
                #expect(!parameter.accepts(.nan))
                #expect(!parameter.name.isEmpty)
            }
            #expect(scene.defaultParameters.count == scene.parameters.count)
        }
    }

    @Test func everySceneHasThreePresetsOfFourOpaqueColours() {
        for scene in SceneCatalog.scenes {
            #expect(scene.presets.count == 3, "\(scene.id)")
            #expect(Set(scene.presets.map(\.id)).count == 3, "\(scene.id)")
            #expect(Set(scene.presets.map(\.colors)).count == 3, "\(scene.id) presets are distinct")
            for preset in scene.presets {
                #expect(preset.colors.count == 4, "\(scene.id).\(preset.id)")
                for color in preset.colors {
                    #expect((0...1).contains(color.r) && (0...1).contains(color.g) && (0...1).contains(color.b))
                }
            }
        }
    }

    @Test func colourComponentsAreClampedAndHexIsExact() {
        let clamped = RGBColor(r: -1, g: 2, b: .nan)
        #expect(clamped == RGBColor(r: 0, g: 1, b: 0))
        let hex = RGBColor(hex: 0xFF8000)
        #expect(hex.r == 1)
        #expect(hex.g == 128.0 / 255)
        #expect(hex.b == 0)
    }

    @Test func scenesAreFoundById() {
        for scene in SceneCatalog.scenes {
            #expect(SceneCatalog.scene(id: scene.id) == scene)
            for parameter in scene.parameters {
                #expect(scene.parameter(parameter.id) == parameter)
            }
        }
        #expect(SceneCatalog.scene(id: "nebula") == nil)
        #expect(SceneCatalog.scenes[0].parameter("missing") == nil)
    }
}
