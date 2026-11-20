// ErosionMaskTests — feature 218 (R02-F18) T-R02F18-004 (FR-R02F18-004; SC-R02F18-003; clarification Q3).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct ErosionMaskTests {
    /// Grid cells per side of the hand-made fixtures.
    static let size: Int = 8

    /// A field of `size` × `size` cells of edge 1 sampled from `height`.
    static func field(_ height: (Double, Double) -> Double) throws -> HeightField {
        try HeightField(columns: size, rows: size, cellSize: 1, height: height)
    }

    /// Channel `c` at grid point (column, row) of a mask grid of width `size + 1`.
    static func value(_ values: [Float], _ column: Int, _ row: Int, _ c: Int) -> Float {
        values[(row * (size + 1) + column) * 3 + c]
    }

    @Test func gridSizeAndChannels() throws {
        let field: HeightField = try HeightField(columns: 5, rows: 3, cellSize: 0.5) { x, z in x * 0.1 + z * 0.2 }
        let masks = ErosionMask.masks(of: field)
        #expect(masks.width == 6)
        #expect(masks.height == 4)
        #expect(masks.channels == 3)
        #expect(masks.values.count == 6 * 4 * 3)
    }

    @Test func flatField() throws {
        let values: [Float] = ErosionMask.masks(of: try Self.field { _, _ in 1.5 }).values
        let points: Double = Double((Self.size + 1) * (Self.size + 1))
        let expectedFlow: Float = Float(log(2.0) / log(1 + points))
        for row in 0...Self.size {
            for column in 0...Self.size {
                #expect(Self.value(values, column, row, 0) == 0)
                #expect(Self.value(values, column, row, 1) == expectedFlow)
                #expect(Self.value(values, column, row, 2) == 0)
            }
        }
    }

    @Test func tiltedPlane() throws {
        let values: [Float] = ErosionMask.masks(of: try Self.field { x, _ in 0.5 * x }).values
        let expectedSteepness: Double = 0.5 / 1.25.squareRoot()
        for row in 0...Self.size {
            var previous: Float = Float.infinity
            var largest: Float = 0
            for column in 0...Self.size {
                #expect(abs(Double(Self.value(values, column, row, 0)) - expectedSteepness) < 1e-6)
                let flow: Float = Self.value(values, column, row, 1)
                // Walking uphill (+x), flow never grows.
                #expect(flow <= previous)
                previous = flow
                largest = max(largest, flow)
            }
            #expect(Self.value(values, 0, row, 1) == largest)
            #expect(Self.value(values, 0, row, 1) > Self.value(values, Self.size, row, 1))
        }
    }

    @Test func valleyGathersOnItsFloor() throws {
        let middle: Double = Double(Self.size / 2)
        let values: [Float] = ErosionMask.masks(of: try Self.field { x, _ in abs(x - middle) }).values
        for row in 0...Self.size {
            let floor: Float = Self.value(values, Self.size / 2, row, 1)
            for column in 0...Self.size where column != Self.size / 2 {
                #expect(Self.value(values, column, row, 1) < floor)
            }
        }
    }

    @Test func pitGathersEverything() throws {
        let middle: Double = Double(Self.size / 2)
        let field: HeightField = try Self.field { x, z in (x - middle) * (x - middle) + (z - middle) * (z - middle) }
        let values: [Float] = ErosionMask.masks(of: field).values
        let pit: Float = Self.value(values, Self.size / 2, Self.size / 2, 1)
        #expect(pit == 1)
        for row in 0...Self.size {
            for column in 0...Self.size where !(column == Self.size / 2 && row == Self.size / 2) {
                #expect(Self.value(values, column, row, 1) < pit)
            }
        }
    }

    @Test func seededTerrainsAreDeterministicAndInRange() throws {
        for k in 0..<20 {
            let noise: GradientNoise2D = GradientNoise2D(seed: UInt64(2_018 + k))
            let field: HeightField = try HeightField(columns: 16, rows: 16, cellSize: 0.25) { x, z in
                noise.value(x: x * 0.7, y: z * 0.7) * 2
            }
            let first: [Float] = ErosionMask.masks(of: field).values
            let second: [Float] = ErosionMask.masks(of: field).values
            #expect(first.count == 17 * 17 * 3)
            var identical: Bool = true
            var inRange: Bool = true
            for index in 0..<first.count {
                if first[index].bitPattern != second[index].bitPattern { identical = false }
                if !(first[index] >= 0 && first[index] <= 1) { inRange = false }
            }
            #expect(identical, "seed \(2_018 + k)")
            #expect(inRange, "seed \(2_018 + k)")
        }
    }
}
