# API contract: R02-G17-02 (additions to CelestialEclipseLabCore)

```swift
extension CelestialEclipseLabError { case generation(Int), witness(String) }   // r02-g17.generation, r02-g17.witness
public struct CelestialEclipseLabManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let seed: UInt64; public let band: Int; public let budget: Int; public let emphasis: String }
public enum CelestialEclipseLabManifest { public static let entries: [CelestialEclipseLabManifestEntry]   // 100
    public static let provenance: String }
public struct CelestialEclipseLabBandProfile: Sendable, Equatable { public let bodies: ClosedRange<Int>
    public let targets: ClosedRange<Int>; public let horizon: ClosedRange<Int>; public let moved: Int
    public let planRange: ClosedRange<Int>; public static func of(band: Int) -> Self }
public struct CelestialEclipseLabPlan: Sendable, Equatable, Codable { public let actions: [CelestialEclipseLabAction]
    public let settingsByDepth: [Int]   // settings judged at depths 0 … size − 1 (depth 0 is the start: 1)
    public let work: Int; public var size: Int { get } }
public enum CelestialEclipseLabSolver {
    public static let workBound: Int        // 60 000 settings judged
    public static let maxChanges: Int       // 5
    public static func plan(_ level: CelestialEclipseLabLevel, maxChanges: Int = maxChanges,
                            workBound: Int = workBound) -> CelestialEclipseLabPlan?
    public static func wins(_ level: CelestialEclipseLabLevel, actions: [CelestialEclipseLabAction]) -> Bool }
public struct CelestialEclipseLabDifficulty: Sendable, Hashable, Codable { public let changes, bodies, movable,
    targets, events, settingsSearched, work: Int; public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct CelestialEclipseLabGenerated: Sendable, Equatable { public let entry: CelestialEclipseLabManifestEntry
    public let level: CelestialEclipseLabLevel; public let plan: CelestialEclipseLabPlan
    public let difficulty: CelestialEclipseLabDifficulty; public let skipped: Int }
public enum CelestialEclipseLabGenerator {
    public static let catalogID: String     // "celestial-eclipse-lab"
    public static let maxCandidates: Int    // 256
    public static func levelID(_ number: Int) -> String   // celestial-eclipse-lab-NNN
    public static func candidate(_ entry: CelestialEclipseLabManifestEntry, index: Int) -> CelestialEclipseLabLevel?
    public static func generate(_ entry: CelestialEclipseLabManifestEntry, previous: CelestialEclipseLabLevel?)
        throws(CelestialEclipseLabError) -> CelestialEclipseLabGenerated
    public static func catalog() throws(CelestialEclipseLabError) -> [CelestialEclipseLabGenerated]   // manifest order
    public static func catalogDigest(_ levels: [CelestialEclipseLabLevel]) -> String }
public struct CelestialEclipseLabCounterexample: Sendable, Hashable, Codable {
    public let depth: Int       // plan.size − 1
    public let settings: Int    // settings judged at exactly that depth (none won)
    public init(depth: Int, settings: Int) }
public struct CelestialEclipseLabWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static let schema: Int                                          // 1
    public static func canonicalText(phases: [Int], spent: Int) -> String  // "phases=0,3,5;spent=2"
    public static func digest(phases: [Int], spent: Int) -> String         // first 16 hex of SHA-256
    public static func make(_ generated: CelestialEclipseLabGenerated) throws(CelestialEclipseLabError) -> Self
    public static func decode(_ data: Data) throws(CelestialEclipseLabError) -> Self; public func encoded() -> Data }
```
