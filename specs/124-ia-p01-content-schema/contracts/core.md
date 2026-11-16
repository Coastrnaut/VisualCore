# Contract: InteractiveAnatomyCore (feature 124)

```swift
public struct AnatomyRegion: Codable, Equatable, Sendable { static let schemaVersion = 1; let id: String; … }
public struct AnatomicalStructure: Codable, Equatable, Sendable, Identifiable { … }
public enum AnatomyLayer: String, Codable, CaseIterable, Sendable { case bones, cartilage, ligaments }
public struct ProceduralMeshDeclaration: Codable, Equatable, Sendable { let id: String; let kind: Kind }
public struct ContentManifest: Codable, Equatable, Sendable { …; var reviewSentence: String }
public struct AnatomyLabel: Equatable, Sendable { let structureID: String; let text: String; let anchorMeshID: String }
public struct ContentRefusal: Error, Equatable, Sendable { let reason: Reason; let sentence: String }
public enum AnatomyContent {
    static let maxBytes = 262_144
    static func decode(_ data: Data) -> Result<AnatomyRegion, ContentRefusal>   // decode + validate
    static func validate(_ region: AnatomyRegion) -> ContentRefusal?
    static func labels(_ region: AnatomyRegion) -> [AnatomyLabel]
    static func bundledRightKnee() throws -> AnatomyRegion                       // Bundle.module resource
    static func encoded(_ region: AnatomyRegion) -> Data                         // sorted keys
}
```
