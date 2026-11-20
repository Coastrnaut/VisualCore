# API contract: R02-G02-02 (LissajousLabyrinthCore additions)

```swift
extension LissajousLabyrinthError { case generation(Int) /* r02-g02.generation */; case witness(String) /* r02-g02.witness */ }
public struct LissajousLabyrinthManifestEntry: Sendable, Equatable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum LissajousLabyrinthManifest { public static let entries: [LissajousLabyrinthManifestEntry] }   // 100
public struct LissajousLabyrinthSolution: Sendable, Equatable { public let shortest: Int
    public let actions: [LissajousLabyrinthAction]; public let setting: LissajousLabyrinthDials
    public let winningSettings: Int; public let work: Int }
public enum LissajousLabyrinthSolver {
    public static func legalSettings() -> [LissajousLabyrinthDials]                 // 14,080, ordered (a, b, φ, ψ)
    public static func winningSettings(_ level: LissajousLabyrinthLevel) -> (settings: [LissajousLabyrinthDials], work: Int)
    public static func solve(_ level: LissajousLabyrinthLevel) -> LissajousLabyrinthSolution?   // nil: no winner
}
public struct LissajousLabyrinthDifficulty: Sendable, Equatable, Codable { public let shortest: Int
    public let winningSettings: Int; public let clearance: Int; public let work: Int
    public static func clearance(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel) -> Int }
public struct LissajousLabyrinthBandProfile: Sendable, Equatable { public static func of(band: Int) -> Self }
public struct LissajousLabyrinthGenerated: Sendable, Equatable { public let entry: LissajousLabyrinthManifestEntry
    public let level: LissajousLabyrinthLevel; public let solution: LissajousLabyrinthSolution
    public let difficulty: LissajousLabyrinthDifficulty; public let skipped: Int }
public enum LissajousLabyrinthGenerator {
    public static let tutorialLevels: ClosedRange<Int>   // 1 … 3
    public static func generate(_ entry: LissajousLabyrinthManifestEntry) throws(LissajousLabyrinthError) -> LissajousLabyrinthGenerated
    public static func catalogDigest(_ levels: [LissajousLabyrinthLevel]) -> String
}
public struct LissajousLabyrinthWitness: Sendable, Equatable, Codable {
    public static let schema = 1
    public static func make(_ generated: LissajousLabyrinthGenerated) throws(LissajousLabyrinthError) -> Self
    public func encoded() -> Data
    public static func decode(_ data: Data) throws(LissajousLabyrinthError) -> Self   // refuses newer, damaged, non-replaying
}
```
