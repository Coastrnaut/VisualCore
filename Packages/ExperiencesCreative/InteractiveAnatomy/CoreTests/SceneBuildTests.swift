// SceneBuildTests — feature 125 (A17-P02) T-A17-202 (FR-A17-201; SC-A17-201). The region scene of the bundled right
// knee, host-free and short: every declared mesh has a placement of its declared kind and is built at both levels;
// every mesh validates and is closed; 20 items (one per mesh) of the 14 parts in inventory order; every world box lies
// inside the region bounds and inside its part's sphere; the same content and level give the same digest twice.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import InteractiveAnatomyCore

@Suite struct SceneBuildTests {
    /// The bundled knee's scene at `quality`; throws the refusal.
    private static func sceneBuildScene(_ quality: AnatomyQuality) throws -> AnatomyScene {
        let region = try AnatomyContent.bundledRightKnee()
        return try AnatomyScene.build(region, quality: quality).get()
    }

    @Test func everyDeclaredMeshHasAPlacementOfItsKind() throws {
        let region = try AnatomyContent.bundledRightKnee()
        #expect(region.meshes.count == 20)
        #expect(AnatomyGeometry.placements.count == 20)
        for declaration in region.meshes {
            let placement = AnatomyGeometry.placement(for: declaration.id)
            #expect(placement?.kind == declaration.kind, "\(declaration.id)")
        }
        #expect(AnatomyGeometry.placement(for: "mesh.unknown.part") == nil)
    }

    @Test func everyMeshValidatesAndIsClosedAtBothLevels() throws {
        for quality in AnatomyQuality.levels {
            let scene = try Self.sceneBuildScene(quality)
            for item in scene.items {
                let report = item.mesh.validate(requireClosed: true, budget: quality.meshBudget)
                #expect(report.isValid, "level \(quality.level) \(item.meshID): \(report)")
                #expect(report.summary.isClosed, "level \(quality.level) \(item.meshID)")
            }
        }
    }

    @Test func itemsFollowTheInventoryOrder() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let scene = try Self.sceneBuildScene(AnatomyQuality.levels[0])
        let partIDs = region.structures.filter { $0.parent != nil }.map(\.id)
        #expect(scene.parts.count == 14)
        #expect(scene.parts.map(\.id) == partIDs)
        #expect(scene.items.count == 20)
        #expect(scene.drawCount == 20)
        let expectedMeshes = scene.parts.flatMap(\.meshIDs)
        #expect(scene.items.map(\.meshID) == expectedMeshes)
        for item in scene.items {
            let part = scene.parts[item.structureIndex]
            #expect(item.structureID == part.id, "\(item.meshID)")
            #expect(item.layer == part.layer, "\(item.meshID)")
            #expect(part.meshIDs.contains(item.meshID), "\(item.meshID)")
            #expect(item.worldTriangles.count == 3 * item.triangleCount, "\(item.meshID)")
        }
        for index in 0..<14 {
            #expect(scene.partIndex(partIDs[index]) == index)
        }
    }

    @Test func worldBoxesLieInsideTheRegionAndTheirSpheres() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let scene = try Self.sceneBuildScene(AnatomyQuality.levels[0])
        let low = region.bounds.min, high = region.bounds.max
        for item in scene.items {
            let lo = item.worldMin, hi = item.worldMax
            #expect(lo.x >= low.x && lo.y >= low.y && lo.z >= low.z, "\(item.meshID)")
            #expect(hi.x <= high.x && hi.y <= high.y && hi.z <= high.z, "\(item.meshID)")
            let part = scene.structureSphere(item.structureIndex)
            #expect(part.radius > 0, "\(item.meshID)")
            for corner in [lo, hi] {
                #expect((corner - part.center).length <= part.radius + 1e-9, "\(item.meshID)")
                #expect((corner - scene.regionCenter).length <= scene.regionRadius + 1e-9, "\(item.meshID)")
            }
            let inside = item.worldTriangles.allSatisfy { p in
                p.x >= lo.x - 1e-9 && p.x <= hi.x + 1e-9 && p.y >= lo.y - 1e-9 && p.y <= hi.y + 1e-9
                    && p.z >= lo.z - 1e-9 && p.z <= hi.z + 1e-9
            }
            #expect(inside, "\(item.meshID)")
        }
        #expect(scene.structureSphere(99).radius == 0)
    }

    @Test func theSameContentAndLevelGiveTheSameDigest() throws {
        let first = try Self.sceneBuildScene(AnatomyQuality.levels[0])
        let second = try Self.sceneBuildScene(AnatomyQuality.levels[0])
        #expect(first.digest == second.digest)
        #expect(first.digest.count == 64)
        let reduced = try Self.sceneBuildScene(AnatomyQuality.levels[1])
        #expect(reduced.digest != first.digest)
        for (a, b) in zip(first.items, second.items) {
            #expect(a.mesh.digest == b.mesh.digest, "\(a.meshID)")
        }
    }

    @Test func visibleItemsFollowTheLayers() throws {
        let scene = try Self.sceneBuildScene(AnatomyQuality.levels[1])
        #expect(scene.visibleItems(Set(AnatomyLayer.allCases)).count == 20)
        #expect(scene.visibleItems([]).isEmpty)
        for layer in AnatomyLayer.allCases {
            let shown = scene.visibleItems([layer])
            #expect(!shown.isEmpty, "\(layer)")
            #expect(shown.allSatisfy { $0.layer == layer }, "\(layer)")
        }
        #expect(scene.visibleItems([.bones]).count + scene.visibleItems([.cartilage]).count
                + scene.visibleItems([.ligaments]).count == 20)
    }
}
