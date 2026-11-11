// FluidSolver.swift — viscosity, divergence, Jacobi pressure and projection with walls or open edges: the CPU
// reference the GPU passes are checked against (feature 021 T-A02-304; FR-A02-301–FR-A02-304; spec 021
// clarifications 1–5; research R3–R6). Every formula is evaluated in the same operation order as the shaders in
// FluidShaders.swift, and every stored result is rounded (and encoded in 8-bit storage) like the GPU storage. The
// model is artistic, not a physical simulation.
import VisualCoreSimulation

/// Encodings of the stored fields in 8-bit fallback storage (nil = stored unencoded, as in half-float storage).
public struct FluidEncodings: Sendable, Equatable {
    /// Velocity (cells/s).
    public let velocity: SignedRangeEncoding?
    /// Divergence (cells/s per cell), range 2 × velocity range.
    public let divergence: SignedRangeEncoding?
    /// Pressure (cells²/s), range 4 × velocity range.
    public let pressure: SignedRangeEncoding?

    /// No encoding (half-float or float storage).
    public static let none = FluidEncodings(velocity: nil, divergence: nil, pressure: nil)

    /// The 8-bit encodings for a velocity range in cells per second (zero at 128/255).
    public static func unorm8(velocityRange: Float) -> FluidEncodings? {
        guard let v = SignedRangeEncoding.unorm8(range: velocityRange),
              let d = SignedRangeEncoding.unorm8(range: velocityRange * 2),
              let p = SignedRangeEncoding.unorm8(range: velocityRange * 4) else { return nil }
        return FluidEncodings(velocity: v, divergence: d, pressure: p)
    }

    /// Creates encodings from explicit values.
    public init(velocity: SignedRangeEncoding?, divergence: SignedRangeEncoding?, pressure: SignedRangeEncoding?) {
        self.velocity = velocity
        self.divergence = divergence
        self.pressure = pressure
    }
}

/// The incompressible part of the solver, on cell-centered grids with a cell size of 1.
public enum FluidSolver {
    /// Counts grid reads; `outOfGrid` must stay 0 (the boundary rules decide outside neighbors without reading).
    public struct AccessLog: Sendable, Equatable {
        /// Cells read.
        public var reads = 0
        /// Reads that asked for a cell outside the grid (clamped, and counted as a defect).
        public var outOfGrid = 0
        /// An empty log.
        public init() {}
    }

    /// Number of implicit viscosity iterations (clarification 3).
    public static let viscosityIterations = 8
    /// ν per unit of the viscosity setting, in cells² per second (clarification 3).
    public static let viscosityScale: Double = 50

    // MARK: Reading

    private static func read(_ g: FieldGrid, _ x: Int, _ y: Int, _ c: Int, _ log: inout AccessLog) -> Float {
        log.reads += 1
        guard x >= 0, y >= 0, x < g.width, y < g.height else {
            log.outOfGrid += 1
            return g[min(max(x, 0), g.width - 1), min(max(y, 0), g.height - 1), c]
        }
        return g[x, y, c]
    }

    private static func decoded(_ u: Float, _ e: SignedRangeEncoding?) -> Float { e.map { $0.decode(u) } ?? u }

    private static func stored(_ v: Float, _ e: SignedRangeEncoding?, _ p: StoragePrecision) -> Float {
        p.round(e.map { $0.encode(v) } ?? v)
    }

    /// Velocity at (x, y) in cells/s; outside the grid: the center cell, with the normal component negated for walls.
    static func velocity(_ g: FieldGrid, _ x: Int, _ y: Int, cx: Int, cy: Int, mode: BoundaryMode,
                         encoding e: SignedRangeEncoding?, log: inout AccessLog) -> SIMD2<Float> {
        if x >= 0, y >= 0, x < g.width, y < g.height {
            return SIMD2(decoded(read(g, x, y, 0, &log), e), decoded(read(g, x, y, 1, &log), e))
        }
        var v = SIMD2(decoded(read(g, cx, cy, 0, &log), e), decoded(read(g, cx, cy, 1, &log), e))
        if mode == .walls {
            if x < 0 || x >= g.width { v.x = -v.x }
            if y < 0 || y >= g.height { v.y = -v.y }
        }
        return v
    }

