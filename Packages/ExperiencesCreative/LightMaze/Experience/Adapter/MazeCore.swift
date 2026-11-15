// MazeCore — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121, FR-A13-122; clarification Q5; research D5; plan
// "Lifecycle"). The state of Light Maze as an experience: a `MazeState` (level index, orientations of the level's
// turnable tiles, selection), the preparation seed and, as a cache of the state, the traced `Beam` of the current board
// (recomputed by every accepted action, never saved). Nothing animates: a host step (the default 1/120 s) changes
// nothing, so a suspension never changes the maze either.
//
// Preparation: every preparation seed opens the first level in its starting orientations with nothing selected
// (`MazeState.initial`); the seed is kept only as the envelope's preparation seed (`reset()` returns to the same first
// state). The levels are fixed data, so nothing depends on the seed.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange`, a non-finite value with `nonFinite` and a wrong value count with `wrongValueCount` before
// the core sees it):
//   level.select [0…19]   the level by index in its starting orientations, nothing selected; a value that is not a
//                         whole index 0…19 is refused with `a13.invalid-choice`.
//   level.next            the next level (refused with `a13.invalid-choice` on the last level).
//   level.previous        the previous level (refused with `a13.invalid-choice` on the first level).
//   tile.select [index]   selects turnable tile `index` (an index into the level's mirrors and prisms in tile order;
//                         the declared range is 0…(the largest turnable count of the catalog − 1)); an index that is
//                         not whole or not below the current level's turnable count is refused with
//                         `a13.invalid-choice`.
//   tile.turn             toggles the selected tile's orientation; refused with `a13.invalid-choice` when nothing is
//                         selected.
//   level.reset           the level's starting orientations, nothing selected.
// Called directly (not through the engine), the core refuses an unknown control with `unknownControl` and a wrong
// value count with `wrongValueCount`, as the engine does. A refusal changes nothing.
//
// Snapshot schema 1: `MazeState.encoded()` (JSON with sorted keys); the preparation seed and the schema version come
// from the snapshot envelope (`MigrationChain(currentVersion: 1)`, so a newer envelope is refused by the engine). A
// payload `MazeState.decode(_:)` refuses (damaged, or a newer schema inside the payload) is refused (the restore throws
// `MazeRestoreError`). One quality tier (`level-0`). The digest is the canonical text of the state followed by every
// field of the beam it traces (segments with exact end points, bounce and branch; lit targets; end reasons; dropped
// branches; solved), so a scenario's final digest pins the beam path too. The outcome is `level-solved` while every
// target of the current level is lit, none otherwise.
//
// The canvas description (clarification Q5): "Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at the
// wall; not solved." — the level number and name, the counts of mirrors, prisms (only when the level has any) and
// targets with plurals, where the beam ends (`MazeCore.endWords`) and "solved" or "not solved".
import Foundation
import LightMazeCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Light Maze's refusals.
public enum MazeRule {
    /// A level or tile index that is not a valid choice, a step past the first or last level, or a turn with nothing
    /// selected.
    public static let invalidChoice = "a13.invalid-choice"
}

/// Why a stored maze state is refused.
public enum MazeRestoreError: Error, Equatable {
    /// `MazeState.decode(_:)` refused the payload, for the named reason.
    case refused(MazeStateRefusal)
}

