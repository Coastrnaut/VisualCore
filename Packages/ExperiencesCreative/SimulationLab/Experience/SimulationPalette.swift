// SimulationPalette — feature 117 (A16-P01) T-A16-105 (FR-A16-130). The family colour maps from the CPU field to RGBA8
// pixels, one pixel per cell, rows bottom-up (the field's own order and GL's), alpha 255:
//   cellular automaton  dead cells dark navy (13, 17, 31), alive cells bright mint (120, 240, 190);
//   reaction-diffusion  from the inhibitor v, t = clamp(v / 0.5, 0, 1), through deep blue (20, 30, 90) at t = 0, teal
//                       (40, 170, 160) at t = 0.5 and yellow (250, 230, 120) at t = 1;
//   wave field          a diverging map around 0: h = clamp(height, −1, 1) from a dark neutral (24, 24, 32) at 0 toward
//                       blue (40, 110, 255) at −1 and orange (255, 140, 40) at +1.
// Colour is never the only information: the canvas description carries the family, the preset, the state and the
// field in numbers (`SimulationCore.canvasDescription`). Each channel is `(a + (b − a) · t)` rounded to the nearest
// byte, so the map is exact and the same on every device.
import SimulationLabCore
import VisualCoreSimulation

/// The colour maps of the three families.
enum SimulationPalette {
    /// An RGB colour of bytes.
    typealias RGB = (r: UInt8, g: UInt8, b: UInt8)

    /// The canvas around the grid (Rec. 709 luma about 9 of 255: the `dark` colour class).
    static let background: RGB = (8, 9, 15)
    /// The automaton's dead cells.
    static let dead: RGB = (13, 17, 31)
    /// The automaton's alive cells.
    static let alive: RGB = (120, 240, 190)
    /// The reaction-diffusion stops at t = 0, 0.5 and 1.
    static let reactionStops: [RGB] = [(20, 30, 90), (40, 170, 160), (250, 230, 120)]
    /// The v that maps to the last reaction-diffusion stop.
    static let reactionScale: Float = 0.5
    /// The wave's colour at height 0.
    static let waveZero: RGB = (24, 24, 32)
    /// The wave's colour at height −1.
    static let waveNegative: RGB = (40, 110, 255)
    /// The wave's colour at height +1.
    static let wavePositive: RGB = (255, 140, 40)

    /// The background as RGBA floats 0…1, for the display pass.
    static var backgroundRGBA: SIMD4<Float> {
        SIMD4(Float(background.r) / 255, Float(background.g) / 255, Float(background.b) / 255, 1)
    }

    /// `a + (b − a) · t` per channel, rounded to the nearest byte; `t` is clamped to 0…1 (NaN counts as 0).
    static func mix(_ a: RGB, _ b: RGB, _ t: Float) -> RGB {
        let s = t.isNaN ? 0 : min(max(t, 0), 1)
        func channel(_ x: UInt8, _ y: UInt8) -> UInt8 {
            UInt8((Float(x) + (Float(y) - Float(x)) * s).rounded())
        }
        return (channel(a.r, b.r), channel(a.g, b.g), channel(a.b, b.b))
    }

    /// The colour of an automaton cell: alive for a value of at least 0.5, dead otherwise.
    static func automatonColor(_ value: Float) -> RGB {
        value >= 0.5 ? alive : dead
    }

    /// The colour of a reaction-diffusion cell from its v.
    static func reactionColor(v: Float) -> RGB {
        let t = v.isNaN ? 0 : min(max(v / reactionScale, 0), 1)
        return t <= 0.5 ? mix(reactionStops[0], reactionStops[1], t * 2) : mix(reactionStops[1], reactionStops[2],
                                                                              (t - 0.5) * 2)
    }

    /// The colour of a wave cell from its height.
    static func waveColor(_ height: Float) -> RGB {
        let h = height.isNaN ? 0 : min(max(height, -1), 1)
        return h >= 0 ? mix(waveZero, wavePositive, h) : mix(waveZero, waveNegative, -h)
    }

    /// The colour of cell `index` of `grid` for `kind`.
    static func color(_ grid: FieldGrid, cell index: Int, kind: SimulationKind) -> RGB {
        let base = index * grid.channels
        switch kind {
        case .automaton: return automatonColor(grid.values[base])
        case .reactionDiffusion: return reactionColor(v: grid.values[base + 1])
        case .wave: return waveColor(grid.values[base])
        }
    }

    /// The RGBA8 pixels of `field` for `kind`: width × height × 4 bytes, rows bottom-up, alpha 255.
    static func rgba(_ field: SimulationField, kind: SimulationKind) -> [UInt8] {
        let grid = field.current
        let cells = grid.width * grid.height
        var pixels = [UInt8](repeating: 255, count: cells * 4)
        for index in 0..<cells {
            let c = color(grid, cell: index, kind: kind)
            pixels[index * 4] = c.r
            pixels[index * 4 + 1] = c.g
            pixels[index * 4 + 2] = c.b
        }
        return pixels
    }

    /// `pixels` (RGBA8) as floats n / 255 for `RenderTarget.upload(rgbaFloats:)`.
    static func floats(_ pixels: [UInt8]) -> [Float] {
        var values = [Float](repeating: 0, count: pixels.count)
        for i in pixels.indices { values[i] = Float(pixels[i]) / 255 }
        return values
    }
}
