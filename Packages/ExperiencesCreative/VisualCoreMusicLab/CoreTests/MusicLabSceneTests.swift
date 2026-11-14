// MusicLabSceneTests — feature 049 (A06-P03) T-A06-304 (FR-A06-310, FR-A06-311; data-model "MusicLabScene",
// "SceneParameter", "MappingChoice"; research D4). The three scenes with their parameter counts, ranges, unique names
// and display names, the valid defaults, the spin slot, and the mapping choice's ranges and validating Codable.
import Foundation
import Testing
import VisualCoreMusicLabCore

@Suite struct MusicLabSceneTests {
    @Test func thereAreThreeScenesWithTwoTwoAndThreeParameters() {
        #expect(MusicLabScene.allCases == [.bars, .rings, .geometry])
        #expect(MusicLabScene.allCases.map(\.rawValue) == [0, 1, 2])
        #expect(MusicLabScene.allCases.map { $0.parameters.count } == [2, 2, 3])
        #expect(MusicLabScene.bars.parameters.map(\.name) == ["height", "glow"])
        #expect(MusicLabScene.rings.parameters.map(\.name) == ["radius", "wobble"])
        #expect(MusicLabScene.geometry.parameters.map(\.name) == ["pulse", "spin", "lift"])
    }

    @Test func everyRangeIsNonEmptyAndMatchesTheDesign() {
        for scene in MusicLabScene.allCases {
            for parameter in scene.parameters {
                #expect(parameter.range.lowerBound < parameter.range.upperBound)
                #expect(parameter.attack > 0 && parameter.release > 0)
                #expect(!parameter.title.isEmpty)
            }
        }
        #expect(MusicLabScene.bars.parameters.map(\.range) == [0.3...1.0, 0.4...1.0])
        #expect(MusicLabScene.rings.parameters.map(\.range) == [0.2...0.45, 0.02...0.15])
        #expect(MusicLabScene.geometry.parameters.map(\.range) == [0.6...1.2, 0.1...2.0, 0.2...1.5])
    }

    @Test func beatDrivenParametersSmoothFaster() {
        for scene in MusicLabScene.allCases {
            for (parameter, choice) in zip(scene.parameters, scene.defaultChoices) {
                let expected = choice.feature == 2 ? (0.01, 0.2) : (0.02, 0.25)
                #expect(parameter.attack == expected.0)
                #expect(parameter.release == expected.1)
            }
        }
    }

    @Test func namesAreUniquePerScene() {
        for scene in MusicLabScene.allCases {
            let names = scene.parameters.map(\.name)
            #expect(Set(names).count == names.count)
        }
    }

    @Test func defaultsAreValidAndOnePerParameter() {
        for scene in MusicLabScene.allCases {
            #expect(scene.defaultChoices.count == scene.parameters.count)
            #expect(scene.defaultChoices.allSatisfy { $0.isValid && $0.gain == 1 })
        }
        #expect(MusicLabScene.bars.defaultChoices.map(\.feature) == [0, 2])
        #expect(MusicLabScene.rings.defaultChoices.map(\.feature) == [0, 5])
        #expect(MusicLabScene.geometry.defaultChoices.map(\.feature) == [2, 0, 3])
        #expect(MusicLabScene.defaultMappings() == MusicLabScene.allCases.map(\.defaultChoices))
    }

    @Test func displayNamesAndSpinSlot() {
        #expect(MusicLabScene.allCases.map(\.displayName) == ["Bars", "Rings", "Geometry"])
        #expect(MusicLabScene.bars.spinParameterIndex == nil)
        #expect(MusicLabScene.rings.spinParameterIndex == nil)
        #expect(MusicLabScene.geometry.spinParameterIndex == 1)
        #expect(MusicLabScene.geometry.parameters[1].name == "spin")
    }

    @Test func mappingChoiceRefusesOutOfRangeValues() {
        #expect(MappingChoice.featureRange == 0...6)
        #expect(MappingChoice.gainRange == 0.0...4.0)
        #expect(MappingChoice.featureNames.count == 7)
        #expect(MappingChoice(feature: -1, gain: 1) == nil)
        #expect(MappingChoice(feature: 7, gain: 1) == nil)
        #expect(MappingChoice(feature: 0, gain: -0.1) == nil)
        #expect(MappingChoice(feature: 0, gain: 4.1) == nil)
        #expect(MappingChoice(feature: 0, gain: .nan) == nil)
        #expect(MappingChoice(feature: 0, gain: .infinity) == nil)
        #expect(MappingChoice(feature: 0, gain: 0)?.isValid == true)
        #expect(MappingChoice(feature: 6, gain: 4)?.isValid == true)
        var choice = MappingChoice(feature: 3, gain: 2)!
        choice.feature = 9
        #expect(choice.isValid == false)
    }

    @Test func mappingChoiceRoundTripsAndDecodingRefusesInvalidValues() throws {
        let choices = MusicLabScene.defaultMappings() + [[MappingChoice(feature: 6, gain: 3.5)!]]
        let data = try JSONEncoder().encode(choices)
        #expect(try JSONDecoder().decode([[MappingChoice]].self, from: data) == choices)
        for json in [
            #"{"feature":-1,"gain":1}"#, #"{"feature":7,"gain":1}"#,
            #"{"feature":0,"gain":-0.1}"#, #"{"feature":0,"gain":4.1}"#,
            #"{"feature":0}"#, #"{"gain":1}"#,
        ] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(MappingChoice.self, from: Data(json.utf8))
            }
        }
    }
}
