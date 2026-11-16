// BudgetTests — feature 125 (A17-P02) T-A17-202 (FR-A17-209; SC-A17-204; clarification Q1). The two quality levels
// and their budgets: the declared values; the knee within each level's triangle, draw and label budgets; level 1
// lighter than level 0; content over a budget refused as `over-budget` naming the level and the count; a declared
// mesh without a placement refused as `missing-mesh` naming it; a generator failure refused as `build-failed`.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import InteractiveAnatomyCore

@Suite struct BudgetTests {
    /// A level-0 copy with other budgets and the level number 9.
    private static func budgetQuality(maxTriangles: Int, maxDraws: Int = 32) -> AnatomyQuality {
        let full = AnatomyQuality.levels[0]
        return AnatomyQuality(level: 9, segments: full.segments, tubeSides: full.tubeSides,
                              sphereSegments: full.sphereSegments, sphereRings: full.sphereRings,
                              maxTriangles: maxTriangles, maxDraws: maxDraws, maxLabels: full.maxLabels)
    }

    /// The refusal of `result`, or nil when it built.
    private static func budgetRefusal(_ result: Result<AnatomyScene, SceneRefusal>) -> SceneRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    @Test func theTwoLevelsHaveTheDeclaredValues() {
        let levels = AnatomyQuality.levels
        #expect(levels.count == 2)
        #expect(levels[0] == AnatomyQuality(level: 0, segments: 48, tubeSides: 16, sphereSegments: 32, sphereRings: 16,
                                            maxTriangles: 60_000, maxDraws: 32, maxLabels: 16))
        #expect(levels[1] == AnatomyQuality(level: 1, segments: 24, tubeSides: 8, sphereSegments: 16, sphereRings: 8,
                                            maxTriangles: 20_000, maxDraws: 32, maxLabels: 16))
        #expect(levels[0].meshBudget.maxIndices == 180_000)
        #expect(levels[1].meshBudget.maxIndices == 60_000)
    }

    @Test func theKneeFitsEveryLevel() throws {
        let region = try AnatomyContent.bundledRightKnee()
        var counts: [Int] = []
        for quality in AnatomyQuality.levels {
            let scene = try AnatomyScene.build(region, quality: quality).get()
            #expect(scene.quality == quality)
            #expect(scene.triangleCount <= quality.maxTriangles, "level \(quality.level): \(scene.triangleCount)")
            #expect(scene.drawCount <= quality.maxDraws, "level \(quality.level)")
            #expect(AnatomyContent.labels(region).count <= quality.maxLabels, "level \(quality.level)")
            counts.append(scene.triangleCount)
        }
        #expect(counts[1] < counts[0])
    }

    @Test func tooManyTrianglesAreRefusedNamingTheLevelAndCount() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let full = try AnatomyScene.build(region, quality: AnatomyQuality.levels[0]).get()
        let tight = Self.budgetQuality(maxTriangles: full.triangleCount - 1)
        let refusal = Self.budgetRefusal(AnatomyScene.build(region, quality: tight))
        #expect(refusal?.reason == .overBudget)
        #expect(refusal?.reason.rawValue == "over-budget")
        #expect(refusal?.sentence.contains("\(full.triangleCount) triangles") == true, "\(String(describing: refusal))")
        #expect(refusal?.sentence.contains("level 9") == true)
        #expect(refusal?.sentence.hasSuffix(".") == true)
        let exact = Self.budgetQuality(maxTriangles: full.triangleCount)
        #expect(Self.budgetRefusal(AnatomyScene.build(region, quality: exact)) == nil)
    }

    @Test func aMeshOverTheMeshBudgetIsRefusedAsOverBudget() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let refusal = Self.budgetRefusal(AnatomyScene.build(region, quality: Self.budgetQuality(maxTriangles: 1_000)))
        #expect(refusal?.reason == .overBudget)
        #expect(refusal?.sentence.contains("mesh.femur.condyles") == true, "\(String(describing: refusal))")
        #expect(refusal?.sentence.contains("level 9") == true)
    }

    @Test func tooManyDrawsAreRefusedNamingTheLevelAndCount() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let refusal = Self.budgetRefusal(AnatomyScene.build(region,
                                                            quality: Self.budgetQuality(maxTriangles: 60_000,
                                                                                        maxDraws: 19)))
        #expect(refusal?.reason == .overBudget)
        #expect(refusal?.sentence.contains("20 draws") == true, "\(String(describing: refusal))")
        #expect(refusal?.sentence.contains("level 9") == true)
    }

    @Test func aDeclaredMeshWithoutAPlacementIsRefused() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let result = AnatomyScene.build(region, quality: AnatomyQuality.levels[0]) { id in
            id == "mesh.acl.band" ? nil : AnatomyGeometry.placement(for: id)
        }
        let refusal = Self.budgetRefusal(result)
        #expect(refusal?.reason == .missingMesh)
        #expect(refusal?.reason.rawValue == "missing-mesh")
        #expect(refusal?.sentence.contains("mesh.acl.band") == true, "\(String(describing: refusal))")
    }

    @Test func aGeneratorFailureIsRefusedNamingTheMesh() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let broken = MeshPlacement(meshID: "mesh.pcl.band", kind: .tube,
                                   shape: .tube(path: [Vec3(0, 0, 0), Vec3(0, 1, 0)], radius: 0), model: .identity)
        let result = AnatomyScene.build(region, quality: AnatomyQuality.levels[1]) { id in
            id == "mesh.pcl.band" ? broken : AnatomyGeometry.placement(for: id)
        }
        let refusal = Self.budgetRefusal(result)
        #expect(refusal?.reason == .buildFailed)
        #expect(refusal?.reason.rawValue == "build-failed")
        #expect(refusal?.sentence.contains("mesh.pcl.band") == true, "\(String(describing: refusal))")
    }
}
