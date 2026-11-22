// NocturneGardenDragPreview — feature 384 (R02-G09-04) T-R02G0904-004 (FR-R02G0904-002; SC-R02G0904-001, 003;
// clarification Q2). The exact diagnostic a bloom drag shows while the finger moves: the would-be shadow of the
// arrangement with the dragged bloom moved to the drag's target anchor, or without it while the finger is outside the
// bed, computed with the kernel's own cell computation (`NocturneGardenMask.union`) on a copy of the blooms under the
// play's sun, with its match (shared and either cells against the target) and its leak (cells in the forbidden
// regions), and the line "would match 12/16, leak 0 cells" or "would remove: match 9/16, leak 0 cells". Presentation
// only: the play is never changed, so the digest is unchanged. Integers only; no clock, no random source.
import Foundation

/// The would-be shadow of a bloom drag in progress (feature 384): the arrangement with one bloom moved or removed.
public struct NocturneGardenDragPreview: Sendable, Equatable {
    /// The dragged bloom's index in the play's blooms (canonical order).
    public let bloom: Int
    /// The target anchor's column (for a removal, the column the finger was over, possibly outside the bed).
    public let column: Int
    /// The target anchor's row (for a removal, the row the finger was over, possibly outside the bed).
    public let row: Int
    /// Whether the preview is of the arrangement without the bloom (the finger is outside the bed).
    public let removes: Bool
    /// The would-be dark cells (row-major indices), ascending.
    public let cells: [Int]
    /// The would-be cells dark and in the target.
    public let shared: Int
    /// The would-be cells dark or in the target.
    public let either: Int
    /// The would-be cells dark and forbidden.
    public let leak: Int

    /// The preview of `play` with bloom `bloom` moved to (`column`, `row`), or removed when `removes`; nil when the
    /// bloom index is not one of the play's blooms or, for a move, when (`column`, `row`) is not a cell of the bed. A
    /// move to the bloom's own anchor previews the arrangement as it is. The play is not changed.
    public static func make(play: NocturneGardenPlay, bloom: Int, column: Int, row: Int,
                            removes: Bool) -> NocturneGardenDragPreview? {
        let level: NocturneGardenLevel = play.level
        guard play.blooms.indices.contains(bloom) else { return nil }
        var blooms: [NocturneGardenBloom] = play.blooms
        if removes {
            blooms.remove(at: bloom)
        } else {
            guard column >= 0, column < level.width, row >= 0, row < level.height else { return nil }
            let old: NocturneGardenBloom = blooms[bloom]
            blooms[bloom] = NocturneGardenBloom(kind: old.kind, column: column, row: row, size: old.size)
        }
        let mask: NocturneGardenMask = NocturneGardenMask.union(blooms, elevation: play.elevation, width: level.width,
                                                                height: level.height)
        return NocturneGardenDragPreview(bloom: bloom, column: column, row: row, removes: removes,
                                         cells: mask.cells.sorted(), shared: mask.intersection(level.target),
                                         either: mask.union(level.target),
                                         leak: mask.leak(forbidden: level.forbidden))
    }

    /// The preview in words: "would match 12/16, leak 0 cells" for a move, "would remove: match 9/16, leak 0 cells"
    /// for a removal (shared over either cells; the cell count worded as `NocturneGardenLevel.cellsText(_:)`).
    public var text: String {
        let words: String = "match \(shared)/\(either), leak \(NocturneGardenLevel.cellsText(leak))"
        return removes ? "would remove: " + words : "would " + words
    }
}
