# API contract: R02-G12-02 (additions to HarmonicBridgesCore)

```swift
extension HarmonicBridgesError { case generation(Int), witness(String) }   // r02-g12.generation, r02-g12.witness
public struct HarmonicBridgesManifestEntry: Sendable, Hashable, Codable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum HarmonicBridgesManifest { public static let entries: [HarmonicBridgesManifestEntry]   // 100, manifest order
    public static let provenance: String }
public struct HarmonicBridgesBandProfile: Sendable, Equatable { public let scrambled: ClosedRange<Int>
    public let steps: ClosedRange<Int>; public let tones: ClosedRange<Int>; public let thresholds: ClosedRange<Int>
    public let decoys: ClosedRange<Int>; public static func of(band: Int) -> Self }
public struct HarmonicBridgesPlan: Sendable, Equatable, Codable { public let tunings: [HarmonicBridgesTuning]
    public let smallerChoices: Int; public let work: Int }
public struct HarmonicBridgesTuning: Sendable, Hashable, Codable { public let string: Int; public let peg: Int }
public enum HarmonicBridgesSolver {
    public static let workBound: Int        // 400,000 choices
    public static let maxTunings: Int       // 6
    public static func pattern(_ level: HarmonicBridgesLevel, string: Int, peg: Int) -> [Bool]   // per step
    public static func options(_ level: HarmonicBridgesLevel, string: Int) -> [HarmonicBridgesTuning]
    public static func plan(_ level: HarmonicBridgesLevel, workBound: Int = workBound) -> HarmonicBridgesPlan?
    public static func actions(_ plan: HarmonicBridgesPlan) -> [HarmonicBridgesAction]   // tunings, then test
    public static func wins(_ level: HarmonicBridgesLevel, actions: [HarmonicBridgesAction]) -> Bool }
public struct HarmonicBridgesDifficulty: Sendable, Hashable, Codable { public let tunings, islands, strings, locked,
    steps, tones, threshold, smallerChoices, work: Int; public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct HarmonicBridgesGenerated: Sendable, Equatable { public let entry: HarmonicBridgesManifestEntry
    public let level: HarmonicBridgesLevel; public let plan: HarmonicBridgesPlan
    public let difficulty: HarmonicBridgesDifficulty; public let skipped: Int }
public enum HarmonicBridgesGenerator {
    public static let catalogID: String     // "harmonic-bridges"
    public static let maxCandidates: Int    // 256
    public static let frequencies: [Int]    // 6, 12, 18, 24, 30, 36, 48, 60, 72
    public static func levelID(_ number: Int) -> String   // harmonic-bridges-NNN
    public static func candidate(_ entry: HarmonicBridgesManifestEntry, index: Int) -> HarmonicBridgesLevel?
    public static func generate(_ entry: HarmonicBridgesManifestEntry) throws(HarmonicBridgesError) -> HarmonicBridgesGenerated
    public static func catalogDigest(_ levels: [HarmonicBridgesLevel]) -> String }
public struct HarmonicBridgesWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static func digest(_ report: HarmonicBridgesReport) -> String   // first 16 hex of SHA-256 of the bridges per step
    public static func make(_ generated: HarmonicBridgesGenerated) throws(HarmonicBridgesError) -> Self
    public static func decode(_ data: Data) throws(HarmonicBridgesError) -> Self; public func encoded() -> Data }
```
