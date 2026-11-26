// MicroscopicAuroraReconciliation — feature 487 (R02-G19-07) T-R02G1907-002 (FR-R02G1907-001, 002, 003;
// SC-R02G1907-003; clarifications Q1, Q2, Q3; research R2–R4, R6, R7). Restored scores are checked against the rules
// before they count: each result that carries a trace (or claims to be verified) is replayed on a fresh play of its
// certified level (campaign budget, begun with its tutorial dismissed as the adapter does), and the result is kept only
// when every placement and removal of the trace is accepted, the trace ends with exactly one `.play` that wins the play
// (an action the kernel refuses, an action after the play or a trace without a final play never verifies; a failing
// play ends the play failed), the placements and removals the trace spends (the play's actions spent after the replay)
// are at most `actionsSpent` (actions spent count undone placements and removals too, so an honest play with undos
// spent at least what its trace spends) and the recorded stars are the stars rule for `actionsSpent` against the
// certified plan's placement count (``MicroscopicAuroraExperienceCore/certifiedPlacements``, the certified plan's
// wells). A trace longer than 64 actions never verifies (bounded restore work; the kernel's largest budget is 24, so an
// honest trace holds at most 24 placements and removals and the play). Results without a trace that are not marked
// verified (written before snapshot schema 3) are kept, unverified. The frontier is kept as saved: dropping a result
// never closes a level (research R4). The effective actions of a play's records (``netTrace(_:)``) are the trace the
// adapter stores with a win. Pure and deterministic: integers only, no clock, no random source; the certified levels
// come from the per-process cache of ``MicroscopicAuroraExperienceCore/generated(number:)``. Modelled on feature
// 477's ApsidesWorkshopReconciliation.
import Foundation

/// The check of restored Microscopic Aurora scores and the trace of a play (see the file header).
public enum MicroscopicAuroraReconciliation {
    /// The longest trace that can verify: 64 actions (bounded restore work; an honest winning play spends at most the
    /// kernel's largest budget, 24, so its effective trace holds at most 25 actions with the play).
    public static let maxTraceLength: Int = 64

    /// The effective actions of a play's `records`: each place, remove or play record appends its action and clears
    /// the redo stack; each undo removes the last effective action and pushes it on the redo stack; each redo pops it
    /// back onto the effective actions. Event records (begin, dismissTutorial, pause, resume) are skipped. The result
    /// holds no undo or redo; an undone placement, removal or play (a failed play undone included) is left out unless
    /// redone. Replayed on a fresh play of the same level, the effective actions reach the same wells, report, failure
    /// and stage as the records (undo and redo restore exact moments); the actions spent are at most the records'.
    public static func netTrace(_ records: [MicroscopicAuroraRecord]) -> [MicroscopicAuroraAction] {
        var net: [MicroscopicAuroraAction] = []
        var redo: [MicroscopicAuroraAction] = []
        for record in records {
            switch record.kind {
            case .place, .remove, .play:
                guard let action = record.action else { continue }
                net.append(action)
                redo.removeAll()
            case .undo:
                if let last = net.popLast() { redo.append(last) }
            case .redo:
                if let again = redo.popLast() { net.append(again) }
            case .begin, .dismissTutorial, .pause, .resume:
                continue
            }
        }
        return net
    }

    /// Whether `result` of `level` replays: its trace holds 1 … ``maxTraceLength`` actions, every action is accepted
    /// on a fresh play of certified level `level` (1 … 100) with the campaign budget while the play is still playing,
    /// the last action is the play and the play ends won, the placements and removals the trace spends are at most
    /// `actionsSpent`, and `stars` is ``MicroscopicAuroraProgress/stars(actionsSpent:certified:)`` for `actionsSpent`
    /// against the certified plan's placement count. False for anything else, including a result without a trace, a
    /// trace with an action the kernel refuses, an action after the play, a failing play, no final play, or a level
    /// that cannot be generated.
    public static func verifies(level: Int, result: MicroscopicAuroraProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength else { return false }
        guard result.trace.last == .play else { return false }
        guard MicroscopicAuroraExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(MicroscopicAuroraError) {
            let certified: MicroscopicAuroraGenerated = try MicroscopicAuroraExperienceCore.generated(number: level)
            var play: MicroscopicAuroraPlay = try MicroscopicAuroraExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                guard play.stage == .playing else { return false }
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            guard play.actionsSpent <= result.actionsSpent else { return false }
            return result.stars == MicroscopicAuroraProgress.stars(actionsSpent: result.actionsSpent,
                                                                   certified: certified.plan.wells.count)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: MicroscopicAuroraProgress
    ) -> (progress: MicroscopicAuroraProgress, dropped: Int) {
        var kept: MicroscopicAuroraProgress = progress
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
