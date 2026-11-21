# API contract: R02-G04-02 (HueCompassCore additions)

```swift
extension HueCompassError { case generation(Int) /* r02-g04.generation */; case witness(String) /* r02-g04.witness */ }
public struct HueCompassManifestEntry: Sendable, Equatable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum HueCompassManifest { public static let entries: [HueCompassManifestEntry] }   // 100
public struct HueCompassAmbiguity: Sendable, Equatable, Codable { public let probes: [Int]; public let targets: [Int] }  // 2 targets
public struct HueCompassSolution: Sendable, Equatable { public let probes: [Int]; public var smallest: Int { probes.count }
    public let work: Int; public let bestSingle: Int; public let largestAfterBestSingle: Int
    public let ambiguity: HueCompassAmbiguity? }   // the insufficient smaller set, nil when the smallest count is 0
public enum HueCompassSolver {
    public static let maximumDepth = 2
    public static func candidates(_ level: HueCompassLevel) -> [Int]          // bearings farther from the start than the tolerance
    public static func classes(_ level: HueCompassLevel, probes: [Int]) -> [[Int]]   // candidates grouped by their clues, in order
    public static func selection(for targets: [Int], in level: HueCompassLevel) -> HueCompassSelection?   // smallest acceptable
    public static func solve(_ level: HueCompassLevel, depth: Int = maximumDepth) -> HueCompassSolution?   // nil: none within depth
}
public struct HueCompassDifficulty: Sendable, Equatable, Codable { public let smallest: Int
    public let largestAfterBestSingle: Int; public let bearingTolerance: Int; public let bandTolerance: Int
    public let clearShare: Int; public let work: Int }
public struct HueCompassBandProfile: Sendable, Equatable { public let bearingTolerance: Int; public let bandTolerance: Int
    public let clearShare: Int; public let smallest: ClosedRange<Int>; public static func of(band: Int) -> Self }
public struct HueCompassGenerated: Sendable, Equatable { public let entry: HueCompassManifestEntry
    public let level: HueCompassLevel; public let solution: HueCompassSolution
    public let difficulty: HueCompassDifficulty; public let skipped: Int }
public enum HueCompassGenerator {
    public static let tutorialLevels: ClosedRange<Int>   // 1 … 3
    public static func candidate(_ entry: HueCompassManifestEntry, index: Int) -> HueCompassLevel
    public static func generate(_ entry: HueCompassManifestEntry) throws(HueCompassError) -> HueCompassGenerated
    public static func catalogDigest(_ levels: [HueCompassLevel]) -> String
}
public struct HueCompassWitness: Sendable, Equatable, Codable {
    public static let schema = 1
    public static func actions(for solution: HueCompassSolution, level: HueCompassLevel) -> [HueCompassAction]
    public static func make(_ generated: HueCompassGenerated) throws(HueCompassError) -> Self
    public func encoded() -> Data
    public static func decode(_ data: Data) throws(HueCompassError) -> Self   // refuses newer, damaged, non-replaying
}
```
