// DensityRasterTests — feature 220 (R02-F20) T-R02F20-004 (FR-R02F20-004; SC-R02F20-004; clarification Q5; research
// R6). Fifty seeded swarms (agents inside, outside, non-finite, on edges and corners) on seeded raster sizes: the total
// equals the in-area count within 1e-9 relative and every cell is finite and ≥ 0; a cell-centre agent lands in one cell
// with weight 1; corner and edge weight folds onto the edge cells; a 1 × 1 raster; clear(); the FieldGrid handoff;
// refusals. Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

@Suite struct DensityRasterTests {
    /// An agent at (x, y) at rest in group 0.
    private func agent(_ x: Double, _ y: Double) -> SteeringAgent {
        SteeringAgent(position: Vec2(x, y), velocity: .zero, group: 0)
    }

    @Test func totalEqualsInAreaCountForSeededSwarms() throws {
        var random = SeededRandom(seed: 2_020)
        for _ in 0..<50 {
            let width: Int = random.int(1...64)
            let height: Int = random.int(1...64)
            let minX: Double = random.double() * 20 - 10
            let minY: Double = random.double() * 20 - 10
            let maxX: Double = minX + 0.5 + random.double() * 20
            let maxY: Double = minY + 0.5 + random.double() * 20
            let bounds = SteeringBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
            let count: Int = random.int(0...200)
            var agents: [SteeringAgent] = []
            var inside: Int = 0
            for _ in 0..<count {
                let kind: Int = random.int(0...9)
                let x: Double = minX + random.double() * (maxX - minX)
                let y: Double = minY + random.double() * (maxY - minY)
                switch kind {
                case 6:
                    let side: Int = random.int(0...3)
                    if side == 0 { agents.append(agent(minX - 0.01 - random.double(), y)) }
                    if side == 1 { agents.append(agent(maxX + 0.01 + random.double(), y)) }
                    if side == 2 { agents.append(agent(x, minY - 0.01 - random.double())) }
                    if side == 3 { agents.append(agent(x, maxY + 0.01 + random.double())) }
                case 7:
                    let bad: [Double] = [.nan, .infinity, -.infinity]
                    let value: Double = bad[random.int(0...2)]
                    if random.int(0...1) == 0 { agents.append(agent(value, y)) } else { agents.append(agent(x, value)) }
                case 8:
                    let side: Int = random.int(0...3)
                    if side == 0 { agents.append(agent(minX, y)) }
                    if side == 1 { agents.append(agent(maxX, y)) }
                    if side == 2 { agents.append(agent(x, minY)) }
                    if side == 3 { agents.append(agent(x, maxY)) }
                    inside += 1
                case 9:
                    let cx: Double = random.int(0...1) == 0 ? minX : maxX
                    let cy: Double = random.int(0...1) == 0 ? minY : maxY
                    agents.append(agent(cx, cy))
                    inside += 1
                default:
                    agents.append(agent(x, y))
                    inside += 1
                }
            }
            let raster = try DensityRaster.of(agents, bounds: bounds, width: width, height: height)
            #expect(raster.cells.count == width * height)
            let expected = Double(inside)
            #expect(abs(raster.total - expected) <= 1e-9 * max(expected, 1))
            for value in raster.cells {
                #expect(value.isFinite && value >= 0)
            }
        }
    }

    @Test func cellCentreAgentLandsInOneCell() throws {
        var random = SeededRandom(seed: 2_020)
        for _ in 0..<20 {
            // Power-of-two sides and a power-of-two cell size keep the centre arithmetic exact.
            let width: Int = 1 << random.int(0...6)
            let height: Int = 1 << random.int(0...6)
            let cell: Double = 0.25
            let bounds = SteeringBounds(minX: 0, maxX: Double(width) * cell, minY: 0, maxY: Double(height) * cell)
            let i: Int = random.int(0...(width - 1))
            let j: Int = random.int(0...(height - 1))
            let centre = agent((Double(i) + 0.5) * cell, (Double(j) + 0.5) * cell)
            let raster = try DensityRaster.of([centre], bounds: bounds, width: width, height: height)
            for index in 0..<raster.cells.count {
                let want: Double = index == j * width + i ? 1 : 0
                #expect(raster.cells[index] == want)
            }
        }
    }

    @Test func edgeAndCornerWeightFoldsOntoEdgeCells() throws {
        let bounds = SteeringBounds(minX: -2, maxX: 3, minY: 1, maxY: 4)
        let width = 5
        let height = 3
        let corners: [(Double, Double, Int)] = [
            (-2, 1, 0), (3, 1, width - 1), (-2, 4, (height - 1) * width), (3, 4, height * width - 1),
        ]
        for (x, y, cell) in corners {
            let raster = try DensityRaster.of([agent(x, y)], bounds: bounds, width: width, height: height)
            for index in 0..<raster.cells.count {
                let want: Double = index == cell ? 1 : 0
                #expect(raster.cells[index] == want)
            }
        }
        // On the left edge at the centre height of row 1: the half past the edge folds onto column 0.
        let edge = try DensityRaster.of([agent(-2, 2.5)], bounds: bounds, width: width, height: height)
        for index in 0..<edge.cells.count {
            let want: Double = index == 1 * width + 0 ? 1 : 0
            #expect(edge.cells[index] == want)
        }
    }