    /// Scalar (channel 0) at (x, y); outside the grid: the center value (zero normal gradient).
    static func scalar(_ g: FieldGrid, _ x: Int, _ y: Int, cx: Int, cy: Int, encoding e: SignedRangeEncoding?,
                       log: inout AccessLog) -> Float {
        let inside = x >= 0 && y >= 0 && x < g.width && y < g.height
        return decoded(read(g, inside ? x : cx, inside ? y : cy, 0, &log), e)
    }

    // MARK: Passes

    /// `d = 0.5·((u_R − u_L) + (v_T − v_B))`, stored in channel 0.
    public static func divergence(velocity v: FieldGrid, mode: BoundaryMode, precision: StoragePrecision,
                                  encodings: FluidEncodings, log: inout AccessLog) -> FieldGrid {
        var out = FieldGrid(width: v.width, height: v.height, channels: 4)
        let zero = stored(0, encodings.divergence, precision)
        for y in 0..<v.height {
            for x in 0..<v.width {
                let l = velocity(v, x - 1, y, cx: x, cy: y, mode: mode, encoding: encodings.velocity, log: &log)
                let r = velocity(v, x + 1, y, cx: x, cy: y, mode: mode, encoding: encodings.velocity, log: &log)
                let b = velocity(v, x, y - 1, cx: x, cy: y, mode: mode, encoding: encodings.velocity, log: &log)
                let t = velocity(v, x, y + 1, cx: x, cy: y, mode: mode, encoding: encodings.velocity, log: &log)
                let d = 0.5 * ((r.x - l.x) + (t.y - b.y))
                out[x, y, 0] = stored(d, encodings.divergence, precision)
                for c in 1..<4 { out[x, y, c] = c == 3 ? 1 : zero }
            }
        }
        return out
    }

    /// Pressure from `iterations` Jacobi steps `p' = (p_L + p_R + p_B + p_T − d) · 0.25`, starting at 0.
    public static func jacobiPressure(divergence d: FieldGrid, iterations: Int, precision: StoragePrecision,
                                      encodings: FluidEncodings, log: inout AccessLog) -> FieldGrid {
        let zero = stored(0, encodings.pressure, precision)
        var p = FieldGrid(width: d.width, height: d.height, channels: 4, fill: zero)
        for i in p.values.indices where i % 4 == 3 { p.values[i] = 1 }
        for _ in 0..<max(1, iterations) {
            var next = p
            for y in 0..<d.height {
                for x in 0..<d.width {
                    let pl = scalar(p, x - 1, y, cx: x, cy: y, encoding: encodings.pressure, log: &log)
                    let pr = scalar(p, x + 1, y, cx: x, cy: y, encoding: encodings.pressure, log: &log)
                    let pb = scalar(p, x, y - 1, cx: x, cy: y, encoding: encodings.pressure, log: &log)
                    let pt = scalar(p, x, y + 1, cx: x, cy: y, encoding: encodings.pressure, log: &log)
                    let div = scalar(d, x, y, cx: x, cy: y, encoding: encodings.divergence, log: &log)
                    next[x, y, 0] = stored((pl + pr + pb + pt - div) * 0.25, encodings.pressure, precision)
                }
            }
            p = next
        }
        return p
    }

    /// `u −= 0.5·(p_R − p_L)`, `v −= 0.5·(p_T − p_B)`; with walls the normal component of edge cells becomes 0.
    public static func subtractGradient(velocity v: FieldGrid, pressure p: FieldGrid, mode: BoundaryMode,
                                        precision: StoragePrecision, encodings: FluidEncodings,
                                        log: inout AccessLog) -> FieldGrid {
        var out = v
        for y in 0..<v.height {
            for x in 0..<v.width {
                let pl = scalar(p, x - 1, y, cx: x, cy: y, encoding: encodings.pressure, log: &log)
                let pr = scalar(p, x + 1, y, cx: x, cy: y, encoding: encodings.pressure, log: &log)
                let pb = scalar(p, x, y - 1, cx: x, cy: y, encoding: encodings.pressure, log: &log)
                let pt = scalar(p, x, y + 1, cx: x, cy: y, encoding: encodings.pressure, log: &log)
                let c = velocity(v, x, y, cx: x, cy: y, mode: mode, encoding: encodings.velocity, log: &log)
                var u = c.x - 0.5 * (pr - pl)
                var w = c.y - 0.5 * (pt - pb)
                if mode == .walls {
                    if x == 0 || x == v.width - 1 { u = 0 }
                    if y == 0 || y == v.height - 1 { w = 0 }
                }
                out[x, y, 0] = stored(u, encodings.velocity, precision)
                out[x, y, 1] = stored(w, encodings.velocity, precision)
            }
        }
        return out
    }

