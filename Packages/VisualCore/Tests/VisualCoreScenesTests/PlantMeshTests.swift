// PlantMeshTests — feature 219 (R02-F19) T-R02F19-006 (FR-R02F19-004; SC-R02F19-003; clarification Q3). Plant meshes of
// 50 seeded grammars validate, stay within budget, have exactly the vertices of their parts, and place every part with
// its origin at its marker.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct PlantMeshTests {
    static func grammar(seed: UInt64) throws -> PlantGrammar {
        let x: PlantRule = try PlantRule("X", weighted: [("F[+XP][-XC]FX", 2), ("F[&XL]^FX", 1), ("FXP", 1)])
        return try PlantGrammar(start: "X", rules: [x], generations: 3, angle: 0.45, step: 0.3, radius: 0.04,
                                radiusFactor: 0.8, seed: seed)
    }

    @Test func seededPlantsValidateAndPlacePartsAtTheirMarkers() throws {
        let petal: PetalShape = try PetalShape(length: 0.2, width: 0.08, curl: 0.6, segments: 4)
        let cap: CapShape = try CapShape(radius: 0.1, height: 0.05, rim: 0.01, sides: 8, rings: 3)
        let petalVertices: Int = try petal.mesh().positions.count
        let capVertices: Int = try cap.mesh().positions.count
        let leafVertices: Int = try PetalShape(length: 0.2, width: 0.04, curl: 0.6, segments: 4).mesh().positions.count
        let tube: CurveSamples = try CurveSamples(positions: [Vec3(0, 0, 0), Vec3(0, 1, 0)], closed: false)
        let tubeVertices: Int = try Mesh.tube(samples: tube, radius: 0.04, sides: 6, caps: true).positions.count
        var withMarkers: Int = 0
        for k in 0..<50 {
            let skeleton: PlantSkeleton = try PlantTurtle.grow(try Self.grammar(seed: 2_019 + UInt64(k)))
            let mesh: Mesh = try PlantMesh.build(skeleton, petal: petal, cap: cap)
            var expected: Int = skeleton.branches.count * tubeVertices
            for marker in skeleton.markers {
                switch marker.kind {
                case .petal: expected += petalVertices
                case .cap: expected += capVertices
                case .leaf: expected += leafVertices
                }
            }
            #expect(mesh.positions.count == expected, "plant \(k)")
            #expect(mesh.positions.count <= MeshBudget.default.maxVertices)
            // Touching parts share positions, so the merged mesh is not one manifold; every part validates as a closed
            // mesh on its own, and the merged mesh has in-range indices, finite positions and unit normals.
            for branch in skeleton.branches {
                let samples: CurveSamples = try CurveSamples(positions: [branch.start, branch.end], closed: false)
                let part: Mesh = try Mesh.tube(samples: samples, radius: branch.radius, sides: 6, caps: true)
                #expect(part.validate(requireClosed: true).isValid, "plant \(k) branch")
            }
            #expect(mesh.indices.count % 3 == 0)
            var bad: Int = 0
            for index in mesh.indices where Int(index) >= mesh.positions.count { bad += 1 }
            for k2 in 0..<mesh.positions.count {
                let p: Vec3 = mesh.positions[k2], n: Vec3 = mesh.normals[k2]
                if !(p.x.isFinite && p.y.isFinite && p.z.isFinite) || abs(n.length - 1) > 1e-6 { bad += 1 }
            }
            #expect(bad == 0, "plant \(k)")
            // Each part's origin (its local (0, 0, 0), the first vertex of a petal or the base of a cap) lands at the
            // marker: the placed copy of a part equals its local mesh moved into the marker frame.
            var offset: Int = skeleton.branches.count * tubeVertices
            for marker in skeleton.markers {
                let local: Mesh
                switch marker.kind {
                case .petal: local = try petal.mesh()
                case .cap: local = try cap.mesh()
                case .leaf: local = try PetalShape(length: 0.2, width: 0.04, curl: 0.6, segments: 4).mesh()
                }
                let right: Vec3 = Vec3(-marker.left.x, -marker.left.y, -marker.left.z)
                for v in 0..<local.positions.count {
                    let p: Vec3 = local.positions[v]
                    let want: Vec3 = marker.position + right * p.x + marker.heading * p.y + marker.up * p.z
                    #expect((mesh.positions[offset + v] - want).length <= 1e-9)
                }
                offset += local.positions.count
            }
            if !skeleton.markers.isEmpty { withMarkers += 1 }
        }
        #expect(withMarkers >= 40)
    }

    @Test func partsValidateAsClosedMeshes() throws {
        let petal: PetalShape = try PetalShape(length: 0.2, width: 0.08, curl: 0.6, segments: 4)
        let cap: CapShape = try CapShape(radius: 0.1, height: 0.05, rim: 0.01, sides: 8, rings: 3)
        let leaf: PetalShape = try PetalShape(length: 0.2, width: 0.04, curl: 0.6, segments: 4)
        #expect(try petal.mesh().validate(requireClosed: true).isValid)
        #expect(try cap.mesh().validate(requireClosed: true).isValid)
        #expect(try leaf.mesh().validate(requireClosed: true).isValid)
    }

    @Test func emptySkeletonIsRefused() throws {
        let petal: PetalShape = try PetalShape(length: 0.2, width: 0.08, curl: 0, segments: 2)
        let cap: CapShape = try CapShape(radius: 0.1, height: 0.05, rim: 0, sides: 8, rings: 2)
        let empty: PlantSkeleton = try PlantTurtle.interpret("+-", grammar: try Self.grammar(seed: 1))
        #expect(throws: MeshError.self) { try PlantMesh.build(empty, petal: petal, cap: cap) }
        let tiny: MeshBudget = MeshBudget(maxVertices: 10, maxIndices: 30)
        let skeleton: PlantSkeleton = try PlantTurtle.grow(try Self.grammar(seed: 2_019))
        #expect(throws: MeshError.self) { try PlantMesh.build(skeleton, petal: petal, cap: cap, budget: tiny) }
    }
}