    @Test func oneByOneRasterHoldsEveryInsideAgent() throws {
        let bounds = SteeringBounds(minX: 0, maxX: 1, minY: 0, maxY: 1)
        var agents: [SteeringAgent] = []
        var random = SeededRandom(seed: 2_020)
        for _ in 0..<37 { agents.append(agent(random.double(), random.double())) }
        agents.append(agent(0, 0))
        agents.append(agent(1, 1))
        agents.append(agent(2, 0.5))
        agents.append(agent(.nan, 0.5))
        let raster = try DensityRaster.of(agents, bounds: bounds, width: 1, height: 1)
        #expect(raster.cells.count == 1)
        #expect(abs(raster.cells[0] - 39) <= 1e-9 * 39)
    }

    @Test func clearEmptiesTheRaster() throws {
        let bounds = SteeringBounds(minX: 0, maxX: 10, minY: 0, maxY: 10)
        var raster = try DensityRaster(width: 7, height: 9, bounds: bounds)
        let empty = raster
        raster.splat([agent(3.3, 4.4), agent(9.9, 0.1), agent(5, 5)])
        #expect(abs(raster.total - 3) <= 1e-9 * 3)
        raster.clear()
        #expect(raster == empty)
        #expect(raster.total == 0)
        raster.splat([agent(1, 1)])
        #expect(abs(raster.total - 1) <= 1e-9)
        var none = try DensityRaster(width: 2, height: 2, bounds: bounds)
        none.splat([])
        #expect(none.total == 0)
    }

    @Test func fieldGridHandoffMatchesCells() throws {
        let bounds = SteeringBounds(minX: -4, maxX: 4, minY: -3, maxY: 3)
        var agents: [SteeringAgent] = []
        var random = SeededRandom(seed: 2_020)
        for _ in 0..<100 { agents.append(agent(random.double() * 8 - 4, random.double() * 6 - 3)) }
        let raster = try DensityRaster.of(agents, bounds: bounds, width: 11, height: 6)
        let grid = raster.fieldGrid()
        #expect(grid.width == 11 && grid.height == 6 && grid.channels == 1)
        #expect(grid.values.count == raster.cells.count)
        for y in 0..<6 {
            for x in 0..<11 {
                #expect(grid[x, y, 0] == Float(raster.cells[y * 11 + x]))
            }
        }
    }

    @Test func refusals() throws {
        let good = SteeringBounds(minX: 0, maxX: 1, minY: 0, maxY: 1)
        #expect(throws: SwarmError.rasterSize) { try DensityRaster(width: 0, height: 4, bounds: good) }
        #expect(throws: SwarmError.rasterSize) { try DensityRaster(width: 4, height: 0, bounds: good) }
        #expect(throws: SwarmError.rasterSize) { try DensityRaster(width: -1, height: 4, bounds: good) }
        #expect(throws: SwarmError.rasterSize) { try DensityRaster(width: 1_025, height: 1, bounds: good) }
        #expect(throws: SwarmError.rasterSize) { try DensityRaster(width: 1, height: 1_025, bounds: good) }
        #expect(throws: SwarmError.rasterSize) { try DensityRaster(width: 1_024, height: 1_025, bounds: good) }
        let flat = SteeringBounds(minX: 1, maxX: 1, minY: 0, maxY: 1)
        let reversed = SteeringBounds(minX: 0, maxX: 1, minY: 2, maxY: 1)
        let notANumber = SteeringBounds(minX: .nan, maxX: 1, minY: 0, maxY: 1)
        let infinite = SteeringBounds(minX: 0, maxX: 1, minY: 0, maxY: .infinity)
        #expect(throws: SwarmError.bounds) { try DensityRaster(width: 4, height: 4, bounds: flat) }
        #expect(throws: SwarmError.bounds) { try DensityRaster(width: 4, height: 4, bounds: reversed) }
        #expect(throws: SwarmError.bounds) { try DensityRaster(width: 4, height: 4, bounds: notANumber) }
        #expect(throws: SwarmError.bounds) { try DensityRaster.of([], bounds: infinite, width: 4, height: 4) }
        let largest = try DensityRaster(width: 1_024, height: 1_024, bounds: good)
        #expect(largest.cells.count == DensityRaster.maxCells)
        let wide = try DensityRaster(width: 1_024, height: 1, bounds: good)
        #expect(wide.cells.count == 1_024)
        #expect(SwarmError.rasterSize.reasonCode == "r2-f20.raster-size")
    }
    @Test func swarmRasterCountsEveryAgent() throws {
        let bounds = SteeringBounds(minX: -4, maxX: 4, minY: -2, maxY: 2)
        var random = SeededRandom(seed: 2_020)
        var agents: [SteeringAgent] = []
        for _ in 0..<64 {
            let p = Vec2(random.double() * 8 - 4, random.double() * 4 - 2)
            agents.append(SteeringAgent(position: p, velocity: Vec2(1, 0), group: 0))
        }
        var swarm = try Swarm(agents: agents, bounds: bounds)
        for _ in 0..<10 { try swarm.step(by: 0.05) }
        let raster = try DensityRaster.of(swarm, width: 16, height: 8)
        #expect(abs(raster.total - 64) <= 64 * 1e-9)
        #expect(throws: SwarmError.rasterSize) { try DensityRaster.of(swarm, width: 0, height: 8) }
    }
}
