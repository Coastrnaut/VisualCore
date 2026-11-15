// BeamTracerTests — feature 096 (A13-P01) T-A13-103 (FR-A13-111; clarifications Q2–Q3; research D3; SC-A13-102).
// The beam tracer, host-free and short: the first level's start ends at the wall and its solution at the target; a
// mirror reflects with the incidence angle equal to the reflection angle and never hits its own surface again; a beam
// sent back to the emitter ends with "emitter"; a prism makes two branches (reflected and straight on); branches that
// merge into traced states end with "loop"; each cap holds on a board built to hit it (64 bounces, 256 segments, 16
// branches); every bundled level traces identically twice; an invalid board gives an empty beam.
import Foundation
import LightMazeCore
import Testing
import VisualCoreMath

/// A board from a map drawn with the north row first: `.` empty, `#` wall, `T` target, `>` `<` `^` `v` emitter
/// (east, west, north, south), `/` and `\` mirrors, `P` and `Q` prisms (slash and backslash). Tiles are listed row by
/// row from the south row, west to east.
func mapBoard(_ rows: [String]) -> Board {
    let height = rows.count
    let width = rows.first?.count ?? 0
    var tiles: [Tile] = []
    for row in 0..<height {
        let characters = Array(rows[height - 1 - row])
        for column in 0..<characters.count {
            switch characters[column] {
            case "#": tiles.append(.wall(column, row))
            case "T": tiles.append(.target(column, row))
            case ">": tiles.append(.emitter(column, row, .east))
            case "<": tiles.append(.emitter(column, row, .west))
            case "^": tiles.append(.emitter(column, row, .north))
            case "v": tiles.append(.emitter(column, row, .south))
            case "/": tiles.append(.mirror(column, row, .slash))
            case "\\": tiles.append(.mirror(column, row, .backslash))
            case "P": tiles.append(.prism(column, row, .slash))
            case "Q": tiles.append(.prism(column, row, .backslash))
            default: break
            }
        }
    }
    return Board(width: width, height: height, tiles: tiles)
}