/// The state of Light Maze. Schema version 1.
public struct MazeCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a13.light-maze"

    /// The action ids in declaration order.
    public static let actionIDs = ["level.select", "level.next", "level.previous", "tile.select", "tile.turn",
                                   "level.reset"]

    /// The outcome code while the current level is solved.
    public static let solvedOutcome = "level-solved"

    /// The number of levels of the catalog (20).
    public static var levelCount: Int { MazeState.catalog.levels.count }

    /// The largest number of turnable tiles of any level (the declared range of `tile.select` is 0…this − 1).
    public static var maxTurnable: Int { max(1, MazeState.catalog.levels.map(\.turnableCount).max() ?? 1) }

    /// The preparation seed; `reset()` returns to the first state.
    public private(set) var preparationSeed: UInt64
    /// The whole saved state: level, orientations and selection.
    public private(set) var state: MazeState
    /// The beam of the current board (a cache of the state, never saved).
    public private(set) var beam: Beam

    /// The first state (the first level, starting orientations, nothing selected) with `seed` as preparation seed.
    public init(seed: UInt64) {
        self.init(seed: seed, state: .initial)
    }

    /// A core holding `state`, prepared with `seed`.
    init(seed: UInt64, state: MazeState) {
        preparationSeed = seed
        self.state = state
        beam = state.beam
    }

    /// The current level.
    public var level: Level { state.level }
    /// The current board with the state's orientations.
    public var board: Board { state.board }
    /// True when every target of the current board is lit.
    public var isSolved: Bool { beam.isSolved }

    // MARK: Contract

    /// One quality tier (`level-0`): the drawing has nothing to scale down in this phase.
    public static var qualityTiers: Int { 1 }

    /// Schema 1, the first; nothing to migrate.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: MazeState.schemaVersion) }

    /// The six controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "level.select", ranges: [0...Double(levelCount - 1)]),
         ExperienceControl(id: "level.next"),
         ExperienceControl(id: "level.previous"),
         ExperienceControl(id: "tile.select", ranges: [0...Double(maxTurnable - 1)]),
         ExperienceControl(id: "tile.turn"),
         ExperienceControl(id: "level.reset")]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> MazeCore {
        try Task.checkCancellation()
        return MazeCore(seed: seed)
    }

    /// A host step changes nothing: nothing animates in this phase.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let expected = ["level.select": 1, "level.next": 0, "level.previous": 0, "tile.select": 1, "tile.turn": 0,
                        "level.reset": 0][action.control]
        guard let expected else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        let refused = ActionResult.rejected(.rule(code: MazeRule.invalidChoice))
        var next = state
        switch action.control {
        case "level.select":
            guard let index = Self.choice(v[0], count: Self.levelCount), next.selectLevel(index) else { return refused }
        case "level.next":
            guard next.selectLevel(state.levelIndex + 1) else { return refused }
        case "level.previous":
            guard next.selectLevel(state.levelIndex - 1) else { return refused }
        case "tile.select":
            guard let index = Self.choice(v[0], count: state.orientations.count), next.selectTile(index) else {
                return refused
            }
        case "tile.turn":
            guard next.turnSelected() else { return refused }
        default:   // level.reset
            next.reset()
        }
        replace(with: next)
        return .accepted
    }

    /// Takes `next` as the state and traces its beam again when the board changed.
    private mutating func replace(with next: MazeState) {
        let retrace = next.levelIndex != state.levelIndex || next.orientations != state.orientations
        state = next
        if retrace { beam = next.beam }
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// `level-solved` while every target of the current level is lit; nil otherwise.
    public var outcome: ExperienceOutcome? { isSolved ? ExperienceOutcome(code: Self.solvedOutcome) : nil }

    /// Back to the first state.
    public mutating func reset() {
        self = MazeCore(seed: preparationSeed)
    }

    /// The canonical text of the state, then every field of its beam (see the file header). A non-finite beam
    /// coordinate (never: the tracer only produces finite points) is refused as non-finite.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = String(data: state.encoded(), encoding: .utf8), !text.isEmpty else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a13.maze.v1|" + text)
        builder.add(beam.segments.count)
        for segment in beam.segments {
            try builder.add(segment.start.x)
            try builder.add(segment.start.y)
            try builder.add(segment.end.x)
            try builder.add(segment.end.y)
            builder.add(segment.bounce)
            builder.add(segment.branch)
        }
        builder.add(beam.litTargets.count)
        for cell in beam.litTargets {
            builder.add(cell.column)
            builder.add(cell.row)
        }
        builder.add(beam.endReasons.map(\.rawValue).joined(separator: ","))
        builder.add(beam.droppedBranches)
        builder.add(beam.isSolved)
    }

    /// The maze state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        state.encoded()
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed; a payload that
    /// `MazeState.decode(_:)` refuses (damaged or newer) throws ``MazeRestoreError/refused(_:)``.
    public static func restore(payload: Data, seed: UInt64) throws -> MazeCore {
        switch MazeState.decode(payload) {
        case .success(let state): return MazeCore(seed: seed, state: state)
        case .failure(let reason): throw MazeRestoreError.refused(reason)
        }
    }

    // MARK: Words

    /// "1 mirror", "2 mirrors" (`noun` with an "s" for a count other than 1).
    public static func counted(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    /// The tiles of `board` in words: "1 mirror, 1 target"; prisms only when there are any ("2 mirrors, 1 prism,
    /// 2 targets").
    public static func tileWords(_ board: Board) -> String {
        let mirrors = board.tiles.filter { $0.kind == .mirror }.count
        let prisms = board.tiles.filter { $0.kind == .prism }.count
        let targets = board.tiles.filter { $0.kind == .target }.count
        var parts = [counted(mirrors, "mirror")]
        if prisms > 0 { parts.append(counted(prisms, "prism")) }
        parts.append(counted(targets, "target"))
        return parts.joined(separator: ", ")
    }

    /// The place a branch ends in words, singular ("the wall") or counted ("2 walls").
    public static func endPlace(_ reason: BeamEnd, count: Int) -> String {
        let noun: String
        switch reason {
        case .leftBoard: noun = "edge"
        case .wall: noun = "wall"
        case .target: noun = "target"
        case .emitter: noun = "emitter"
        case .loop: return count == 1 ? "a loop" : counted(count, "loop")
        case .bounceCap: noun = "bounce limit"
        case .segmentCap: noun = "segment limit"
        }
        return count == 1 ? "the " + noun : counted(count, noun)
    }

    /// Where `beam` ends in words: "beam ends at the wall" for one branch; "beams end at the target and 2 walls" for
    /// several (the distinct reasons in the order of their first branch, each counted).
    public static func endWords(_ beam: Beam) -> String {
        var order: [BeamEnd] = []
        var counts: [BeamEnd: Int] = [:]
        for reason in beam.endReasons {
            if counts[reason] == nil { order.append(reason) }
            counts[reason, default: 0] += 1
        }
        let places = order.map { endPlace($0, count: counts[$0] ?? 1) }
        let joined: String
        switch places.count {
        case 0: return "no beam"
        case 1: joined = places[0]
        default: joined = places.dropLast().joined(separator: ", ") + " and " + (places.last ?? "")
        }
        return (beam.endReasons.count == 1 ? "beam ends at " : "beams end at ") + joined
    }

    /// The status line: "level 1, First light; 1 mirror, 1 target; beam ends at the wall; not solved".
    public static func status(_ state: MazeState, beam: Beam) -> String {
        "level \(state.levelIndex + 1), \(state.level.name); \(tileWords(state.board)); \(endWords(beam)); "
            + (beam.isSolved ? "solved" : "not solved")
    }

    /// The canvas description: "Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at the wall; not
    /// solved."
    public static func canvasDescription(_ state: MazeState, beam: Beam) -> String {
        "Light Maze: \(status(state, beam: beam))."
    }

    /// The canvas description of this core.
    public var canvasDescription: String { Self.canvasDescription(state, beam: beam) }
}
