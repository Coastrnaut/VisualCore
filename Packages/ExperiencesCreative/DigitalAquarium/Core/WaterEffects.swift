// WaterEffects — feature 071 (A09-P04) T-A09-403 (FR-A09-401–404, 410; clarifications 1 and 2; research D1, D2;
// data-model "Bubble", "Mote", "Depth layer"). Bubbles, drifting motes and depth layers as pure functions of the
// aquarium's step count (60 steps per second), so nothing is saved and everything holds while the step count holds
// (paused or suspended). Coordinates are habitat units: the tank is 16 × 9 (x 0…16, y 0…9, y up).
//
// Bubbles: vent `v` (an x position on the gravel) has the phase `(v mod 2) × 10` steps; its bubble `k` (k ≥ 0) is
// released at step `20k + phase`; its age is `(step − release) / 60` s; it rises from `ventY` at `riseSpeed` (Reduce
// Motion: half) with a sideways wobble `wobble × sin(2π × wobbleHz × age + k)` (Reduce Motion: none) and is alive
// while it is below `surface`. Each vent gives at most its newest `bubblesPerVent` bubbles, newest first; the vents
// follow in order and the whole list is cut to `maxBubbles`, so with up to two vents nothing is cut and with more the
// later vents give way.
//
// Motes: `moteCount` base positions from `SeededRandom(seed: 0x0A09)` (x 0…16, y 2…8) drift sideways at `moteSpeed`
// (Reduce Motion: a tenth), wrapping into 0…16, and sway ±0.15 units at 0.1 Hz (Reduce Motion: a tenth of the
// amplitude) around their base, clamped to 1.5…8.5.
//
// Depth layers: fish `i` and plant `i` are in layer `i mod 3` (0 back, 1 middle, 2 front), drawn at scale 0.75, 0.875
// and 1.0 and tinted 35 %, 15 % and 0 % toward the water colour.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Bubbles, motes and depth layers of the aquarium, derived from the step count alone.
public enum WaterEffects {
    /// The most bubbles drawn at once over all vents.
    public static let maxBubbles = 48
    /// The most bubbles one vent gives at once.
    public static let bubblesPerVent = 24
    /// Steps between two bubbles of one vent.
    public static let releaseInterval = 20
    /// The number of drifting motes.
    public static let moteCount = 24
    /// Bubble rise speed in habitat units per second (Reduce Motion: half).
    public static let riseSpeed = 1.2
    /// Sideways wobble amplitude of a bubble in habitat units (Reduce Motion: none).
    public static let wobble = 0.08
    /// Wobble frequency in hertz.
    public static let wobbleHz = 1.5
    /// The water surface height; a bubble that reaches it is gone.
    public static let surface = 9.0
    /// The height bubbles are released at (the top of the gravel).
    public static let ventY = 1.0
    /// Mote drift speed in habitat units per second (Reduce Motion: a tenth).
    public static let moteSpeed = 0.05

    /// Steps per second of the aquarium's simulation.
    static let stepsPerSecond = 60.0
    /// The phase offset in steps between neighbouring vents.
    static let ventPhase = 10
    /// The mote sway amplitude in habitat units (Reduce Motion: a tenth).
    static let moteSway = 0.15
    /// The mote sway frequency in hertz.
    static let moteSwayHz = 0.1
    /// The vertical range motes stay in.
    static let moteYRange = 1.5...8.5

    /// The release step offset of vent `index`: 0 for even and 10 for odd vents.
    static func phase(vent index: Int) -> Int { (index % 2) * ventPhase }

