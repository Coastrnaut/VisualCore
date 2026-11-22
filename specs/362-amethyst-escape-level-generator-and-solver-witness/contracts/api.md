# API contract: R02-G07-02 (additions to AmethystEscapeCore)

```swift
extension AmethystEscapeError { case generation(Int), witness(String) }   // r02-g07.generation, r02-g07.witness
public struct AmethystEscapeManifestEntry: Sendable, Hashable, Codable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum AmethystEscapeManifest { public static let entries: [AmethystEscapeManifestEntry]   // 100, manifest order
    public static let provenance: String }
public struct AmethystEscapeBandProfile: Sendable, Equatable { public let sectors, shells: Int
    public let smallest: ClosedRange<Int>; public static func of(band: Int) -> Self }
public struct AmethystEscapeSolution: Sendable, Equatable, Codable { public let smallest: Int
    public let actions: [AmethystEscapeAction]; public let depths: [Int]; public let work: Int }
public enum AmethystEscapeSolver {
    public static func stateCount(_ level: AmethystEscapeLevel) -> Int               // N^K × K × N
    public static func encode(_ crystal: AmethystEscapeCrystal, level: AmethystEscapeLevel) -> Int
    public static func decode(_ state: Int, level: AmethystEscapeLevel) -> AmethystEscapeCrystal
    public static func escapesByAdvancing(_ level: AmethystEscapeLevel) -> Bool       // advances alone
    public static func solve(_ level: AmethystEscapeLevel) -> AmethystEscapeSolution? }  // nil when no escape exists
public struct AmethystEscapeDifficulty: Sendable, Hashable, Codable { public let smallest, turns, advances, shells, sectors, explored: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }   // shortest = smallest, explored = explored (R02-F24)
public struct AmethystEscapeGenerated: Sendable, Equatable { public let entry: AmethystEscapeManifestEntry
    public let level: AmethystEscapeLevel; public let solution: AmethystEscapeSolution
    public let difficulty: AmethystEscapeDifficulty; public let skipped: Int }
public enum AmethystEscapeGenerator {
    public static let catalogID: String    // "amethyst-escape"
    public static let maxCandidates: Int   // 512
    public static func levelID(_ number: Int) -> String   // amethyst-escape-NNN
    public static func candidate(_ entry: AmethystEscapeManifestEntry, index: Int) -> AmethystEscapeLevel?
    public static func generate(_ entry: AmethystEscapeManifestEntry) throws(AmethystEscapeError) -> AmethystEscapeGenerated
    public static func catalogDigest(_ levels: [AmethystEscapeLevel]) -> String }
public struct AmethystEscapeCounterexample: Sendable, Equatable, Codable { public let actions: [AmethystEscapeAction]
    public let outcome: String; public let move: Int }   // "stuck", "wedge", "budget" or "open" (not escaped yet)
public struct AmethystEscapeWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static func digest(_ crystal: AmethystEscapeCrystal) -> String   // first 16 hex of SHA-256 of offsets and pearl
    public static func make(_ generated: AmethystEscapeGenerated) throws(AmethystEscapeError) -> Self
    public static func decode(_ data: Data) throws(AmethystEscapeError) -> Self; public func encoded() -> Data }
```
