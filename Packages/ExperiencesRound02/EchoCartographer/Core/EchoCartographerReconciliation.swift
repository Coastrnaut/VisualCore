// EchoCartographerReconciliation — feature 407 (R02-G11-07) T-R02G1107-002 (FR-R02G1107-001, 003; clarifications Q1,
// Q2; contracts/api.md). Restored scores are checked against the rules before they count: each result that carries a
// trace (or claims to be verified) is replayed on a fresh play of its certified level (campaign energy, begun with its
// tutorial dismissed as the adapter does), and the result is kept only when every trace action is accepted, the play
// ends won, the energy the trace spends (the level's energy less the play's energy left) is at most `energySpent`
// (energy spent counts undone pulses and claims too, so an honest play with undos spent at least what its trace spends)
// and the recorded stars are the stars rule for `energySpent` against the certified plan's pulse count. A trace longer
// than 128 actions never verifies (bounded restore work). Results without a trace that are not marked verified
// (written before schema 3) are kept, unverified. The frontier is kept as saved: dropping a result never closes a
// level. The effective actions of a play's records (``netTrace(_:)``) are the trace the adapter stores with a win.
// Pure and deterministic: integers only, no clock, no random source; the certified levels come from the per-process
// cache of ``EchoCartographerExperienceCore/generated(number:)``. Modelled on feature 397's
// BackwardsAuroraReconciliation.
import Foundation

/// The check of restored Echo Cartographer scores and the trace of a play (see the file header).
public enum EchoCartographerReconciliation {
    /// The longest trace that can verify: 128 actions (bounded restore work; an honest winning play is far shorter).
    public static let maxTraceLength: Int = 128

    /// The effective actions of a play's `records`: each pulse, claim or mark record appends its action and clears the
    /// redo stack; each undo removes the last effective action and pushes it on the redo stack; each redo pops it back
    /// onto the effective actions. The result holds no undo or redo; an undone action is left out unless redone.
    /// Replayed on a fresh play of the same level, the effective actions reach the same knowledge, markers, located
    /// beacons, energy and outcome as the records (undo and redo restore exact moments).
    public static func netTrace(_ records: [EchoCartographerRecord]) -> [EchoCartographerAction] {
        var net: [EchoCartographerAction] = []
        var redo: [EchoCartographerAction] = []
        for record in records {
            switch record.kind {
            case .pulse, .claim, .mark:
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
    /// on a fresh play of certified level `level` (1 … 100) with the campaign energy, the play ends won, the energy the
    /// trace spends is at most `energySpent`, and `stars` is ``EchoCartographerProgress/stars(energySpent:certified:)``
    /// for `energySpent` against the certified plan's pulse count. False for anything else, including a result without
    /// a trace or a level that cannot be generated.
    public static func verifies(level: Int, result: EchoCartographerProgress.Result) -> Bool {
        guard !result.trace.isEmpty, result.trace.count <= maxTraceLength else { return false }
        guard EchoCartographerExperienceCore.levelNumbers.contains(level) else { return false }
        do throws(EchoCartographerError) {
            let certified: EchoCartographerGenerated = try EchoCartographerExperienceCore.generated(number: level)
            var play: EchoCartographerPlay = try EchoCartographerExperienceCore.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard play.stage == .won else { return false }
            let traceEnergy: Int = certified.level.energy - play.energy
            guard traceEnergy <= result.energySpent else { return false }
            return result.stars == EchoCartographerProgress.stars(energySpent: result.energySpent,
                                                                  certified: certified.plan.pulses.count)
        } catch {
            return false
        }
    }

    /// `progress` with every result that carries a trace or is marked verified but does not replay
    /// (``verifies(level:result:)``) removed, and the number removed. Results without a trace that are not marked
    /// verified are kept (unverified). The frontier is the saved one.
    public static func reconcile(
        _ progress: EchoCartographerProgress
    ) -> (progress: EchoCartographerProgress, dropped: Int) {
        var kept: EchoCartographerProgress = progress
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
