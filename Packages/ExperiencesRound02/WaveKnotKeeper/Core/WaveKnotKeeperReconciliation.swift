// WaveKnotKeeperReconciliation — feature 327 (R02-G03-07) T-R02G0307-002 (FR-R02G0307-003; clarifications Q1, Q2).
// Restored scores are checked against the rules before they count: each result that carries a trace (or claims to be
// verified) is replayed on a fresh play of its certified level, and the result is kept only when every trace move is
// legal and the play ends won after exactly `bestMoves` moves with the recorded stars (the stars rule for that count
// against the certified shortest). Results without a trace (written before schema 3) are kept, unverified. The frontier
// is kept as saved: dropping a result never closes a level, and a daily win never opens one (feature 325), so a kept
// daily result may lie beyond the frontier. Pure and deterministic: no clock, no random source; the certified levels
// come from the per-process cache of ``WaveKnotKeeperExperienceCore/generated(number:)``. Modelled on feature 317's
// LissajousLabyrinthReconciliation.
import Foundation

/// The check of restored Wave Knot Keeper scores (see the file header).
public enum WaveKnotKeeperReconciliation {
    /// Whether `result` of `level` replays: its trace is non-empty and has exactly `bestMoves` moves, every move is legal
    /// on a fresh play of certified level `level` (1 … 100), the play ends won after the last one, and `stars` is
    /// ``WaveKnotKeeperProgress/stars(moves:shortest:)`` for `bestMoves` against the certified shortest. False for
    /// anything else, including a result without a trace or a level that cannot be generated.
    public static func verifies(level: Int, result: WaveKnotKeeperProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count == result.bestMoves else { return false }
        guard WaveKnotKeeperExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(WaveKnotKeeperError) {
            let certified: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: level)
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperExperienceCore.freshPlay(of: certified.level)
            for move in result.trace {
                try play.apply(move, expecting: play.fingerprint)
            }
            guard play.stage == .won, play.spent == result.bestMoves else { return false }
            return result.stars == WaveKnotKeeperProgress.stars(moves: result.bestMoves,
                                                                shortest: certified.solution.shortest)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one (see the file header).
    public static func reconcile(_ progress: WaveKnotKeeperProgress)
        -> (progress: WaveKnotKeeperProgress, dropped: Int) {
        var kept: WaveKnotKeeperProgress = progress
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
