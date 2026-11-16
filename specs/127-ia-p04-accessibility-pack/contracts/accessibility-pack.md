# Contract: A17-P04 (feature 127)

```swift
// VisualCoreMath (additive)
public enum AnchoredLabelLayout {
    public struct Candidate: Equatable, Sendable { public let id: Int; public let anchor: Vec3; public let size: Vec2; public let priority: Int }
    public struct Placement: Equatable, Sendable { public let id: Int; public let point: Vec2; public let minX, minY, maxX, maxY: Double }
    public static let offset = 6.0
    public static func place(_ candidates: [Candidate], camera: OrbitCamera, aspect: Double, canvas: Vec2, budget: Int) -> [Placement]
    public static func overlaps(_ a: Placement, _ b: Placement) -> Bool    // positive area only
}
// Core
public struct AnatomyLayerSign: Equatable, Sendable { static let all: [AnatomyLayerSign]; static func of(_ layer: AnatomyLayer) -> AnatomyLayerSign; let layer: AnatomyLayer; let sign: String; let words: String; let colorHex: String; var stateSign: StateSign }
public enum AnatomyLabels { static func candidates(scene: AnatomyScene, solid: Set<Int>, selected: Int?) -> [AnchoredLabelLayout.Candidate]; static func boxSize(_ text: String) -> Vec2 }
public enum AnatomyContentPack { static let kind = "a17.content-pack"; static let schemaVersion = 2; static let maxBytes = 262_144
    static func decode(_ data: Data) -> Result<AnatomyRegion, ContentRefusal>; static func encode(_ region: AnatomyRegion) -> Data; static func digest(_ region: AnatomyRegion) -> String }
public struct AnatomyProvenance: Equatable, Sendable { static func of(_ region: AnatomyRegion) -> AnatomyProvenance; var problems: [String] }
// Experience: drag/pinch/tap via AnatomyGestures; overlay labels; announcements "<name> selected." / "Selection cleared."; limit sentence "The camera is at its limit."
```
