// AuroraLoomReconciliation — feature 307 (R02-G01-07) T-R02G0107-002 (FR-R02G0107-003; clarification Q2; data-model.md
// "AuroraLoomReconciliation"; contracts/api.md). Restored scores are checked against the rules before they count: each
// verified result's winning trace is replayed on a fresh play of its certified level, and the result is kept only when
// that play ends won after exactly `bestMoves` moves with the recorded stars (the stars rule for that count). Results
// without a trace (written before schema 3) are kept, unverified. The frontier is kept as saved but never below one
// level after the highest kept result. Pure and deterministic: no clock, no random source.
import Foundation

/// The check of restored Aurora Loom scores (see the file header).
public enum AuroraLoomReconciliation {
    /// Whether the verified `result` of `level` replays: `verified` is true, the trace has exactly `bestMoves` moves,
    /// every move is legal on a fresh play of certified level `level` (1 … 100), the play ends won after the last one
    /// and `stars` is the stars rule for `bestMoves` against the certified shortest. False for anything else, including
    /// an unverified result or a level that cannot be generated.
    public static func verifies(level: Int, result: AuroraLoomProgress.Result) -> Bool {
        guard result.verified, result.trace.count == result.bestMoves, !result.trace.isEmpty else { return false }
        guard AuroraLoomExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(AuroraLoomError) {
            let certified = try AuroraLoomExperienceCore.generated(number: level)
            var play = try AuroraLoomExperienceCore.freshPlay(of: certified.level)
            for move in result.trace {
                try play.apply(move, expecting: play.fingerprint)
            }
            guard play.stage == .won, play.spent == result.bestMoves else { return false }
            return result.stars == AuroraLoomProgress.stars(moves: result.bestMoves,
                                                            shortest: certified.solution.shortest)
        } catch {
            return false
        }
    }

    /// `progress` with every verified result that does not replay (``verifies(level:result:)``) removed, and the
    /// number removed. Unverified results are kept. The frontier is the saved one, raised to one level after the
    /// highest kept result (at most 100) when it is lower.
    public static func reconcile(_ progress: AuroraLoomProgress) -> (progress: AuroraLoomProgress, dropped: Int) {
        var kept = progress
        var dropped = 0
        for level in progress.solved.keys.sorted() {
            guard let result = progress.solved[level], result.verified else { continue }
            if !verifies(level: level, result: result) {
                kept.remove(level: level)
                dropped += 1
            }
        }
        if let highest = kept.solved.keys.max() {
            kept.frontier = max(kept.frontier, min(highest + 1, AuroraLoomProgress.levelCount))
        }
        return (kept, dropped)
    }
}
