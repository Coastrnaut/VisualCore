// WorldPreset — feature 089 (A12-P01) T-A12-103 (FR-A12-110, FR-A12-111; clarification 3; research D3; data-model
// "WorldPreset"). The three terrain recipes of Tiny Worlds. Every world is 12 × 12 m, centred at the origin in the x–z
// plane (x and z in −6…6, y up), and every terrain height is clamped into −1…1.6 m. The shaping is a pure function of
// (x, z) and the seed; it uses only +, −, ×, ÷, floor, min and max on binary64 values (falloffs are smoothsteps of
// squared distances, so there is no square root, trigonometric or exponential call), so a seed gives the same heights
// on every supported device.
//
// - island (index 0): 64 × 64 cells; h = 1.6 × (0.5 + 0.5 n) − 1.8 × smoothstep(0.15, 1, r²/36), with n the fractal
//   noise (4 octaves, frequency 0.18 per metre, lacunarity 2, gain 0.5) and r² = x² + z²: a rounded landmass whose
//   rim sinks below sea level 0 towards the edge (from r ≈ 5.5 m on and at every corner). Drawn with a sea plane at 0.
// - asteroid garden (index 1): 64 × 64 cells; a rocky disc of radius 5.5 m, rock = 0.35 + 0.6 n (n: 5 octaves, 0.3 per
//   metre); 6 craters (centres within 4.5 m of the centre, radius 0.6…1.4 m, depth 0.35 × radius, bowl profile
//   −depth × (1 − q)² with q = d²/radius²) and then 8 boulder mounds (centres within 4.5 m, radius 0.4…0.9 m, height
//   0.25…0.55 m, profile height × (1 − q)²), all drawn from `SeededRandom(seed: UInt64(seed))` in that order before the
//   field is sampled (a centre is drawn as x, z uniform in −4.5…4.5, redrawn until inside the 4.5 m disc); outside
//   the disc the surface falls to −1 over smoothstep(1, 1.44, r²/5.5²) (radius 5.5…6.6 m). No sea plane: the void
//   colour is the background.
// - miniature city (index 2): 48 × 48 cells; base = 0.2 + 1.3 × (0.5 + 0.5 n) (n: 2 octaves, 0.12 per metre)
//   quantised into 0.35 m terraces as 0.1 + 0.35 × floor(base / 0.35), a square plateau whose edge (m = max(|x|, |z|))
//   falls to −0.6 over smoothstep(4.8, 5.6, m). Drawn with a sea plane at 0.
//
// The noise of every preset is seeded with `UInt64(seed)`.
import Foundation
import VisualCoreScenes
import VisualCoreSimulation

/// The three presets, by index (the `world.preset` action's choice).
public enum WorldPresetID: Int, CaseIterable, Codable, Sendable {
    /// The island: land rising from a flat sea.
    case island = 0
    /// The asteroid garden: a cratered rocky disc with boulder mounds over a dark void.
    case asteroidGarden = 1
    /// The miniature city: a terraced plateau of block-like rises in a sea.
    case miniatureCity = 2

    /// The content id (kebab-case), equal to the preset record's and the palette's id.
    public var contentId: String {
        switch self {
        case .island: "island"
        case .asteroidGarden: "asteroid-garden"
        case .miniatureCity: "miniature-city"
        }
    }

    /// The display name.
    public var name: String {
        switch self {
        case .island: "Island"
        case .asteroidGarden: "Asteroid garden"
        case .miniatureCity: "Miniature city"
        }
    }
}

/// A round terrain feature (crater or mound): its centre, radius and amplitude (depth or height) in metres.
public struct TerrainFeature: Equatable, Sendable {
    /// Centre x in metres.
    public var x: Double
    /// Centre z in metres.
    public var z: Double
    /// Radius in metres.
    public var radius: Double
    /// Depth (crater) or height (mound) in metres, positive.
    public var amplitude: Double

    /// Creates a feature.
    public init(x: Double, z: Double, radius: Double, amplitude: Double) {
        self.x = x; self.z = z; self.radius = radius; self.amplitude = amplitude
    }

    /// The bump profile (1 − q)² with q = d² / radius² inside the radius, 0 outside.
    func profile(x px: Double, z pz: Double) -> Double {
        let dx = px - x, dz = pz - z
        let q = (dx * dx + dz * dz) / (radius * radius)
        guard q < 1 else { return 0 }
        let w = 1 - q
        return w * w
    }
}

/// One terrain recipe: grid, noise settings, shaping rule, palette and whether a sea plane is drawn.
public struct WorldPreset: Equatable, Sendable {
    /// The side of every world in metres.
    public static let worldSize = 12.0
    /// The world's lowest x and z (the grid origin); the world spans −6…6 m.
    public static let worldOrigin = -6.0
    /// The range every terrain height is clamped into, in metres.
    public static let heightRange: ClosedRange<Double> = -1...1.6
    /// The height of the sea plane in metres.
    public static let seaLevel = 0.0

    /// Which preset this is.
    public let id: WorldPresetID
    /// Grid cells along x.
    public let columns: Int
    /// Grid cells along z.
    public let rows: Int
    /// Noise octaves.
    public let octaves: Int
    /// Noise frequency per metre.
    public let frequency: Double
    /// True when the world is drawn with a sea plane at ``seaLevel``.
    public let hasSea: Bool

    /// The edge length of one grid cell in metres (12 m / columns).
    public var cellSize: Double { Self.worldSize / Double(columns) }
    /// The id of the preset's palette (equal to its content id).
    public var paletteId: String { id.contentId }
    /// The display name.
    public var name: String { id.name }

