// AnatomyQuality — feature 125 (A17-P02) T-A17-202 (FR-A17-201, FR-A17-209; clarification Q1; data-model
// "AnatomyQuality"; contracts/scene.md). The two quality levels of the region scene:
// - level 0 (full): revolutions with 48 segments, tubes with 16 sides, spheres 32 × 16; at most 60,000 triangles;
// - level 1 (reduced): 24 segments, 8 sides, 16 × 8; at most 20,000 triangles.
// At both levels at most 32 draws (one per mesh) and 16 labels. The per-mesh `MeshBudget` is the level's triangle
// budget: 3 indices per triangle, and as many vertices as indices.
import Foundation
import VisualCoreScenes

/// One quality level of the region scene: segment counts and budgets.
public struct AnatomyQuality: Equatable, Sendable {
    /// The two levels, full (0) then reduced (1); their count equals the experience's quality tiers.
    public static let levels: [AnatomyQuality] = [
        AnatomyQuality(level: 0, segments: 48, tubeSides: 16, sphereSegments: 32, sphereRings: 16,
                       maxTriangles: 60_000, maxDraws: 32, maxLabels: 16),
        AnatomyQuality(level: 1, segments: 24, tubeSides: 8, sphereSegments: 16, sphereRings: 8,
                       maxTriangles: 20_000, maxDraws: 32, maxLabels: 16),
    ]

    /// The level number, 0 (full) or 1 (reduced).
    public let level: Int
    /// The segments around a solid of revolution.
    public let segments: Int
    /// The sides of a tube.
    public let tubeSides: Int
    /// The segments around a sphere.
    public let sphereSegments: Int
    /// The rings of a sphere, pole to pole.
    public let sphereRings: Int
    /// The most triangles the whole scene may hold.
    public let maxTriangles: Int
    /// The most draws (meshes) the scene may hold.
    public let maxDraws: Int
    /// The most labels the scene may show.
    public let maxLabels: Int

    /// Creates a quality level.
    public init(level: Int, segments: Int, tubeSides: Int, sphereSegments: Int, sphereRings: Int, maxTriangles: Int,
                maxDraws: Int, maxLabels: Int) {
        self.level = level
        self.segments = segments
        self.tubeSides = tubeSides
        self.sphereSegments = sphereSegments
        self.sphereRings = sphereRings
        self.maxTriangles = maxTriangles
        self.maxDraws = maxDraws
        self.maxLabels = maxLabels
    }

    /// The budget of one mesh at this level: the level's triangles as indices, and as many vertices.
    public var meshBudget: MeshBudget {
        MeshBudget(maxVertices: 3 * maxTriangles, maxIndices: 3 * maxTriangles)
    }
}
