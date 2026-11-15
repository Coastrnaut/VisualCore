// BeamTracer — feature 096 (A13-P01) T-A13-103 (FR-A13-111, FR-A13-113; clarifications Q2–Q3; research D3;
// data-model "Beam"; gap G-BOARD). The beam of a board, traced with VisualCore's generic 2D ray cast (`Ray2.cast`)
// against every tile segment and the four board edges (`Board.geometry`).
//
// A branch is an origin, a grid direction, the segment indices it must not hit on its next cast and its bounce count.
// The branches run in FIFO order, each to its end before the next starts, so the segments are deterministic:
// 1. The first branch starts at the emitter cell's centre in the emitter's direction with the emitter's own four
//    segments excluded.
// 2. Each step first checks the caps and the cycle rule: when the trace already holds 256 segments the branch ends with
//    `segment-cap`; when the state (cell, direction) — the cell the branch leaves (the emitter's, then the cell of the
//    mirror or prism it was turned by) and its direction — was already seen in any branch of this trace, it ends with
//    `loop`. Otherwise it casts the ray, excluding its excluded segments, and records the segment from its origin to
//    the hit point (with its bounce count and branch index).
// 3. The tile owning the hit segment decides: a wall ends the branch with `wall`, a target with `target` (and lights
//    it, from any side), the emitter with `emitter`, a board edge with `left-board`. A mirror reflects: when the branch
//    already made 64 bounces it ends with `bounce-cap`; otherwise the direction becomes `direction.reflected(about:
//    normal)` (`Vec2.reflected`), snapped to the grid direction it lies along (`Direction.nearest`, because every
//    diagonal is at 45° the reflection is a grid direction up to rounding), the bounce count grows by one and the next
//    cast excludes the mirror's segment. A prism does the same and also queues a straight-on branch from the hit point
//    in the old direction with the prism's segment excluded and the same bounce count — unless the trace already has
//    16 branches, in which case the straight-on branch is dropped and counted.
// 4. A cast that hits nothing (impossible inside the board edges) ends the branch with `left-board`.
// Because every origin is a cell centre or a point on a diagonal at a cell centre, and every direction is a grid
// direction, every segment end point on a cell centre or a board edge is exact (integers and halves); a target is hit
// at c + 0.2 or c + 0.8 up to rounding, the same bits on every run.
// The level is solved when every target is lit (and there is at least one target).
import Foundation
import VisualCoreMath

/// Why a branch of the beam ended; the raw values are the reason names used in documents and tests.
public enum BeamEnd: String, Codable, CaseIterable, Sendable {
    /// The branch reached a board edge.
    case leftBoard = "left-board"
    /// The branch hit a wall.
    case wall
    /// The branch hit (and lit) a target.
    case target
    /// The branch came back to the emitter.
    case emitter
    /// The branch reached a (cell, direction) state already traced.
    case loop
    /// The branch would have made its 65th bounce.
    case bounceCap = "bounce-cap"
    /// The trace already held 256 segments.
    case segmentCap = "segment-cap"
}

/// One straight piece of the beam.
public struct BeamSegment: Codable, Equatable, Sendable {
    /// Where the piece starts (board coordinates).
    public var start: Vec2
    /// Where the piece ends: the hit point.
    public var end: Vec2
    /// The number of bounces the branch made before this piece (0 for the first piece from the emitter).
    public var bounce: Int
    /// The index of the branch this piece belongs to (0 for the branch from the emitter).
    public var branch: Int

    /// Creates a beam segment.
    public init(start: Vec2, end: Vec2, bounce: Int, branch: Int) {
        self.start = start; self.end = end; self.bounce = bounce; self.branch = branch
    }
}

/// The traced beam of a board.
public struct Beam: Codable, Equatable, Sendable {
    /// Every straight piece in trace order (branch by branch).
    public let segments: [BeamSegment]
    /// The lit targets' cells in the order they were first lit (no repeats).
    public let litTargets: [Cell]
    /// Why each branch ended, by branch index.
    public let endReasons: [BeamEnd]
    /// The number of prism splits dropped because the trace already had 16 branches.
    public let droppedBranches: Int
    /// True when the board has at least one target and every target is lit.
    public let isSolved: Bool

    /// Creates a beam from its fields (the tracer builds beams; this initializer exists for tests and fixtures).
    public init(segments: [BeamSegment], litTargets: [Cell], endReasons: [BeamEnd], droppedBranches: Int,
                isSolved: Bool) {
        self.segments = segments
        self.litTargets = litTargets
        self.endReasons = endReasons
        self.droppedBranches = droppedBranches
        self.isSolved = isSolved
    }

