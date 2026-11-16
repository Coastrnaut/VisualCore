// WaveField — feature 117 (A16-P01) T-A16-103 (FR-A16-103; SC-A16-103; clarification Q3). The CPU reference of the
// 2D wave field, one leapfrog step:
//   uⁿ⁺¹ = (2uⁿ − uⁿ⁻¹ + C²∇²uⁿ)(1 − γ),
// with the Courant number C = c · Δt / Δx (Δx = 1), ∇² the five-point stencil (left + right) + (down + up) − 4 · centre
// (summed in that grouping, so a mirror-symmetric field stays exactly symmetric) and a fixed zero border: the
// outermost cells are held at zero and only interior cells are stepped. The result is rounded to the storage
// precision, a parameter (`float16` in the experience, `float32` for the energy check). Stability needs C ≤ 1/√2
// (`SimulationSpec.validated()` refuses larger numbers).
//
// Energy (verified numerically before the tests were written; feature 117 agent note). With A = −∇² (symmetric,
// positive definite with the zero border) and ⟨Ax, y⟩ = Σ over unordered horizontal and vertical neighbour pairs
// (xᵢ − xⱼ)(yᵢ − yⱼ) (pairs with the zero border included), the undamped scheme conserves exactly
//   E(uⁿ⁺¹, uⁿ) = Σ(uⁿ⁺¹ − uⁿ)² + C² ⟨Auⁿ⁺¹, uⁿ⟩,
// the form of clarification Q3. With damping, that form is not monotone for this scheme (it oscillates; step-to-step
// rises of about 0.7 % at γ = 0.002 on a 32 × 32 pulse). Per eigenmode the damped recurrence is
// xⁿ⁺¹ = β(2 − μ)xⁿ − βxⁿ⁻¹ with β = 1 − γ, whose quadratic form (xⁿ⁺¹)² − β(2 − μ)xⁿ⁺¹xⁿ + β(xⁿ)² decays by exactly β
// per step. Summed over the modes it is
//   E_γ(uⁿ⁺¹, uⁿ) = (1 − γ) E(uⁿ⁺¹, uⁿ) + γ Σ(uⁿ⁺¹)²,   E_γⁿ⁺¹ = (1 − γ) E_γⁿ,
// which equals E at γ = 0, is positive below the Courant limit, and never increases with γ > 0.
// `energy(current:previous:courant:damping:)` computes E_γ (E with the default damping 0), in `Double`.
import VisualCoreSimulation

/// The leapfrog wave field on one-channel grids with a fixed zero border.
public enum WaveField {
    /// One step from `current` (uⁿ) and `previous` (uⁿ⁻¹) with the Courant number c · Δt and damping γ of `spec`,
    /// rounded to `precision`.
    public static func step(current: FieldGrid, previous: FieldGrid, spec: SimulationSpec,
                            precision: StoragePrecision = .float16) -> FieldGrid {
        step(current: current, previous: previous, courant: spec.courantNumber,
             damping: spec.value(ParameterCatalog.damping.name), precision: precision)
    }

    /// One step from `current` (uⁿ) and `previous` (uⁿ⁻¹) with Courant number `courant` and damping `damping`,
    /// rounded to `precision`; the border cells of the result are zero. When the shapes differ, `current` is
    /// returned unchanged.
    public static func step(current: FieldGrid, previous: FieldGrid, courant: Double, damping: Double,
                            precision: StoragePrecision = .float16) -> FieldGrid {
        let w = current.width, h = current.height
        guard previous.width == w, previous.height == h, previous.channels == current.channels else { return current }
        let c2 = Float(courant * courant), keep = Float(1 - damping)
        var out = FieldGrid(width: w, height: h, channels: current.channels)
        guard w > 2, h > 2 else { return out }
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let u = current[x, y, 0]
                let lap = (current[x - 1, y, 0] + current[x + 1, y, 0]) + (current[x, y - 1, 0] + current[x, y + 1, 0])
                    - 4 * u
                out[x, y, 0] = precision.round((2 * u - previous[x, y, 0] + c2 * lap) * keep)
            }
        }
        return out
    }

    /// The discrete leapfrog energy of the pair (`current` = uⁿ⁺¹, `previous` = uⁿ): Σ(uⁿ⁺¹ − uⁿ)² + C² Σ over
    /// unordered horizontal and vertical neighbour pairs (uⁿ⁺¹ᵢ − uⁿ⁺¹ⱼ)(uⁿᵢ − uⁿⱼ), the border pairs included. With
    /// `damping` γ > 0 it is the damped energy (1 − γ) · that + γ Σ(uⁿ⁺¹)², which the damped scheme multiplies by
    /// exactly 1 − γ per step (see the file header). NaN when the shapes differ.
    public static func energy(current: FieldGrid, previous: FieldGrid, courant: Double,
                              damping: Double = 0) -> Double {
        let w = current.width, h = current.height
        guard previous.width == w, previous.height == h, previous.channels == current.channels else { return .nan }
        var kinetic = 0.0, potential = 0.0, square = 0.0
        for y in 0..<h {
            for x in 0..<w {
                let a = Double(current[x, y, 0]), b = Double(previous[x, y, 0])
                kinetic += (a - b) * (a - b)
                square += a * a
                if x + 1 < w {
                    potential += (a - Double(current[x + 1, y, 0])) * (b - Double(previous[x + 1, y, 0]))
                }
                if y + 1 < h {
                    potential += (a - Double(current[x, y + 1, 0])) * (b - Double(previous[x, y + 1, 0]))
                }
            }
        }
        let undamped = kinetic + courant * courant * potential
        return damping == 0 ? undamped : (1 - damping) * undamped + damping * square
    }
}
