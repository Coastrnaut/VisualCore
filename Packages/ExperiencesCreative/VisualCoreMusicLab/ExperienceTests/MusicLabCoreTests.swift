// MusicLabCoreTests — feature 047 (A06-P01) T-A06-104 (FR-A06-104, FR-A06-120, FR-A06-121). The adapter core of
// VisualCore Music Lab against the experience contract, short runs only: conformance over four seeds, the preparation
// seed as demo seed, every source, mode and reseed action changing the digest, the permission mirror leaving it
// unchanged, the microphone refused by rule while access is off, the snapshot round trip, a damaged payload refused and
// reset.
import Foundation
import Testing
@testable import VisualCoreMusicLabExperience
import VisualCoreExperience
import VisualCoreMusicLabCore

private let id = ExperienceID(rawValue: MusicLabCore.experienceID)!

private func engine(seed: UInt64 = 7) async throws -> ExperienceEngine<MusicLabCore> {
    var engine = ExperienceEngine<MusicLabCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

private func core(_ engine: ExperienceEngine<MusicLabCore>) throws -> MusicLabCore {
    try #require(engine.core)
}

@Suite struct MusicLabCoreTests {
    @Test func controlsAndId() {
        #expect(MusicLabCore.experienceID == "a06.visualcore-music-lab")
        #expect(VisualCoreMusicLabExperience.id?.rawValue == "a06.visualcore-music-lab")
        #expect(MusicLabCore.controls.map(\.id)
                == ["source.demo", "source.microphone", "source.file", "demo.mode", "demo.reseed", "permission.mirror",
                    "scene.select", "mapping.set", "mapping.reset", "preset.apply", "palette.select"])
        #expect(MusicLabCore.migrations.currentVersion == 3)
    }

    @Test func conformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 4,
            actions: [ScriptedAction("demo.mode", [1]), ScriptedAction("demo.reseed"),
                      ScriptedAction("source.microphone"), ScriptedAction("source.file"),
                      ScriptedAction("source.demo"), ScriptedAction("demo.mode", [3]),
                      ScriptedAction("permission.mirror", [2]), ScriptedAction("scene.select", [2]),
                      ScriptedAction("mapping.set", [2, 1, 4, 1.5]), ScriptedAction("mapping.reset", [2]),
                      ScriptedAction("preset.apply", [1, 3, 1.2, 6, 2, 0, 0, 1]),
                      ScriptedAction("palette.select", [2])],
            rejected: [ScriptedAction("demo.mode", [4]), ScriptedAction("demo.mode", [.nan]),
                       ScriptedAction("source.demo", [1]), ScriptedAction("permission.mirror", [9]),
                       ScriptedAction("scene.select", [3]), ScriptedAction("mapping.set", [0, 0, 7, 1]),
                       ScriptedAction("mapping.set", [0, 0, 1, 4.5]), ScriptedAction("preset.apply", [0, 0, 1, 2, 1, 3, 1, 0]),
                       ScriptedAction("palette.select", [3]), ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(MusicLabCore.self, id: id, plan: plan)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func preparationUsesTheSeedAsDemoSeed() async throws {
        let state = try core(try await engine(seed: 99)).state
        #expect(state.demoSeed == 99)
        #expect(state.source == .demo)
        #expect(state.demoMode == 0)
    }

    @Test func eachSourceModeAndReseedActionChangesTheDigest() async throws {
        var engine = try await engine()
        let steps: [(String, [Double], SourceKind)] = [
            ("source.microphone", [], .microphone), ("source.file", [], .file), ("source.demo", [], .demo),
        ]
        for (control, values, expected) in steps {
            let before = try engine.digest()
            #expect(engine.handle(control: control, values: values).isAccepted, "\(control)")
            #expect(try core(engine).state.source == expected, "\(control)")
            #expect(try engine.digest() != before, "\(control) changes the digest")
        }
        for (control, values) in [("demo.mode", [2.0]), ("demo.reseed", [])] {
            let before = try engine.digest()
            #expect(engine.handle(control: control, values: values).isAccepted, "\(control)")
            #expect(try engine.digest() != before, "\(control) changes the digest")
        }
        #expect(try core(engine).state.demoMode == 2)
    }

    @Test func thePermissionMirrorLeavesTheDigestAsItWas() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        for access in MicrophoneAccess.allCases {
            #expect(engine.handle(control: "permission.mirror", values: [Double(access.rawValue)]).isAccepted)
            #expect(try core(engine).state.permission == access)
            #expect(try engine.digest() == before, "\(access)")
        }
    }

    @Test func theMicrophoneIsRefusedByRuleWhileAccessIsOff() async throws {
        for access in [MicrophoneAccess.denied, .restricted] {
            var engine = try await engine()
            #expect(engine.handle(control: "permission.mirror", values: [Double(access.rawValue)]).isAccepted)
            let before = try engine.digest()
            let result = engine.handle(control: "source.microphone")
            #expect(result == .rejected(.rule(code: MusicLabRule.permissionDenied)), "\(access)")
            #expect(try engine.digest() == before, "\(access): unchanged")
            #expect(try core(engine).state.source == .demo)
        }
        var engine = try await engine()
        #expect(engine.handle(control: "permission.mirror", values: [Double(MicrophoneAccess.granted.rawValue)]).isAccepted)
        #expect(engine.handle(control: "source.microphone").isAccepted)
    }

    @Test func outOfRangeValuesAreRefused() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        #expect(engine.handle(control: "demo.mode", values: [4]) == .rejected(.outOfRange(index: 0)))
        #expect(engine.handle(control: "demo.mode", values: []) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(engine.handle(control: "source.file", values: [1]) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(engine.handle(control: "bogus") == .rejected(.unknownControl("bogus")))
        #expect(try engine.digest() == before)
    }

    @Test func theSnapshotRoundTripsIntoAnotherSession() async throws {
        var first = try await engine(seed: 7)
        #expect(first.handle(control: "source.file").isAccepted)
        #expect(first.handle(control: "demo.mode", values: [1]).isAccepted)
        #expect(first.handle(control: "demo.reseed").isAccepted)
        let snapshot = try first.snapshot()
        #expect(snapshot.schemaVersion == 3)
        let decoded = try ExperienceSnapshot(data: snapshot.encoded())
        var second = try await engine(seed: 3)
        try second.restore(decoded)
        #expect(try second.digest() == first.digest())
        #expect(try core(second).state == core(first).state)
        #expect(try core(second).seed == 7)
    }

    @Test func aDamagedPayloadIsRefusedAndChangesNothing() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        let payload = Data(#"{"demoMode":9,"demoSeed":7,"source":"demo"}"#.utf8)
        let snapshot = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: 7, stepIndex: 0, digest: before,
                                              payload: payload)
        #expect(throws: ExperienceError.self) { try engine.restore(snapshot) }
        #expect(try engine.digest() == before)
    }

    @Test func resetReturnsToTheMelodyAndKeepsTheMirror() async throws {
        var engine = try await engine(seed: 11)
        let prepared = try engine.digest()
        #expect(engine.handle(control: "permission.mirror", values: [Double(MicrophoneAccess.denied.rawValue)]).isAccepted)
        #expect(engine.handle(control: "source.file").isAccepted)
        #expect(engine.handle(control: "demo.mode", values: [3]).isAccepted)
        try engine.reset()
        #expect(try engine.digest() == prepared)
        #expect(try core(engine).state.source == .demo)
        #expect(try core(engine).state.permission == .denied)
    }

    // Feature 049 (A06-P03) T-A06-306: scenes and mappings.
    @Test func sceneAndMappingActionsChangeTheDigest() async throws {
        var engine = try await engine()
        var last = try engine.digest()
        for (control, values) in [("scene.select", [1.0]), ("scene.select", [2.0]), ("mapping.set", [2.0, 1, 4, 1.5]),
                                  ("mapping.set", [0.0, 0, 6, 0.5]), ("mapping.reset", [2.0])] {
            #expect(engine.handle(control: control, values: values).isAccepted, "\(control) \(values)")
            let now = try engine.digest()
            #expect(now != last, "\(control) \(values)")
            last = now
        }
        #expect(try core(engine).state.scene == .geometry)
        #expect(try core(engine).state.mappings[2] == MusicLabScene.geometry.defaultChoices)
    }

    @Test func aSlotBeyondTheScenesParametersIsRefusedAsARule() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        #expect(engine.handle(control: "mapping.set", values: [0, 2, 1, 1])
                == .rejected(.rule(code: MusicLabRule.noSuchParameter)))
        #expect(try engine.digest() == before)
    }

    @Test func aSchemaOnePayloadRestoresWithBarsAndDefaults() async throws {
        var engine = try await engine(seed: 5)
        let payload = Data(#"{"demoMode":2,"demoSeed":5,"source":"file"}"#.utf8)
        let snapshot = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: 5, stepIndex: 0,
                                              digest: try engine.digest(), payload: payload)
        try engine.restore(snapshot)
        let state = try core(engine).state
        #expect(state.scene == .bars)
        #expect(state.mappings == MusicLabScene.defaultMappings())
        #expect(state.demoMode == 2)
        #expect(state.source == .file)
    }

    @Test func aDamagedMappingPayloadIsRefused() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        let payload = Data(#"{"demoMode":0,"demoSeed":7,"mappings":[[{"feature":9,"gain":1}]],"palette":0,"scene":0,"source":"demo"}"#.utf8)
        let snapshot = try ExperienceSnapshot(experience: id, schemaVersion: 3, seed: 7, stepIndex: 0, digest: before,
                                              payload: payload)
        #expect(throws: ExperienceError.self) { try engine.restore(snapshot) }
        #expect(try engine.digest() == before)
    }

    // Feature 050 (A06-P04) T-A06-405: applying a preset in one action.
    @Test func applyingAPresetSetsTheSceneAndItsChoices() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        #expect(engine.handle(control: "preset.apply", values: [2, 2, 1.5, 5, 1, 3, 1.5, 1]).isAccepted)
        let state = try core(engine).state
        #expect(state.scene == .geometry)
        #expect(state.mappings[2] == [MappingChoice(feature: 2, gain: 1.5)!, MappingChoice(feature: 5, gain: 1)!,
                                      MappingChoice(feature: 3, gain: 1.5)!])
        #expect(try engine.digest() != before)
    }

    @Test func aPresetWithValuesForAMissingSlotIsRefusedAndChangesNothing() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        #expect(engine.handle(control: "preset.apply", values: [0, 0, 1, 2, 1, 3, 1, 0])
                == .rejected(.rule(code: MusicLabRule.noSuchParameter)))
        #expect(engine.handle(control: "preset.apply", values: [0, 0, 1]) == .rejected(.wrongValueCount(expected: 8, found: 3)))
        #expect(try engine.digest() == before)
    }

    // Feature 051 (A06-P05) T-A06-506: the palette.
    @Test func thePaletteActionAndPresetPaletteChangeTheDigest() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        #expect(engine.handle(control: "palette.select", values: [1]).isAccepted)
        #expect(try core(engine).state.palette == .ember)
        let afterPalette = try engine.digest()
        #expect(afterPalette != before)
        #expect(engine.handle(control: "preset.apply", values: [0, 0, 1, 2, 1, 0, 0, 2]).isAccepted)
        #expect(try core(engine).state.palette == .mono)
        #expect(engine.handle(control: "palette.select", values: [3]) == .rejected(.outOfRange(index: 0)))
    }

    @Test func aSchemaTwoPayloadRestoresWithAurora() async throws {
        var engine = try await engine(seed: 5)
        let payload = Data(#"{"demoMode":1,"demoSeed":5,"mappings":[[{"feature":0,"gain":1},{"feature":2,"gain":1}],[{"feature":0,"gain":1},{"feature":5,"gain":1}],[{"feature":2,"gain":1},{"feature":0,"gain":1},{"feature":3,"gain":1}]],"scene":2,"source":"demo"}"#.utf8)
        let snapshot = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: 5, stepIndex: 0,
                                              digest: try engine.digest(), payload: payload)
        try engine.restore(snapshot)
        let state = try core(engine).state
        #expect(state.palette == .aurora)
        #expect(state.scene == .geometry)
        #expect(state.demoMode == 1)
    }
}
