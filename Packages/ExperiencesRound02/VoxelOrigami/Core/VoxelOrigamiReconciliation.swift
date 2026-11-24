// VoxelOrigamiReconciliation — feature 447 (R02-G15-07) T-R02G1507-002 (FR-R02G1507-001, 003; clarifications Q1, Q2;
// contracts/api.md). Restored scores are checked against the rules before they count: each result that carries a
// trace (or claims to be verified) is replayed on a fresh play of its certified level (campaign budget, begun with its
// tutorial dismissed as the adapter does), and the result is kept only when every trace turn is accepted and clear (a
// turn the kernel refuses, or one that fails with a collision or a sweep, never verifies), the play ends won, the turns
// the trace spends (the play's actions spent after the replay) are at most `actionsSpent` (actions spent count undone
// turns too, so an honest play with undos spent at least what its trace spends) and the recorded stars are the stars
// rule for `actionsSpent` against the certified witness's turn count. A trace longer than 64 turns never verifies
// (bounded restore work; a winning play spends at most the kernel's largest budget, 40, so its effective trace is never
// longer). Results without a trace that are not marked verified (written before schema 3) are kept, unverified. The
// frontier is kept as saved: dropping a result never closes a level. The effective turns of a play's records
// (``netTrace(_:)``) are the trace the adapter stores with a win. Pure and deterministic: integers only, no clock, no
// random source; the certified levels come from the per-process cache of
// ``VoxelOrigamiExperienceCore/generated(number:)``. Modelled on feature 437's MoonlitMechanismReconciliation.
import Foundation

/// The check of restored Voxel Origami scores and the trace of a play (see the file header).
public enum VoxelOrigamiReconciliation {
    /// The longest trace that can verify: 64 turns (bounded restore work; an honest winning play spends at most the
    /// kernel's largest budget, so its effective trace is never longer).
    public static let maxTraceLength: Int = 64

    /// The effective turns of a play's `records`: each turn record appends its action and clears the redo stack; each
    /// undo removes the last effective turn and pushes it on the redo stack; each redo pops it back onto the effective
    /// turns. The result holds no undo or redo; an undone turn is left out unless redone. Replayed on a fresh play of
    /// the same level, the effective turns reach the same turns, pose, report, failure and outcome as the records (undo
    /// and redo restore exact moments); the actions spent are at most the records'.
    public static func netTrace(_ records: [VoxelOrigamiRecord]) -> [VoxelOrigamiAction] {
        var net: [VoxelOrigamiAction] = []
        var redo: [VoxelOrigamiAction] = []
        for record in records {
            switch record.kind {
            case .turn:
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

    /// Whether `result` of `level` replays: its trace holds 1 … ``maxTraceLength`` turns, every turn is accepted on a
    /// fresh play of certified level `level` (1 … 100) with the campaign budget, the play ends won, the turns the trace
    /// spends are at most `actionsSpent`, and `stars` is ``VoxelOrigamiProgress/stars(actionsSpent:certified:)`` for
    /// `actionsSpent` against the certified witness's turn count. False for anything else, including a result without a
    /// trace, a trace with a turn the kernel refuses or that fails (collision or sweep), or a level that cannot be
    /// generated.
    public static func verifies(level: Int, result: VoxelOrigamiProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength else { return false }
        guard VoxelOrigamiExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(VoxelOrigamiError) {
            let certified: VoxelOrigamiGenerated = try VoxelOrigamiExperienceCore.generated(number: level)
            var play: VoxelOrigamiPlay = try VoxelOrigamiExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            guard play.actionsSpent <= result.actionsSpent else { return false }
            return result.stars == VoxelOrigamiProgress.stars(actionsSpent: result.actionsSpent,
                                                              certified: certified.plan.size)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: VoxelOrigamiProgress
    ) -> (progress: VoxelOrigamiProgress, dropped: Int) {
        var kept: VoxelOrigamiProgress = progress
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
