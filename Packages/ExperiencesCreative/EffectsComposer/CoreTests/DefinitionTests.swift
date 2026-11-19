// DefinitionTests — feature 180 (A25-P01) T-A25-104 (FR-A25-101, FR-A25-102; SC-A25-101; clarification Q1). The five
// definitions in their order with the table of Q1; every default validates and lies inside a finite range; values
// at exactly a range end are valid; unknown, missing, non-finite, fractional-whole and out-of-range values are refused
// with their code and the field `<effect>.<parameter>`; fingerprints are distinct across effects and stable.
import Foundation
import Testing
import VisualCoreExperience
@testable import EffectsComposerCore

@Suite struct DefinitionTests {
    @Test func libraryListsFiveEffectsInOrder() {
        #expect(EffectLibrary.all.map(\.id) == [.grade, .blur, .distort, .vignette, .posterize])
        #expect(EffectLibrary.all.map(\.title) == ["Color grade", "Blur", "Distort", "Vignette", "Posterize"])
        #expect(EffectID.allCases.count == 5)
        for definition in EffectLibrary.all {
            #expect(definition.version == 1)
            #expect(EffectLibrary.definition(definition.id) == definition)
        }
    }

    @Test func parameterTableMatchesClarification() {
        func table(_ id: EffectID) -> [String] {
            EffectLibrary.definition(id).parameters.map {
                "\($0.name) \($0.range.lowerBound)...\($0.range.upperBound) \($0.defaultValue) \($0.whole)"
            }
        }
        #expect(table(.grade) == ["exposure -2.0...2.0 0.0 false", "contrast 0.5...2.0 1.0 false",
                                  "saturation 0.0...2.0 1.0 false"])
        #expect(table(.blur) == ["radius 0.0...8.0 2.0 true"])
        #expect(table(.distort) == ["amplitude 0.0...0.05 0.01 false", "frequency 1.0...16.0 4.0 false"])
        #expect(table(.vignette) == ["amount 0.0...1.0 0.5 false", "radius 0.2...1.0 0.75 false",
                                     "softness 0.05...1.0 0.3 false"])
        #expect(table(.posterize) == ["levels 2.0...32.0 8.0 true"])
    }

    @Test func everyDefaultValidatesInsideAFiniteRange() throws {
        for definition in EffectLibrary.all {
            for parameter in definition.parameters {
                #expect(parameter.range.lowerBound.isFinite && parameter.range.upperBound.isFinite)
                #expect(parameter.range.contains(parameter.defaultValue))
            }
            #expect(Set(definition.defaults.keys) == Set(definition.parameters.map(\.name)))
            try definition.validate(values: definition.defaults)
        }
    }

    @Test func rangeEndsAreValid() throws {
        for definition in EffectLibrary.all {
            for parameter in definition.parameters {
                for end in [parameter.range.lowerBound, parameter.range.upperBound] {
                    var values = definition.defaults
                    values[parameter.name] = end
                    try definition.validate(values: values)
                }
            }
        }
    }

    /// The refusal of `values` for `id`, or nil when valid.
    private func refusal(_ id: EffectID, _ change: (inout [String: Double]) -> Void) -> ChainRefusal? {
        let definition = EffectLibrary.definition(id)
        var values = definition.defaults
        change(&values)
        do throws(ChainRefusal) {
            try definition.validate(values: values)
            return nil
        } catch {
            return error
        }
    }

    @Test func invalidValuesAreRefusedNamingTheField() {
        #expect(refusal(.grade) { $0["gamma"] = 1 } == .unknownParameter("grade.gamma"))
        #expect(refusal(.grade) { $0["contrast"] = nil } == .missingParameter("grade.contrast"))
        #expect(refusal(.grade) { $0["exposure"] = .nan } == .notFinite("grade.exposure"))
        #expect(refusal(.vignette) { $0["amount"] = .infinity } == .notFinite("vignette.amount"))
        #expect(refusal(.blur) { $0["radius"] = 2.5 } == .outOfRange("blur.radius"))
        #expect(refusal(.posterize) { $0["levels"] = 7.25 } == .outOfRange("posterize.levels"))
        #expect(refusal(.grade) { $0["contrast"] = 2.0001 } == .outOfRange("grade.contrast"))
        #expect(refusal(.distort) { $0["amplitude"] = -0.001 } == .outOfRange("distort.amplitude"))
        #expect(refusal(.posterize) { $0["levels"] = 1 } == .outOfRange("posterize.levels"))
        #expect(refusal(.blur) { $0["radius"] = 9 } == .outOfRange("blur.radius"))
        #expect(refusal(.grade) { $0["gamma"] = 1 }?.code == "unknown-parameter")
        #expect(refusal(.grade) { $0["contrast"] = nil }?.code == "missing-parameter")
        #expect(refusal(.grade) { $0["exposure"] = .nan }?.code == "not-finite")
        #expect(refusal(.blur) { $0["radius"] = 2.5 }?.code == "out-of-range")
    }

    @Test func fingerprintsAreDistinctAndStable() {
        let prints = EffectLibrary.all.map { $0.fingerprint() }
        #expect(Set(prints).count == 5)
        #expect(EffectLibrary.all.map { $0.fingerprint() } == prints)
        for digest in prints { #expect(digest.hex.count == 64) }
        // A different definition (one default changed) gives a different fingerprint.
        let grade = EffectLibrary.definition(.grade)
        var parameters = grade.parameters
        parameters[1] = ParameterSpec(name: "contrast", range: 0.5...2, defaultValue: 1.5)
        let changed = EffectDefinition(id: .grade, version: 1, title: grade.title, parameters: parameters)
        #expect(changed.fingerprint() != grade.fingerprint())
    }
}
