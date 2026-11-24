# API contract: R02-G15-01 (VoxelOrigamiCore)

```swift
public enum VoxelOrigamiError: Error, Equatable, Sendable { case level(String), action(String), stage, stale,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g15.*
public struct VoxelOrigamiVector: Sendable, Hashable, Codable, Comparable { public let x: Int; public let y: Int
    public let z: Int; public static let units: [VoxelOrigamiVector] }   // +x, -x, +y, -y, +z, -z
public struct VoxelOrigamiRotation: Sendable, Hashable { public static let identity: Self
    public static func quarter(about axis: VoxelOrigamiVector, turns: Int) -> Self      // right-hand rule, turns mod 4
    public static let all: [Self]                                                       // the 24 rotations
    public func applied(to v: VoxelOrigamiVector) -> VoxelOrigamiVector; public static func * (a: Self, b: Self) -> Self }
public enum VoxelOrigamiOrientations: String, Sendable, Hashable, Codable { case fixed, upright, any
    public var group: [VoxelOrigamiRotation] }
public struct VoxelOrigamiCube: Sendable, Hashable, Codable { public let parent: Int?; public let direction: VoxelOrigamiVector
    public let startTurn: Int }
public struct VoxelOrigamiPose: Sendable, Equatable { public let cells: [VoxelOrigamiVector]
    public let orientations: [VoxelOrigamiRotation] }
public enum VoxelOrigamiLattice {
    public static func pose(_ cubes: [VoxelOrigamiCube], turns: [Int]) -> VoxelOrigamiPose
    public static func swinging(_ cubes: [VoxelOrigamiCube], hinge: Int) -> [Int]                 // descendants
    public static func check(_ cubes: [VoxelOrigamiCube], turns: [Int], hinge: Int, step: Int) -> VoxelOrigamiFailure?
        // collision first, then sweep; nil when the turn is clear
    public static func inBand(still: VoxelOrigamiVector, start: VoxelOrigamiVector, end: VoxelOrigamiVector,
        axisPoint: VoxelOrigamiVector, axis: VoxelOrigamiVector, step: Int) -> Bool
    public static func canonical(_ cells: [VoxelOrigamiVector], group: [VoxelOrigamiRotation]) -> [VoxelOrigamiVector]
    public static func canonicalHash(_ cells: [VoxelOrigamiVector], group: [VoxelOrigamiRotation]) -> String
    public static func covered(target: [VoxelOrigamiVector], occupied: [VoxelOrigamiVector],
        group: [VoxelOrigamiRotation]) -> (count: Int, rotation: Int, translation: VoxelOrigamiVector) }
public struct VoxelOrigamiShapeReport: Sendable, Equatable { public let occupancy: Bool; public let hash: String
    public let covered: Int; public let matched: Bool }
public struct VoxelOrigamiLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(VoxelOrigamiError);
    encoded() -> Data; static func decode(_:) throws(VoxelOrigamiError) -> Self; fingerprint */
    public func report(turns: [Int]) -> VoxelOrigamiShapeReport
    public func cubeName(_ index: Int) -> String                       // "cube 3"
    public func hingeName(_ hinge: Int, turn: Int) -> String           // "hinge 3, turned 90 degrees"
    public func progressDescription(report: VoxelOrigamiShapeReport, actionsLeft: Int) -> String }
public enum VoxelOrigamiFailure: Sendable, Hashable, Codable {
    case collision(hinge: Int, moving: Int, still: Int, cell: VoxelOrigamiVector)
    case sweep(hinge: Int, moving: Int, still: Int, cell: VoxelOrigamiVector)
    case budget(Int); public var code: String }
public enum VoxelOrigamiAction: Sendable, Hashable, Codable { case turn(Int, Int) }
public enum VoxelOrigamiStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum VoxelOrigamiEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum VoxelOrigamiRecordKind: String, Sendable, Codable { case turn, undo, redo }
public struct VoxelOrigamiRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64
    public let index: Int; public let kind: VoxelOrigamiRecordKind; public let action: VoxelOrigamiAction?
    public let previous: String; public let next: String }
public struct VoxelOrigamiPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: VoxelOrigamiLevel
    public private(set) var stage: VoxelOrigamiStage, turns: [Int], actionsSpent: Int, pose: VoxelOrigamiPose,
        report: VoxelOrigamiShapeReport, failure: VoxelOrigamiFailure?, records: [VoxelOrigamiRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }; public var canUndo, canRedo: Bool { get }
    public init(level: VoxelOrigamiLevel)
    public mutating func handle(_ event: VoxelOrigamiEvent) throws(VoxelOrigamiError)            // .stage
    public mutating func apply(_ action: VoxelOrigamiAction, expecting previous: String) throws(VoxelOrigamiError)
        // order: .stage, .stale, .action
    public mutating func undo() throws(VoxelOrigamiError); public mutating func redo() throws(VoxelOrigamiError)
    public static func replay(level: VoxelOrigamiLevel, records: [VoxelOrigamiRecord]) throws(VoxelOrigamiError) -> VoxelOrigamiPlay
}
public struct VoxelOrigamiRules: PuzzleRules { /* State = Position (turns, actions spent, outcome), Move = VoxelOrigamiAction;
    rulesID "r02-g15-voxel-origami"; moves per data-model.md; var initialState: Position */ }
```