    /// The number of branches traced.
    public var branchCount: Int { endReasons.count }
}

/// Traces the beam of a board (see the file header for the rules).
public enum BeamTracer {
    /// The most bounces a branch makes; the next mirror or prism ends it with `bounce-cap`.
    public static let maxBounces = 64
    /// The most segments a trace holds.
    public static let maxSegments = 256
    /// The most branches a trace holds (the first one included).
    public static let maxBranches = 16

    /// One branch waiting to run.
    private struct Branch {
        var origin: Vec2
        var direction: Direction
        var cell: Cell
        var excluded: Set<Int>
        var bounces: Int
    }

    /// One visited state of the cycle rule.
    private struct State: Hashable {
        var cell: Cell
        var direction: Direction
    }

    /// The beam of `board`; an invalid board (see `Board.problem`) gives an empty, unsolved beam.
    public static func trace(_ board: Board) -> Beam {
        guard board.isValid, let emitterIndex = board.emitterIndex,
              let emitterDirection = board.tiles[emitterIndex].direction else {
            return Beam(segments: [], litTargets: [], endReasons: [], droppedBranches: 0, isSolved: false)
        }
        let geometry = board.geometry
        let emitterCell = board.tiles[emitterIndex].cell
        var queue = [Branch(origin: emitterCell.center, direction: emitterDirection, cell: emitterCell,
                            excluded: Set(geometry.tileSegments[emitterIndex]), bounces: 0)]
        var segments: [BeamSegment] = []
        var lit: [Cell] = []
        var ends: [BeamEnd] = []
        var visited = Set<State>()
        var dropped = 0
        var next = 0
        while next < queue.count {
            let index = next
            var branch = queue[index]
            next += 1
            var end: BeamEnd
            stepping: while true {
                if segments.count >= maxSegments { end = .segmentCap; break stepping }
                let state = State(cell: branch.cell, direction: branch.direction)
                if visited.contains(state) { end = .loop; break stepping }
                visited.insert(state)
                guard let hit = cast(branch, geometry.segments) else { end = .leftBoard; break stepping }
                segments.append(BeamSegment(start: branch.origin, end: hit.point, bounce: branch.bounces,
                                            branch: index))
                guard case .tile(let owner) = geometry.owners[hit.segmentIndex] else {
                    end = .leftBoard; break stepping
                }
                let tile = board.tiles[owner]
                switch tile.kind {
                case .wall: end = .wall; break stepping
                case .emitter: end = .emitter; break stepping
                case .target:
                    if !lit.contains(tile.cell) { lit.append(tile.cell) }
                    end = .target
                    break stepping
                case .mirror, .prism:
                    if branch.bounces >= maxBounces { end = .bounceCap; break stepping }
                    let reflected = branch.direction.vector.reflected(about: hit.normal)
                    let turned = Direction.nearest(to: reflected) ?? branch.direction
                    if tile.kind == .prism {
                        if queue.count < maxBranches {
                            queue.append(Branch(origin: hit.point, direction: branch.direction, cell: tile.cell,
                                                excluded: [hit.segmentIndex], bounces: branch.bounces))
                        } else {
                            dropped += 1
                        }
                    }
                    branch = Branch(origin: hit.point, direction: turned, cell: tile.cell,
                                    excluded: [hit.segmentIndex], bounces: branch.bounces + 1)
                }
            }
            ends.append(end)
        }
        let targets = board.targetCells
        let solved = !targets.isEmpty && targets.allSatisfy { lit.contains($0) }
        return Beam(segments: segments, litTargets: lit, endReasons: ends, droppedBranches: dropped, isSolved: solved)
    }

    /// True when every target of `board` is lit by its beam.
    public static func isSolved(_ board: Board) -> Bool { trace(board).isSolved }

    /// The nearest hit of `branch`'s ray against `segments`, skipping its excluded indices.
    private static func cast(_ branch: Branch, _ segments: [Segment2])
        -> (point: Vec2, segmentIndex: Int, normal: Vec2)? {
        guard let ray = Ray2(origin: branch.origin, direction: branch.direction.vector) else { return nil }
        if branch.excluded.count <= 1 {
            guard let hit = ray.cast(against: segments, excluding: branch.excluded.first) else { return nil }
            return (hit.point, hit.segmentIndex, hit.normal)
        }
        var candidates: [Segment2] = []
        var map: [Int] = []
        candidates.reserveCapacity(segments.count)
        for (index, segment) in segments.enumerated() where !branch.excluded.contains(index) {
            candidates.append(segment)
            map.append(index)
        }
        guard let hit = ray.cast(against: candidates) else { return nil }
        return (hit.point, map[hit.segmentIndex], hit.normal)
    }
}
