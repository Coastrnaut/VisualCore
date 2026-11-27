# API contract: R02-G22-03 (MyceliumArchitectCore presentation and MyceliumArchitectExperience)

Every new public name carries `///` documentation. Modelled one for one on feature 503's contract.

```swift
public enum MyceliumArchitectPalette { /* the colours of clarification Q3 as Vec4 */ public static let hex: [String] }
                                                         // ["#06070A", "#2FE08A", "#E08A3C", "#7B3FB8", "#12161C"]
public struct MyceliumArchitectTier: Sendable, Equatable, Hashable { public let name: String; public let index: Int
    public let tubeSides, capSegments, fuzzStrands, spores, glowShells: Int
    public static let all: [MyceliumArchitectTier]; public static func of(_ index: Int) -> MyceliumArchitectTier }
public struct MyceliumArchitectSceneSnapshot: Sendable, Equatable {
    public let level: MyceliumArchitectLevel; public let arrangement: MyceliumArchitectArrangement
    public let grown: [MyceliumArchitectCell]; public let grownPulses: [Int]; public let parents: [Int?]
    public let pathWeights: [Int]; public let consumed: [MyceliumArchitectCell]; public let totalWeight: Int
    public let terminalPulses: [Int?]; public let pulsesRun: Int; public let shownPulse: Int
    public let fitScale: Double; public let failure: MyceliumArchitectFailure?; public let stage: MyceliumArchitectStage
    public let actionsLeft: Int; public let levelNumber: Int; public let time: Double
    public init(play: MyceliumArchitectPlay, shownPulse: Int, levelNumber: Int, time: Double)
    public var isWon: Bool { get }
    public func isShown(_ grownIndex: Int) -> Bool                 // grownPulses[i] ≤ shownPulse
    public func isReached(_ terminal: Int) -> Bool }               // terminalPulses[t] ≤ shownPulse
public struct MyceliumArchitectCamera: Sendable, Equatable { public let eye, target: SIMD3<Double>
    public let fovY, aspect, near, far: Double; public let viewProjection: Mat4 }
public struct MyceliumArchitectReferencePoint: Sendable, Equatable {
    public enum Kind: Int, Sendable, CaseIterable { case boardCentre, root, terminal, gaugeMargin, actionsBar }
    public let kind: Kind; public let index: Int; public let centre: SIMD3<Double> }
public enum MyceliumArchitectSceneGeometry {
    public static let boardSide: Double                  // 1.9
    public static let eye, lookAt, boxLow, boxHigh: SIMD3<Double>
    public static let aspectRange: ClosedRange<Double>   // 0.4 … 2.5
    public static func fitScale(width: Int, height: Int) -> Double   // 1.9 / max(W, H)
    public static func centre(_ cell: MyceliumArchitectCell, width: Int, height: Int, scale: Double) -> SIMD3<Double>
    public static func camera(aspect: Double) -> MyceliumArchitectCamera
    public static func referencePoints(_ snapshot: MyceliumArchitectSceneSnapshot) -> [MyceliumArchitectReferencePoint]
    public static func board(_ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier) -> Mesh
    public static func glow(_ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier) -> Mesh }
public enum MyceliumArchitectShaders { public static let boardVertex, boardFragment, glowVertex, glowFragment: String
    public static let uniformSlots: [String: Int] }
public struct MyceliumArchitectExperienceCore: ExperienceCore, Equatable {      // the shared contract (as Binary Gardens)
    public static let experienceID: String              // "r02-g22.mycelium-architect"
    public static let qualityTiers: [String]             // ["level-0", "level-1", "level-2"]
    public static let schemaVersion: Int                 // 1
    public var snapshotForRendering: MyceliumArchitectSceneSnapshot { get } }
// Experience (iOS): MyceliumArchitectExperience (factory), MyceliumArchitectPresenter (probes(_:), qualityLevels,
// tierLog, fallbackReason), MyceliumArchitectBoardScene, MyceliumArchitectControls (labelled minimal panel).
```
