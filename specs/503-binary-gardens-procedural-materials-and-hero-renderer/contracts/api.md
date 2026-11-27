# API contract: R02-G21-03

Existing names are features 501's and 502's, as committed (`BinaryGardensLevel`, `BinaryGardensStar`,
`BinaryGardensWorld`, `BinaryGardensArrangement`, `BinaryGardensPoint`, `BinaryGardensBand`, `BinaryGardensBloom`,
`BinaryGardensFailure`, `BinaryGardensWorldLight`, `BinaryGardensReport`, `BinaryGardensAction`, `BinaryGardensSky`,
`BinaryGardensPlay`, `BinaryGardensRecord`, `BinaryGardensStage`, `BinaryGardensError`; `BinaryGardensManifest`,
`BinaryGardensManifestEntry`, `BinaryGardensBandProfile`, `BinaryGardensGenerator`, `BinaryGardensGenerated`,
`BinaryGardensSolver`, `BinaryGardensPlan`, `BinaryGardensDifficulty`, `BinaryGardensWitness`,
`BinaryGardensLevel.phaseStep`). Shared names are VisualCore's, as `MushroomWeatherCore` uses them (`Mesh`,
`MeshBuilder`, `Mat4`, `Vec4`, `ExperienceCore`, `ExperienceControl`, `ExperienceAction`, `ActionResult`,
`ExperienceInput`, `ExperienceOutcome`, `ExperienceFailure`, `DigestBuilder`, `MigrationChain`, `QualityProfile`,
`QualityLevel`, `ScenarioManifest`, `ScenarioStep`, `ExperienceID`, `FrameProbe`, `ShaderMeshRenderer`,
`MeshRenderer`, `ExperienceShell`, `ExperienceStorage`). Every new public name carries `///` documentation.

