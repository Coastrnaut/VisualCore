// SuccessCue — feature 099 (A13-P04) T-A13-404 (FR-A13-420, FR-A13-421; clarification Q3; research D5; data-model
// "SuccessCue"). The rules of the success cue that plays once on every transition to solved.
//
// Brightness of the success border: 1 + 0.5·sin(π·t/0.6) for 0 ≤ t < 0.6 s, otherwise 1 — one rise to at most
// ``SuccessCue/peak`` and one fall, never repeated (well under three changes a second). Exactly 1 under Reduce Motion
// (a static border) and under Reduce Flashing (no brightness change); a negative or non-finite elapsed time gives 1.
//
// Words: "Level N solved in M moves. Level N+1 is open." — the second sentence only when the solve opened the next
// level and the level is not the last; "move" singular for 1.
//
// Sound: a sine sweep 660 → 990 Hz, 0.25 s, attack 0.01 s, release 0.1 s, gain 0.3, no noise. The parameters are
// plain constants so the experience builds the VisualCore sound effect and this core stays free of audio.
import Foundation

/// The rules of Light Maze's success cue: border brightness over time, the spoken words and the sound parameters.
public enum SuccessCue {
    /// The length of the border brightening in seconds.
    public static let duration = 0.6
    /// The highest brightness factor the border reaches (at half the duration).
    public static let peak = 1.5

    /// The start frequency of the success sound's sine sweep in hertz.
    public static let soundStartFrequency = 660.0
    /// The end frequency of the success sound's sine sweep in hertz.
    public static let soundEndFrequency = 990.0
    /// The length of the success sound in seconds.
    public static let soundDuration = 0.25
    /// The attack time of the success sound's envelope in seconds.
    public static let soundAttack = 0.01
    /// The release time of the success sound's envelope in seconds.
    public static let soundRelease = 0.1
    /// The linear gain of the success sound (0…1).
    public static let soundGain = 0.3

    /// The border brightness factor `elapsed` seconds after the solve.
    ///
    /// 1 + 0.5·sin(π·t/``duration``) for 0 ≤ t < ``duration``, otherwise 1. Exactly 1 when `reduceMotion` or
    /// `reduceFlashing` is true, or when `elapsed` is negative or not finite.
    /// - Parameters:
    ///   - elapsed: Seconds since the transition to solved.
    ///   - reduceMotion: True when Reduce Motion is on (static border).
    ///   - reduceFlashing: True when Reduce Flashing (Dim Flashing Lights) is on (no brightness change).
    /// - Returns: A factor in 1…``peak``.
    public static func brightness(elapsed: Double, reduceMotion: Bool, reduceFlashing: Bool) -> Double {
        if reduceMotion || reduceFlashing { return 1 }
        guard elapsed.isFinite, elapsed >= 0, elapsed < duration else { return 1 }
        let value: Double = 1 + (peak - 1) * sin(Double.pi * elapsed / duration)
        return min(max(value, 1), peak)
    }

    /// The words spoken and shown when a level is solved.
    ///
    /// "Level N solved in M moves. Level N+1 is open." — the second sentence only when `nextOpened` is true and
    /// `isLast` is false; "move" singular for 1.
    /// - Parameters:
    ///   - levelNumber: The 1-based number of the solved level.
    ///   - moves: The moves the solve took.
    ///   - nextOpened: True when this solve opened the next level.
    ///   - isLast: True when the solved level is the last level.
    /// - Returns: One or two sentences.
    public static func words(levelNumber: Int, moves: Int, nextOpened: Bool, isLast: Bool) -> String {
        let unit: String = moves == 1 ? "move" : "moves"
        let solved: String = "Level \(levelNumber) solved in \(moves) \(unit)."
        guard nextOpened, !isLast else { return solved }
        return solved + " Level \(levelNumber + 1) is open."
    }
}
