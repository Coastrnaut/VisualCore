// ExperimentPresetTests — feature 120 (A16-P04) T-A16-402 (FR-A16-430; SC-A16-403; clarification Q4). The
// schema-1 experiment preset, host-free and short: every bundled preset round-trips through sorted-key JSON, is
// valid and carries an allowed license and a source; damaged bytes are refused as damaged, a schema-2 file as newer,
// a refused spec (reaction-diffusion Δt 2.0) as invalid; a name over 60 characters, an empty name, a long annotation,
// an unknown license or palette and a grid other than 64 are problems.
import Foundation
import Testing
import VisualCoreSimulation
@testable import SimulationLabCore

@Suite struct ExperimentPresetTests {
    @Test func theSixFamilyPresetsAreBundled() {
        let names = ExperimentPreset.bundled.map(\.name)
        #expect(names == ["Life", "HighLife", "Seeds", "Spots", "Mazes", "Pulse"])
        let kinds = ExperimentPreset.bundled.map(\.spec.kind)
        #expect(kinds == [.automaton, .automaton, .automaton, .reactionDiffusion, .reactionDiffusion, .wave])
        #expect(ExperimentPreset.bundled[5].license == "original")
        for preset in ExperimentPreset.bundled.prefix(5) { #expect(preset.license == "public-domain") }
    }

    @Test func everyBundledPresetIsValidAndAttributed() {
        for preset in ExperimentPreset.bundled {
            #expect(preset.problem() == nil, "\(preset.name)")
            #expect(ExperimentPreset.licenses.contains(preset.license))
            #expect(!preset.source.isEmpty && !preset.annotation.isEmpty && preset.palette == "standard")
            #expect(preset.schema == 1 && preset.spec.gridSize == 64)
        }
    }

    @Test func everyBundledPresetRoundTrips() throws {
        for preset in ExperimentPreset.bundled {
            let data = preset.encoded()
            #expect(try ExperimentPreset.decode(data).get() == preset)
            #expect(ExperimentPreset.decode(data).map(\.name) == .success(preset.name))
            #expect(preset.encoded() == data)
        }
    }

    @Test func damagedBytesAreRefusedAsDamaged() {
        let good = ExperimentPreset.bundled[0].encoded()
        let damaged: [Data] = [Data(), Data("nope".utf8), Data("{}".utf8), Data("{\"schema\":\"one\"}".utf8),
                               Data("{\"schema\":0}".utf8), Data("{\"schema\":1}".utf8), good.prefix(good.count / 2)]
        for data in damaged { #expect(ExperimentPreset.decode(data) == .failure(.damaged)) }
    }

    @Test func aNewerSchemaIsRefusedAsNewer() throws {
        let data = ExperimentPreset.bundled[0].encoded()
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schema"] = 2
        let newer = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(ExperimentPreset.decode(newer) == .failure(.newerVersion))
        #expect(ExperimentPreset.PresetRefusal.newerVersion.rawValue == "newer-version")
    }

    @Test func aRefusedSpecIsRefusedAsInvalid() {
        var preset = ExperimentPreset.bundled[3]
        preset.spec.timeStep = 2.0
        #expect(preset.problem() != nil)
        #expect(ExperimentPreset.decode(preset.encoded()) == .failure(.invalid))
    }

    @Test func badFieldsAreProblems() {
        var long = ExperimentPreset.bundled[0]
        long.name = String(repeating: "a", count: 61)
        #expect(long.problem() != nil)
        #expect(ExperimentPreset.decode(long.encoded()) == .failure(.invalid))
        var sixty = ExperimentPreset.bundled[0]
        sixty.name = "  " + String(repeating: "a", count: 60) + " "
        #expect(sixty.problem() == nil)
        var empty = ExperimentPreset.bundled[0]
        empty.name = "   "
        #expect(empty.problem() != nil)
        var annotation = ExperimentPreset.bundled[0]
        annotation.annotation = String(repeating: "b", count: 201)
        #expect(annotation.problem() != nil)
        var license = ExperimentPreset.bundled[0]
        license.license = "cc-by"
        #expect(license.problem() != nil)
        var source = ExperimentPreset.bundled[0]
        source.source = ""
        #expect(source.problem() != nil)
        var palette = ExperimentPreset.bundled[0]
        palette.palette = "neon"
        #expect(palette.problem() != nil)
        var grid = ExperimentPreset.bundled[0]
        grid.spec.gridSize = 32
        #expect(grid.problem() != nil)
    }
}
