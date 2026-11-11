// Splat.swift — one injection of dye and force (feature 020 T-A02-207; FR-A02-203, FR-A02-205; spec clarification 2;
// research R3). `apply` is the CPU reference the GPU splat pass is checked against.
import Foundation
import VisualCoreSimulation

/// A validated splat: a Gaussian blob of dye and force on the simulation grid.
public struct Splat: Sendable, Equatable {
    /// Largest force magnitude in cells per second; larger forces are scaled down, keeping their direction.
    public static let maxForce: Float = 10_000

    /// Center in normalized grid coordinates (0…1, origin bottom-left as in GL).
    public let position: SIMD2<Float>
    /// Radius as a fraction of the shorter grid edge (0.005…0.25).
    public let radius: Float
    /// Force in grid cells per second.
    public let force: SIMD2<Float>
    /// Dye color added (RGB used; each channel 0…1).
    public let color: SIMD4<Float>
    /// Time of the touch sample (seconds), or 0 for generated splats.
    public let timestamp: Double
    /// True when any value had to be clamped or scaled.
    public let wasClamped: Bool

    /// Nil when any value is NaN or infinite; otherwise clamps position to 0…1, radius to 0.005…0.25, the force
    /// magnitude to `maxForce` and color channels to 0…1.
    public init?(position: SIMD2<Float>, radius: Float, force: SIMD2<Float>, color: SIMD4<Float>, timestamp: Double = 0) {
        let values = [position.x, position.y, radius, force.x, force.y, color.x, color.y, color.z, color.w]
        guard values.allSatisfy(\.isFinite), timestamp.isFinite else { return nil }
        let p = position.clamped(lowerBound: .zero, upperBound: .one)
        let r = min(max(radius, Float(FluidConfiguration.brushRadiusRange.lowerBound)), Float(FluidConfiguration.brushRadiusRange.upperBound))
        let magnitude = (force.x * force.x + force.y * force.y).squareRoot()
        let f = magnitude > Self.maxForce ? force * (Self.maxForce / magnitude) : force
        let c = color.clamped(lowerBound: .zero, upperBound: .one)
        self.position = p
        self.radius = r
        self.force = f
        self.color = c
        self.timestamp = timestamp
        wasClamped = p != position || r != radius || f != force || c != color
    }

    /// The center in cells on a width × height grid.
    public func center(width: Int, height: Int) -> SIMD2<Float> { position * SIMD2(Float(width), Float(height)) }

    /// The radius in cells: `radius × min(width, height)`.
    public func radiusCells(width: Int, height: Int) -> Float { radius * Float(min(width, height)) }

    /// The falloff `exp(−d²/r²)` at a cell coordinate (cell centers at `i + 0.5`), with `d` in cells.
    public func weight(cellX: Float, cellY: Float, width: Int, height: Int) -> Float {
        let d = SIMD2(cellX, cellY) - center(width: width, height: height)
        let r = radiusCells(width: width, height: height)
        return Foundation.exp(-(d.x * d.x + d.y * d.y) / (r * r))
    }

    /// CPU reference. Velocity channels 0–1 gain `force · w`, decoded and re-encoded with `velocityEncoding` when
    /// it is given. Dye RGB gains `color · w`, and alpha is unchanged. Every changed value is rounded to `precision`.
    public func apply(velocity: inout FieldGrid, dye: inout FieldGrid, precision: StoragePrecision,
                      velocityEncoding: SignedRangeEncoding? = nil) {
        for y in 0..<velocity.height {
            for x in 0..<velocity.width {
                let w = weight(cellX: Float(x) + 0.5, cellY: Float(y) + 0.5, width: velocity.width, height: velocity.height)
                for c in 0..<min(2, velocity.channels) {
                    let v = velocity[x, y, c]
                    let next = velocityEncoding.map { $0.encode($0.decode(v) + force[c] * w) } ?? v + force[c] * w
                    velocity[x, y, c] = precision.round(next)
                }
            }
        }
        for y in 0..<dye.height {
            for x in 0..<dye.width {
                let w = weight(cellX: Float(x) + 0.5, cellY: Float(y) + 0.5, width: dye.width, height: dye.height)
                for c in 0..<min(3, dye.channels) { dye[x, y, c] = precision.round(dye[x, y, c] + color[c] * w) }
            }
        }
    }
}
