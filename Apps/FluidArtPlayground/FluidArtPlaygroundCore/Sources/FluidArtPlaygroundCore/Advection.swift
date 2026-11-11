// Advection.swift — semi-Lagrangian transport, the CPU reference for the GPU advect pass (feature 020 T-A02-210;
// FR-A02-206, FR-A02-207; spec clarifications 1 and 5; research R1). Each cell looks back along its own velocity,
// `source(cell − Δt·v)`, sampled with VisualCore's exact bilinear sampler (clamp-to-edge). Bilinear resampling
// smooths the field a little every step: this numerical diffusion is expected for the artistic model, not a defect.
import VisualCoreSimulation

/// Semi-Lagrangian advection of the velocity and dye fields.
public enum Advection {
    /// One step, in the order of spec clarification 5: velocity advects itself, then dye is advected by the new
    /// velocity. Dissipation `1/(1 + d·Δt)` is applied in both. Fields are RGBA grids (velocity in channels 0–1, in
    /// cells per second, encoded with `velocityEncoding` in 8-bit storage), and results are rounded to `precision`.
    public static func step(velocity: inout FieldGrid, dye: inout FieldGrid, dt: Double, velocityDissipation: Double,
                            dyeDissipation: Double, precision: StoragePrecision, velocityEncoding: SignedRangeEncoding? = nil) {
        velocity = advect(velocity, by: velocity, dt: dt, factor: Dissipation.factor(d: velocityDissipation, dt: dt),
                          precision: precision, velocityEncoding: velocityEncoding, sourceIsVelocity: true)
        dye = advect(dye, by: velocity, dt: dt, factor: Dissipation.factor(d: dyeDissipation, dt: dt),
                     precision: precision, velocityEncoding: velocityEncoding, sourceIsVelocity: false)
    }

    /// `source` transported by `velocity` for `dt` seconds and multiplied by `factor`. When the source is encoded
    /// velocity, its channels 0–1 are decoded after sampling, scaled and re-encoded (channels 2–3 are kept).
    public static func advect(_ source: FieldGrid, by velocity: FieldGrid, dt: Double, factor: Float,
                              precision: StoragePrecision, velocityEncoding: SignedRangeEncoding?,
                              sourceIsVelocity: Bool) -> FieldGrid {
        var out = source
        let step = Float(dt)
        for y in 0..<source.height {
            for x in 0..<source.width {
                var vx = velocity[x, y, 0], vy = velocity[x, y, 1]
                if let e = velocityEncoding { vx = e.decode(vx); vy = e.decode(vy) }
                let sx = Float(x) + 0.5 - step * vx
                let sy = Float(y) + 0.5 - step * vy
                let s = source.sampleBilinear(cellX: sx, cellY: sy)
                for c in 0..<source.channels {
                    let value: Float
                    if sourceIsVelocity, c < 2, let e = velocityEncoding {
                        value = e.encode(e.decode(s[c]) * factor)
                    } else if sourceIsVelocity, velocityEncoding != nil {
                        value = s[c]
                    } else {
                        value = s[c] * factor
                    }
                    out[x, y, c] = precision.round(value)
                }
            }
        }
        return out
    }
}
