// LissajousLabyrinthReconciliation — feature 317 (R02-G02-07) T-R02G0207-002 (FR-R02G0207-003; clarifications Q1, Q2;
// research R2–R4). Restored scores are checked against the rules before they count: each result that carries a trace (or
// claims to be verified) is replayed on a fresh play of its certified level, and the result is kept only when every
// trace action is legal and the play ends won after exactly `bestActions` actions with the recorded stars (the stars
// rule for that count against the certified shortest). Results without a trace (written before schema 3) are kept,
// unverified. The frontier is kept as saved (research R4): dropping a result never closes a level, and a daily win
// never opens one (feature 315), so a kept daily result may lie beyond the frontier. Pure and deterministic: no clock,
// no random source; the certified levels come from the per-process cache of
// ``LissajousLabyrinthExperienceCore/generated(number:)``.
import Foundation

/// The check of restored Lissajous Labyrinth scores (see the file header).
public enum LissajousLabyrinthReconciliation {
    /// Whether `result` of `level` replays: its trace is non-empty and has exactly `bestActions` actions, every action
    /// is legal on a fresh play of certified level `level` (1 … 100), the play ends won after the last one, and `stars`
    /// is ``LissajousLabyrinthProgress/stars(actions:shortest:)`` for `bestActions` against the certified shortest.
    /// False for anything else, including a result without a trace or a level that cannot be generated.
    public static func verifies(level: Int, result: LissajousLabyrinthProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count == result.bestActions else { return false }
        guard LissajousLabyrinthExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(LissajousLabyrinthError) {
            let certified: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: level)
            var play: LissajousLabyrinthPlay = try LissajousLabyrinthExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won, play.spent == result.bestActions else { return false }
            return result.stars == LissajousLabyrinthProgress.stars(actions: result.bestActions,
                                                                    shortest: certified.solution.shortest)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one (see the file header).
    public static func reconcile(_ progress: LissajousLabyrinthProgress)
        -> (progress: LissajousLabyrinthProgress, dropped: Int) {
        var kept: LissajousLabyrinthProgress = progress
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
