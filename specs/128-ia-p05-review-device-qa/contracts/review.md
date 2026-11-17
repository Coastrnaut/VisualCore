# Contract: A17-P05 (feature 128)

```swift
public struct AnatomyReviewEntry: Codable, Equatable, Sendable { enum Kind: String { case editorial, clinical }; let part: String; let kind: Kind; let reviewer: String; let date: String; let method: String; let sources: [String] }
public struct AnatomyReviewRecord: Equatable, Sendable { static let kind = "a17.review-record"; static let schemaVersion = 1
    let contentVersion: Int; let entries: [AnatomyReviewEntry]
    static func decode(_ data: Data, region: AnatomyRegion) -> Result<AnatomyReviewRecord, ContentRefusal>
    static func bundled(for region: AnatomyRegion) -> Result<AnatomyReviewRecord, ContentRefusal> }
public enum AnatomyReview { static let modelStatement = "Schematic model for learning; shapes are simplified."
    static func lines(partID: String, record: AnatomyReviewRecord?) -> [String] }
extension AnatomyPanel { var modelStatement: String; var reviewLines: [String] }
// Experience: the About row identifier experience.a17.interactive-anatomy.about-model.
```
