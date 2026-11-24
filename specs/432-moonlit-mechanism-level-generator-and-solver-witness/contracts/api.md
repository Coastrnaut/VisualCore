# API contract: R02-G14-02 (additions to MoonlitMechanismCore)

```swift
extension MoonlitMechanismError { case generation(Int), witness(String) }   // r02-g14.generation, r02-g14.witness
public struct MoonlitMechanismManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let seed: UInt64; public let band: Int; public let budget: Int }
public enum MoonlitMechanismManifest { public static let entries: [MoonlitMechanismManifestEntry]   // 100
    public static let provenance: String }
public struct MoonlitMechanismBandProfile: Sendable, Equatable { public let gears: ClosedRange<Int>
    public let lampHeights: ClosedRange<Int>; public let keyFrames: ClosedRange<Int>; public let scramble: ClosedRange<Int>
    public let planRange: ClosedRange<Int>; public static func of(band: Int) -> Self }
public struct MoonlitMechanismPlan: Sendable, Equatable, Codable { public let turns: Int; public let lamp: Int
    public let reseats: [Int]; public let smallerVectors: Int; public let work: Int
    public var size: Int { get } }
public enum MoonlitMechanismSolver {
    public static let workBound: Int        // 400,000 runs
    public static let maxActions: Int       // 6
    public static func plan(_ level: MoonlitMechanismLevel, maxActions: Int = maxActions,
                            workBound: Int = workBound) -> MoonlitMechanismPlan?
    public static func actions(_ plan: MoonlitMechanismPlan) -> [MoonlitMechanismAction]   // turns, re-seats, lamp, run
    public static func wins(_ level: MoonlitMechanismLevel, actions: [MoonlitMechanismAction]) -> Bool }
public struct MoonlitMechanismDifficulty: Sendable, Hashable, Codable { public let actions, gears, meshes, teeth,
    keyFrames, requiredKeyFrames, targetCells, forbiddenCells, lampHeights, smallerVectors, work: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct MoonlitMechanismGenerated: Sendable, Equatable { public let entry: MoonlitMechanismManifestEntry
    public let level: MoonlitMechanismLevel; public let plan: MoonlitMechanismPlan
    public let difficulty: MoonlitMechanismDifficulty; public let skipped: Int }
public enum MoonlitMechanismGenerator {
    public static let catalogID: String     // "moonlit-mechanism"
    public static let maxCandidates: Int    // 256
    public static func levelID(_ number: Int) -> String   // moonlit-mechanism-NNN
    public static func candidate(_ entry: MoonlitMechanismManifestEntry, index: Int) -> MoonlitMechanismLevel?
    public static func generate(_ entry: MoonlitMechanismManifestEntry) throws(MoonlitMechanismError) -> MoonlitMechanismGenerated
    public static func catalogDigest(_ levels: [MoonlitMechanismLevel]) -> String }
public struct MoonlitMechanismCounterexample: Sendable, Hashable, Codable {
    public let norm: Int      // plan.size − 1
    public let vectors: Int   // vectors of exactly that norm the solver tried (all of them; none won)
    public init(norm: Int, vectors: Int) }
public struct MoonlitMechanismWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static let schema: Int                                          // 1
    public static func canonicalText(phases: [Int], height: Int) -> String   // "phases=3,0,11;height=2"
    public static func digest(phases: [Int], height: Int) -> String   // first 16 hex of SHA-256 of canonicalText
    public static func vectors(dimensions: Int, norm: Int) -> Int     // Σₖ 2ᵏ·C(d,k)·C(c−1,k−1); 1 at norm 0
    public static func make(_ generated: MoonlitMechanismGenerated) throws(MoonlitMechanismError) -> Self
    public static func decode(_ data: Data) throws(MoonlitMechanismError) -> Self; public func encoded() -> Data }
```
