// StarlitCartoucheReconciliation — feature 457 (R02-G16-07) T-R02G1607-002 (contracts/api.md; research R2, R3, R6, R7).
// Restored scores are checked against the rules before they count: each result that carries a trace (or claims to be
// verified) is replayed on a fresh play of its certified level (campaign budget, begun with its tutorial dismissed as
// the adapter does), and the result is kept only when every trace leg is accepted and clear (a leg the kernel refuses,
// or one that fails with a departure, hazard, arrival, deadline or stroke failure, never verifies), the play ends won,
// the legs the trace spends (the play's actions spent after the replay) are at most `actionsSpent` (actions spent count
// undone legs too, so an honest play with undos spent at least what its trace spends) and the recorded stars are the
// stars rule for `actionsSpent` against the certified witness's leg count. A trace longer than 64 legs never verifies
// (bounded restore work; a winning play spends at most the kernel's largest budget, 24, so its effective trace is never
// longer). Results without a trace that are not marked verified (written before snapshot schema 3) are kept,
// unverified. The frontier is kept as saved: dropping a result never closes a level. The effective legs of a play's
// records (``netTrace(_:)``) are the trace the adapter stores with a win. Pure and deterministic: integers only, no
// clock, no random source; the certified levels come from the per-process cache of
// ``StarlitCartoucheExperienceCore/generated(number:)``. Modelled on feature 447's VoxelOrigamiReconciliation.
import Foundation

/// The check of restored Starlit Cartouche scores and the trace of a play (see the file header).
public enum StarlitCartoucheReconciliation {
    /// The longest trace that can verify: 64 legs (bounded restore work; an honest winning play spends at most the
    /// kernel's largest budget, so its effective trace is never longer).
    public static let maxTraceLength: Int = 64

    /// The effective legs of a play's `records`: each leg record appends its action and clears the redo stack; each
    /// undo removes the last effective leg and pushes it on the redo stack; each redo pops it back onto the effective
    /// legs. The result holds no undo or redo; an undone leg is left out unless redone. Replayed on a fresh play of the
    /// same level, the effective legs reach the same ship, beat, strokes, legs, report, failure and outcome as the
    /// records (undo and redo restore exact moments); the actions spent are at most the records'.
    public static func netTrace(_ records: [StarlitCartoucheRecord]) -> [StarlitCartoucheAction] {
        var net: [StarlitCartoucheAction] = []
        var redo: [StarlitCartoucheAction] = []
        for record in records {
            switch record.kind {
            case .leg:
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

    /// Whether `result` of `level` replays: its trace holds 1 … ``maxTraceLength`` legs, every leg is accepted on a
    /// fresh play of certified level `level` (1 … 100) with the campaign budget and none fails, the play ends won, the
    /// legs the trace spends are at most `actionsSpent`, and `stars` is
    /// ``StarlitCartoucheProgress/stars(actionsSpent:certified:)`` for `actionsSpent` against the certified witness's
    /// leg count. False for anything else, including a result without a trace, a trace with a leg the kernel refuses or
    /// that fails, or a level that cannot be generated.
    public static func verifies(level: Int, result: StarlitCartoucheProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength else { return false }
        guard StarlitCartoucheExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(StarlitCartoucheError) {
            let certified: StarlitCartoucheGenerated = try StarlitCartoucheExperienceCore.generated(number: level)
            var play: StarlitCartouchePlay = try StarlitCartoucheExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                guard play.stage == .playing else { return false }
                try play.apply(action, expecting: play.fingerprint)
                guard play.failure == nil else { return false }
            }
            guard play.stage == .won else { return false }
            guard play.actionsSpent <= result.actionsSpent else { return false }
            return result.stars == StarlitCartoucheProgress.stars(actionsSpent: result.actionsSpent,
                                                                  certified: certified.plan.size)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: StarlitCartoucheProgress
    ) -> (progress: StarlitCartoucheProgress, dropped: Int) {
        var kept: StarlitCartoucheProgress = progress
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
