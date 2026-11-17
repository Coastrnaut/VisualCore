// StoneSelection — feature 147 (A20-P03) T-A20-302 (FR-A20-303, FR-A20-304; clarifications Q2, Q4; data-model.md
// "StoneSelection"; gap G-SELECTION). Layer-aware selection by stone id: `topmost(at:in:)` gives the id of the stone
// of the highest depth whose `StoneShape` contains a point (the same shape the layer draws, so what is seen is what is
// picked), or nil on empty sand; `cycle(from:direction:in:)` gives the neighbour of a stone in depth order, wrapping
// at both ends, for the native previous and next controls. Ids start at 1; the presenter sends 0 for "none". Pure.
import Foundation
import VisualCoreMath

/// Picking and cycling stones in depth order (see the file header).
public enum StoneSelection {
    /// `stones` in ascending depth (the drawing order; equal depths keep their order).
    public static func ordered(_ stones: [Stone]) -> [Stone] {
        stones.enumerated().sorted { lhs, rhs in
            lhs.element.depth != rhs.element.depth ? lhs.element.depth < rhs.element.depth : lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// The id of the highest-depth stone of `stones` whose shape contains `point` (normalized tray coordinates); nil
    /// when no stone does.
    public static func topmost(at point: Vec2, in stones: [Stone]) -> UInt32? {
        for stone in ordered(stones).reversed() {
            if let shape = StoneShape(stone: stone), shape.contains(point) { return stone.id }
        }
        return nil
    }

    /// The id of the neighbour of the stone `id` in depth order: the next higher one for a positive `direction`, the
    /// next lower one otherwise, wrapping at both ends. Without a stone `id` (nil or unknown) a positive direction
    /// gives the lowest stone and a negative one the highest. Nil when there are no stones.
    public static func cycle(from id: UInt32?, direction: Int, in stones: [Stone]) -> UInt32? {
        let order = ordered(stones)
        guard !order.isEmpty else { return nil }
        guard let id, let index = order.firstIndex(where: { $0.id == id }) else {
            return direction >= 0 ? order[0].id : order[order.count - 1].id
        }
        let step = direction >= 0 ? 1 : -1
        let next = (index + step + order.count) % order.count
        return order[next].id
    }

    /// The 1-based place of the stone `id` in depth order (1 is the lowest); nil when no stone has that id.
    public static func place(of id: UInt32, in stones: [Stone]) -> Int? {
        ordered(stones).firstIndex { $0.id == id }.map { $0 + 1 }
    }
}
