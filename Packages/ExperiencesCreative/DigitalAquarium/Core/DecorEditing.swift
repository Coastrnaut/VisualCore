// DecorEditing — feature 070 (A09-P03) T-A09-304 (FR-A09-310; clarification 2; contracts/api.md). Placing, moving and
// removing decor pieces of a habitat document. Positions are clamped into the 16 × 9 tank (x 0…16, y 0…9, y up); a
// placement at the limit of ``HabitatDocument/maxDecor`` pieces or of an empty kind id is refused, and a move or
// removal of a missing index is refused, each leaving the document unchanged. A new piece has rotation 0 and scale 1.
// Action fractions (0…1, x left→right, y bottom→top) become tank points through `tankPoint(fractionX:fractionY:)`.
import Foundation
import VisualCoreMath

/// Pure decor editing on a ``HabitatDocument``: place, move and remove pieces, positions clamped into the tank.
public enum DecorEditing {
    /// The tank point of a pair of fractions: (`fractionX` × 16, `fractionY` × 9). Each fraction is clamped to 0…1; a
    /// non-finite fraction counts as 0.5 (the middle).
    public static func tankPoint(fractionX: Double, fractionY: Double) -> Vec2 {
        Vec2(unit(fractionX) * SwimBounds.tankWidth, unit(fractionY) * SwimBounds.tankHeight)
    }

    /// Appends a piece of `kindId` at `point` (clamped into the tank) with rotation 0 and scale 1. Returns false and
    /// leaves `doc` unchanged when the document already holds ``HabitatDocument/maxDecor`` pieces or `kindId` is
    /// empty.
    @discardableResult
    public static func place(kindId: String, at point: Vec2, into doc: inout HabitatDocument) -> Bool {
        guard !kindId.isEmpty, doc.decor.count < HabitatDocument.maxDecor else { return false }
        doc.decor.append(DecorPlacement(kindId: kindId, position: clamped(point), rotation: 0, scale: 1))
        return true
    }

    /// Moves the piece at `index` to `point` (clamped into the tank). Returns false and leaves `doc` unchanged when
    /// there is no piece at `index`.
    @discardableResult
    public static func move(index: Int, to point: Vec2, in doc: inout HabitatDocument) -> Bool {
        guard doc.decor.indices.contains(index) else { return false }
        doc.decor[index].position = clamped(point)
        return true
    }

    /// Removes the piece at `index`; the later pieces move down by one. Returns false and leaves `doc` unchanged when
    /// there is no piece at `index`.
    @discardableResult
    public static func remove(index: Int, from doc: inout HabitatDocument) -> Bool {
        guard doc.decor.indices.contains(index) else { return false }
        doc.decor.remove(at: index)
        return true
    }

    /// `point` clamped into the tank (x 0…16, y 0…9); a non-finite coordinate becomes the tank's middle on that axis.
    static func clamped(_ point: Vec2) -> Vec2 {
        Vec2(clamp(point.x, SwimBounds.tankWidth), clamp(point.y, SwimBounds.tankHeight))
    }

    private static func clamp(_ value: Double, _ limit: Double) -> Double {
        value.isFinite ? min(max(value, 0), limit) : limit / 2
    }

    private static func unit(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0.5
    }
}
