// HueCompassReconciliation — feature 337 (R02-G04-07) T-R02G0407-002 (FR-R02G0407-003; clarifications Q1, Q2; research
// R3, R4, R6). Restored scores are checked against the rules before they count: each result that carries a trace (or
// claims to be verified) is replayed on a fresh play of its certified level (campaign allowance, begun with its tutorial
// dismissed as the adapter does), and the result is kept only when every trace action is legal and the play ends won
// having spent exactly `bestUnits` units with the recorded stars (the stars rule for that count against the certified
// smallest probe count). A trace longer than 24 units plus 48 turns per unit never verifies (bounded restore work).
// Results without a trace (written before schema 3) are kept, unverified. The frontier is kept as saved: dropping a
// result never closes a level, and a daily win never opens one, so a kept daily result may lie beyond the frontier.
// Pure and deterministic: no clock, no random source; the certified levels come from the per-process cache of
// ``HueCompassExperienceCore/generated(number:)``. Modelled on feature 327's WaveKnotKeeperReconciliation.
import Foundation

/// The check of restored Hue Compass scores (see the file header).
public enum HueCompassReconciliation {
    /// Whether `result` of `level` replays: its trace is non-empty and at most
    /// ``HueCompassProgress/maximumTraceLength`` actions, every action is legal on a fresh play of certified level
    /// `level` (1 … 100) with campaign allowance, the play ends won after the last one having spent exactly `bestUnits`
    /// units, and `stars` is ``HueCompassProgress/stars(units:smallest:)`` for `bestUnits` against the certified smallest
    /// probe count. False for anything else, including a result without a trace or a level that cannot be generated.
    public static func verifies(level: Int, result: HueCompassProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= HueCompassProgress.maximumTraceLength else { return false }
        guard HueCompassExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(HueCompassError) {
            let certified: HueCompassGenerated = try HueCompassExperienceCore.generated(number: level)
            var play: HueCompassPlay = try HueCompassExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won, play.spent == result.bestUnits else { return false }
            return result.stars == HueCompassProgress.stars(units: result.bestUnits,
                                                            smallest: certified.solution.smallest)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one (see the file header).
    public static func reconcile(_ progress: HueCompassProgress) -> (progress: HueCompassProgress, dropped: Int) {
        var kept: HueCompassProgress = progress
        var dropped: Int = 0
        for level in progress.solved.keys.sorted() {
            guard let result = progress.solved[level], result.verified || !result.trace.isEmpty else { continue }
            if !verifies(level: level, result: result) {
                kept.drop(level: level)
                dropped += 1
            }
        }
        return (kept, dropped)
    }
}
