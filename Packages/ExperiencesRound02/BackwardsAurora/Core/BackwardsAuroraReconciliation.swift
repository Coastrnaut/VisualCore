// BackwardsAuroraReconciliation — feature 397 (R02-G10-07) T-R02G1007-002 (FR-R02G1007-001, 003; clarifications Q1,
// Q2; research R2, R3, R4, R6, R7; contracts/api.md). Restored scores are checked against the rules before they count:
// each result that carries a trace (or claims to be verified) is replayed on a fresh play of its certified level
// (campaign budget, begun with its tutorial dismissed as the adapter does), and the result is kept only when every
// trace reversal is accepted, the play ends won, the trace is at most `reversalsMade` long (reversals made count undone
// reversals too, so an honest play with undos has more reversals made than effective reversals) and the recorded stars
// are the stars rule for `reversalsMade` against the certified smallest reversal count. A trace with more than 40
// reversals (the kernel's largest budget) never verifies (bounded restore work). Results without a trace that are not
// marked verified (written before schema 3) are kept, unverified. The frontier is kept as saved: dropping a result
// never closes a level. The effective reversals of a play's records (``netTrace(_:)``) are the trace the adapter stores
// with a win. Pure and deterministic: no clock, no random source; the certified levels come from the per-process cache
// of ``BackwardsAuroraExperienceCore/generated(number:)``. Modelled on feature 387's NocturneGardenReconciliation.
import Foundation

/// The check of restored Backwards Aurora scores and the trace of a play (see the file header).
public enum BackwardsAuroraReconciliation {
    /// The longest trace that can verify: 40 reversals, the kernel's largest budget (``BackwardsAuroraLevel/budgets``).
    public static let maxTraceLength: Int = BackwardsAuroraLevel.budgets.upperBound

    /// The effective reversals of a play's `records`: each reversal record appends its action and clears the redo
    /// stack; each undo removes the last effective reversal and pushes it on the redo stack; each redo pops it back
    /// onto the effective reversals. The result holds no undo or redo; an undone reversal is left out unless redone.
    /// Replayed on a fresh play of the same level, the effective reversals reach the same wave, reversals spent and
    /// outcome as the records (undo and redo restore exact moments, the reversals spent included).
    public static func netTrace(_ records: [BackwardsAuroraRecord]) -> [BackwardsAuroraAction] {
        var net: [BackwardsAuroraAction] = []
        var redo: [BackwardsAuroraAction] = []
        for record in records {
            switch record.kind {
            case .reverse:
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

    /// Whether `result` of `level` replays: its trace holds 1 … ``maxTraceLength`` reversals and at most
    /// `reversalsMade`, every reversal is accepted on a fresh play of certified level `level` (1 … 100) with the
    /// campaign budget, the play ends won, and `stars` is ``BackwardsAuroraProgress/stars(reversalsMade:smallest:)``
    /// for `reversalsMade` against the certified solution's smallest reversal count. False for anything else,
    /// including a result without a trace or a level that cannot be generated.
    public static func verifies(level: Int, result: BackwardsAuroraProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength,
              result.trace.count <= result.reversalsMade else { return false }
        guard BackwardsAuroraExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(BackwardsAuroraError) {
            let certified: BackwardsAuroraGenerated = try BackwardsAuroraExperienceCore.generated(number: level)
            var play: BackwardsAuroraPlay = try BackwardsAuroraExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            return result.stars == BackwardsAuroraProgress.stars(reversalsMade: result.reversalsMade,
                                                                 smallest: certified.solution.smallest)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: BackwardsAuroraProgress
    ) -> (progress: BackwardsAuroraProgress, dropped: Int) {
        var kept: BackwardsAuroraProgress = progress
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
