// BoardTests — feature 096 (A13-P01) T-A13-103 (FR-A13-110, FR-A13-112; clarification Q2; data-model "Direction",
// "Orientation", "Tile", "Board"). The board, host-free and short: direction unit vectors and snapping; the orientation
// toggle; each tile's segments in board coordinates (wall square, target square of side 0.6, mirror and prism
// diagonals by orientation, emitter square); the geometry's order and owners with the four board edges; every
// refusal reason named in order; turnable tiles and applying orientations; the flat tile JSON.
import Foundation
import LightMazeCore
import Testing
import VisualCoreMath

@Suite struct BoardTests {
    /// A valid 5 × 5 board: emitter, mirror, prism, wall and target.
    private let board = Board(width: 5, height: 5, tiles: [
        .emitter(0, 2, .east), .mirror(2, 2, .slash), .wall(4, 4), .prism(3, 1, .backslash), .target(2, 4),
    ])

    @Test func directionsAreUnitGridVectors() {
        let vectors: [Vec2] = Direction.allCases.map(\.vector)
        #expect(vectors == [Vec2(1, 0), Vec2(0, 1), Vec2(-1, 0), Vec2(0, -1)])
        for direction in Direction.allCases {
            #expect(Double(direction.step.column) == direction.vector.x)
            #expect(Double(direction.step.row) == direction.vector.y)
            #expect(Direction.nearest(to: direction.vector * 3) == direction)
        }
        #expect(Direction.nearest(to: Vec2(2.220446049250313e-16, 0.9999999999999998)) == .north)
        #expect(Direction.nearest(to: Vec2(-1, 1)) == .west)
        #expect(Direction.nearest(to: .zero) == nil)
        #expect(Direction.nearest(to: Vec2(.nan, 1)) == nil)
    }

    @Test func orientationsToggle() {
        #expect(Orientation.slash.toggled == .backslash && Orientation.backslash.toggled == .slash)
        #expect(Orientation.slash.symbol == "/" && Orientation.backslash.symbol == "\\")
        #expect(TileKind.allCases.filter(\.isTurnable) == [.mirror, .prism])
    }

