// SimulationBrushTests — feature 120 (A16-P04) T-A16-402 (FR-A16-401; SC-A16-401; clarification Q1). The paint
// brush, host-free and short, on the 64 × 64 standard starts: in each family a tap writes exactly the brush's cells
// (automaton toggle, reaction-diffusion u 0.25 and v 0.5 in radius 2 with wrap, wave height 1 in the cell and its four
// neighbours in both fields) and leaves every other cell as it was; an automaton tap twice restores the field and a
// drag sets the cell alive; a wave tap at the edge keeps the edges 0; a cell outside the grid changes nothing; the
// step count never changes.
import Testing
import VisualCoreSimulation
@testable import SimulationLabCore

@Suite struct SimulationBrushTests {
    /// The standard model of `kind`, paused.
    private func model(_ kind: SimulationKind) throws -> SimulationModel {
        try SimulationModel(spec: .standard(kind, preset: 0, seed: 1), running: false)
    }

    /// The set of cell indices (y · n + x) in `cells`.
    private func indexSet(_ cells: [(Int, Int)], n: Int) -> Set<Int> {
        var out = Set<Int>()
        for (x, y) in cells { out.insert(y * n + x) }
        return out
    }

    /// The cell indices where any channel of `a` and `b` differs.
    private func changed(_ a: FieldGrid, _ b: FieldGrid) -> Set<Int> {
        var out = Set<Int>()
        for cell in 0..<(a.width * a.height) {
            for c in 0..<a.channels where a.values[cell * a.channels + c] != b.values[cell * b.channels + c] {
                out.insert(cell)
            }
        }
        return out
    }

    @Test func anAutomatonTapTogglesExactlyOneCellAndTwiceRestores() throws {
        var m = try model(.automaton)
        let before = m.field
        let steps = m.stepCount
        do { let painted = m.paint(x: 10, y: 20, mode: .tap); #expect(painted) }
        #expect(changed(before.current, m.field.current) == [20 * 64 + 10])
        #expect(m.field.current[10, 20, 0] == 1 - before.current[10, 20, 0])
        do { let painted = m.paint(x: 10, y: 20, mode: .tap); #expect(painted) }
        #expect(m.field == before)
        #expect(m.stepCount == steps)
    }

    @Test func anAutomatonDragSetsTheCellAlive() throws {
        var m = try model(.automaton)
        for _ in 0..<2 {
            do { let painted = m.paint(x: 5, y: 7, mode: .drag); #expect(painted) }
            #expect(m.field.current[5, 7, 0] == 1)
        }
        #expect(SimulationBrush.cells(kind: .automaton, x: 5, y: 7, size: 64).count == 1)
    }

    @Test func aReactionTapWritesExactlyTheWrappedDisc() throws {
        var m = try model(.reactionDiffusion)
        let before = m.field
        let cells = SimulationBrush.cells(kind: .reactionDiffusion, x: 0, y: 63, size: 64)
        #expect(cells.count == 13)
        do { let painted = m.paint(x: 0, y: 63, mode: .tap); #expect(painted) }
        #expect(changed(before.current, m.field.current) == indexSet(cells, n: 64))
        for (x, y) in cells {
            #expect(m.field.current[x, y, 0] == 0.25 && m.field.current[x, y, 1] == 0.5)
        }
        let wrapped = indexSet(cells, n: 64)
        #expect(wrapped.contains(63 * 64 + 62) && wrapped.contains(61 * 64 + 0) && wrapped.contains(0 * 64 + 0))
        #expect(m.stepCount == 0)
    }

    @Test func aWaveTapWritesTheCellAndItsNeighboursInBothFields() throws {
        var m = try model(.wave)
        let before = m.field
        let cells = SimulationBrush.cells(kind: .wave, x: 12, y: 40, size: 64)
        #expect(cells.count == 5)
        do { let painted = m.paint(x: 12, y: 40, mode: .tap); #expect(painted) }
        let brush = indexSet(cells, n: 64)
        let previous = try #require(m.field.previous)
        let previousBefore = try #require(before.previous)
        #expect(changed(before.current, m.field.current).isSubset(of: brush))
        #expect(changed(previousBefore, previous).isSubset(of: brush))
        for (x, y) in cells { #expect(m.field.current[x, y, 0] == 1 && previous[x, y, 0] == 1) }
        #expect(m.stepCount == 0)
    }

    @Test func aWaveTapAtTheEdgeKeepsTheEdgesZero() throws {
        var m = try model(.wave)
        #expect(SimulationBrush.cells(kind: .wave, x: 0, y: 0, size: 64).isEmpty)
        #expect(SimulationBrush.cells(kind: .wave, x: 1, y: 1, size: 64).count == 3, "the cell and its two interior neighbours")
        #expect(SimulationBrush.cells(kind: .wave, x: 63, y: 30, size: 64).count == 1)
        do { let painted = m.paint(x: 1, y: 1, mode: .tap); #expect(painted) }
        do { let painted = m.paint(x: 63, y: 30, mode: .drag); #expect(painted) }
        let previous = try #require(m.field.previous)
        for i in 0..<64 {
            let edges = [m.field.current[i, 0, 0], m.field.current[i, 63, 0], m.field.current[0, i, 0],
                         m.field.current[63, i, 0], previous[i, 0, 0], previous[i, 63, 0], previous[0, i, 0],
                         previous[63, i, 0]]
            for value in edges { #expect(value == 0) }
        }
        #expect(m.field.current[1, 1, 0] == 1 && m.field.current[62, 30, 0] == 1)
    }

    @Test func aWaveFieldWithoutPreviousGetsACopy() {
        let grid = FieldGrid(width: 8, height: 8, channels: 1)
        let painted = SimulationBrush.painted(SimulationField(current: grid), kind: .wave, x: 3, y: 3, mode: .tap,
                                              precision: .float16)
        #expect(painted?.previous == painted?.current)
        #expect(painted?.current[3, 4, 0] == 1)
    }

    @Test func outsideTheGridNothingChanges() throws {
        for kind in SimulationKind.allCases {
            var m = try model(kind)
            let before = m
            let outside = [(-1, 0), (0, -1), (64, 0), (0, 64), (100, 100)]
            for (x, y) in outside {
                do { let painted = m.paint(x: x, y: y, mode: .tap); #expect(!painted) }
                do { let painted = m.paint(x: x, y: y, mode: .drag); #expect(!painted) }
                #expect(SimulationBrush.cells(kind: kind, x: x, y: y, size: 64).isEmpty)
            }
            #expect(m == before)
        }
    }

    @Test func paintingNeverChangesTheStepCount() throws {
        for kind in SimulationKind.allCases {
            var m = try model(kind)
            m.step()
            m.step()
            do { let painted = m.paint(x: 32, y: 32, mode: .tap); #expect(painted) }
            do { let painted = m.paint(x: 33, y: 32, mode: .drag); #expect(painted) }
            #expect(m.stepCount == 2)
        }
    }
}
