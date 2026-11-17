// AuroraCoreTests — feature 153 (A21-P02) T-A21-204 (FR-A21-201, FR-A21-202; SC-A21-201; clarifications Q1, Q4;
// contracts/experience.md "Actions"). The adapter core `SkyCore`: each of the eight actions is accepted at its ends and
// in between and refused outside its range or when fractional for a whole-number control, with the state and its
// digest unchanged; a preset keeps the hue shift and the limit; the snapshot round trip; a damaged, refused or newer
// snapshot is refused on restore with the state unchanged; the digest covers exactly the scene, the hue and the limit
// (not the quality tier); two quality tiers named level-0 and level-1. Short runs only.
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite struct AuroraCoreTests {
    /// Each action with values accepted (its ends and a middle value) and refused (outside or fractional).
    static let cases: [(control: String, accepted: [Double], refused: [Double], fractional: [Double])] = [
        ("preset.select", [0, 1, 2], [-1, 3], [0.5, 1.25]),
        ("colour.hue", [-0.5, 0, 0.25, 0.5], [-0.51, 0.6], []),
        ("motion.speed", [0, 1.3, 2], [-0.1, 2.1], []),
        ("motion.turbulence", [0, 0.4, 1], [-0.01, 1.5], []),
        ("sky.ribbons", [1, 3, 4], [0, 5], [2.5]),
        ("sky.stars", [0, 120, 400], [-1, 401], [10.5]),
        ("sky.clouds", [0, 0.7, 1], [-0.2, 1.01], []),
        ("light.limit", [0.2, 0.45, 0.72], [0.19, 0.73], []),
    ]

    /// The value the state holds for `control`.
    static func value(_ core: SkyCore, _ control: String) -> Double {
        switch control {
        case "preset.select": return Double(core.presetIndex)
        case "colour.hue": return core.hue
        case "motion.speed": return core.scene.speed
        case "motion.turbulence": return core.scene.turbulence
        case "sky.ribbons": return Double(core.scene.ribbons)
        case "sky.stars": return Double(core.scene.stars)
        case "sky.clouds": return core.scene.cloudiness
        default: return core.limit
        }
    }

    @Test func theEightControlsAreDeclaredWithTheirRanges() {
        #expect(SkyCore.experienceID == "a21.aurora")
        #expect(AuroraExperience.id?.rawValue == "a21.aurora")
        #expect(SkyCore.controls.map(\.id) == SkyCore.actionIDs)
        #expect(SkyCore.actionIDs == Self.cases.map(\.control))
        let ranges = Dictionary(uniqueKeysWithValues: SkyCore.controls.map { ($0.id, $0.ranges) })
        #expect(ranges["preset.select"] == [0...2] && ranges["colour.hue"] == [-0.5...0.5])
        #expect(ranges["motion.speed"] == [0...2] && ranges["motion.turbulence"] == [0...1])
        #expect(ranges["sky.ribbons"] == [1...4] && ranges["sky.stars"] == [0...400])
        #expect(ranges["sky.clouds"] == [0...1] && ranges["light.limit"] == [0.2...0.72])
        let core = SkyCore()
        #expect(core.scene == SkyPresets.polarNight.scene && core.hue == 0 && core.limit == 0.6)
        #expect(core.outcome?.code == "preset-polar-night")
    }

    @Test func everyActionIsAcceptedInRange() throws {
        for item in Self.cases {
            for value in item.accepted {
                let (next, result) = skyApplied(SkyCore(), item.control, [value])
                #expect(result == .accepted, "\(item.control) \(value)")
                #expect(Self.value(next, item.control) == value, "\(item.control) \(value)")
            }
        }
    }

    @Test func outOfRangeAndFractionalValuesAreRefusedAndChangeNothing() async throws {
        let shell = try await AuroraTest.shell()
        AuroraTest.accept(shell, "preset.select", [1])
        AuroraTest.accept(shell, "colour.hue", [0.2])
        let before = try AuroraTest.core(shell)
        let digest = try shell.engine.digest()
        for item in Self.cases {
            for value in item.refused + [Double.nan, Double.infinity] {
                let result = shell.handle(control: item.control, values: [value])
                #expect(!result.isAccepted, "\(item.control) \(value)")
                let direct = skyApplied(before, item.control, [value])
                #expect(!direct.1.isAccepted && direct.0 == before, "\(item.control) \(value) direct")
            }
            for value in item.fractional {
                let result = shell.handle(control: item.control, values: [value])
                #expect(result.code == "action.rule." + SkyRule.notWhole, "\(item.control) \(value)")
            }
            let wrongCount = shell.handle(control: item.control, values: [])
            #expect(!wrongCount.isAccepted)
        }
        #expect(try AuroraTest.core(shell) == before)
        #expect(try shell.engine.digest() == digest)
    }

    @Test func aPresetKeepsTheHueAndTheLimit() {
        var (core, _) = skyApplied(SkyCore(), "colour.hue", [-0.25])
        (core, _) = skyApplied(core, "light.limit", [0.3])
        (core, _) = skyApplied(core, "sky.stars", [12])
        let (next, result) = skyApplied(core, "preset.select", [2])
        #expect(result == .accepted)
        #expect(next.scene == SkyPresets.dawnHaze.scene, "the preset's whole scene")
        #expect(next.hue == -0.25 && next.limit == 0.3)
        #expect(next.outcome?.code == "preset-dawn-haze")
    }

    @Test func theSnapshotRoundTrips() async throws {
        var (core, _) = skyApplied(SkyCore(), "preset.select", [1])
        for (control, value) in [("colour.hue", 0.125), ("motion.speed", 1.5), ("motion.turbulence", 0.9),
                                 ("sky.ribbons", 4.0), ("sky.stars", 40.0), ("sky.clouds", 0.05),
                                 ("light.limit", 0.33)] {
            (core, _) = skyApplied(core, control, [value])
        }
        let payload = try core.snapshotPayload()
        let text = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"hue\":0.125,\"limit\":0.33,\"scene\":{"), "\(text)")
        let restored = try SkyCore.restore(payload: payload, seed: 9)
        #expect(restored == core)
        #expect(try restored.snapshotPayload() == payload)
        #expect(try skyDigest(restored) == skyDigest(core))

        let shell = try await AuroraTest.shell()
        AuroraTest.accept(shell, "preset.select", [2])
        AuroraTest.accept(shell, "light.limit", [0.25])
        let snapshot = try shell.snapshot()
        #expect(snapshot.schemaVersion == 1)
        let other = try await AuroraTest.shell()
        try other.restore(snapshot)
        #expect(try AuroraTest.core(other) == AuroraTest.core(shell))
        #expect(try other.engine.digest() == shell.engine.digest())
    }

    @Test func damagedRefusedAndNewerSnapshotsAreRefused() async throws {
        #expect(throws: SkyRestoreRefusal.damaged) { try SkyCore.restore(payload: Data("{}".utf8), seed: 1) }
        #expect(throws: SkyRestoreRefusal.damaged) { try SkyCore.restore(payload: Data("[1]".utf8), seed: 1) }
        let good = try String(decoding: SkyCore().snapshotPayload(), as: UTF8.self)
        let badStars = good.replacingOccurrences(of: "\"stars\":320", with: "\"stars\":999")
        #expect(badStars != good)
        #expect(throws: SkyRestoreRefusal.scene(.outOfRange("stars"))) {
            try SkyCore.restore(payload: Data(badStars.utf8), seed: 1)
        }
        let badPreset = good.replacingOccurrences(of: "\"polar-night\"", with: "\"no-such-sky\"")
        #expect(throws: SkyRestoreRefusal.scene(.unknownPreset("no-such-sky"))) {
            try SkyCore.restore(payload: Data(badPreset.utf8), seed: 1)
        }
        let badHue = good.replacingOccurrences(of: "\"hue\":0", with: "\"hue\":0.9")
        #expect(throws: SkyRestoreRefusal.outOfRange("hue")) { try SkyCore.restore(payload: Data(badHue.utf8), seed: 1) }
        let badLimit = good.replacingOccurrences(of: "\"limit\":0.6", with: "\"limit\":0.9")
        #expect(throws: SkyRestoreRefusal.outOfRange("limit")) {
            try SkyCore.restore(payload: Data(badLimit.utf8), seed: 1)
        }

        var engine = try await AuroraTest.engine()
        _ = engine.handle(control: "preset.select", values: [1])
        let before = try #require(engine.core)
        let digest = try engine.digest()
        let current = try engine.snapshot()
        let newer = try ExperienceSnapshot(experience: AuroraTest.id, schemaVersion: 2, seed: current.seed,
                                           stepIndex: 0, digest: current.digest, payload: Data(current.payload.utf8))
        #expect(throws: (any Error).self) { try engine.restore(newer) }
        for payload in [Data("{\"hue\":0}".utf8), Data(badStars.utf8), Data(badHue.utf8)] {
            let refused = try ExperienceSnapshot(experience: AuroraTest.id, schemaVersion: 1, seed: current.seed,
                                                 stepIndex: 0, digest: current.digest, payload: payload)
            #expect(throws: (any Error).self) { try engine.restore(refused) }
        }
        #expect(engine.core == before)
        #expect(try engine.digest() == digest)
    }

    @Test func theDigestCoversExactlyTheSceneTheHueAndTheLimit() throws {
        let base = SkyCore()
        let baseDigest = try skyDigest(base)
        var seen: Set<String> = [baseDigest]
        for item in Self.cases {
            let value = item.accepted.first { $0 != Self.value(base, item.control) } ?? item.accepted[0]
            let (next, _) = skyApplied(base, item.control, [value])
            let digest = try skyDigest(next)
            #expect(digest != baseDigest, "\(item.control) reaches the digest")
            seen.insert(digest)
        }
        #expect(seen.count == Self.cases.count + 1)
        var tiered = base
        tiered.setQualityTier(1)
        #expect(tiered.qualityTier == 1 && tiered == base)
        #expect(try skyDigest(tiered) == baseDigest, "the quality tier is not state")
        tiered.reset()
        #expect(tiered.qualityTier == 1 && tiered == SkyCore())
    }

    @Test func twoQualityTiersNamedLevelZeroAndOne() {
        #expect(SkyCore.qualityTiers == 2)
        #expect(SkyCore.qualityProfile.count == 2)
        #expect(SkyCore.qualityProfile.names == ["level-0", "level-1"])
        #expect(SkyShader.octaves(forLevel: 0) == 5 && SkyShader.octaves(forLevel: 1) == 3)
        var core = SkyCore()
        core.setQualityTier(7)
        #expect(core.qualityTier == 1)
    }
}
