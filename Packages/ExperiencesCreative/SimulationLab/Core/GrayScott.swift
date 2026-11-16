// GrayScott — feature 117 (A16-P01) T-A16-103 (FR-A16-102; SC-A16-102; clarification Q2). The CPU reference of
// Gray-Scott reaction-diffusion, one explicit Euler step:
//   u′ = u + Δt (Dᵤ∇²u − uv² + F(1 − u)),   v′ = v + Δt (Dᵥ∇²v + uv² − (F + k)v),
// with ∇² the five-point stencil (left + right + down + up − 4 · centre, cell spacing 1) over a wrap boundary,
// Dᵤ = 0.16 and Dᵥ = 0.08. After the step u and v are clamped to 0…1 (NaN reads as 0) and rounded to the storage
// precision (`float16` by default). The stability bound is Δt · 4 · max(Dᵤ, Dᵥ) ≤ 1, that is Δt ≤ 1.5625
// (`SimulationSpec.validated()` refuses larger steps). Arithmetic is in `Float`, like the GPU pass that follows.
import VisualCoreSimulation

/// Gray-Scott reaction-diffusion on a two-channel grid (channel 0 = u, channel 1 = v).
public enum GrayScott {
    /// The diffusion constant of u.
    public static let diffusionU: Float = 0.16
    /// The diffusion constant of v.
    public static let diffusionV: Float = 0.08

    /// One step of `grid` with the feed, kill and time step of `spec`, rounded to `precision`.
    public static func step(_ grid: FieldGrid, spec: SimulationSpec,
                            precision: StoragePrecision = .float16) -> FieldGrid {
        step(grid, feed: spec.value(ParameterCatalog.feed.name), kill: spec.value(ParameterCatalog.kill.name),
             timeStep: spec.timeStep, precision: precision)
    }

    /// One step of `grid` with feed F, kill k and time step Δt, rounded to `precision`; a grid with fewer than two
    /// channels is returned unchanged.
    public static func step(_ grid: FieldGrid, feed: Double, kill: Double, timeStep: Double,
                            precision: StoragePrecision = .float16) -> FieldGrid {
        guard grid.channels >= 2 else { return grid }
        let w = grid.width, h = grid.height
        let f = Float(feed), k = Float(kill), dt = Float(timeStep)
        var out = grid
        for y in 0..<h {
            let down = (y + h - 1) % h, up = (y + 1) % h
            for x in 0..<w {
                let left = (x + w - 1) % w, right = (x + 1) % w
                let u = grid[x, y, 0], v = grid[x, y, 1]
                let lapU = (grid[left, y, 0] + grid[right, y, 0]) + (grid[x, down, 0] + grid[x, up, 0]) - 4 * u
                let lapV = (grid[left, y, 1] + grid[right, y, 1]) + (grid[x, down, 1] + grid[x, up, 1]) - 4 * v
                let uvv = u * v * v
                let nu = u + dt * (diffusionU * lapU - uvv + f * (1 - u))
                let nv = v + dt * (diffusionV * lapV + uvv - (f + k) * v)
                out[x, y, 0] = precision.round(clampUnit(nu))
                out[x, y, 1] = precision.round(clampUnit(nv))
            }
        }
        return out
    }

    /// `x` clamped to 0…1; NaN gives 0.
    static func clampUnit(_ x: Float) -> Float {
        x.isNaN ? 0 : min(max(x, 0), 1)
    }
}
