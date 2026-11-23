// HarmonicBridgesReconciliation — feature 417 (R02-G12-07) T-R02G1207-002 (FR-R02G1207-001, 003; clarifications Q1,
// Q2; research R2, R3, R6, R7; contracts/api.md). Restored scores are checked against the rules before they count: each
// result that carries a trace (or claims to be verified) is replayed on a fresh play of its certified level (campaign
// budget, begun with its tutorial dismissed as the adapter does), and the result is kept only when every trace action is
// accepted, the play ends won, the actions the trace spends (the play's actions spent after the replay) are at most
// `actionsSpent` (actions spent count undone tunings and tests too, so an honest play with undos spent at least what its
// trace spends) and the recorded stars are the stars rule for `actionsSpent` against the certified witness's action
// count (its tunings plus the test). A trace longer than 64 actions never verifies (bounded restore work; a winning play
// spends at most the kernel's largest budget, 60). Results without a trace that are not marked verified (written before
// schema 3) are kept, unverified. The frontier is kept as saved: dropping a result never closes a level. The effective
// actions of a play's records (``netTrace(_:)``) are the trace the adapter stores with a win. Pure and deterministic:
// integers only, no clock, no random source; the certified levels come from the per-process cache of
// ``HarmonicBridgesExperienceCore/generated(number:)``. Modelled on feature 407's EchoCartographerReconciliation.
import Foundation

/// The check of restored Harmonic Bridges scores and the trace of a play (see the file header).
public enum HarmonicBridgesReconciliation {
    /// The longest trace that can verify: 64 actions (bounded restore work; an honest winning play spends at most the
    /// kernel's largest budget, 60 actions, so its effective trace is never longer).
    public static let maxTraceLength: Int = 64

    /// The effective actions of a play's `records`: each tune or test record appends its action and clears the redo
    /// stack; each undo removes the last effective action and pushes it on the redo stack; each redo pops it back onto
    /// the effective actions. The result holds no undo or redo; an undone action is left out unless redone. Replayed on
    /// a fresh play of the same level, the effective actions reach the same pegs, actions spent, report, failure and
    /// outcome as the records (undo and redo restore exact moments).
    public static func netTrace(_ records: [HarmonicBridgesRecord]) -> [HarmonicBridgesAction] {
        var net: [HarmonicBridgesAction] = []
        var redo: [HarmonicBridgesAction] = []
        for record in records {
            switch record.kind {
            case .tune, .test:
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

    /// Whether `result` of `level` replays: its trace holds 1 … ``maxTraceLength`` actions, every action is accepted
    /// on a fresh play of certified level `level` (1 … 100) with the campaign budget, the play ends won, the actions the
    /// trace spends are at most `actionsSpent`, and `stars` is ``HarmonicBridgesProgress/stars(actionsSpent:certified:)``
    /// for `actionsSpent` against the certified witness's action count. False for anything else, including a result
    /// without a trace or a level that cannot be generated.
    public static func verifies(level: Int, result: HarmonicBridgesProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength else { return false }
        guard HarmonicBridgesExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(HarmonicBridgesError) {
            let certified: HarmonicBridgesGenerated = try HarmonicBridgesExperienceCore.generated(number: level)
            var play: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            guard play.actionsSpent <= result.actionsSpent else { return false }
            return result.stars == HarmonicBridgesProgress.stars(actionsSpent: result.actionsSpent,
                                                                 certified: certified.actions.count)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: HarmonicBridgesProgress
    ) -> (progress: HarmonicBridgesProgress, dropped: Int) {
        var kept: HarmonicBridgesProgress = progress
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