    @Test func tileSegmentsAreInBoardCoordinates() {
        let wall: [Segment2] = Tile.wall(2, 3).segments
        #expect(wall == [Segment2(Vec2(2, 3), Vec2(3, 3)), Segment2(Vec2(3, 3), Vec2(3, 4)),
                         Segment2(Vec2(3, 4), Vec2(2, 4)), Segment2(Vec2(2, 4), Vec2(2, 3))])
        #expect(Tile.emitter(2, 3, .north).segments == wall)
        #expect(Tile.mirror(1, 2, .slash).segments == [Segment2(Vec2(1, 2), Vec2(2, 3))])
        #expect(Tile.mirror(1, 2, .backslash).segments == [Segment2(Vec2(1, 3), Vec2(2, 2))])
        #expect(Tile.prism(1, 2, .slash).segments == Tile.mirror(1, 2, .slash).segments)
        #expect(Tile.prism(1, 2, .backslash).segments == Tile.mirror(1, 2, .backslash).segments)
        let target: [Segment2] = Tile.target(4, 1).segments
        #expect(target.count == 4)
        for segment in target {
            #expect(abs(segment.a.distance(to: segment.b) - Tile.targetSide) < 1e-12)
        }
        #expect(abs(target[0].a.x - 4.2) < 1e-12 && abs(target[0].a.y - 1.2) < 1e-12)
        #expect(abs(target[2].a.x - 4.8) < 1e-12 && abs(target[2].a.y - 1.8) < 1e-12)
        #expect(Tile.targetSide == 0.6)
    }

    @Test func theGeometryListsTileSegmentsThenTheBoardEdges() {
        let geometry = board.geometry
        #expect(geometry.segments.count == 4 + 1 + 4 + 1 + 4 + 4)
        #expect(geometry.owners.count == geometry.segments.count)
        #expect(geometry.tileSegments == [[0, 1, 2, 3], [4], [5, 6, 7, 8], [9], [10, 11, 12, 13]])
        #expect(geometry.owners[4] == .tile(1) && geometry.owners[13] == .tile(4))
        let edges: [SegmentOwner] = Array(geometry.owners.suffix(4))
        #expect(edges == [.boardEdge, .boardEdge, .boardEdge, .boardEdge])
        #expect(Array(geometry.segments.suffix(4)) == board.edges)
        #expect(board.edges == [Segment2(Vec2(0, 0), Vec2(5, 0)), Segment2(Vec2(5, 0), Vec2(5, 5)),
                                Segment2(Vec2(5, 5), Vec2(0, 5)), Segment2(Vec2(0, 5), Vec2(0, 0))])
    }

    @Test func aValidBoardHasNoProblem() {
        #expect(board.problem == nil && board.isValid)
        #expect(Board.validated(width: 5, height: 5, tiles: board.tiles) == .success(board))
        #expect(board.emitterIndex == 0 && board.targetCells == [Cell(2, 4)])
        #expect(board.tileIndex(at: Cell(4, 4)) == 2 && board.tileIndex(at: Cell(1, 1)) == nil)
        #expect(board.contains(Cell(4, 4)) && !board.contains(Cell(5, 0)) && !board.contains(Cell(0, -1)))
        #expect(Cell(2, 3).center == Vec2(2.5, 3.5))
        #expect(Cell(containing: Vec2(2.5, 3.99)) == Cell(2, 3) && Cell(containing: Vec2(.infinity, 0)) == nil)
    }

    @Test func everyRefusalIsNamedInOrder() {
        let emitter = Tile.emitter(0, 0, .east), target = Tile.target(3, 3)
        let cases: [(Board, BoardRefusal)] = [
            (Board(width: 3, height: 5, tiles: [emitter, target]), .sizeOutOfRange),
            (Board(width: 5, height: 13, tiles: [emitter, target]), .sizeOutOfRange),
            (Board(width: 12, height: 12, tiles: Array(repeating: target, count: 145)), .tooManyTiles),
            (Board(width: 4, height: 4, tiles: [emitter, .target(4, 0)]), .outsideBoard),
            (Board(width: 4, height: 4, tiles: [emitter, .target(0, -1)]), .outsideBoard),
            (Board(width: 4, height: 4, tiles: [emitter, target, .wall(3, 3)]), .duplicateCell),
            (Board(width: 4, height: 4, tiles: [Tile(kind: .emitter, cell: Cell(0, 0)), target]), .missingDirection),
            (Board(width: 4, height: 4, tiles: [emitter, target, Tile(kind: .prism, cell: Cell(1, 1))]),
             .missingOrientation),
            (Board(width: 4, height: 4, tiles: [target]), .emitterCount),
            (Board(width: 4, height: 4, tiles: [emitter, .emitter(1, 0, .north), target]), .emitterCount),
            (Board(width: 4, height: 4, tiles: [emitter, .wall(2, 2)]), .noTarget),
        ]
        for (candidate, reason) in cases {
            #expect(candidate.problem == reason, "\(reason.rawValue)")
            #expect(Board.validated(width: candidate.width, height: candidate.height, tiles: candidate.tiles)
                == .failure(reason))
        }
        #expect(BoardRefusal.allCases.map(\.rawValue) == ["size-out-of-range", "too-many-tiles", "outside-board",
                                                         "duplicate-cell", "missing-direction", "missing-orientation",
                                                         "emitter-count", "no-target"])
        let full = (0..<144).map { Tile.wall($0 % 12, $0 / 12) }
        #expect(Board(width: 12, height: 12, tiles: full).problem == .emitterCount)
    }

    @Test func turnableTilesTakeOrientations() throws {
        #expect(board.turnableIndices == [1, 3])
        #expect(board.orientations == [.slash, .backslash])
        let turned = try #require(board.applying([.backslash, .slash]))
        #expect(turned.orientations == [.backslash, .slash])
        #expect(turned.tiles[1].orientation == .backslash && turned.tiles[3].orientation == .slash)
        #expect(turned.tiles[0] == board.tiles[0] && turned.tiles[2] == board.tiles[2])
        #expect(board.applying([.slash]) == nil && board.applying([.slash, .slash, .slash]) == nil)
    }

    @Test func tilesUseAFlatJSONLayout() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let emitter = String(decoding: try encoder.encode(Tile.emitter(1, 2, .west)), as: UTF8.self)
        #expect(emitter == #"{"column":1,"direction":"west","kind":"emitter","row":2}"#)
        let mirror = String(decoding: try encoder.encode(Tile.mirror(3, 0, .backslash)), as: UTF8.self)
        #expect(mirror == #"{"column":3,"kind":"mirror","orientation":"backslash","row":0}"#)
        let decoded = try JSONDecoder().decode(Board.self, from: try encoder.encode(board))
        #expect(decoded == board)
    }
}
