# Contract: A07-P04 additions

```swift
// module AudioOdysseyCore
public struct JourneyPreset: Equatable, Sendable {
  public static let format: Int; public static let nameLimit: Int        // 1, 60
  public static let builtIns: [JourneyPreset]
  public let id: UUID; public let name: String; public let saved: Date; public let isBuiltIn: Bool
  public let world: JourneyWorld; public let mappings: [WorldMapping]; public let speedTarget: Double
  public let easing: Easing; public let calmMotion: Bool
  public init?(id:name:saved:world:mappings:speedTarget:easing:calmMotion:isBuiltIn: = false)
  public init(from state: JourneyState, id: UUID, name: String, saved: Date)
  public var actionValues: [Double]                                     // 16 values for preset.apply
  public func fileData() throws -> Data
  public static func decode(_ data: Data, fileID: UUID) throws(FileError) -> JourneyPreset
  public enum FileError: Error, Equatable { case newer(Int), malformed }
  public static func clean(_ name: String) -> String
  public static func uniqueName(_ name: String, among: [String]) -> String
  public static func fileName(for id: UUID) -> String; public static func id(fromFileName: String) -> UUID?
}
public enum DemoResponseTrace {
  public static func run(bandFrames: [[Float]], flux: [Float], onsets: [Bool], world: JourneyWorld,
                         mapping: WorldMapping, step: Double) -> [(primary: Double, light: Double)]
}
// module AudioOdysseyExperience (internal)
@MainActor final class JourneyPresetStore { init(storage: ExperienceStorage); entries; unreadable; newer; lastMessage;
  save(name:from:now:) -> JourneyPreset?; rename(_:to:) -> Bool; delete(_:) -> Bool; preset(_:); reload() }
```
