// BoardDescription — feature 099 (A13-P04) T-A13-403 (FR-A13-410, FR-A13-411; clarifications Q2 and Q5; data-model
// "BoardDescription"). The Light Maze board in words: a short summary of the lit targets for the board element's
// accessible value, and the full description the Describe control shows and speaks.
//
// Places are "row R, column C", counted from 1, columns from the left and rows from the bottom (as the presenter's
// selected-tile words). Orientations: slash "leaning right", backslash "leaning left"; directions by their raw values.
//
// The full text is plain sentences joined by single spaces, in this order:
// 1. "Level 3, Bounce: 5 by 5 board." (width by height);
// 2. one sentence per tile kind present, in the order emitters, walls, mirrors, prisms, listing the places in board
//    tile order ("Emitter: row 3, column 1, facing east." / "Walls: row 2, column 3; row 4, column 1." / "Mirrors: row
//    2, column 3, leaning right; row 4, column 1, leaning left." / prisms as mirrors), the label singular for one tile;
// 3. one sentence per beam branch: "Beam 1 starts at row 1, column 1 heading east, turns at row 1, column 4, and ends
//    at the target at row 3, column 4." ("turns at …" left out for a branch of one segment; "Beam 2 stops at once at a
//    loop." for a split that ended before its first cast), or "No beam." when the beam has no segments;
// 4. the targets, last as in clarification Q5: "Targets: row 3, column 4, lit; row 5, column 2, unlit."
//
// Cells of a branch: it starts in the cell containing its first segment's start nudged 1e-6 along the segment (the
// emitter's cell for branch 0, the prism's cell for a split); it turns in the cell containing the end of each segment
// followed by another of the same branch, nudged 1e-6 back along the incoming segment (consecutive repeats removed);
// it ends where its last segment's end, nudged 1e-6 forward, lies: a wall, target or emitter cell named by the end
// reason, otherwise "the board's edge", "a loop", "the bounce limit" or "the segment limit".
//
// Bound: at most ``BoardDescription/maxLength`` characters. When the text would be longer, every list (tile places
// and turn cells) keeps its first entries and ends with "and N more", the number of kept entries halving until the
// text fits; a final prefix cut guarantees the bound.
import Foundation
import VisualCoreMath

/// The Light Maze board in words: the lit-target summary and the full spoken description.
public enum BoardDescription {
    /// The most characters a full description holds.
    public static let maxLength = 4_000

    /// The distance a point is moved along a segment so a point on a cell edge resolves to the intended cell.
    private static let nudge = 1e-6

    /// "K of T targets lit": K the distinct target cells of `board` in `beam.litTargets`, T the board's target count
    /// ("target" singular when T is 1, as "0 of 1 target lit").
    public static func targetWords(board: Board, beam: Beam) -> String {
        let targets = board.targetCells
        var lit = Set<Cell>()
        for cell in beam.litTargets where targets.contains(cell) {
            lit.insert(cell)
        }
        let noun = targets.count == 1 ? "target" : "targets"
        return "\(lit.count) of \(targets.count) \(noun) lit"
    }

    /// The full description of `board` with its traced `beam` for level number `levelNumber` named `levelName` (see
    /// the file header for the sentences); at most ``maxLength`` characters.
    public static func full(levelName: String, levelNumber: Int, board: Board, beam: Beam) -> String {
        var text = compose(levelName: levelName, levelNumber: levelNumber, board: board, beam: beam, limit: nil)
        if text.count <= maxLength { return text }
        var limit = 64
        while limit >= 1 {
            text = compose(levelName: levelName, levelNumber: levelNumber, board: board, beam: beam, limit: limit)
            if text.count <= maxLength { return text }
            limit /= 2
        }
        return String(text.prefix(maxLength))
    }

    /// The sentences of the description, every list cut to `limit` entries (nil: no cut).
    private static func compose(levelName: String, levelNumber: Int, board: Board, beam: Beam, limit: Int?) -> String {
        var sentences: [String] = []
        sentences.append("Level \(levelNumber), \(levelName): \(board.width) by \(board.height) board.")
        let kinds: [TileKind] = [.emitter, .wall, .mirror, .prism]
        for kind in kinds {
            var places: [String] = []
            for tile in board.tiles where tile.kind == kind {
                places.append(tileWords(tile))
            }
            if places.isEmpty { continue }
            sentences.append(label(kind, count: places.count) + ": " + list(places, separator: "; ", limit: limit) + ".")
        }
        if beam.segments.isEmpty {
            sentences.append("No beam.")
        } else {
            for branch in 0..<beam.branchCount {
                if let words = branchWords(branch, beam: beam, limit: limit) {
                    sentences.append(words)
                }
            }
        }
        let lit = Set(beam.litTargets)
        var targets: [String] = []
        for tile in board.tiles where tile.kind == .target {
            targets.append(place(tile.cell) + (lit.contains(tile.cell) ? ", lit" : ", unlit"))
        }
        if !targets.isEmpty {
            sentences.append(label(.target, count: targets.count) + ": "
                + list(targets, separator: "; ", limit: limit) + ".")
        }
        return sentences.joined(separator: " ")
    }