    /// Divergence, Jacobi pressure and gradient subtraction.
    public static func project(velocity v: FieldGrid, iterations: Int, mode: BoundaryMode, precision: StoragePrecision,
                               encodings: FluidEncodings, log: inout AccessLog) -> FieldGrid {
        let d = divergence(velocity: v, mode: mode, precision: precision, encodings: encodings, log: &log)
        let p = jacobiPressure(divergence: d, iterations: iterations, precision: precision, encodings: encodings, log: &log)
        return subtractGradient(velocity: v, pressure: p, mode: mode, precision: precision, encodings: encodings, log: &log)
    }

    /// Implicit viscosity: 8 Jacobi steps of `x' = (x_L + x_R + x_B + x_T + α·b) / (4 + α)`, `α = 1/(ν·Δt)`,
    /// `ν = viscosity × 50`. Returns the input unchanged at viscosity 0.
    public static func diffuse(velocity v: FieldGrid, viscosity: Double, dt: Double, mode: BoundaryMode,
                               precision: StoragePrecision, encodings: FluidEncodings, log: inout AccessLog) -> FieldGrid {
        guard viscosity > 0, dt > 0 else { return v }
        let alpha = Float(1 / (viscosity * viscosityScale * dt))
        let b = v
        var x = v
        for _ in 0..<viscosityIterations {
            var next = x
            for cy in 0..<v.height {
                for cx in 0..<v.width {
                    let l = velocity(x, cx - 1, cy, cx: cx, cy: cy, mode: mode, encoding: encodings.velocity, log: &log)
                    let r = velocity(x, cx + 1, cy, cx: cx, cy: cy, mode: mode, encoding: encodings.velocity, log: &log)
                    let bo = velocity(x, cx, cy - 1, cx: cx, cy: cy, mode: mode, encoding: encodings.velocity, log: &log)
                    let t = velocity(x, cx, cy + 1, cx: cx, cy: cy, mode: mode, encoding: encodings.velocity, log: &log)
                    let c = velocity(b, cx, cy, cx: cx, cy: cy, mode: mode, encoding: encodings.velocity, log: &log)
                    let n = (l + r + bo + t + alpha * c) / (4 + alpha)
                    next[cx, cy, 0] = stored(n.x, encodings.velocity, precision)
                    next[cx, cy, 1] = stored(n.y, encodings.velocity, precision)
                }
            }
            x = next
        }
        return x
    }

    /// One full frame (clarification 5): splats, advect velocity, viscosity, projection with `pressureIterations`,
    /// then dye advected by the projected velocity.
    public static func step(velocity: inout FieldGrid, dye: inout FieldGrid, splats: [Splat], configuration c: FluidConfiguration,
                            pressureIterations: Int, dt: Double, precision: StoragePrecision, encodings: FluidEncodings,
                            log: inout AccessLog) {
        let limit = Float(c.velocityRange * 60)   // cells per second, the 8-bit storage range (feature 023)
        for s in splats {
            s.apply(velocity: &velocity, dye: &dye, precision: precision, velocityEncoding: encodings.velocity,
                    velocityLimit: encodings.velocity == nil ? limit : nil)
        }
        velocity = Advection.advect(velocity, by: velocity, dt: dt, factor: Dissipation.factor(d: c.velocityDissipation, dt: dt),
                                    precision: precision, velocityEncoding: encodings.velocity, sourceIsVelocity: true)
        velocity = diffuse(velocity: velocity, viscosity: c.viscosity, dt: dt, mode: c.boundaryMode, precision: precision,
                           encodings: encodings, log: &log)
        velocity = project(velocity: velocity, iterations: pressureIterations, mode: c.boundaryMode, precision: precision,
                           encodings: encodings, log: &log)
        dye = Advection.advect(dye, by: velocity, dt: dt, factor: Dissipation.factor(d: c.dyeDissipation, dt: dt),
                               precision: precision, velocityEncoding: encodings.velocity, sourceIsVelocity: false)
    }
}
