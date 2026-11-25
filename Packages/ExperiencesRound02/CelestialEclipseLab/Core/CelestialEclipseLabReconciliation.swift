// CelestialEclipseLabReconciliation — feature 467 (R02-G17-07) T-R02G1707-002 (contracts/api.md; research R2, R3, R6,
// R7; clarifications Q1, Q2). Restored scores are checked against the rules before they count: each result that
// carries a trace (or claims to be verified) is replayed on a fresh play of its certified level (campaign budget, begun
// with its tutorial dismissed as the adapter does), and the result is kept only when every phase change of the trace is
// accepted, the trace ends with exactly one `.run` that wins the play (an action the kernel refuses, an action after
// the run or a trace without a final run never verifies; a failing run ends the play failed), the phase changes the
// trace spends (the play's actions spent after the replay) are at most `actionsSpent` (actions spent count undone
// changes too, so an honest play with undos spent at least what its trace spends) and the recorded stars are the stars
// rule for `actionsSpent` against the certified witness's phase-change count. A trace longer than 64 actions never
// verifies (bounded restore work; the kernel's largest budget is 24, so an honest trace holds at most 24 changes and
// the run).
// Results without a trace that are not marked verified (written before snapshot schema 3) are kept, unverified. The
// frontier is kept as saved: dropping a result never closes a level. The effective actions of a play's records
// (``netTrace(_:)``) are the trace the adapter stores with a win. Pure and deterministic: integers only, no clock, no
// random source; the certified levels come from the per-process cache of
// ``CelestialEclipseLabExperienceCore/generated(number:)``. Modelled on feature 457's StarlitCartoucheReconciliation.
import Foundation

/// The check of restored Celestial Eclipse Lab scores and the trace of a play (see the file header).
public enum CelestialEclipseLabReconciliation {
    /// The longest trace that can verify: 64 actions (bounded restore work; an honest winning play spends at most the
    /// kernel's largest budget, 24, so its effective trace holds at most 25 actions with the run).
    public static let maxTraceLength: Int = 64

    /// The effective actions of a play's `records`: each phase or run record appends its action and clears the redo
    /// stack; each undo removes the last effective action and pushes it on the redo stack; each redo pops it back onto
    /// the effective actions. Event records (begin, dismissTutorial, pause, resume) are skipped. The result holds no
    /// undo or redo; an undone change or run (a failed run undone included) is left out unless redone. Replayed on a
    /// fresh play of the same level, the effective actions reach the same phases, actions spent, timeline, failure and
    /// stage as the records (undo and redo restore exact moments); the actions spent are at most the records'.
    public static func netTrace(_ records: [CelestialEclipseLabRecord]) -> [CelestialEclipseLabAction] {
        var net: [CelestialEclipseLabAction] = []
        var redo: [CelestialEclipseLabAction] = []
        for record in records {
            switch record.kind {
            case .phase, .run:
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
    /// the last action is the run and the play ends won, the phase changes the trace spends are at most
    /// `actionsSpent`, and `stars` is ``CelestialEclipseLabProgress/stars(actionsSpent:certified:)`` for
    /// `actionsSpent` against the certified witness's phase-change count. False for anything else, including a result
    /// without a trace, a trace with an action the kernel refuses, an action after the run, a failing run, no final
    /// run, or a level that cannot be generated.
    public static func verifies(level: Int, result: CelestialEclipseLabProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength else { return false }
        guard result.trace.last == .run else { return false }
        guard CelestialEclipseLabExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(CelestialEclipseLabError) {
            let certified: CelestialEclipseLabGenerated = try CelestialEclipseLabExperienceCore.generated(number: level)
            var play: CelestialEclipseLabPlay = try CelestialEclipseLabExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                guard play.stage == .playing else { return false }
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            guard play.actionsSpent <= result.actionsSpent else { return false }
            return result.stars == CelestialEclipseLabProgress.stars(actionsSpent: result.actionsSpent,
                                                                     certified: certified.plan.size)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: CelestialEclipseLabProgress
    ) -> (progress: CelestialEclipseLabProgress, dropped: Int) {
        var kept: CelestialEclipseLabProgress = progress
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
