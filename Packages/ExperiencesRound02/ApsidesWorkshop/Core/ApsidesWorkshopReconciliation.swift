// ApsidesWorkshopReconciliation — feature 477 (R02-G18-07) T-R02G1807-002 (FR-R02G1807-001, 003; clarifications Q1,
// Q2; research R2–R4, R6, R7). Restored scores are checked against the rules before they count: each result that
// carries a trace (or claims to be verified) is replayed on a fresh play of its certified level (campaign budget, begun
// with its tutorial dismissed as the adapter does), and the result is kept only when every tuning of the trace is
// accepted, the trace ends with exactly one `.play` that wins the play (an action the kernel refuses, an action after
// the play or a trace without a final play never verifies; a failing play ends the play failed), the tunings the trace
// spends (the play's actions spent after the replay) are at most `actionsSpent` (actions spent count undone tunings
// too, so an honest play with undos spent at least what its trace spends) and the recorded stars are the stars rule for
// `actionsSpent` against the certified witness's tuning count (``ApsidesWorkshopExperienceCore/certifiedTunings``, the
// certified plan's size). A trace longer than 64 actions never verifies (bounded restore work; the kernel's largest
// budget is 24, so an honest trace holds at most 24 tunings and the play).
// Results without a trace that are not marked verified (written before snapshot schema 3) are kept, unverified. The
// frontier is kept as saved: dropping a result never closes a level (research R4). The effective actions of a play's
// records (``netTrace(_:)``) are the trace the adapter stores with a win. Pure and deterministic: integers only, no
// clock, no random source; the certified levels come from the per-process cache of
// ``ApsidesWorkshopExperienceCore/generated(number:)``. Modelled on feature 467's CelestialEclipseLabReconciliation.
import Foundation

/// The check of restored Apsides Workshop scores and the trace of a play (see the file header).
public enum ApsidesWorkshopReconciliation {
    /// The longest trace that can verify: 64 actions (bounded restore work; an honest winning play spends at most the
    /// kernel's largest budget, 24, so its effective trace holds at most 25 actions with the play).
    public static let maxTraceLength: Int = 64

    /// The effective actions of a play's `records`: each periapsis, size or play record appends its action and clears
    /// the redo stack; each undo removes the last effective action and pushes it on the redo stack; each redo pops it
    /// back onto the effective actions. Event records (begin, dismissTutorial, pause, resume) are skipped. The result
    /// holds no undo or redo; an undone tuning or play (a failed play undone included) is left out unless redone.
    /// Replayed on a fresh play of the same level, the effective actions reach the same orbit, actions spent, failure
    /// and stage as the records (undo and redo restore exact moments); the actions spent are at most the records'.
    public static func netTrace(_ records: [ApsidesWorkshopRecord]) -> [ApsidesWorkshopAction] {
        var net: [ApsidesWorkshopAction] = []
        var redo: [ApsidesWorkshopAction] = []
        for record in records {
            switch record.kind {
            case .periapsis, .size, .play:
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
    /// the last action is the play and the play ends won, the tunings the trace spends are at most `actionsSpent`,
    /// and `stars` is ``ApsidesWorkshopProgress/stars(actionsSpent:certified:)`` for `actionsSpent` against the
    /// certified witness's tuning count. False for anything else, including a result without a trace, a trace with an
    /// action the kernel refuses, an action after the play, a failing play, no final play, or a level that cannot be
    /// generated.
    public static func verifies(level: Int, result: ApsidesWorkshopProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength else { return false }
        guard result.trace.last == .play else { return false }
        guard ApsidesWorkshopExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(ApsidesWorkshopError) {
            let certified: ApsidesWorkshopGenerated = try ApsidesWorkshopExperienceCore.generated(number: level)
            var play: ApsidesWorkshopPlay = try ApsidesWorkshopExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                guard play.stage == .playing else { return false }
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            guard play.actionsSpent <= result.actionsSpent else { return false }
            return result.stars == ApsidesWorkshopProgress.stars(actionsSpent: result.actionsSpent,
                                                                 certified: certified.plan.size)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: ApsidesWorkshopProgress
    ) -> (progress: ApsidesWorkshopProgress, dropped: Int) {
        var kept: ApsidesWorkshopProgress = progress
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
