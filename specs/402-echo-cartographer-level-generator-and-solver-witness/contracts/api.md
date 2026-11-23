# API contract: R02-G11-02 (additions to EchoCartographerCore)

```swift
extension EchoCartographerError { case generation(Int), witness(String) }   // r02-g11.generation, r02-g11.witness
public struct EchoCartographerManifestEntry: Sendable, Hashable, Codable { public let number: Int; public let seed: UInt64
    public let band: Int; public let energy: Int }
public enum EchoCartographerManifest { public static let entries: [EchoCartographerManifestEntry]   // 100, manifest order
    public static let provenance: String }
public struct EchoCartographerBandProfile: Sendable, Equatable { public let sizes: ClosedRange<Int>
    public let wallOneIn: Int; public let beacons: ClosedRange<Int>; public let tolerance: Int; public let missCost: Int
    public let pulses: ClosedRange<Int>; public static func of(band: Int) -> Self }
public struct EchoCartographerObservation: Sendable, Hashable, Codable { public let emitter: EchoCartographerCell
    public let echoes: [Int] }
public struct EchoCartographerPlan: Sendable, Equatable, Codable { public let pulses: [EchoCartographerCell]
    public let placements: [Int]; public let counterexample: [[EchoCartographerCell]]; public let work: Int }
public enum EchoCartographerSolver {
    public static let workBound: Int        // 400,000 enumeration nodes
    public static let placementCap: Int     // 1,000
    public static let maxPulses: Int        // 6
    public static func region(_ level: EchoCartographerLevel) -> [EchoCartographerCell]   // reachable open cells, not the entry, index order
    public static func fitting(_ level: EchoCartographerLevel, observations: [EchoCartographerObservation],
                               cap: Int, work: inout Int, collect: Int = 0) -> (count: Int, first: [[EchoCartographerCell]])
    public static func plan(_ level: EchoCartographerLevel, workBound: Int = workBound) -> EchoCartographerPlan?
    public static func actions(_ level: EchoCartographerLevel, plan: EchoCartographerPlan) -> [EchoCartographerAction]
    public static func wins(_ level: EchoCartographerLevel, actions: [EchoCartographerAction]) -> Bool }
public struct EchoCartographerDifficulty: Sendable, Hashable, Codable { public let pulses, width, height, region, beacons,
    tolerance, placementsBeforeLast, work: Int; public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct EchoCartographerGenerated: Sendable, Equatable { public let entry: EchoCartographerManifestEntry
    public let level: EchoCartographerLevel; public let plan: EchoCartographerPlan
    public let difficulty: EchoCartographerDifficulty; public let skipped: Int }
public enum EchoCartographerGenerator {
    public static let catalogID: String     // "echo-cartographer"
    public static let maxCandidates: Int    // 256
    public static let minimumRegion: Int    // 12
    public static func levelID(_ number: Int) -> String   // echo-cartographer-NNN
    public static func candidate(_ entry: EchoCartographerManifestEntry, index: Int) -> EchoCartographerLevel?
    public static func generate(_ entry: EchoCartographerManifestEntry) throws(EchoCartographerError) -> EchoCartographerGenerated
    public static func catalogDigest(_ levels: [EchoCartographerLevel]) -> String }
public struct EchoCartographerWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static func digest(_ echo: EchoCartographerEcho) -> String   // first 16 hex of SHA-256 of the canonical echo
    public static func make(_ generated: EchoCartographerGenerated) throws(EchoCartographerError) -> Self
    public static func decode(_ data: Data) throws(EchoCartographerError) -> Self; public func encoded() -> Data }
```