    /// The island (64 × 64, 4 octaves at 0.18 per metre, sea).
    public static let island = WorldPreset(id: .island, columns: 64, rows: 64, octaves: 4, frequency: 0.18,
                                           hasSea: true)
    /// The asteroid garden (64 × 64, 5 octaves at 0.3 per metre, no sea).
    public static let asteroidGarden = WorldPreset(id: .asteroidGarden, columns: 64, rows: 64, octaves: 5,
                                                   frequency: 0.3, hasSea: false)
    /// The miniature city (48 × 48, 2 octaves at 0.12 per metre, sea).
    public static let miniatureCity = WorldPreset(id: .miniatureCity, columns: 48, rows: 48, octaves: 2,
                                                  frequency: 0.12, hasSea: true)
    /// All presets in index order.
    public static let all: [WorldPreset] = [island, asteroidGarden, miniatureCity]

    /// The preset with `index` (0…2), or nil.
    public static func preset(index: Int) -> WorldPreset? { all.indices.contains(index) ? all[index] : nil }

    /// The preset of `id`.
    public static func preset(_ id: WorldPresetID) -> WorldPreset { all[id.rawValue] }

    /// The shaping of this preset for `seed` (features placed, noise seeded), or nil when the noise settings are
    /// refused by `FractalNoise2D` (never for the bundled presets).
    public func shape(seed: UInt32) -> WorldShape? { WorldShape(preset: self, seed: seed) }
}

/// A preset's shaping rule for one seed: the seeded noise and, for the asteroid garden, its craters and mounds.
public struct WorldShape: Sendable {
    /// Craters and mounds are placed within this radius of the centre, in metres.
    public static let featureRadius = 4.5
    /// The asteroid garden's disc radius in metres.
    public static let discRadius = 5.5
    /// The miniature city's terrace step in metres.
    public static let terraceStep = 0.35

    /// The preset.
    public let preset: WorldPreset
    /// The seed.
    public let seed: UInt32
    /// The asteroid garden's craters (empty for the other presets).
    public let craters: [TerrainFeature]
    /// The asteroid garden's boulder mounds (empty for the other presets).
    public let mounds: [TerrainFeature]
    private let noise: FractalNoise2D

    /// Seeds the noise with `UInt64(seed)` and, for the asteroid garden, draws 6 craters and then 8 mounds from
    /// `SeededRandom(seed: UInt64(seed))`; nil when the noise settings are refused.
    public init?(preset: WorldPreset, seed: UInt32) {
        guard let noise = FractalNoise2D(seed: UInt64(seed), octaves: preset.octaves, frequency: preset.frequency,
                                         lacunarity: 2, gain: 0.5) else { return nil }
        self.preset = preset
        self.seed = seed
        self.noise = noise
        if preset.id == .asteroidGarden {
            var random = SeededRandom(seed: UInt64(seed))
            var craters: [TerrainFeature] = []
            for _ in 0..<6 {
                let (x, z) = Self.centre(&random)
                let radius = random.range(0.6...1.4)
                craters.append(TerrainFeature(x: x, z: z, radius: radius, amplitude: 0.35 * radius))
            }
            var mounds: [TerrainFeature] = []
            for _ in 0..<8 {
                let (x, z) = Self.centre(&random)
                let radius = random.range(0.4...0.9)
                mounds.append(TerrainFeature(x: x, z: z, radius: radius, amplitude: random.range(0.25...0.55)))
            }
            self.craters = craters
            self.mounds = mounds
        } else {
            craters = []
            mounds = []
        }
    }

    /// A centre uniform in the disc of radius ``featureRadius``: x and z uniform in the square, redrawn until inside
    /// (at most 64 draws; the centre of the world after that, which has probability below 1e-40).
    private static func centre(_ random: inout SeededRandom) -> (Double, Double) {
        let r = featureRadius
        for _ in 0..<64 {
            let x = random.range(-r...r), z = random.range(-r...r)
            if x * x + z * z <= r * r { return (x, z) }
        }
        return (0, 0)
    }

    /// The Hermite smoothstep of `x` between `edge0` and `edge1` (0 below, 1 above).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// The terrain height at (x, z) in metres, clamped into ``WorldPreset/heightRange`` (see the file header for each
    /// preset's rule).
    public func height(x: Double, z: Double) -> Double {
        let n = noise.value(x: x, y: z)
        let r2 = x * x + z * z
        let h: Double
        switch preset.id {
        case .island:
            h = 1.6 * (0.5 + 0.5 * n) - 1.8 * Self.smoothstep(0.15, 1, r2 / 36)
        case .asteroidGarden:
            var rock = 0.35 + 0.6 * n
            for crater in craters { rock -= crater.amplitude * crater.profile(x: x, z: z) }
            for mound in mounds { rock += mound.amplitude * mound.profile(x: x, z: z) }
            let t = Self.smoothstep(1, 1.44, r2 / (Self.discRadius * Self.discRadius))
            h = rock * (1 - t) - t
        case .miniatureCity:
            let base = 0.2 + 1.3 * (0.5 + 0.5 * n)
            let terraced = 0.1 + Self.terraceStep * (base / Self.terraceStep).rounded(.down)
            let t = Self.smoothstep(4.8, 5.6, max(abs(x), abs(z)))
            h = terraced * (1 - t) - 0.6 * t
        }
        guard h.isFinite else { return 0 }
        return min(max(h, WorldPreset.heightRange.lowerBound), WorldPreset.heightRange.upperBound)
    }
}
