// ColorfallCanyonsSoundRecipe — feature 346 (R02-G05-06) T-R02G0506-005 (FR-R02G0506-006; SC-R02G0506-004;
// clarification Q4; research R6). The optional ambient sound of Colorfall Canyons as an `AmbientLoopRecipe`, a pure
// function of the basins' colour masses and the stage, so equal basins sound equal. The chord shows which colours have
// arrived: a root at 98 Hz (G2) always sounds; each colour that has any mass in any basin adds its partial — cyan the
// fifth (98 × 3/2 = 147 Hz), coral the major third (98 × 5/4 = 122.5 Hz), yellow the octave (98 × 2 = 196 Hz) — with
// amplitude base × (0.3 + 0.7 · s), where s is that colour's share of all the mass held in basins, so the dominant colour
// sounds loudest. With no fluid in any basin the root sounds alone. A won play adds a brighter octave (196 Hz) at the base
// amplitude, kept as its own partial even when yellow already sounds at 196 Hz, so the won sound always differs. A failed
// play halves every amplitude and the loop gain (the synthesiser normalises the summed partials to the loop gain, so the
// gain is what makes it quieter). The loop lasts 10 s, so every partial has a whole number of cycles in it: 980 (root),
// 1,470 (cyan), 1,225 (coral) and 1,960 (yellow and the won octave). Bounds: at most 5 partials (limit 6), amplitudes ≤
// 0.8 (limit 1), gain ≤ 0.14 (limit 0.3), 10 s (limit 4 … 16), so every recipe is valid. A basin's mass list is read as
// cyan, coral, yellow; missing entries count as 0 and negative masses as 0.
import VisualCoreAudioDSP

/// The ambient loop recipe of Colorfall Canyons (presentation only; the presenter builds it at level open, when the
/// basins' masses or the stage change, and when the Sound toggle turns on).
public enum ColorfallCanyonsSoundRecipe {
    /// The loop length in seconds.
    public static let seconds = 10
    /// The root frequency in hertz (G2).
    public static let rootHertz = 98.0
    /// The amplitude of the root and the won octave, and the base of every colour partial.
    public static let baseAmplitude = 0.8
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.14
    /// The share of the base amplitude every present colour gets before its mass share is added.
    public static let floorShare = 0.3

    /// The root's cycles per loop (980).
    public static var rootCycles: Int { Int((rootHertz * Double(seconds)).rounded()) }

    /// The cycles per loop of each colour's partial, cyan, coral, yellow: the root × 3/2, × 5/4 and × 2 (1,470, 1,225
    /// and 1,960).
    public static var colourCycles: [Int] { [rootCycles * 3 / 2, rootCycles * 5 / 4, rootCycles * 2] }

    /// The cycles per loop of the won octave (1,960, 196 Hz).
    public static var octaveCycles: Int { rootCycles * 2 }

    /// The total mass of each colour (cyan, coral, yellow) over every basin in `basinMasses`; missing entries and
    /// negative masses count as 0.
    public static func colourTotals(_ basinMasses: [[Int]]) -> [Int] {
        var totals: [Int] = [0, 0, 0]
        for masses in basinMasses {
            for color in 0..<min(masses.count, 3) { totals[color] += max(masses[color], 0) }
        }
        return totals
    }

    /// The recipe for the basins' colour masses `basinMasses` (one list of cyan, coral, yellow masses per basin) and
    /// `stage`: 10 s, one swell; the root (980 cycles, the base amplitude); for each colour with mass in a basin its
    /// partial (``colourCycles``) at base × (0.3 + 0.7 · its share of all basin mass); when won the octave (1,960 cycles,
    /// the base amplitude, always its own partial); gain ``baseGain``. A failed play halves every amplitude and the gain.
    /// Always valid.
    public static func recipe(basinMasses: [[Int]], stage: ColorfallCanyonsStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let totals: [Int] = colourTotals(basinMasses)
        let all: Int = totals.reduce(0, +)
        let cycles: [Int] = colourCycles
        var partials: [AmbientLoopPartial] = [AmbientLoopPartial(cyclesPerLoop: rootCycles,
                                                                 amplitude: baseAmplitude * scale)]
        if all > 0 {
            for color in 0..<3 where totals[color] > 0 {
                let share: Double = Double(totals[color]) / Double(all)
                let amplitude: Double = baseAmplitude * (floorShare + (1 - floorShare) * share) * scale
                partials.append(AmbientLoopPartial(cyclesPerLoop: cycles[color], amplitude: amplitude))
            }
        }
        if stage == .won {
            partials.append(AmbientLoopPartial(cyclesPerLoop: octaveCycles, amplitude: baseAmplitude * scale))
        }
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: 1, gain: baseGain * scale)
    }

    /// The basins' colour masses of `snapshot`: the masses of each basin's cell, in basin order (an out-of-range cell
    /// gives no masses).
    public static func basinMasses(_ snapshot: ColorfallCanyonsSceneSnapshot) -> [[Int]] {
        var result: [[Int]] = []
        result.reserveCapacity(snapshot.basins.count)
        for basin in snapshot.basins {
            result.append(snapshot.masses.indices.contains(basin.cell) ? snapshot.masses[basin.cell] : [])
        }
        return result
    }
}
