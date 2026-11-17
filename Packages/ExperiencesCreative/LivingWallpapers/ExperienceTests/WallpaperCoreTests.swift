// WallpaperCoreTests — feature 139 (A19-P02) T-A19-208 (FR-A19-206; contracts/experience.md "Actions"). The pure core
// of Living Wallpapers through the engine: every action accepted inside its range and refused outside (the engine's
// declared ranges, the core's whole-index and switch rules, a parameter outside its scene's range, an index the scene
// does not have); a refusal changes nothing; equal actions give equal digests and every field changes the digest; a
// scene change resets the preset and parameters; the snapshot round trip keeps the digest and a damaged payload is
// refused; the outcome, the quality tiers and the project.
import Foundation
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreDiagnostics
import VisualCoreExperience

@MainActor
@Suite struct WallpaperCoreTests {
    /// One accepted value per control, from the opening state.
    static let accepted: [(String, [Double])] = [
        ("scene.select", [2]), ("scene.preset", [1]), ("scene.parameter", [0, 7]), ("canvas.template", [8]),
        ("canvas.orientation", [1]), ("scene.time", [3600]), ("export.format", [2]), ("motion.enabled", [0]),
    ]

    /// Values the engine refuses for their declared range or count.
    static let refusedByEngine: [(String, [Double])] = [
        ("scene.select", [4]), ("scene.select", [-1]), ("scene.preset", [3]), ("scene.parameter", [3, 1]),
        ("scene.parameter", [0, 41]), ("canvas.template", [9]), ("canvas.orientation", [2]), ("scene.time", [3601]),
        ("scene.time", [-0.5]), ("export.format", [3]), ("motion.enabled", [-1]), ("scene.select", [1, 2]),
        ("scene.parameter", [0]), ("scene.unknown", [0]),
    ]

    /// Values inside the declared ranges that the core's rules refuse.
    static let refusedByCore: [(String, [Double])] = [
        ("scene.select", [1.5]), ("scene.preset", [0.5]), ("scene.parameter", [0.5, 4]), ("scene.parameter", [0, 9]),
        ("scene.parameter", [0, 1]), ("canvas.template", [2.5]), ("canvas.orientation", [0.5]),
        ("export.format", [1.2]), ("motion.enabled", [0.3]),
    ]

    @Test func everyControlIsAcceptedInsideItsRange() async throws {
        #expect(WallpaperCore.controls.map(\.id) == WallpaperCore.actionIDs)
        for (control, values) in Self.accepted {
            var engine = try await WallpaperTest.engine()
            let result = engine.handle(control: control, values: values)
            #expect(result == .accepted, "\(control) \(values)")
        }
    }

    @Test func outOfRangeAndMalformedActionsAreRefusedAndChangeNothing() async throws {
        var engine = try await WallpaperTest.engine()
        let digest = try engine.digest()
        for (control, values) in Self.refusedByEngine + Self.refusedByCore {
            let result = engine.handle(control: control, values: values)
            #expect(!result.isAccepted, "\(control) \(values)")
            #expect(try engine.digest() == digest, "\(control) \(values)")
        }
    }

    @Test func aParameterIndexTheSceneDoesNotHaveIsRefused() {
        let (cells, selected) = wallpaperApplied(WallpaperCore(), "scene.select", [2])
        #expect(selected == .accepted)
        #expect(cells.sceneDefinition.parameters.count == 2)
        let (same, result) = wallpaperApplied(cells, "scene.parameter", [2, 1])
        #expect(result == .rejected(.rule(code: WallpaperRule.unknownParameter)))
        #expect(same == cells)
        let (changed, edge) = wallpaperApplied(cells, "scene.parameter", [1, 0.9])
        #expect(edge == .accepted)
        #expect(changed.parameters == [14, 0.9, 0])
    }

    @Test func aSceneChangeResetsThePresetAndTheParameters() {
        var core = WallpaperCore()
        #expect(core.parameters == [4, 0.35, 0.6])
        for (control, values) in [("scene.preset", [2.0]), ("scene.parameter", [0.0, 7]), ("scene.select", [0.0])] {
            let (next, result) = wallpaperApplied(core, control, values)
            #expect(result == .accepted)
            core = next
        }
        #expect(core.preset == 2 && core.parameters[0] == 7, "choosing the shown scene keeps them")
        let (dunes, result) = wallpaperApplied(core, "scene.select", [3])
        #expect(result == .accepted)
        #expect(dunes.preset == 0)
        #expect(dunes.parameters == WallpaperCore.defaultParameters(scene: 3))
        #expect(dunes.parameters == [4, 0.2, 0.8])
    }