@Suite struct BeamTracerTests {
    @Test func theFirstLevelEndsAtTheWallAndItsSolutionAtTheTarget() throws {
        let level = LevelCatalog.bundled.levels[0]
        let start = BeamTracer.trace(level.board)
        #expect(start.endReasons == [.wall] && start.litTargets.isEmpty && !start.isSolved)
        #expect(start.segments.last?.end == Vec2(2.5, 1))
        let solved = BeamTracer.trace(try #require(level.solvedBoard))
        #expect(solved.endReasons == [.target] && solved.litTargets == [Cell(2, 4)] && solved.isSolved)
        #expect(BeamTracer.isSolved(try #require(level.solvedBoard)))
        #expect(!BeamTracer.isSolved(level.board))
    }

    @Test func mirrorsReflectWithEqualAnglesAndNeverHitThemselvesAgain() {
        let levels: [Level] = LevelCatalog.bundled.levels
        for level in levels {
            guard let board = level.solvedBoard else { continue }
            let beam = BeamTracer.trace(board)
            for index in 1..<beam.segments.count {
                let previous = beam.segments[index - 1]
                let current = beam.segments[index]
                guard previous.branch == current.branch else { continue }
                #expect(current.start == previous.end, "\(level.id) segment \(index) starts where the last ended")
                #expect(current.bounce == previous.bounce + 1, "\(level.id) segment \(index)")
                #expect(current.start.distance(to: current.end) > 0.1, "\(level.id) segment \(index) has length")
                let incoming = (previous.end - previous.start).normalized
                let outgoing = (current.end - current.start).normalized
                // A 45° mirror turns a grid direction by exactly 90°: the angles to the mirror's normal are equal.
                #expect(abs(incoming.dot(outgoing)) < 1e-12, "\(level.id) segment \(index) turns by 90°")
                #expect(abs(outgoing.length - 1) < 1e-12)
            }
        }
    }

    @Test func aBeamSentBackToTheEmitterEndsThere() {
        let board = mapBoard(["......",
                              "......",
                              "./.\\.T",
                              "......",
                              ".>./..",
                              "......"])
        #expect(board.problem == nil)
        let beam = BeamTracer.trace(board)
        #expect(beam.endReasons == [.emitter])
        #expect(beam.segments.count == 4)
        #expect(beam.segments.last?.end == Vec2(1.5, 2))
    }

    @Test func aPrismMakesTwoBranches() {
        let board = mapBoard(["..T..",
                              ".....",
                              ">.P.T",
                              ".....",
                              "....."])
        let beam = BeamTracer.trace(board)
        #expect(beam.branchCount == 2 && beam.endReasons == [.target, .target])
        #expect(beam.litTargets == [Cell(2, 4), Cell(4, 2)] && beam.isSolved)
        let expected: [BeamSegment] = [
            BeamSegment(start: Vec2(0.5, 2.5), end: Vec2(2.5, 2.5), bounce: 0, branch: 0),
            BeamSegment(start: Vec2(2.5, 2.5), end: Vec2(2.5, 4.2), bounce: 1, branch: 0),
            BeamSegment(start: Vec2(2.5, 2.5), end: Vec2(4.2, 2.5), bounce: 0, branch: 1),
        ]
        #expect(beam.segments.count == expected.count)
        for index in 0..<min(beam.segments.count, expected.count) {
            let segment = beam.segments[index]
            #expect(segment.start == expected[index].start && segment.bounce == expected[index].bounce)
            #expect(segment.branch == expected[index].branch)
            #expect(segment.end.distance(to: expected[index].end) < 1e-12)
        }
    }

    @Test func branchesThatReachTracedStatesEndWithLoop() {
        // Branch 0 turns north at the prism, goes round the mirrors, comes back through the prism and leaves the board
        // to the south; branch 1 (straight on) goes round the other way, back through the prism and to the emitter;
        // the straight-on branches of those two passes (branches 2 and 3) start in states already traced.
        let board = mapBoard(["......",
                              "......",
                              "../.\\.",
                              "......",
                              ">.P./T",
                              "......"])
        #expect(board.problem == nil)
        let beam = BeamTracer.trace(board)
        #expect(beam.endReasons == [.leftBoard, .emitter, .loop, .loop])
        #expect(beam.segments.count == 11)
    }

    @Test func theBounceCapHolds() {
        let board = mapBoard([#"...........T"#,
                              #"../.\/\....."#,
                              #".//....\./.\"#,
                              #".\/.\..\\..."#,
                              #"../\/./\\\\."#,
                              #"./.\...////."#,
                              #".\...//\\\\/"#,
                              #"..\/\././\/."#,
                              #"......\/...."#,
                              #"..././......"#,
                              #"............"#,
                              #">../........"#])
        #expect(board.problem == nil)
        let beam = BeamTracer.trace(board)
        #expect(beam.endReasons == [.bounceCap])
        #expect(beam.segments.count == BeamTracer.maxBounces + 1)
        #expect(beam.segments.map(\.bounce).max() == BeamTracer.maxBounces)
        #expect(BeamTracer.maxBounces == 64)
    }

    @Test func theSegmentCapHolds() {
        let board = mapBoard([#"...........T"#,
                              #"...../\P\.//"#,
                              #"../\P\\\\\.."#,
                              #".//\/\/\/P.."#,
                              #"///..\\\\\.."#,
                              #"\/P///P\.P.."#,
                              #".\\//\/\\\.."#,
                              #".//\\Q\\\\/."#,
                              #"/PQ/\Q.\\/.."#,
                              #"/\\/\P.Q\\.."#,
                              #"\\P/\\////.."#,
                              #">//\Q/\\/..."#])
        #expect(board.problem == nil)
        let beam = BeamTracer.trace(board)
        #expect(beam.segments.count == BeamTracer.maxSegments && BeamTracer.maxSegments == 256)
        #expect(beam.endReasons.contains(.segmentCap))
        #expect(beam.endReasons.last == .segmentCap)
        #expect(beam.branchCount <= BeamTracer.maxBranches)
    }

    @Test func theBranchCapHolds() {
        // Two rows of prisms: every prism splits, far more than 16 branches would start.
        var tiles: [Tile] = [.emitter(0, 0, .east), .target(0, 11)]
        for column in 1...11 {
            tiles.append(.prism(column, 0, .slash))
            tiles.append(.prism(column, 5, .backslash))
        }
        let board = Board(width: 12, height: 12, tiles: tiles)
        #expect(board.problem == nil)
        let beam = BeamTracer.trace(board)
        #expect(beam.branchCount == BeamTracer.maxBranches && BeamTracer.maxBranches == 16)
        #expect(beam.droppedBranches == 5)
        #expect(beam.segments.allSatisfy { $0.branch < BeamTracer.maxBranches })
        #expect(!beam.endReasons.contains(.segmentCap))
    }

    @Test func everyLevelTracesIdenticallyTwice() {
        let levels: [Level] = LevelCatalog.bundled.levels
        for level in levels {
            #expect(BeamTracer.trace(level.board) == BeamTracer.trace(level.board), "\(level.id) start")
            if let solved = level.solvedBoard {
                #expect(BeamTracer.trace(solved) == BeamTracer.trace(solved), "\(level.id) solved")
            }
        }
    }

    @Test func everySegmentStaysOnTheBoard() {
        let levels: [Level] = LevelCatalog.bundled.levels
        for level in levels {
            let boards: [Board] = [level.board, level.solvedBoard ?? level.board]
            for board in boards {
                let beam = BeamTracer.trace(board)
                #expect(beam.endReasons.count == beam.branchCount && !beam.segments.isEmpty)
                for segment in beam.segments {
                    let points: [Vec2] = [segment.start, segment.end]
                    for point in points {
                        #expect(point.isFinite && point.x >= 0 && point.y >= 0, "\(level.id)")
                        #expect(point.x <= Double(board.width) && point.y <= Double(board.height), "\(level.id)")
                    }
                }
            }
        }
    }

    @Test func anInvalidBoardGivesAnEmptyBeam() {
        let board = Board(width: 5, height: 5, tiles: [.emitter(0, 0, .east)])
        #expect(board.problem == .noTarget)
        let beam = BeamTracer.trace(board)
        #expect(beam.segments.isEmpty && beam.endReasons.isEmpty && !beam.isSolved && beam.litTargets.isEmpty)
    }

    @Test func theReasonNamesAreStable() {
        #expect(BeamEnd.allCases.map(\.rawValue) == ["left-board", "wall", "target", "emitter", "loop", "bounce-cap",
                                                    "segment-cap"])
    }
}
