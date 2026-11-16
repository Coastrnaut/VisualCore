# Contract: A17-P03 (feature 126)

```swift
// VisualCoreRendering (additive)
extension DepthMeshPass.Item { public var center: Vec3 }  // init(renderer:model:color:center: = .zero)
extension DepthMeshPass {
    public func draw(_ opaque: [Item], translucent: [Item], view: Mat4, projection: Mat4, fog: MeshFog?, context: RenderContext) throws
    public func draw(_ opaque: [Item], translucent: [Item], camera: OrbitCamera, context: RenderContext) throws
}
// Core
public enum AnatomySearch { struct Result: Equatable { let index: Int; let rank: Int; let matched: String }
    static func results(_ query: String, region: AnatomyRegion) -> [Result] }
public struct AnatomyPanel: Equatable { static func make(partIndex: Int?, region: AnatomyRegion) -> AnatomyPanel
    let heading: String; let standardName: String?; let layerWords: String?; let description: String?; let citations: [String]; let reviewSentence: String }
public struct AnatomyIsolate: Codable, Equatable, Sendable { enum Target { case part(Int), layer(AnatomyLayer) }; enum Mode: String { case ghost, hide } }
extension AnatomyViewState { static let schemaVersion = 2; var isolate: AnatomyIsolate?
    func solidParts(parts:) -> Set<Int>; func ghostParts(parts:) -> Set<Int>; static let migrations: MigrationChain
    static func decode(_ data: Data, parts: [String]) -> (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) }
public enum AnatomyViewDocument { static let fileName = "view.json"; static let kind = "a17.view"; static let maxBytes = 65_536
    static func encode(_ view: AnatomyViewState) -> Data; static func decode(_ data: Data, parts: [String]) -> (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) }
// Experience actions: isolate.part [0…13], isolate.layer [0…2], isolate.mode [0/1], isolate.clear; search results send structure.select.
// Controls identifiers: search-field, search-result-<i>, panel, isolate-part, isolate-layer-<l>, isolate-mode, show-all.
```
