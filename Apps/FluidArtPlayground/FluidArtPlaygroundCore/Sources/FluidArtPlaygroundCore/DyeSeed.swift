// DyeSeed.swift — initial fields (feature 019 T-A02-109; FR-A02-110). The same seed gives the same dye on the
// CPU and, after upload, on the GPU.
import Foundation
import VisualCoreSimulation

/// Initial dye and velocity fields.
public enum DyeSeed {
    /// The palette of the seeded blobs (linear RGB, values ≤ 1).
    public static let palette: [SIMD3<Float>] = [
        SIMD3(0.95, 0.35, 0.55), SIMD3(0.25, 0.65, 0.95), SIMD3(0.98, 0.78, 0.30),
        SIMD3(0.45, 0.90, 0.60), SIMD3(0.70, 0.45, 0.95), SIMD3(0.98, 0.55, 0.25),
    ]

    /// Every cell set to `rgba` (4 channels).
    public static func uniform(width: Int, height: Int, rgba: SIMD4<Float>) -> FieldGrid {
        var g = FieldGrid(width: width, height: height, channels: 4)
        for cell in 0..<(g.width * g.height) {
            for c in 0..<4 { g.values[cell * 4 + c] = rgba[c] }
        }
        return g
    }

    /// Eight soft palette-colored blobs placed by `SeededRandom(seed:)`; RGB in 0…1, alpha 1. Deterministic.
    public static func pattern(width: Int, height: Int, seed: UInt64) -> FieldGrid {
        var g = FieldGrid(width: width, height: height, channels: 4)
        var rng = SeededRandom(seed: seed)
        let w = Float(g.width), h = Float(g.height), scale = min(w, h)
        var blobs: [(x: Float, y: Float, r: Float, color: SIMD3<Float>)] = []
        for i in 0..<8 {
            let x = Float(rng.double()) * w, y = Float(rng.double()) * h
            let r = (0.10 + 0.15 * Float(rng.double())) * scale
            blobs.append((x, y, r, palette[(i + Int(rng.next() % 6)) % palette.count]))
        }
        for y in 0..<g.height {
            for x in 0..<g.width {
                var rgb = SIMD3<Float>(repeating: 0)
                for b in blobs {
                    let dx = Float(x) + 0.5 - b.x, dy = Float(y) + 0.5 - b.y
                    rgb += b.color * exp(-(dx * dx + dy * dy) / (b.r * b.r))
                }
                rgb = simd_clamp01(rgb)
                g[x, y, 0] = rgb.x
                g[x, y, 1] = rgb.y
                g[x, y, 2] = rgb.z
                g[x, y, 3] = 1
            }
        }
        return g
    }

    /// A zero velocity field (2 channels).
    public static func zeroVelocity(width: Int, height: Int) -> FieldGrid {
        FieldGrid(width: width, height: height, channels: 2)
    }

    private static func simd_clamp01(_ v: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(min(max(v.x, 0), 1), min(max(v.y, 0), 1), min(max(v.z, 0), 1))
    }
}