    @Test func equalActionsGiveEqualDigestsAndEveryFieldChangesIt() async throws {
        var first = try await WallpaperTest.engine()
        var second = try await WallpaperTest.engine()
        let opening = try first.digest()
        var seen: Set<String> = [opening.hex]
        for (control, values) in Self.accepted {
            #expect(first.handle(control: control, values: values) == .accepted)
            #expect(second.handle(control: control, values: values) == .accepted)
            let digest = try first.digest()
            #expect(digest == (try second.digest()), "\(control)")
            #expect(seen.insert(digest.hex).inserted, "\(control) changes the digest")
        }
        let otherSeed = try await WallpaperTest.engine(seed: 2)
        #expect(try otherSeed.digest() != opening, "the seed is in the digest")
    }

    @Test func theSnapshotRoundTripKeepsTheDigest() async throws {
        var engine = try await WallpaperTest.engine(seed: 7)
        for (control, values) in Self.accepted { _ = engine.handle(control: control, values: values) }
        let core = try #require(engine.core)
        let payload = try core.snapshotPayload()
        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(Set(object.keys) == ["animationTime", "format", "motion", "orientation", "parameters", "preset",
                                     "scene", "template"])
        let restored = try WallpaperCore.restore(payload: payload, seed: 7)
        #expect(restored == core)
        #expect(try wallpaperDigest(restored) == (try wallpaperDigest(core)))
        let snapshot = try engine.snapshot()
        var other = try await WallpaperTest.engine(seed: 7)
        try other.restore(snapshot)
        #expect(try other.digest() == (try engine.digest()))
    }

    @Test func aPayloadOutsideItsRangesIsRefused() throws {
        let good = try WallpaperCore().snapshotPayload()
        let object = try #require(try JSONSerialization.jsonObject(with: good) as? [String: Any])
        let damaged: [(String, Any)] = [("scene", 4), ("preset", 3), ("template", 9), ("orientation", 2),
                                        ("format", 3), ("animationTime", 3601), ("parameters", [9, 0.35, 0.6]),
                                        ("parameters", [4, 0.35]), ("parameters", [4, 0.35, 0.6, 0])]
        for (key, value) in damaged {
            var changed = object
            changed[key] = value
            let data = try JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys])
            #expect(throws: (any Error).self, "\(key)") { try WallpaperCore.restore(payload: data, seed: 1) }
        }
        let (cells, _) = wallpaperApplied(WallpaperCore(), "scene.select", [2])
        var unused = try #require(try JSONSerialization.jsonObject(with: cells.snapshotPayload()) as? [String: Any])
        unused["parameters"] = [14, 0.5, 1]
        let data = try JSONSerialization.data(withJSONObject: unused, options: [.sortedKeys])
        #expect(throws: (any Error).self, "an unused slot must be 0") {
            try WallpaperCore.restore(payload: data, seed: 1)
        }
    }

    @Test func theOutcomeNamesTheSceneAndResetKeepsTheSeed() {
        for index in 0..<SceneCatalog.scenes.count {
            let (core, _) = wallpaperApplied(WallpaperCore(), "scene.select", [Double(index)])
            #expect(core.outcome?.code == "scene-" + SceneCatalog.scenes[index].id)
        }
        var core = WallpaperCore(seed: 9)
        core.setQualityTier(1)
        let (changed, _) = wallpaperApplied(core, "scene.select", [1])
        var reset = changed
        reset.reset()
        #expect(reset == WallpaperCore(seed: 9))
        #expect(reset.qualityTier == 1)
    }

    @Test func theQualityTiersAreLevelZeroAndLevelOne() throws {
        #expect(WallpaperCore.qualityTiers == 2)
        #expect(WallpaperCore.qualityProfile.levels.map(\.name) == ["level-0", "level-1"])
        var core = WallpaperCore()
        let digest = try wallpaperDigest(core)
        core.setQualityTier(5)
        #expect(core.qualityTier == 1)
        #expect(try wallpaperDigest(core) == digest)
    }

    @Test func theProjectIsWhatThePlannerPlans() throws {
        var core = WallpaperCore(seed: 3)
        for (control, values) in [("scene.select", [1.0]), ("scene.preset", [2.0]), ("scene.parameter", [1.0, 2.5]),
                                  ("canvas.template", [5.0]), ("canvas.orientation", [1.0]), ("scene.time", [12.0]),
                                  ("export.format", [1.0])] {
            let (next, result) = wallpaperApplied(core, control, values)
            #expect(result == .accepted, "\(control)")
            core = next
        }
        let project = core.project
        #expect(project.validation() == nil)
        #expect(project.scene == "ink-flow" && project.preset == 2 && project.seed == 3)
        #expect(project.parameters == ["warp": 0.8, "scale": 2.5, "flowSpeed": 0.25])
        #expect(project.template == "ipad-pro-13-m4" && project.orientation == .landscape)
        #expect(project.animationTime == 12 && project.format == .jpeg)
        let plan = try ExportPlanner.plan(project: project, maxEdge: 4096).get()
        #expect(plan.width == 2752 && plan.height == 2064)
        #expect(WallpaperCore().project == WallpaperProject.default)
    }
}