    /// The bubbles alive at `step` for vents at the x positions `vents`: per vent newest first, vents in order, at
    /// most ``bubblesPerVent`` per vent and ``maxBubbles`` in all. Every bubble is at or above ``ventY`` and below
    /// ``surface``, and within ``wobble`` of its vent's x (exactly at it with Reduce Motion). A negative step or no
    /// vents give no bubbles. The same arguments always give the same list.
    public static func bubbles(step: Int, vents: [Double], reduceMotion: Bool) -> [Vec2] {
        guard step >= 0 else { return [] }
        let speed = reduceMotion ? riseSpeed * 0.5 : riseSpeed
        var result: [Vec2] = []
        result.reserveCapacity(min(maxBubbles, vents.count * bubblesPerVent))
        for (index, ventX) in vents.enumerated() {
            if result.count >= maxBubbles { break }
            let offset = phase(vent: index)
            guard step >= offset else { continue }
            let newest = (step - offset) / releaseInterval
            var k = newest, given = 0
            while k >= 0, given < bubblesPerVent, result.count < maxBubbles {
                let release = releaseInterval * k + offset
                let age = Double(step - release) / stepsPerSecond
                let y = ventY + speed * age
                guard y < surface else { break }  // older bubbles are higher still
                let sway = reduceMotion ? 0 : wobble * sin(2 * Double.pi * wobbleHz * age + Double(k))
                result.append(Vec2(ventX + sway, y))
                given += 1
                k -= 1
            }
        }
        return result
    }

    /// The motes' base positions: ``moteCount`` points from `SeededRandom(seed: 0x0A09)`, x in 0…16, y in 2…8.
    static let moteBases: [Vec2] = {
        var random = SeededRandom(seed: 0x0A09)
        return (0..<moteCount).map { _ in
            let x = random.range(0...SwimBounds.tankWidth)
            let y = random.range(2.0...8.0)
            return Vec2(x, y)
        }
    }()

    /// The ``moteCount`` motes at `step`: each drifts sideways from its seeded base at ``moteSpeed`` (Reduce Motion:
    /// a tenth), wrapped into 0 ≤ x < 16, and sways ±0.15 at 0.1 Hz (Reduce Motion: ±0.015) around its base height,
    /// inside 1.5…8.5. The same arguments always give the same list.
    public static func motes(step: Int, reduceMotion: Bool) -> [Vec2] {
        let t = Double(step) / stepsPerSecond
        let speed = reduceMotion ? moteSpeed * 0.1 : moteSpeed
        let sway = reduceMotion ? moteSway * 0.1 : moteSway
        let width = SwimBounds.tankWidth
        return moteBases.enumerated().map { index, base in
            var x = (base.x + speed * t).truncatingRemainder(dividingBy: width)
            if x < 0 { x += width }
            if x >= width { x = 0 }
            let y = base.y + sway * sin(2 * Double.pi * moteSwayHz * t + Double(index))
            return Vec2(x, min(max(y, moteYRange.lowerBound), moteYRange.upperBound))
        }
    }

    /// The depth layer of fish or plant `index`: `index mod 3` (0 back, 1 middle, 2 front), never negative.
    public static func layer(index: Int) -> Int { ((index % 3) + 3) % 3 }

    /// The drawing scale of `layer` (taken mod 3): 0.75 back, 0.875 middle, 1.0 front.
    public static func scale(layer: Int) -> Double {
        switch self.layer(index: layer) {
        case 0: 0.75
        case 1: 0.875
        default: 1.0
        }
    }

    /// The tint amount toward the water colour of `layer` (taken mod 3): 0.35 back, 0.15 middle, 0 front.
    public static func tint(layer: Int) -> Double {
        switch self.layer(index: layer) {
        case 0: 0.35
        case 1: 0.15
        default: 0.0
        }
    }

    /// `color` mixed linearly toward `water` by `amount` (clamped to 0…1; a non-finite amount counts as 0) in red,
    /// green and blue; the alpha of `color` is kept.
    public static func tinted(_ color: RGBA, toward water: RGBA, amount: Double) -> RGBA {
        let f = amount.isFinite ? min(max(amount, 0), 1) : 0
        return RGBA(color.r + (water.r - color.r) * f, color.g + (water.g - color.g) * f,
                    color.b + (water.b - color.b) * f, color.a)
    }
}
