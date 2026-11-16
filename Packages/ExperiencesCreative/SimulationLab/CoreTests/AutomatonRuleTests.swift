// AutomatonRuleTests — feature 117 (A16-P01) T-A16-103 (FR-A16-101; SC-A16-101; clarification Q1). The cellular
// automaton, host-free and short: B/S notation parses and refuses malformed text; the Life blinker has period 2 and
// differs after 1 step (also across the wrap edge); a block is still after 10 steps; a glider wraps across the edges
// back to its shape and place after 4 · N steps on an N × N grid; Seeds keeps no cell; the field stays exact 0 and 1.
import Testing
import VisualCoreSimulation
@testable import SimulationLabCore

@Suite struct AutomatonRuleTests {
    /// `grid` after `n` steps of `rule`.
    private func run(_ rule: AutomatonRule, _ grid: FieldGrid, steps n: Int) -> FieldGrid {
        var g = grid
        for _ in 0..<n { g = rule.step(g) }
        return g
    }

    /// `grid` moved by (dx, dy) with wrap.
    private func shifted(_ grid: FieldGrid, dx: Int, dy: Int) -> FieldGrid {
        var out = grid
        let w = grid.width, h = grid.height
        for y in 0..<h {
            for x in 0..<w { out[(x + dx + w) % w, (y + dy + h) % h, 0] = grid[x, y, 0] }
        }
        return out
    }

    @Test func notationParsesThePresets() {
        #expect(AutomatonRule(notation: "B3/S23") == .life)
        #expect(AutomatonRule(notation: "b36/s23") == .highLife)
        #expect(AutomatonRule(notation: "B63/S32") == .highLife)
        #expect(AutomatonRule(notation: "B2/S") == .seeds)
        #expect(AutomatonRule.life.notation == "B3/S23" && AutomatonRule.highLife.notation == "B36/S23")
        #expect(AutomatonRule.seeds.notation == "B2/S")
        #expect(AutomatonRule.presets == [.life, .highLife, .seeds])
        for rule in AutomatonRule.presets { #expect(AutomatonRule(notation: rule.notation) == rule) }
        #expect(AutomatonRule(notation: "B/S012345678")?.survival.count == 9)
    }

    @Test func malformedNotationIsRefused() {
        let refused: [String] = ["", "B3", "S23/B3", "B9/S23", "B33/S23", "B3/S2x", "B3/S23/", "3/23", "B3 /S23",
                                 "B3/S23 ", "B-3/S23", "B3/X23", "B٣/S23"]
        for text in refused { #expect(AutomatonRule(notation: text) == nil, "\(text)") }
    }

    @Test func theBlinkerHasPeriodTwo() {
        let start = Seeding.pattern(gridSize: 8, alive: [(x: 2, y: 4), (x: 3, y: 4), (x: 4, y: 4)])
        let vertical = Seeding.pattern(gridSize: 8, alive: [(x: 3, y: 3), (x: 3, y: 4), (x: 3, y: 5)])
        let rules: [AutomatonRule] = [.life, .highLife]
        for rule in rules {
            let one = rule.step(start)
            #expect(one != start && one == vertical)
            #expect(rule.step(one) == start)
        }
    }

    @Test func aBlinkerAcrossTheWrapEdgeHasPeriodTwo() {
        let start = Seeding.pattern(gridSize: 8, alive: [(x: 7, y: 0), (x: 0, y: 0), (x: 1, y: 0)])
        let one = AutomatonRule.life.step(start)
        #expect(one != start && one[0, 7, 0] == 1 && one[0, 1, 0] == 1 && AutomatonRule.liveCount(one) == 3)
        #expect(AutomatonRule.life.step(one) == start)
    }

    @Test func theBlockIsStillAfterTenSteps() {
        let block = Seeding.pattern(gridSize: 8, alive: [(x: 3, y: 3), (x: 4, y: 3), (x: 3, y: 4), (x: 4, y: 4)])
        for n in 1...10 { #expect(run(.life, block, steps: n) == block, "\(n)") }
    }

    @Test func aGliderWrapsBackToItsShapeAfterFourNSteps() {
        let sizes: [Int] = [8, 16]
        for n in sizes {
            let glider = Seeding.pattern(gridSize: n, alive: [(x: 1, y: 0), (x: 2, y: 1), (x: 0, y: 2), (x: 1, y: 2),
                                                              (x: 2, y: 2)])
            let four = run(.life, glider, steps: 4)
            #expect(four != glider && four == shifted(glider, dx: 1, dy: 1))
            #expect(run(.life, glider, steps: 4 * n) == glider, "\(n)")
            #expect(run(.life, glider, steps: 2 * n) != glider, "\(n)")
        }
    }

    @Test func seedsKeepsNoCellAndAnEmptyGridStaysEmpty() {
        let single = Seeding.pattern(gridSize: 8, alive: [(x: 4, y: 4)])
        #expect(AutomatonRule.liveCount(AutomatonRule.seeds.step(single)) == 0)
        let pair = Seeding.pattern(gridSize: 8, alive: [(x: 3, y: 4), (x: 4, y: 4)])
        let next = AutomatonRule.seeds.step(pair)
        #expect(next[3, 4, 0] == 0 && next[4, 4, 0] == 0 && AutomatonRule.liveCount(next) == 4)
        let empty = FieldGrid(width: 8, height: 8, channels: 1)
        for rule in AutomatonRule.presets { #expect(rule.step(empty) == empty) }
    }

    @Test func theFieldStaysExactZeroAndOne() {
        var grid = Seeding.automatonStart(gridSize: 16, seed: 11)
        for _ in 0..<20 {
            grid = AutomatonRule.highLife.step(grid)
            #expect(grid.values.allSatisfy { $0 == 0 || $0 == 1 })
            #expect(grid.rounded(to: .unorm8) == grid)
        }
    }
}
