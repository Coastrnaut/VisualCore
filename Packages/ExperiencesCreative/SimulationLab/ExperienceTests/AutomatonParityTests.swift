// AutomatonParityTests — feature 118 (A16-P02) T-A16-203 (FR-A16-201; SC-A16-201, SC-A16-202; clarification Q3;
// contracts/gpu.md). ``AutomatonGPU`` against the CPU reference ``AutomatonRule``, cell for cell: a seeded 64 × 64
// automaton (the experience's grid) and a seeded 16 × 16 one, under each preset rule (Life, HighLife, Seeds), equal the
// reference after 1, 2, 10 and 100 GPU steps; the GPU blinker has period 2 (also across the wrap edge); a GPU glider
// on a 16 grid is back after 4 × 16 steps and shifted by (1, 1) after 4; the rule masks are the documented 9-bit
// values; an invalid step source or grid size throws with nothing left allocated. The GL context comes from a
// `RenderHost` off screen whose scene runs the work inside one `renderOneFrame(present: false)`, with the context
// current on the main thread. A few frames of small grids: far under 10 s.
import Foundation
import SimulationLabCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import SimulationLabExperience

/// A scene that runs `body` inside `render`, with the context current.
@MainActor
private final class AutomatonProbeScene: RenderScene {
    /// The work of the next frame.
    var body: ((RenderContext) throws -> Void)?
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws { try body?(context) }
    func teardown(_ context: RenderContext) {}
}

/// The GPU automaton against the CPU reference.
@MainActor
final class AutomatonParityTests: XCTestCase {
    /// Runs `body` once inside a frame of an off-screen host and rethrows what it threw.
    private func onGPU(_ body: @escaping (ResourceRegistry) throws -> Void) throws {
        let scene = AutomatonProbeScene()
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        defer { host.destroy() }
        var failure: Error?
        var ran = false
        scene.body = { context in
            ran = true
            do { try body(context.resources) } catch { failure = error }
        }
        XCTAssertTrue(host.renderOneFrame(present: false), "the frame ran")
        scene.body = nil
        XCTAssertTrue(ran, "the GPU work ran")
        if let failure { throw failure }
    }

    /// `grid` after `steps` CPU generations of `rule`.
    private func reference(_ rule: AutomatonRule, _ grid: FieldGrid, steps: Int) -> FieldGrid {
        var out = grid
        for _ in 0..<steps { out = rule.step(out) }
        return out
    }

    /// The number of cells in which `a` and `b` differ (all when the shapes differ).
    private func differingCells(_ a: FieldGrid, _ b: FieldGrid) -> Int {
        guard a.width == b.width, a.height == b.height, a.channels == b.channels else { return max(a.values.count, 1) }
        var n = 0
        for i in a.values.indices where a.values[i] != b.values[i] { n += 1 }
        return n
    }

    func testASeededAutomatonEqualsTheReferenceAfter1_2_10And100Steps() throws {
        let checkpoints = [1, 2, 10, 100]
        var results: [String] = []
        try onGPU { registry in
            for n in [64, 16] {
                for (index, rule) in AutomatonRule.presets.enumerated() {
                    let start = Seeding.automatonStart(gridSize: n, seed: UInt64(7 + index))
                    let gpu = try AutomatonGPU(registry: registry, gridSize: n)
                    defer { gpu.release() }
                    XCTAssertTrue(gpu.load(start), "\(n) \(rule.notation): loaded")
                    XCTAssertEqual(self.differingCells(gpu.readBack(), start), 0, "\(n) \(rule.notation): the start")
                    var cpu = start
                    var done = 0
                    for checkpoint in checkpoints {
                        try gpu.step(rule: rule, count: checkpoint - done)
                        cpu = self.reference(rule, cpu, steps: checkpoint - done)
                        done = checkpoint
                        let differing = self.differingCells(gpu.readBack(), cpu)
                        XCTAssertEqual(differing, 0, "\(n) × \(n) \(rule.notation) after \(checkpoint) steps")
                        results.append("\(n)/\(rule.notation)/\(checkpoint):\(differing)")
                    }
                    XCTAssertEqual(gpu.stepCount, 100)
                    XCTAssertEqual(gpu.loadCount, 1)
                }
            }
        }
        XCTAssertEqual(results.count, 2 * 3 * 4, "every grid, rule and checkpoint was compared")
    }

