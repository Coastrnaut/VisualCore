// FacetedForgeReconciliation — feature 377 (R02-G08-07) T-R02G0807-002 (FR-R02G0807-001, 002; clarifications Q1, Q2;
// research R2, R3, R6, R7; contracts/api.md). Restored scores are checked against the rules before they count: each
// result that carries a trace (or claims to be verified) is replayed on a fresh play of its certified level (campaign
// budget, begun with its tutorial dismissed as the adapter does), and the result is kept only when every trace cut is
// legal, the play ends won, the trace is at most `cutsMade` long (cuts made count undone cuts too, so an honest play
// with undos has more cuts made than effective cuts) and the recorded stars are the stars rule for `cutsMade` against
// the certified smallest cut count. A trace with more than 32 cuts never verifies (bounded restore work). Results
// without a trace that are not marked verified (written before schema 3) are kept, unverified. The frontier is kept as
// saved: dropping a result never closes a level. The effective cuts of a play's records (``netTrace(_:)``) are the
// trace the adapter stores with a win. Pure and deterministic: no clock, no random source; the certified levels come
// from the per-process cache of ``FacetedForgeExperienceCore/generated(number:)``. Modelled on feature 367's
// AmethystEscapeReconciliation.
import Foundation

/// The check of restored Faceted Forge scores and the trace of a play (see the file header).
public enum FacetedForgeReconciliation {
    /// The longest trace that can verify: 32 cuts.
    public static let maxTraceLength: Int = 32

    /// The effective cuts of a play's `records`: each cut record appends its cut and clears the redo stack; each undo
    /// removes the last effective cut and pushes it on the redo stack; each redo pops it back onto the effective cuts.
    /// The result holds no undo or redo; an undone cut is left out unless redone. Replayed on a fresh play of the same
    /// level, the effective cuts reach the same pieces as the records.
    public static func netTrace(_ records: [FacetedForgeRecord]) -> [FacetedForgeAction] {
        var net: [FacetedForgeAction] = []
        var redo: [FacetedForgeAction] = []
        for record in records {
            switch record.kind {
            case .cut:
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

    /// Whether `result` of `level` replays: its trace holds 1 … ``maxTraceLength`` cuts and at most `cutsMade`, every
    /// cut is legal on a fresh play of certified level `level` (1 … 100) with the campaign budget, the play ends won,
    /// and `stars` is ``FacetedForgeProgress/stars(cutsMade:smallest:)`` for `cutsMade` against the certified
    /// solution's smallest cut count. False for anything else, including a result without a trace or a level that
    /// cannot be generated.
    public static func verifies(level: Int, result: FacetedForgeProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength,
              result.trace.count <= result.cutsMade else { return false }
        guard FacetedForgeExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(FacetedForgeError) {
            let certified: FacetedForgeGenerated = try FacetedForgeExperienceCore.generated(number: level)
            var play: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            return result.stars == FacetedForgeProgress.stars(cutsMade: result.cutsMade,
                                                              smallest: certified.solution.smallest)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: FacetedForgeProgress
    ) -> (progress: FacetedForgeProgress, dropped: Int) {
        var kept: FacetedForgeProgress = progress
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
