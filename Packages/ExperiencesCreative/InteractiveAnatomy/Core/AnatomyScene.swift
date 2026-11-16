// AnatomyScene — feature 125 (A17-P02) T-A17-202 (FR-A17-201, FR-A17-209; clarifications Q1, Q2; data-model
// "SceneItem", "AnatomyScene"; contracts/scene.md; SC-A17-201, SC-A17-204). The region scene at one quality level:
// one item per declared mesh of the 14 parts, in inventory order (the region's structures without the root, each
// part's meshes in its own order), each with its mesh, model matrix, world-space triangles (for picking) and the
// sphere around its world bounds.
//
// `build` refuses, checking in this order:
// - `missing-mesh`: a part's mesh id has no placement, or is not declared by the region (the sentence names the id);
// - `over-budget`: more draws than the level allows (checked before building), a mesh over the level's mesh budget
//   (the generator's `.budget`), or more triangles in all than the level allows (the sentence names the level and the
//   count);
// - `build-failed`: a generator refuses its input (the sentence names the id and the problem).
// A mesh's world bounds are its mesh bounds' eight corners through its model matrix; a sphere around a box is its
// centre and half diagonal. A structure's sphere encloses its items' world boxes; the region's encloses all of them.
// The digest is SHA-256 over the lines `<mesh id>:<mesh digest>` joined by newlines, in item order.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// Why a region scene could not be built.
public struct SceneRefusal: Error, Equatable, Sendable {
    /// The kinds of refusal; the raw values are the stable names.
    public enum Reason: String, CaseIterable, Sendable {
        /// The scene would exceed the level's triangle or draw budget.
        case overBudget = "over-budget"
        /// A declared mesh has no placement.
        case missingMesh = "missing-mesh"
        /// A mesh generator refused its input.
        case buildFailed = "build-failed"
    }

    /// The kind of refusal.
    public let reason: Reason
    /// The plain-English sentence that names the problem.
    public let sentence: String

    /// Creates a refusal.
    public init(_ reason: Reason, _ sentence: String) {
        self.reason = reason
        self.sentence = sentence
    }
}

/// One drawn mesh of the scene: its part, layer, mesh, placement and world-space geometry.
public struct SceneItem: Sendable {
    /// The part's index, 0…13 in inventory order.
    public let structureIndex: Int
    /// The part's structure id.
    public let structureID: String
    /// The mesh id.
    public let meshID: String
    /// The part's layer.
    public let layer: AnatomyLayer
    /// The mesh in its own space.
    public let mesh: Mesh
    /// The model matrix from mesh space to region space.
    public let model: Mat4
    /// The triangles in region space, three corners per triangle.
    public let worldTriangles: [Vec3]
    /// The lower corner of the world box (the mesh bounds' corners through the model matrix).
    public let worldMin: Vec3
    /// The upper corner of the world box.
    public let worldMax: Vec3

    /// The centre of the sphere around the world box.
    public var worldCenter: Vec3 { (worldMin + worldMax) * 0.5 }
    /// The radius of the sphere around the world box (its half diagonal).
    public var worldRadius: Double { (worldMax - worldMin).length * 0.5 }
    /// The number of triangles.
    public var triangleCount: Int { mesh.triangleCount }
}

/// The region scene at one quality level (see the file header).
public struct AnatomyScene: Sendable {
    /// The quality level the scene was built at.
    public let quality: AnatomyQuality
    /// The 14 parts in inventory order (the region's structures without the root).
    public let parts: [AnatomicalStructure]
    /// The drawn meshes, part by part in inventory order.
    public let items: [SceneItem]
    /// The centre of the sphere around every item's world box.
    public let regionCenter: Vec3
    /// The radius of the sphere around every item's world box.
    public let regionRadius: Double
    /// The SHA-256 digest over the item meshes (see the file header).
    public let digest: String
    /// The spheres of the parts, by part index.
    private let spheres: [(center: Vec3, radius: Double)]

    /// The triangles of every item.
    public var triangleCount: Int { items.reduce(0) { $0 + $1.triangleCount } }
    /// The draws: one per item.
    public var drawCount: Int { items.count }

    /// The sphere around the world boxes of part `index`'s items; a zero sphere at the region centre for an index out
    /// of range.
    public func structureSphere(_ index: Int) -> (center: Vec3, radius: Double) {
        spheres.indices.contains(index) ? spheres[index] : (regionCenter, 0)
    }

    /// The items whose part's layer is in `layers`, in item order.
    public func visibleItems(_ layers: Set<AnatomyLayer>) -> [SceneItem] {
        items.filter { layers.contains($0.layer) }
    }

    /// The index of the part with `id`, or nil.
    public func partIndex(_ id: String) -> Int? {
        parts.firstIndex { $0.id == id }
    }

    /// Builds the scene of `region` at `quality` from the bundled placements, or the first refusal.
    public static func build(_ region: AnatomyRegion, quality: AnatomyQuality) -> Result<AnatomyScene, SceneRefusal> {
        build(region, quality: quality, placement: AnatomyGeometry.placement(for:))
    }

