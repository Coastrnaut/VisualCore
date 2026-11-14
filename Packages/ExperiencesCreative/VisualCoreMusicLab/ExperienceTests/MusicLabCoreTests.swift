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
                == ["source.demo", "source.microphone", "source.file", "demo.mode", "demo.reseed", "permission.mirror"])
        #expect(MusicLabCore.migrations.currentVersion == 1)
    }

    @Test func conformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 4,
            actions: [ScriptedAction("demo.mode", [1]), ScriptedAction("demo.reseed"),
                      ScriptedAction("source.microphone"), ScriptedAction("source.file"),
                      ScriptedAction("source.demo"), ScriptedAction("demo.mode", [3]),
                      ScriptedAction("permission.mirror", [2])],
            rejected: [ScriptedAction("demo.mode", [4]), ScriptedAction("demo.mode", [.nan]),
                       ScriptedAction("source.demo", [1]), ScriptedAction("permission.mirror", [9]),
                       ScriptedAction("bogus")])
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
        #expect(snapshot.schemaVersion == 1)
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
}
