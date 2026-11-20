# API contract: R02-G01-02 (additions to AuroraLoomCore)

```swift
extension AuroraLoomError { case generation(Int) /* r02-g01.generation */; case witness(String) /* r02-g01.witness */ }

public struct AuroraLoomManifestEntry: Sendable, Equatable, Codable { public let number: Int; public let seed: UInt64; public let band: Int; public let budget: Int }
public enum AuroraLoomManifest { public static let entries: [AuroraLoomManifestEntry]  /* 100 */ ; public static let source: String }

public enum AuroraLoomSolveMethod: String, Sendable, Codable { case descent, grid }
public struct AuroraLoomSolution: Sendable, Equatable {
    public let shortest: Int; public let moves: [AuroraLoomMove]; public let setting: AuroraLoomSteps
    public let work: Int; public let winningSettings: [Int]; public let method: AuroraLoomSolveMethod
}
public enum AuroraLoomSolver {
    public static let maxSweeps: Int            // 32
    /// nil when some ribbon has no winning setting.
    public static func solve(_ level: AuroraLoomLevel) -> AuroraLoomSolution?
}

public struct AuroraLoomDifficulty: Sendable, Equatable, Codable {
    public let shortest: Int; public let work: Int; public let winningSettings: Int; public let tolerance: Int; public let omega: Int
    public init(level: AuroraLoomLevel, solution: AuroraLoomSolution)
    public var puzzleDifficulty: PuzzleDifficulty { get }
}

public struct AuroraLoomBandProfile: Sendable, Equatable { public let band: Int; public let omega: Int; public let tolerance: Int; public let shortest: ClosedRange<Int>
    public static func of(band: Int) -> AuroraLoomBandProfile? }
public struct AuroraLoomGenerated: Sendable, Equatable {
    public let entry: AuroraLoomManifestEntry; public let level: AuroraLoomLevel; public let solution: AuroraLoomSolution
    public let difficulty: AuroraLoomDifficulty; public let skipped: Int }
public enum AuroraLoomGenerator {
    public static let maxCandidates: Int        // 64
    public static func generate(_ entry: AuroraLoomManifestEntry) throws(AuroraLoomError) -> AuroraLoomGenerated   // .generation(number)
    public static func catalog() throws(AuroraLoomError) -> [AuroraLoomGenerated]
    public static func catalogDigest(_ levels: [AuroraLoomGenerated]) -> String   // PuzzleCatalog<AuroraLoomRules>.digest(id: "aurora-loom", identities: fingerprints)
}

public struct AuroraLoomCounterexample: Sendable, Equatable, Codable { public let setting: AuroraLoomSteps; public let mismatch: AuroraLoomMismatch }
public struct AuroraLoomWitness: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let number: Int; public let level: AuroraLoomLevel; public let actions: [AuroraLoomMove]; public let fingerprints: [String]
    public let terminal: AuroraLoomMismatch; public let counterexample: AuroraLoomCounterexample
    public let difficulty: AuroraLoomDifficulty; public let method: AuroraLoomSolveMethod; public let skipped: Int
    public init(_ generated: AuroraLoomGenerated) throws(AuroraLoomError)   // .witness(reason) if it does not win
    public func encoded() -> Data            // sorted keys, pretty, trailing newline
    public static func decode(_ data: Data) throws(AuroraLoomError) -> AuroraLoomWitness   // newerSchema / malformed / witness(reason)
}
```
