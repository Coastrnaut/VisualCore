// ColorfallCanyonsReconciliation — feature 347 (R02-G05-07) T-R02G0507-002 (FR-R02G0507-003; SC-R02G0507-003;
// clarifications Q1, Q2; research R2, R3, R4, R6). Restored scores are checked against the rules before they count: each
// result that carries a trace (or claims to be verified) is replayed on a fresh play of its certified level (campaign
// budget, begun with its tutorial dismissed as the adapter does), and the result is kept only when every trace action is
// legal and the play ends won having spent exactly `bestActions` actions with the recorded stars (the stars rule for that
// count against the certified smallest edit count). A trace with more than 30 carves and valve toggles or more than
// 3,600 steps never verifies (bounded restore work). Results without a trace (written before schema 3) are kept,
// unverified. The frontier is kept as saved: dropping a result never closes a level, and a daily win never opens one, so
// a kept daily result may lie beyond the frontier. The net actions of a play's records (``netActions(_:)``) are the
// trace the adapter stores with a win. Pure and deterministic: no clock, no random source; the certified levels come
// from the per-process cache of ``ColorfallCanyonsExperienceCore/generated(number:)``. Modelled on feature 337's
// HueCompassReconciliation.
import Foundation

/// The check of restored Colorfall Canyons scores and the trace of a play (see the file header).
public enum ColorfallCanyonsReconciliation {
    /// Whether `result` of `level` replays: its trace is non-empty and within
    /// ``ColorfallCanyonsProgress/withinTraceBound(_:)``, every action is legal on a fresh play of certified level
    /// `level` (1 … 100) with the campaign budget, the play ends won after the last one having spent exactly
    /// `bestActions` actions, and `stars` is ``ColorfallCanyonsProgress/stars(actions:smallest:)`` for `bestActions`
    /// against the certified smallest edit count. False for anything else, including a result without a trace or a level
    /// that cannot be generated.
    public static func verifies(level: Int, result: ColorfallCanyonsProgress.Result) -> Bool {
        guard !result.trace.isEmpty, ColorfallCanyonsProgress.withinTraceBound(result.trace) else { return false }
        guard ColorfallCanyonsExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(ColorfallCanyonsError) {
            let certified: ColorfallCanyonsGenerated = try ColorfallCanyonsExperienceCore.generated(number: level)
            var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won, play.spent == result.bestActions else { return false }
            return result.stars == ColorfallCanyonsProgress.stars(actions: result.bestActions,
                                                                  smallest: certified.solution.smallest)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one (see the file header).
    public static func reconcile(
        _ progress: ColorfallCanyonsProgress
    ) -> (progress: ColorfallCanyonsProgress, dropped: Int) {
        var kept: ColorfallCanyonsProgress = progress
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

    /// The net actions of a play's `records` (research R2): each carve, valve or step appends its action and clears the
    /// redo stack; each undo removes the last net action and pushes it on the redo stack; each redo pops it back onto
    /// the net actions. The result never holds an undo or a redo; an undone action is left out unless redone. Replayed on
    /// a fresh play of the same level, the net actions reach the same fluid, actions spent and stage as the records
    /// (a pause is not part of the trace).
    public static func netActions(_ records: [ColorfallCanyonsRecord]) -> [ColorfallCanyonsAction] {
        var net: [ColorfallCanyonsAction] = []
        var redo: [ColorfallCanyonsAction] = []
        for record in records {
            switch record.kind {
            case .carve, .valve, .step:
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
}
