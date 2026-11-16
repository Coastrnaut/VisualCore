// WaveBorderTests — feature 119 (A16-P03) T-A16-304 (FR-A16-302; SC-A16-302; clarification Q1). The wave's fixed zero
// border on the GPU: the seeded 16 × 16 Pulse start is stepped 100 times by ``WaveGPU``; every edge cell of the current
// height reads exactly 0, and the interior is not all zero (the wave moved). One off-screen frame.
import Foundation
import SimulationLabCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import SimulationLabExperience

@MainActor
final class WaveBorderTests: XCTestCase {
    func testEveryEdgeCellIsZeroAfterAHundredSteps() throws {
        let n = 16
        let start = Seeding.waveStart(gridSize: n, seed: 3)
        var field: SimulationField?
        try withFloatContext { registry in
            let gpu = try WaveGPU(registry: registry, gridSize: n)
            defer { gpu.release() }
            XCTAssertTrue(gpu.load(SimulationField(current: start, previous: start)))
            try gpu.step(courant: 0.5, damping: 0.002, count: 100)
            field = gpu.readBack()
        }
        let grid = try XCTUnwrap(field).current
        var edges = 0, nonZeroEdges = 0, interiorMax: Float = 0
        for y in 0..<n {
            for x in 0..<n {
                let value = grid[x, y, 0]
                if x == 0 || y == 0 || x == n - 1 || y == n - 1 {
                    edges += 1
                    if value != 0 { nonZeroEdges += 1 }
                } else {
                    interiorMax = max(interiorMax, abs(value))
                }
            }
        }
        XCTAssertEqual(edges, 4 * n - 4)
        XCTAssertEqual(nonZeroEdges, 0, "100 % of the edge cells read zero")
        XCTAssertGreaterThan(interiorMax, 0, "the interior still carries the wave")
    }
}
