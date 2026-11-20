# API contract: R02-G01-03

```swift
// AuroraLoomCore (host)
public struct AuroraLoomPalette { public static let night, teal, magenta, gold: SIMD3<Double> }
public struct AuroraLoomTier: Sendable, Equatable { public let index: Int; public let layers: Int; public let segments: Int; public let glowPasses: Int
    public static let all: [AuroraLoomTier]; public var name: String /* level-N */ }
public struct AuroraLoomSceneSnapshot: Sendable, Equatable {
    public let level: AuroraLoomLevel; public let steps: AuroraLoomSteps; public let stage: AuroraLoomStage
    public let failure: AuroraLoomMismatch?; public let time: Double
    public init(play: AuroraLoomPlay, time: Double)
    public func lit(ribbon: Int, gate: Int) -> Bool            // residual within tolerance at the snapshot tick
}
public enum AuroraLoomSceneGeometry {
    public static func centreLine(ribbon: Int, snapshot: AuroraLoomSceneSnapshot, segments: Int) -> [Vec3]
    public static func ribbonMeshes(snapshot: AuroraLoomSceneSnapshot, tier: AuroraLoomTier) throws(MeshError) -> [Mesh]
    public static func gateRing(gate: Int, snapshot: AuroraLoomSceneSnapshot) -> [Vec3]
    public static func marker(gate: Int, snapshot: AuroraLoomSceneSnapshot) -> Vec3
    public static func camera(aspect: Double) -> (view: Mat4, projection: Mat4)
    public static func project(_ point: Vec3, aspect: Double, width: Int, height: Int) -> (x: Double, y: Double)?
}
public enum AuroraLoomShaders { public static let ribbonVertex, ribbonFragment, gateVertex, gateFragment: String
    public static let ribbonUniforms, gateUniforms: [String] }
public struct AuroraLoomExperienceCore: ExperienceCore, Equatable { experienceID "r02-g01.aurora-loom"; schemaVersion 1;
    qualityTiers 3; qualityProfile level-0 … level-2; controls; prepare(seed:); apply(_:); writeDigest(into:);
    snapshotPayload(); restore(payload:seed:); public var snapshot: AuroraLoomSceneSnapshot }
// AuroraLoomExperience (iOS)
public enum AuroraLoomExperience { public static let id: ExperienceID?
    @MainActor public static func make(id:storage:reduceMotion:reduceFlashing:) -> any Experience }
```
(Exact math types — `Vec3`, `Mat4`, `MeshError`, `Mesh` — are VisualCoreMath/VisualCoreScenes names; agents confirm them
before writing.)
