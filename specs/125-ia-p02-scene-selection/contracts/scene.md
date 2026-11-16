# Contract: InteractiveAnatomy scene, picker, camera and experience (feature 125)

```swift
// Core (InteractiveAnatomyCore; pure)
public struct AnatomyQuality: Equatable, Sendable { static let levels: [AnatomyQuality]; let level: Int; let segments: Int; let tubeSides: Int; let sphereSegments: Int; let sphereRings: Int; let maxTriangles: Int; let maxDraws: Int; let maxLabels: Int }
public struct SceneRefusal: Error, Equatable, Sendable { enum Reason: String { case overBudget = "over-budget", missingMesh = "missing-mesh", buildFailed = "build-failed" }; let reason: Reason; let sentence: String }
public struct SceneItem: Sendable { let structureIndex: Int; let structureID: String; let meshID: String; let layer: AnatomyLayer; let mesh: Mesh; let model: Mat4; let worldCenter: Vec3; let worldRadius: Double }
public struct AnatomyScene: Sendable {
    static func build(_ region: AnatomyRegion, quality: AnatomyQuality) -> Result<AnatomyScene, SceneRefusal>
    let quality: AnatomyQuality; let items: [SceneItem]; let parts: [AnatomicalStructure]   // the 14 parts in order
    let regionCenter: Vec3; let regionRadius: Double; var triangleCount: Int; var drawCount: Int
    func structureSphere(_ index: Int) -> (center: Vec3, radius: Double)
    func visibleItems(_ layers: Set<AnatomyLayer>) -> [SceneItem]
    var digest: String                                                                      // over the item meshes' digests
}
public enum AnatomyPicker { static func pick(origin: Vec3, direction: Vec3, scene: AnatomyScene, visible: Set<AnatomyLayer>) -> (index: Int, distance: Double)?
                            static func pick(ndc: Vec2, camera: OrbitCamera, aspect: Double, scene: AnatomyScene, visible: Set<AnatomyLayer>) -> (index: Int, distance: Double)? }
public struct AnatomyCameraState: Codable, Equatable, Sendable { var turn: Int; var tilt: Int; var zoom: Int; static let opening
    mutating func turn(_ d: Int) -> Bool; mutating func tilt(_ d: Int) -> Bool; mutating func zoom(_ d: Int) -> Bool
    func camera(center: Vec3, radius: Double, aspect: Double) -> OrbitCamera }              // fovY 60°, fit r × 1.25 / sin(30°) on the narrower axis
public struct AnatomyViewState: Codable, Equatable, Sendable { static let schemaVersion = 1; var camera: AnatomyCameraState; var visibleLayers: [Bool]; var selection: String?; var framed: String?
    func encoded() -> Data; static func decode(_ data: Data, parts: [String]) -> Result<AnatomyViewState, ContentRefusal> }

// Experience (InteractiveAnatomyExperience)
// Actions: structure.select [0…13], structure.clear, layer.show [0…2, 0/1], camera.turn [-1/+1], camera.tilt [-1/+1],
//          camera.zoom [-1/+1], view.reset. Rules: a17.camera-limit, a17.hidden-structure, a17.invalid-choice.
// Controls identifiers experience.a17.interactive-anatomy.<name>: layer-bones, layer-cartilage, layer-ligaments,
//   structure-<i> (14 list rows), turn-left, turn-right, tilt-up, tilt-down, zoom-in, zoom-out, reset-view.
// Canvas description: "Right knee, <shown layers in words or 'no layer shown'>; selected: <English name> or 'nothing selected'".
public enum InteractiveAnatomyExperience { static func make(id:storage:reduceMotion:reduceFlashing:) -> any Experience }
```