```swift
// BinaryGardensCore additions (host-testable)
public enum BinaryGardensPalette { public static let space, spaceTop, starfield, ringIdle, orbit, starOne, starTwo,
    core, world, frost, scorch, flower, pollen, gaugePlate, lethalLow, dim, comfortable, bright, lethalHigh, window,
    marker, tiltLit, tiltUnlit, actionsLit, actionsUnlit, broken, glow: SIMD3<Double>
    public static let hex: [String] }                    // ["#070815", "#FF5A36", "#A6DDFF", "#7BE8BE", "#151B3D"]
public struct BinaryGardensTier: Sendable, Equatable, Hashable { public let name: String; public let index: Int
    public let faceQuads: Int                            // 8, 5, 3 quads per cube face edge
    public let coronaRays: Int; public let trailTicks: Int; public let motes: Int; public let glowShells: Int
    public static let all: [BinaryGardensTier]           // level-0 … level-2, richest first
    public static func of(_ index: Int) -> BinaryGardensTier }
public struct BinaryGardensSceneWorld: Sendable, Equatable {
    public let radius, phase, speed: Int
    public let lethalLow, comfortLow, comfortHigh, lethalHigh: Int; public let window, bloomLow, bloomHigh: Int
    public let positions: [BinaryGardensPoint]           // ticks 1 … 48 (index tick − 1)
    public let flux: [Int]; public let shares: [[Int]]; public let bands: [BinaryGardensBand]
    public let longestLethalRun, longestWindow, windowStart, integral: Int; public let bloom: BinaryGardensBloom }
public struct BinaryGardensSceneSnapshot: Sendable, Equatable {
    public let ringRadii: [Int]; public let luminosityLevels: [Int]; public let maxTilt: Int; public let phaseStep: Int
    public let lethalTolerance: Int; public let worlds: [BinaryGardensSceneWorld]
    public let arrangement: BinaryGardensArrangement
    public let starPositions: [[BinaryGardensPoint]]     // [tick − 1][star]
    public let shownTick: Int                            // 1 … 48
    public let fitScale: Double                          // 0.95 / max(ring radii ∪ world radii)
    public let failure: BinaryGardensFailure?; public let stage: BinaryGardensStage
    public let actionsLeft: Int; public let budget: Int; public let levelNumber: Int; public let time: Double
    public init(play: BinaryGardensPlay, shownTick: Int, levelNumber: Int, time: Double)
    public var isWon: Bool { get }
    public func band(_ world: Int) -> BinaryGardensBand            // at the shown tick
    public func share(_ world: Int, star: Int) -> Int              // at the shown tick, milliflux
    public func starPoint(_ star: Int, tick: Int) -> BinaryGardensPoint
    public func worldPoint(_ world: Int, tick: Int) -> BinaryGardensPoint }

public struct BinaryGardensCamera: Sendable, Equatable { public let eye, target: SIMD3<Double>
    public let fovY, aspect, near, far: Double; public let view, projection, viewProjection: Mat4 }
public struct BinaryGardensElement: Sendable, Equatable {
    public enum Kind: Int, Sendable, CaseIterable { case backdrop, tiltDial, ring, orbit, trail, world, star, gauge,
        actions, glow }                                  // worlds and stars form one group sorted back to front
    public static func drawsBefore(_ a: BinaryGardensElement, _ b: BinaryGardensElement,
                                   eye: SIMD3<Double>) -> Bool      // kind; bodies by eye distance, worlds, index
    public let kind: Kind; public let index: Int; public let item: Int; public let centre: SIMD3<Double> }
public struct BinaryGardensReferencePoint: Sendable, Equatable {
    public enum Kind: Int, Sendable, CaseIterable { case barycentre, world, star, gaugeMargin, actionsBar }
    public let kind: Kind; public let index: Int; public let centre: SIMD3<Double> }
public struct BinaryGardensColouredMesh: Sendable, Equatable { public let mesh: Mesh; public let colours: [Vec4] }
public enum BinaryGardensSceneGeometry {
    public static let discRadius: Double                 // 0.95
    public static let worldRadius: Double                // 0.07
    public static let eye: SIMD3<Double>                 // (0, −2.0, 3.2)
    public static let lookAt: SIMD3<Double>              // (0, −0.35, 0)
    public static let boxLow, boxHigh: SIMD3<Double>     // (−1.3, −1.85, −0.85), (1.3, 1.15, 0.85)
    public static let aspectRange: ClosedRange<Double>   // 0.4 … 2.5
    public static func fitScale(ringRadii: [Int], worldRadii: [Int]) -> Double
    public static func position(_ point: BinaryGardensPoint, scale: Double) -> SIMD3<Double>   // k · p / 2²⁰
    public static func ringVertex(radius: Int, step: Int, tilt: Int, scale: Double) -> SIMD3<Double>  // table point
    public static func orbitVertex(radius: Int, step: Int, scale: Double) -> SIMD3<Double>
    public static func starCentre(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot) -> SIMD3<Double>
    public static func worldCentre(_ world: Int, _ snapshot: BinaryGardensSceneSnapshot) -> SIMD3<Double>
    public static func starRadius(luminosityIndex: Int) -> Double              // 0.05 + 0.012 · index
    public static func tiltPipCentre(_ step: Int) -> SIMD3<Double>
    public static func gaugeY(_ world: Int) -> Double                          // −1.2 − 0.1 · world
    public static func gaugeMargin(_ world: Int) -> SIMD3<Double>              // (−0.925, gaugeY, 0)
    public static func cellCentre(_ world: Int, tick: Int) -> SIMD3<Double>
    public static func cellHeight(flux: Int, lethalHigh: Int) -> Double        // 0.01 + 0.06 · min(1, F/λ_hi)
    public static func bloomX(_ integral: Int, bloomHigh: Int) -> Double
    public static func actionsY(_ snapshot: BinaryGardensSceneSnapshot) -> Double
    public static func actionsBar(_ index: Int, _ snapshot: BinaryGardensSceneSnapshot) -> SIMD3<Double>
    public static func failureColumn(_ tick: Int) -> Int                       // ((tick − 1) mod 48) + 1
    public static func trailTicks(shownTick: Int, count: Int) -> [Int]         // cyclic, newest first
    public static func cubeSphere(faceQuads: Int) -> (positions: [SIMD3<Double>], normals: [SIMD3<Double>],
                                                     triangles: [SIMD3<Int>])  // unit radius
    public static func paintOrder(_ snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensElement]
    public static func referencePoints(_ snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensReferencePoint]
    public static func systemMesh(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier) throws -> Mesh
    public static func glowMesh(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier) throws -> Mesh
    public static func systemPart(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier) throws
        -> BinaryGardensColouredMesh                                           // fallback, unlit colours
    public static func camera(aspect: Double) -> BinaryGardensCamera
    public static func project(_ point: SIMD3<Double>, camera: BinaryGardensCamera) -> SIMD2<Double>?   // 0 … 1
    public static func colour(of code: Double, won: Double) -> SIMD3<Double> }                         // CPU palette

public enum BinaryGardensMaterial: Int, Sendable, CaseIterable, Hashable {   // codes per data-model.md
    public var code: Float { get }; public var paletteConstant: String { get }
    public var baseColour: SIMD3<Double> { get }; public var isValued: Bool { get } }
public enum BinaryGardensShaders {
    public static let versionLine: String                // "#version 300 es"
    public static let systemVertex, systemFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static let mvpUniform, timeUniform, motionUniform, wonUniform, starOneUniform, starTwoUniform,
        glowGainUniform, glowLimitUniform: String        // u_mvp, u_time, u_motion, u_won, u_star1, u_star2, …
    public static let uniformNames: [String: [String]]   // "system", "glow"
    public static let maxUniformVec4s: Int               // 16
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)]
    public static let valueScale: Double                 // 0.4
    public static let brokenOffset: Double               // 32
    public static let ambientFloor: Double               // 0.35
    public static func encode(_ material: BinaryGardensMaterial, value: Double, broken: Bool) -> Double
    public static func decode(_ x: Double) -> (material: BinaryGardensMaterial, value: Double, broken: Bool)
    // CPU twins of the GLSL functions (tested against the CPU reference):
    public static func backdropColour(height: Double) -> SIMD3<Double>
    public static func starfieldCoverage(u: Double, v: Double) -> Double       // fixed hash, ≤ 2 % of the area
    public static func worldShade(normal: SIMD3<Double>, band: BinaryGardensBand, shareOne: Double,
                                  shareTwo: Double, toStarOne: SIMD3<Double>, toStarTwo: SIMD3<Double>)
        -> SIMD3<Double>                                 // two suns, sunrise bands, ambient floor, banding
    public static func bandCoverage(latitude: Double, band: BinaryGardensBand) -> Double   // caps, belts
    public static func flowerCoverage(normal: SIMD3<Double>) -> Double                    // fixed hash
    public static func shaderTime(_ time: Double) -> Double
    public static func motion(reduceMotion: Bool) -> Double
    public static func glowLimit(reduceFlashing: Bool) -> Double
    public static func glowGain(for tier: BinaryGardensTier) -> Double }

public enum BinaryGardensExperienceRule { public static let notWhole: String   // "r02-g21.not-whole"
    public static let tick: String }                                            // "r02-g21.tick"
public enum BinaryGardensRestoreRefusal: Error, Equatable, Sendable { case damaged, levelNumber(Int),
    kernel(BinaryGardensError) }
public struct BinaryGardensExperienceCore: ExperienceCore, Equatable {
    public static let experienceID: String               // "r02-g21.binary-gardens"
    public static let schemaVersion: Int                 // 1
    public static let digestDomain: String               // "r02-g21.binary-gardens.v1"
    public static let actionIDs: [String]                // star.ring, star.phase, star.luminosity, orbit.tilt,
                                                         // light.run, play.undo, play.redo, level.next, clock.show
    public static let levelNumbers: ClosedRange<Int>     // 1 … 100
    public static let starRange, ringRange, phaseRange, luminosityRange, tiltRange, tickRange: ClosedRange<Int>
                                                         // 0…1, 0…7, 0…47, 0…3, 0…6, 0…60 (declared)
    public static let shownTicks: ClosedRange<Int>       // 1 … 48 (accepted by clock.show)
    public static let openingTick: Int                   // 48
    public static let wonCode, failedCode: String        // "won", "failed"
    public static let certifiedCandidates: [Int]         // 100 entries: each R02-G21-02 witness's `skipped`
    public private(set) var levelNumber: Int; public private(set) var play: BinaryGardensPlay
    public private(set) var shownTick: Int; public let openingNumber: Int; public private(set) var qualityTier: Int
    public static func levelNumber(forSeed seed: UInt64) -> Int                // seed % 100 + 1
    public static func level(number: Int) throws(BinaryGardensError) -> BinaryGardensLevel
    public static func generated(number: Int) throws(BinaryGardensError) -> BinaryGardensGenerated
    public static func freshPlay(of level: BinaryGardensLevel) throws(BinaryGardensError) -> BinaryGardensPlay
    public static func opening(number: Int) throws(BinaryGardensError) -> BinaryGardensExperienceCore
    public func snapshot(time: Double) -> BinaryGardensSceneSnapshot
    public var renderTier: BinaryGardensTier { get }
    public static var qualityTiers: Int { get }          // 3
    public static var qualityProfile: QualityProfile { get }
    public mutating func setQualityTier(_ tier: Int)
    // ExperienceCore: migrations, controls, prepare(seed:), update(step:), apply(_:), reset(), outcome,
    // writeDigest(into:), snapshotPayload(), restore(payload:seed:)
}
#if DEBUG || VISUALCORE_AUTOMATION
extension BinaryGardensExperienceCore {
    public static let manifestSeed: UInt64; public static let acceptanceRows: Int        // 0, 80
    public static func acceptanceRowID(_ row: Int) -> String                              // "R2-G21-QA-NNN"
    public static func manifest(for id: ExperienceID, seed: UInt64 = manifestSeed) -> ScenarioManifest }
#endif

// BinaryGardensExperience (iOS only, #if os(iOS)):
public enum BinaryGardensExperience {
    public static let id: ExperienceID?                  // r02-g21.binary-gardens
    @MainActor public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                                       reduceFlashing: Bool) -> any Experience }
// internal: BinaryGardensPresenter (tierLog: [BinaryGardensTierChange], fallbackReason, probes(_:) — two backdrop
// corners, quality levels = BinaryGardensExperienceCore.qualityTiers), BinaryGardensSystemScene (ShaderMeshRenderer;
// MeshRenderer fallback), BinaryGardensControls (star picker, ring −/+, phase −/+ by the phase step, luminosity −/+,
// tilt −/+, tick −/+, run, undo, redo, next level; each labelled).
```
