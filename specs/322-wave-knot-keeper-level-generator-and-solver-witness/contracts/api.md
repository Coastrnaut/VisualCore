# API contract: R02-G03-02 (WaveKnotKeeperCore additions)

```swift
extension WaveKnotKeeperError { case generation(Int) /* r02-g03.generation */; case witness(String) /* r02-g03.witness */ }
public struct WaveKnotKeeperManifestEntry: Sendable, Equatable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum WaveKnotKeeperManifest { public static let entries: [WaveKnotKeeperManifestEntry] }   // 100
public struct WaveKnotKeeperCrossingExample: Sendable, Equatable, Codable { public let points: [WaveKnotKeeperPoint]
    public let move: WaveKnotKeeperMove }
public struct WaveKnotKeeperSolution: Sendable, Equatable { public let shortest: Int
    public let moves: [WaveKnotKeeperMove]; public let final: [WaveKnotKeeperPoint]; public let work: Int
    public let crossing: WaveKnotKeeperCrossingExample? }
public enum WaveKnotKeeperSolver {
    public static let maximumDepth = 3
    public static func solve(_ level: WaveKnotKeeperLevel, depth: Int = maximumDepth) -> WaveKnotKeeperSolution?   // nil: none within depth
}
public struct WaveKnotKeeperDifficulty: Sendable, Equatable, Codable { public let shortest: Int; public let points: Int
    public let gates: Int; public let crossings: Int; public let work: Int }
public struct WaveKnotKeeperBandProfile: Sendable, Equatable { public static func of(band: Int) -> Self }
public struct WaveKnotKeeperGenerated: Sendable, Equatable { public let entry: WaveKnotKeeperManifestEntry
    public let level: WaveKnotKeeperLevel; public let solution: WaveKnotKeeperSolution
    public let difficulty: WaveKnotKeeperDifficulty; public let skipped: Int }
public enum WaveKnotKeeperGenerator {
    public static let tutorialLevels: ClosedRange<Int>   // 1 … 3
    public static func generate(_ entry: WaveKnotKeeperManifestEntry) throws(WaveKnotKeeperError) -> WaveKnotKeeperGenerated
    public static func catalogDigest(_ levels: [WaveKnotKeeperLevel]) -> String
}
public struct WaveKnotKeeperWitness: Sendable, Equatable, Codable {
    public static let schema = 1
    public static func make(_ generated: WaveKnotKeeperGenerated) throws(WaveKnotKeeperError) -> Self
    public func encoded() -> Data
    public static func decode(_ data: Data) throws(WaveKnotKeeperError) -> Self   // refuses newer, damaged, non-replaying
}
```
