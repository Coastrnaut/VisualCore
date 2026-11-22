// NocturneGardenReconciliation — feature 387 (R02-G09-07) T-R02G0907-002 (FR-R02G0907-001, 002; clarifications Q1,
// Q2; research R2, R3, R6, R7; contracts/api.md). Restored scores are checked against the rules before they count:
// each result that carries a trace (or claims to be verified) is replayed on a fresh play of its certified level
// (campaign budget, begun with its tutorial dismissed as the adapter does), and the result is kept only when every
// trace move is legal, the play ends won, the trace is at most `movesMade` long (moves made count undone moves too, so
// an honest play with undos has more moves made than effective moves) and the recorded stars are the stars rule for
// `movesMade` against the certified smallest move count. A trace with more than 40 moves (the kernel's largest budget)
// never verifies (bounded restore work). Results without a trace that are not marked verified (written before schema
// 3) are kept, unverified. The frontier is kept as saved: dropping a result never closes a level. The effective moves
// of a play's records (``netTrace(_:)``) are the trace the adapter stores with a win. Pure and deterministic: no clock,
// no random source; the certified levels come from the per-process cache of
// ``NocturneGardenExperienceCore/generated(number:)``. Modelled on feature 377's FacetedForgeReconciliation.
import Foundation

/// The check of restored Nocturne Garden scores and the trace of a play (see the file header).
public enum NocturneGardenReconciliation {
    /// The longest trace that can verify: 40 moves, the kernel's largest budget (``NocturneGardenLevel/budgets``).
    public static let maxTraceLength: Int = NocturneGardenLevel.budgets.upperBound

    /// The effective moves of a play's `records`: each plant, move, resize, remove or sun record appends its action
    /// and clears the redo stack; each undo removes the last effective move and pushes it on the redo stack; each redo
    /// pops it back onto the effective moves. The result holds no undo or redo; an undone move is left out unless
    /// redone. Replayed on a fresh play of the same level, the effective moves reach the same blooms, sun and moves as
    /// the records (undo and redo restore exact moments, so every bloom index names the same bloom).
    public static func netTrace(_ records: [NocturneGardenRecord]) -> [NocturneGardenAction] {
        var net: [NocturneGardenAction] = []
        var redo: [NocturneGardenAction] = []
        for record in records {
            switch record.kind {
            case .plant, .move, .resize, .remove, .sun:
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

    /// Whether `result` of `level` replays: its trace holds 1 … ``maxTraceLength`` moves and at most `movesMade`,
    /// every move is legal on a fresh play of certified level `level` (1 … 100) with the campaign budget, the play ends
    /// won, and `stars` is ``NocturneGardenProgress/stars(movesMade:smallest:)`` for `movesMade` against the certified
    /// solution's smallest move count. False for anything else, including a result without a trace or a level that
    /// cannot be generated.
    public static func verifies(level: Int, result: NocturneGardenProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength,
              result.trace.count <= result.movesMade else { return false }
        guard NocturneGardenExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(NocturneGardenError) {
            let certified: NocturneGardenGenerated = try NocturneGardenExperienceCore.generated(number: level)
            var play: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            return result.stars == NocturneGardenProgress.stars(movesMade: result.movesMade,
                                                                smallest: certified.solution.smallest)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: NocturneGardenProgress
    ) -> (progress: NocturneGardenProgress, dropped: Int) {
        var kept: NocturneGardenProgress = progress
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
