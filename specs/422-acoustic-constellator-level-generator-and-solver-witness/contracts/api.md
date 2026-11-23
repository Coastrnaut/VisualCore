# API contract: R02-G13-02 (additions to AcousticConstellatorCore)

```swift
extension AcousticConstellatorError { case generation(Int), witness(String) }   // r02-g13.generation, r02-g13.witness
public struct AcousticConstellatorManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let seed: UInt64; public let band: Int; public let budget: Int }
public enum AcousticConstellatorManifest { public static let entries: [AcousticConstellatorManifestEntry]   // 100
    public static let provenance: String }
public struct AcousticConstellatorBandProfile: Sendable, Equatable { public let stars: ClosedRange<Int>
    public let missing: ClosedRange<Int>; public let window: Int; public let planRange: ClosedRange<Int>
    public let cycle: Bool; public static func of(band: Int) -> Self }
public struct AcousticConstellatorNudge: Sendable, Hashable, Codable { public let star: Int; public let step: Int }
public struct AcousticConstellatorPlan: Sendable, Equatable, Codable { public let links: [AcousticConstellatorLink]
    public let nudges: [AcousticConstellatorNudge]; public let smallerSets: Int; public let work: Int
    public var size: Int { get } }
public enum AcousticConstellatorSolver {
    public static let workBound: Int        // 400,000 listens
    public static let maxActions: Int       // 6
    public static func plan(_ level: AcousticConstellatorLevel, maxActions: Int = maxActions,
                            workBound: Int = workBound) -> AcousticConstellatorPlan?
    public static func actions(_ plan: AcousticConstellatorPlan) -> [AcousticConstellatorAction]   // links, nudges, listen
    public static func wins(_ level: AcousticConstellatorLevel, actions: [AcousticConstellatorAction]) -> Bool }
public struct AcousticConstellatorDifficulty: Sendable, Hashable, Codable { public let actions, stars, symbolPairs,
    cycles, fixedLinks, rateSpread, window, hold, threshold, smallerSets, work: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct AcousticConstellatorGenerated: Sendable, Equatable { public let entry: AcousticConstellatorManifestEntry
    public let level: AcousticConstellatorLevel; public let plan: AcousticConstellatorPlan
    public let difficulty: AcousticConstellatorDifficulty; public let skipped: Int }
public enum AcousticConstellatorGenerator {
    public static let catalogID: String     // "acoustic-constellator"
    public static let maxCandidates: Int    // 256
    public static func levelID(_ number: Int) -> String   // acoustic-constellator-NNN
    public static func candidate(_ entry: AcousticConstellatorManifestEntry, index: Int) -> AcousticConstellatorLevel?
    public static func generate(_ entry: AcousticConstellatorManifestEntry) throws(AcousticConstellatorError) -> AcousticConstellatorGenerated
    public static func catalogDigest(_ levels: [AcousticConstellatorLevel]) -> String }
public struct AcousticConstellatorWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static func digest(links: [AcousticConstellatorLink], phases: [Int]) -> String   // first 16 hex of SHA-256
    public static func make(_ generated: AcousticConstellatorGenerated) throws(AcousticConstellatorError) -> Self
    public static func decode(_ data: Data) throws(AcousticConstellatorError) -> Self; public func encoded() -> Data }
```