    /// Builds the scene with `placement` resolving each mesh id (the test seam for a missing placement).
    static func build(_ region: AnatomyRegion, quality: AnatomyQuality,
                      placement: (String) -> MeshPlacement?) -> Result<AnatomyScene, SceneRefusal> {
        let parts = region.structures.filter { $0.parent != nil }
        let declared = Set(region.meshes.map(\.id))
        var resolved: [(index: Int, part: AnatomicalStructure, layer: AnatomyLayer, placement: MeshPlacement)] = []
        for (index, part) in parts.enumerated() {
            let layer = part.layer ?? .bones
            for meshID in part.meshIDs {
                guard declared.contains(meshID), let found = placement(meshID) else {
                    return .failure(SceneRefusal(.missingMesh, "The mesh \(meshID) has no schematic geometry."))
                }
                resolved.append((index, part, layer, found))
            }
        }
        if resolved.count > quality.maxDraws {
            return .failure(SceneRefusal(.overBudget,
                "The scene needs \(resolved.count) draws, more than the \(quality.maxDraws) of level \(quality.level)."))
        }
        var items: [SceneItem] = []
        var triangles = 0
        for entry in resolved {
            let mesh: Mesh
            do {
                mesh = try AnatomyGeometry.build(entry.placement, quality: quality)
            } catch {
                if case let .budget(_, indices, _) = error {
                    return .failure(SceneRefusal(.overBudget,
                        "The mesh \(entry.placement.meshID) needs \(indices / 3) triangles, more than the \(quality.maxTriangles) of level \(quality.level)."))
                }
                return .failure(SceneRefusal(.buildFailed,
                    "The mesh \(entry.placement.meshID) could not be built: \(describe(error))."))
            }
            triangles += mesh.triangleCount
            items.append(makeItem(entry.index, entry.part.id, entry.layer, entry.placement, mesh))
        }
        if triangles > quality.maxTriangles {
            return .failure(SceneRefusal(.overBudget,
                "The scene has \(triangles) triangles, more than the \(quality.maxTriangles) of level \(quality.level)."))
        }
        var spheres: [(center: Vec3, radius: Double)] = []
        for index in parts.indices {
            let own = items.filter { $0.structureIndex == index }
            spheres.append(sphere(around: own))
        }
        let region = sphere(around: items)
        let lines = items.map { "\($0.meshID):\($0.mesh.digest)" }.joined(separator: "\n")
        let digest = StableHash.sha256Hex(Array(lines.utf8))
        return .success(AnatomyScene(quality: quality, parts: parts, items: items, regionCenter: region.center,
                                     regionRadius: region.radius, digest: digest, spheres: spheres))
    }

    /// The item of `mesh` placed by `placement`, with its world triangles and world box.
    private static func makeItem(_ index: Int, _ structureID: String, _ layer: AnatomyLayer,
                                 _ placement: MeshPlacement, _ mesh: Mesh) -> SceneItem {
        let model = placement.model
        let world = mesh.positions.map { model.applyPoint($0) }
        var triangles: [Vec3] = []
        triangles.reserveCapacity(mesh.indices.count)
        for i in mesh.indices { triangles.append(world[Int(i)]) }
        var lo = Vec3(Double.infinity, Double.infinity, Double.infinity)
        var hi = Vec3(-Double.infinity, -Double.infinity, -Double.infinity)
        if case let .box(bmin, bmax) = mesh.bounds {
            for corner in 0..<8 {
                let p = Vec3(corner & 1 == 0 ? bmin.x : bmax.x, corner & 2 == 0 ? bmin.y : bmax.y,
                             corner & 4 == 0 ? bmin.z : bmax.z)
                let w = model.applyPoint(p)
                lo = Vec3(min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z))
                hi = Vec3(max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z))
            }
        } else {
            let origin = model.applyPoint(.zero)
            lo = origin
            hi = origin
        }
        return SceneItem(structureIndex: index, structureID: structureID, meshID: placement.meshID, layer: layer,
                         mesh: mesh, model: model, worldTriangles: triangles, worldMin: lo, worldMax: hi)
    }

    /// The sphere around the union of the items' world boxes (a zero sphere at the origin for no items).
    private static func sphere(around items: [SceneItem]) -> (center: Vec3, radius: Double) {
        guard let first = items.first else { return (.zero, 0) }
        var lo = first.worldMin, hi = first.worldMax
        for item in items.dropFirst() {
            lo = Vec3(min(lo.x, item.worldMin.x), min(lo.y, item.worldMin.y), min(lo.z, item.worldMin.z))
            hi = Vec3(max(hi.x, item.worldMax.x), max(hi.y, item.worldMax.y), max(hi.z, item.worldMax.z))
        }
        return ((lo + hi) * 0.5, (hi - lo).length * 0.5)
    }

    /// A short description of a generator error.
    private static func describe(_ error: MeshError) -> String {
        switch error {
        case let .budget(vertices, indices, budget):
            return "\(vertices) vertices and \(indices) indices exceed \(budget.maxVertices) and \(budget.maxIndices)"
        case let .invalidInput(text):
            return text
        }
    }
}
