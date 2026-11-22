// AmethystEscapeReconciliation — feature 367 (R02-G07-07) T-R02G0707-002 (clarifications Q1 … Q3; research R2, R3,
// R6; contracts/api.md). Restored scores are checked against the rules before they count: each result that carries a
// trace (or claims to be verified) is replayed on a fresh play of its certified level (campaign budget, begun with its
// tutorial dismissed as the adapter does), and the result is kept only when every trace action is legal and the play
// ends won with exactly `bestMoves` moves spent and the recorded stars (the stars rule for that count against the
// certified smallest move count). A trace with more than 64 actions never verifies (bounded restore work). Results
// without a trace that are not marked verified (written before schema 3) are kept, unverified. The frontier is kept as
// saved: dropping a result never closes a level. The net actions of a play's records (``netTrace(_:)``) are the trace
// the adapter stores with a win. Pure and deterministic: no clock, no random source; the certified levels come from the
// per-process cache of ``AmethystEscapeExperienceCore/generated(number:)``. Modelled on feature 357's
// ChronoConstellatorReconciliation.
import Foundation

/// The check of restored Amethyst Escape scores and the trace of a play (see the file header).
public enum AmethystEscapeReconciliation {
    /// The longest trace that can verify: 64 actions.
    public static let maxTraceLength: Int = 64

    /// The net actions of a play's `records`: each rotate or advance record appends its action and clears the redo
    /// stack; each undo removes the last net action and pushes it on the redo stack; each redo pops it back onto the net
    /// actions. The result never holds an undo or a redo; an undone action is left out unless redone. Replayed on a
    /// fresh play of the same level, the net actions reach the same fingerprint as the records.
    public static func netTrace(_ records: [AmethystEscapeRecord]) -> [AmethystEscapeAction] {
        var net: [AmethystEscapeAction] = []
        var redo: [AmethystEscapeAction] = []
        for record in records {
            switch record.kind {
            case .rotate, .advance:
                guard let action = record.action else { continue }
                net.append(action)
                redo.removeAll()
            case .undo:
                if let last = net.popLast() { redo.append(last) }
            case .redo:
                if let again = redo.popLast() { net.append(again) }
            }
        }
        return net
    }

    /// Whether `result` of `level` replays: its trace holds 1 … ``maxTraceLength`` actions, every action is legal on a
    /// fresh play of certified level `level` (1 … 100) with the campaign budget, the play ends won with exactly
    /// `bestMoves` moves spent, and `stars` is ``AmethystEscapeProgress/stars(moves:smallest:)`` for `bestMoves` against
    /// the certified solution's smallest move count. False for anything else, including a result without a trace or a
    /// level that cannot be generated.
    public static func verifies(level: Int, result: AmethystEscapeProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength else { return false }
        guard AmethystEscapeExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(AmethystEscapeError) {
            let certified: AmethystEscapeGenerated = try AmethystEscapeExperienceCore.generated(number: level)
            var play: AmethystEscapePlay = try AmethystEscapePlay.replay(level: certified.level, records: [])
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won, play.moves == result.bestMoves else { return false }
            return result.stars == AmethystEscapeProgress.stars(moves: result.bestMoves,
                                                                smallest: certified.solution.smallest)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: AmethystEscapeProgress
    ) -> (progress: AmethystEscapeProgress, dropped: Int) {
        var kept: AmethystEscapeProgress = progress
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
