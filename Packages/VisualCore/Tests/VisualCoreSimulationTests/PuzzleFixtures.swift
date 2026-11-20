// PuzzleFixtures — feature 223 (R02-F23) T-R02F23-002. Two small original test puzzles with public-domain mechanics:
// 3 × 3 lights-out (a move toggles a cell and its 4-neighbours; solved when all are off; 512 states, 9 moves each) and
// a sliding row (swap two adjacent tiles of a row of 4; solved when sorted; 24 states, 3 moves each).
@testable import VisualCoreSimulation

/// 3 × 3 lights-out: state bit i is cell (i % 3, i / 3).
struct LightsOutRules: PuzzleRules {
    let rulesID = "lights-out-3"
    func moves(in state: UInt16) -> [Int] { Array(0..<9) }
    func apply(_ move: Int, to state: UInt16) -> UInt16? {
        guard move >= 0, move < 9, state < 512 else { return nil }
        let x = move % 3, y = move / 3
        var mask: UInt16 = 1 << move
        if x > 0 { mask |= 1 << (move - 1) }
        if x < 2 { mask |= 1 << (move + 1) }
        if y > 0 { mask |= 1 << (move - 3) }
        if y < 2 { mask |= 1 << (move + 3) }
        return state ^ mask
    }
    func isSolved(_ state: UInt16) -> Bool { state == 0 }
}

/// A row of 4 tiles; move i swaps tiles i and i + 1.
struct SlidingRowRules: PuzzleRules {
    let rulesID = "sliding-row-4"
    func moves(in state: [Int]) -> [Int] { state.count == 4 ? [0, 1, 2] : [] }
    func apply(_ move: Int, to state: [Int]) -> [Int]? {
        guard state.count == 4, move >= 0, move < 3 else { return nil }
        var next = state
        next.swapAt(move, move + 1)
        return next
    }
    func isSolved(_ state: [Int]) -> Bool { state == [0, 1, 2, 3] }
}