    /// One tile's place with its direction (emitter) or orientation (mirror, prism).
    private static func tileWords(_ tile: Tile) -> String {
        var words = place(tile.cell)
        switch tile.kind {
        case .emitter:
            if let direction = tile.direction { words += ", facing \(direction.rawValue)" }
        case .mirror, .prism:
            words += ", " + orientationWords(tile.orientation ?? .slash)
        case .wall, .target:
            break
        }
        return words
    }

    /// "row R, column C", counted from 1 (rows from the bottom, columns from the left).
    private static func place(_ cell: Cell) -> String { "row \(cell.row + 1), column \(cell.column + 1)" }

    /// Slash "leaning right", backslash "leaning left".
    private static func orientationWords(_ orientation: Orientation) -> String {
        orientation == .slash ? "leaning right" : "leaning left"
    }

    /// The label of a tile kind's sentence, singular for one tile.
    private static func label(_ kind: TileKind, count: Int) -> String {
        let singular: String
        switch kind {
        case .emitter: singular = "Emitter"
        case .wall: singular = "Wall"
        case .mirror: singular = "Mirror"
        case .prism: singular = "Prism"
        case .target: singular = "Target"
        }
        return count == 1 ? singular : singular + "s"
    }

    /// `items` joined by `separator`, the first `limit` of them followed by "and N more" when cut.
    private static func list(_ items: [String], separator: String, limit: Int?) -> String {
        guard let limit, items.count > limit else { return items.joined(separator: separator) }
        let kept = Array(items.prefix(max(limit, 0)))
        let more = "and \(items.count - kept.count) more"
        if kept.isEmpty { return more }
        return kept.joined(separator: separator) + separator + more
    }

    /// Turn places joined as "A", "A and B" or "A, B and C"; when cut, "A, B and N more".
    private static func turnList(_ items: [String], limit: Int?) -> String {
        if let limit, items.count > limit {
            return list(items, separator: ", ", limit: limit).replacingOccurrences(of: ", and ", with: " and ")
        }
        if items.count <= 2 { return items.joined(separator: " and ") }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }

    /// The direction from `start` to `end` (east for a zero-length segment).
    private static func direction(_ segment: BeamSegment) -> Direction {
        Direction.nearest(to: segment.end - segment.start) ?? .east
    }

    /// The sentence of branch `branch` (numbered from 1): "stops at once" for a branch without segments (a split that
    /// met a cap or a loop before its first cast), nil for a branch the beam does not have.
    private static func branchWords(_ branch: Int, beam: Beam, limit: Int?) -> String? {
        var pieces: [BeamSegment] = []
        for segment in beam.segments where segment.branch == branch {
            pieces.append(segment)
        }
        let reason: BeamEnd? = beam.endReasons.indices.contains(branch) ? beam.endReasons[branch] : nil
        guard let first = pieces.first, let last = pieces.last else {
            if reason == nil { return nil }
            return "Beam \(branch + 1) stops at once at " + endWords(reason, cell: nil) + "."
        }
        let heading = direction(first)
        let startPoint = first.start + heading.vector * nudge
        let startCell = Cell(containing: startPoint) ?? Cell(0, 0)
        var words = "Beam \(branch + 1) starts at \(place(startCell)) heading \(heading.rawValue)"
        var turns: [String] = []
        var previous: Cell?
        if pieces.count > 1 {
            for index in 0..<(pieces.count - 1) {
                let piece = pieces[index]
                let point = piece.end - direction(piece).vector * nudge
                guard let cell = Cell(containing: point), cell != previous else { continue }
                turns.append(place(cell))
                previous = cell
            }
        }
        if !turns.isEmpty { words += ", turns at " + turnList(turns, limit: limit) + "," }
        let endCell = Cell(containing: last.end + direction(last).vector * nudge)
        words += " and ends at " + endWords(reason, cell: endCell) + "."
        return words
    }

    /// Where a branch ends, in words, by its end reason and the cell its last segment ends in.
    private static func endWords(_ reason: BeamEnd?, cell: Cell?) -> String {
        guard let reason else { return "an unknown place" }
        switch reason {
        case .wall:
            if let cell { return "the wall at " + place(cell) }
            return "a wall"
        case .target:
            if let cell { return "the target at " + place(cell) }
            return "a target"
        case .emitter:
            if let cell { return "the emitter at " + place(cell) }
            return "the emitter"
        case .leftBoard: return "the board's edge"
        case .loop: return "a loop"
        case .bounceCap: return "the bounce limit"
        case .segmentCap: return "the segment limit"
        }
    }
}
