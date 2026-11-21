// HueCompassSceneSnapshot — feature 333 (R02-G04-03) T-R02G0403-002 (FR-R02G0403-002, 003, 004; clarifications Q1–Q4).
// What the renderer may read: an immutable copy of the kernel's state (the bearing, the offset, the fog, the tolerances,
// the clues seen, the selection, the stage and the level number) with the frame time, plus the palette, the 24 band
// colours with their grayscale glyphs and the three quality tiers. The target is present only once the play has ended,
// so no frame of a playing level can give the answer away; the renderer never holds the kernel, so no drawing result can
// change the game (renderer purity).

import Foundation

/// The palette of Hue Compass, sRGB components 0 … 1 (clarification Q3).
public enum HueCompassPalette {
    /// Night background, #05070F.
    public static let night = rgb(0x05, 0x07, 0x0F)
    /// Pearl, #E8E4DA (the glass needle and the probe marks).
    public static let pearl = rgb(0xE8, 0xE4, 0xDA)
    /// Sapphire, #2F6FD8 (the revealed target ring).
    public static let sapphire = rgb(0x2F, 0x6F, 0xD8)
    /// Ember, #E0703A (the selection mark).
    public static let ember = rgb(0xE0, 0x70, 0x3A)
    /// The four colours as hex strings, for the catalog: night, pearl, sapphire, ember.
    public static let hex: [String] = ["#05070F", "#E8E4DA", "#2F6FD8", "#E0703A"]
    /// The saturation of every band colour.
    public static let bandSaturation: Double = 0.85
    /// The value (brightness) of every band colour.
    public static let bandValue: Double = 1.0

    /// The colour of hue band `band` (taken modulo 24): hue band/24, saturation 0.85, value 1.0, by the standard
    /// HSV-to-RGB rule the shaders use too.
    public static func band(_ band: Int) -> SIMD3<Double> {
        let b: Int = ((band % HueCompassWheel.bands) + HueCompassWheel.bands) % HueCompassWheel.bands
        let h: Double = Double(b) / Double(HueCompassWheel.bands) * 6
        let sector: Int = Int(h)
        let f: Double = h - Double(sector)
        let v: Double = bandValue
        let p: Double = v * (1 - bandSaturation)
        let q: Double = v * (1 - bandSaturation * f)
        let t: Double = v * (1 - bandSaturation * (1 - f))
        switch sector % 6 {
        case 0: return SIMD3(v, t, p)
        case 1: return SIMD3(q, v, p)
        case 2: return SIMD3(p, v, t)
        case 3: return SIMD3(p, q, v)
        case 4: return SIMD3(t, p, v)
        default: return SIMD3(v, p, q)
        }
    }

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// The grayscale glyph of one hue band, so no band is told by colour alone: a shape (0 dot, 1 bar, 2 triangle, 3 ring,
/// band mod 4) repeated `marks` times (⌊band / 4⌋ + 1, 1 … 6). Each of the 24 bands has its own glyph.
public struct HueCompassGlyph: Sendable, Equatable, Hashable {
    /// The shape: 0 dot, 1 bar, 2 triangle, 3 ring.
    public let shape: Int
    /// How many times the shape repeats, 1 … 6.
    public let marks: Int

    /// The glyph of `band` (taken modulo 24).
    public static func of(band: Int) -> HueCompassGlyph {
        let b: Int = ((band % HueCompassWheel.bands) + HueCompassWheel.bands) % HueCompassWheel.bands
        return HueCompassGlyph(shape: b % 4, marks: b / 4 + 1)
    }
}

/// One quality tier: it changes only the needle's facets, the fog layers and the glow shells, never bearings, colours,
/// objective or indicators. Tiers are ordered richest first: index n is the catalog's `level-n` (the design's "Tier 0
/// D3-safe" is level-2).
public struct HueCompassTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The facets of the needle prism.
    public let facets: Int
    /// The layers of each fog prism.
    public let fogLayers: Int
    /// The glow shells (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: facets 12/8/4, fog layers 3/2/1, glow shells 2/1/0.
    public static let all: [HueCompassTier] = [
        HueCompassTier(index: 0, facets: 12, fogLayers: 3, glowShells: 2),
        HueCompassTier(index: 1, facets: 8, fogLayers: 2, glowShells: 1),
        HueCompassTier(index: 2, facets: 4, fogLayers: 1, glowShells: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> HueCompassTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of everything the renderer may read about one Hue Compass play at one frame.
public struct HueCompassSceneSnapshot: Sendable, Equatable {
    /// The compass bearing, 0 … 95.
    public let bearing: Int
    /// The level's hue offset, 0 … 23.
    public let offset: Int
    /// The fog density of every bearing, 96 values of 0 … 9.
    public let fog: [Int]
    /// The level's bearing tolerance.
    public let bearingTolerance: Int
    /// The level's band tolerance.
    public let bandTolerance: Int
    /// The clues seen, in order.
    public let clues: [HueCompassClue]
    /// The selection, once made.
    public let selection: HueCompassSelection?
    /// The play's stage.
    public let stage: HueCompassStage
    /// The target bearing, only once the stage is won, failed or result; nil while it could still give the answer away.
    public let target: Int?
    /// The presentation time in seconds (fog drift only; never read by the rules).
    public let time: Double
    /// The level number, 1 … 100.
    public let levelNumber: Int

    /// A snapshot of `play` at `time`; the target is copied only when the play has ended.
    public init(play: HueCompassPlay, levelNumber: Int, time: Double) {
        let level: HueCompassLevel = play.level
        bearing = play.bearing
        offset = level.offset
        fog = level.fog
        bearingTolerance = level.bearingTolerance
        bandTolerance = level.bandTolerance
        clues = play.clues
        selection = play.selection
        stage = play.stage
        target = Self.ended(play.stage) ? level.target : nil
        self.time = time.isFinite ? time : 0
        self.levelNumber = levelNumber
    }

    /// Whether `stage` is one in which the target may be shown (won, failed or result).
    public static func ended(_ stage: HueCompassStage) -> Bool {
        stage == .won || stage == .failed || stage == .result
    }

    /// The band of `bearing` in this level.
    public func band(of bearing: Int) -> Int { HueCompassWheel.band(of: bearing, offset: offset) }
}