    func testTheGPUBlinkerHasPeriodTwo() throws {
        let n = 16
        let centred = Seeding.pattern(gridSize: n, alive: [(x: 7, y: 8), (x: 8, y: 8), (x: 9, y: 8)])
        let acrossTheEdge = Seeding.pattern(gridSize: n, alive: [(x: 15, y: 0), (x: 0, y: 0), (x: 1, y: 0)])
        try onGPU { registry in
            for (name, blinker) in [("centred", centred), ("across the edge", acrossTheEdge)] {
                let gpu = try AutomatonGPU(registry: registry, gridSize: n)
                defer { gpu.release() }
                XCTAssertTrue(gpu.load(blinker))
                try gpu.step(rule: .life, count: 1)
                let one = gpu.readBack()
                XCTAssertNotEqual(one, blinker, "\(name): one step changes it")
                XCTAssertEqual(one, AutomatonRule.life.step(blinker), "\(name): one step equals the reference")
                try gpu.step(rule: .life, count: 1)
                XCTAssertEqual(gpu.readBack(), blinker, "\(name): two steps bring it back")
            }
        }
    }

    func testAGPUGliderIsBackAfterFourNSteps() throws {
        let n = 16
        let glider = Seeding.pattern(gridSize: n, alive: [(x: 1, y: 0), (x: 2, y: 1), (x: 0, y: 2), (x: 1, y: 2),
                                                          (x: 2, y: 2)])
        try onGPU { registry in
            let gpu = try AutomatonGPU(registry: registry, gridSize: n)
            defer { gpu.release() }
            XCTAssertTrue(gpu.load(glider))
            try gpu.step(rule: .life, count: 4)
            let four = gpu.readBack()
            XCTAssertEqual(four, self.reference(.life, glider, steps: 4), "four steps equal the reference")
            XCTAssertNotEqual(four, glider, "four steps move it")
            try gpu.step(rule: .life, count: 2 * n - 4)
            XCTAssertNotEqual(gpu.readBack(), glider, "halfway it is elsewhere")
            try gpu.step(rule: .life, count: 2 * n)
            XCTAssertEqual(gpu.readBack(), glider, "4 × \(n) steps bring it back across the wrap edges")
            XCTAssertEqual(gpu.stepCount, 4 * n)
        }
    }

    func testTheRuleMasksAndTheFailures() throws {
        XCTAssertEqual(AutomatonGPU.mask(AutomatonRule.life.birth), 0b1000)
        XCTAssertEqual(AutomatonGPU.mask(AutomatonRule.life.survival), 0b1100)
        XCTAssertEqual(AutomatonGPU.mask(AutomatonRule.highLife.birth), 0b100_1000)
        XCTAssertEqual(AutomatonGPU.mask(AutomatonRule.seeds.survival), 0)
        XCTAssertEqual(AutomatonGPU.mask(Set(0...8)), 0b1_1111_1111, "nine bits")
        XCTAssertEqual(AutomatonGPU.mask([9, -1]), 0, "counts outside 0…8 are ignored")
        try onGPU { registry in
            let before = registry.stats.liveCount.values.reduce(0, +)
            XCTAssertThrowsError(try AutomatonGPU(registry: registry, gridSize: 16, stepFragment: "not a shader")) {
                guard case AutomatonGPUError.compile = $0 else { return XCTFail("got \($0)") }
            }
            XCTAssertThrowsError(try AutomatonGPU(registry: registry, gridSize: 0)) {
                XCTAssertEqual($0 as? AutomatonGPUError, .invalidGridSize(0))
            }
            XCTAssertEqual(registry.stats.liveCount.values.reduce(0, +), before, "nothing stays allocated")

            let gpu = try AutomatonGPU(registry: registry, gridSize: 16)
            XCTAssertEqual(gpu.current.format, .rgba8)
            XCTAssertEqual(gpu.current.width, 16)
            XCTAssertFalse(gpu.load(FieldGrid(width: 8, height: 8, channels: 1)), "a field of another size is refused")
            gpu.release()
            XCTAssertFalse(gpu.isValid)
            XCTAssertFalse(gpu.load(FieldGrid(width: 16, height: 16, channels: 1)), "a released pair refuses a load")
            XCTAssertThrowsError(try gpu.step(rule: .life, count: 1)) {
                XCTAssertEqual($0 as? FieldPassError, .stale)
            }
            XCTAssertTrue(gpu.readBack().values.allSatisfy(\.isNaN), "a failed read never equals a field")
            XCTAssertEqual(registry.stats.liveCount.values.reduce(0, +), before, "the pair and the pass released together")
        }
    }
}
