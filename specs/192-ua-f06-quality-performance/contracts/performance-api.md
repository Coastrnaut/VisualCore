# Contract: quality and performance API (UA-F06)

Names marked (new) are created by this feature; everything else exists and was verified in research.md.

## VisualCoreDiagnostics (pure)

```swift
public struct QualityLevel: Sendable, Equatable {                     // (new)
    public let name: String
    public let resolutionShare: Double
    public let elementShare: Double
    public let iterationShare: Double
    public let effectPasses: Int
    public init(name: String, resolutionShare: Double = 1, elementShare: Double = 1,
                iterationShare: Double = 1, effectPasses: Int = 0)
}
public enum QualityBudget: String, Sendable, CaseIterable {           // (new)
    case resolutionShare, elementShare, iterationShare, effectPasses
}
public enum QualityProfileError: Error, Sendable, Equatable {         // (new)
    case noLevel, tooManyLevels(Int), invalidName(level: Int), duplicateName(level: Int)
    case outOfRange(level: Int, budget: QualityBudget), rising(level: Int, budget: QualityBudget)
}
public struct QualityProfile: Sendable, Equatable {                   // (new)
    public static let maxLevels = 8
    public let levels: [QualityLevel]
    public init(levels: [QualityLevel]) throws(QualityProfileError)
    public static func uniform(levels: Int) -> QualityProfile
    public static let single: QualityProfile
    public var count: Int { get }
    public var names: [String] { get }
    public func level(_ index: Int) -> QualityLevel
    public func elements(requested: Int, level: Int, minimum: Int = 0) -> Int
    public func iterations(requested: Int, level: Int, minimum: Int = 1) -> Int
}
public enum QualityDeclaration {                                      // (new)
    public static func problems(profile: QualityProfile, tierCount: Int, catalogNames: [String]?) -> [String]
}
public struct QualityGovernor: Sendable, Equatable {                  // (new)
    public static let minimumInterval: Double                         // 1 second
    public init(levelCount: Int, pin: Int? = nil)
    public private(set) var pin: Int?
    public var levelInForce: Int { get }
    public var stepsDown: Int { get }
    public var stepsUp: Int { get }
    public mutating func decide(conditions: DeviceConditions, now: Double) -> Int
    public mutating func setPin(_ pin: Int?)
    public mutating func resume()
}
public struct PacingSummary: Sendable, Equatable, Codable {           // (new)
    public var samples, onTime, missed, invalid: Int
    public var medianMs, p95Ms, p99Ms: Double?
}
public struct PacingMeter: Sendable, Equatable {                      // (new)
    public static let binWidth: Double                                // 0.00025 s
    public static let binCount: Int                                   // 1,000
    public init()
    public mutating func record(interval: Double, period: Double)
    public mutating func skipNext()
    public var summary: PacingSummary { get }
}
public struct ResourceSample: Sendable, Equatable {                   // (new)
    public var footprintBytes: Int?
    public var gpuBytes: Int
}
public enum GrowthVerdict: Sendable, Equatable {                      // (new)
    case flat(footprintChecked: Bool), grew(quantity: String, by: Int), tooFewSamples(Int)
    public var passes: Bool { get }
}
public enum GrowthRule {                                              // (new)
    public static let minimumSamples: Int                             // 60
    public static let footprintMarginBytes: Int                       // 8 MiB
    public static let footprintMarginShare: Double                    // 0.05
    public static func judge(_ samples: [ResourceSample]) -> GrowthVerdict
}
public struct LaunchTiming: Sendable, Equatable {                     // (new)
    public var milliseconds: Double
    public var firstLaunch: Bool
}
public enum PerformanceRecordError: Error, Sendable, Equatable {      // (new)
    case tooLarge(bytes: Int), corrupt(reason: String), newerVersion(Int), unknownVersion(Int)
    case missingField(String), unknownField(String), invalidValue(String)
    public var code: String { get }
}
public struct PerformanceRecord: Sendable, Equatable {                // (new) — fields as in data-model section 5
    public static let version: Int                                    // 1
    public static let maxBytes: Int                                   // 65,536
    public init(data: Data) throws(PerformanceRecordError)
    public func encoded() throws(PerformanceRecordError) -> Data
    public var passes: Bool { get }
}
```

`QualityPolicy`, `DeviceConditions`, `FramePacing`, `ParticleBudget`, `RenderCostEstimate`, `ResourceLedger`
keep their API unchanged.

## VisualCoreExperience (pure)

```swift
public protocol ExperienceCore {                                      // existing
    static var qualityProfile: QualityProfile { get }                 // (new) default: .uniform(levels: qualityTiers)
}
public enum ConformanceCheck { case profileMatchesTiers }             // (new case)
public struct SessionStageTimings {                                   // existing
    public var setup: Double?                                         // (new) seconds
    public var firstPresent: Double?                                  // (new) seconds
    public var programsCompiled: Int?                                 // (new)
}
```

## VisualCoreRendering and VisualCoreExperienceHost (main thread)

```swift
public struct PresentedFrame: Sendable, Equatable {                   // (new)
    public let index: Int; public let time: Double; public let targetTime: Double
}
extension RenderHost {
    public func addPresentObserver(_ observer: @escaping @MainActor (PresentedFrame) -> Void)   // (new)
}
public enum ProcessMemory { public static func footprint() -> Int? }  // (new)

public protocol Experience {                                          // existing
    var qualityProfile: QualityProfile { get }                        // (new) default in an extension: .single
}
extension ExperienceSession {
    public var qualityPin: Int? { get set }                           // (new)
    public var conditions: @MainActor () -> DeviceConditions { get set }   // (new) default DeviceConditions.current
    public var qualityLevel: Int { get }                              // (new)
    public var launch: LaunchTiming? { get set }                      // (new)
    public var performanceRecord: PerformanceRecord? { get }          // (new) while an experience is open
    public var lastPerformanceRecord: PerformanceRecord? { get }      // (new) after a close
    public func refreshQuality(now: Double? = nil)                    // (new) takes a decision now
}
```

## Behaviour contracts

1. A level is applied only through `Experience.setQualityTier`; the digest never changes (existing conformance).
2. The session applies the level in force after a successful preparation and before the render host exists, and
   again after every decision that changed it. With a pin no policy decision is taken.
3. Decisions happen on the main thread: at open, from the frame hook at most once per second while running, and
   on `refreshQuality`. None while suspended, closing or idle.
4. `timings.setup` and `programsCompiled` end with the scene's set-up; `timings.firstPresent` ends at the first
   present observer call; without a display both `firstPresent` and the record's `first_present_ms` are absent
   and `presented` is false.
5. Late compilations = `resources.compileCount` now − the count when the experience became interactive (or after
   the last context recreation); never negative.
6. The pacing takes one interval per presented frame after the first; the first after a resume is skipped.
7. Observers and measurements never change what an experience computes.

## Tools

- `scripts/xcodebuild_package.py --only-testing <Target/Class> …` (new option, passed to xcodebuild).
- `scripts/check_performance_docs.py [--dir docs/performance]` (new): exit 0 when every budget row is a proposal
  with its confirming device measurement and every file that mentions a simulator carries the notice; exit 1
  with file and line otherwise. Step `performance-docs` of `scripts/release_check.py`.
