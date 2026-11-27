// BinaryGardensSolver — feature 502 (R02-G21-02) T-R02G2102-003 (FR-R02G2102-002; SC-R02G2102-001, 002, 005;
// clarification Q2; research R3, R6, R9, R10). The certifying solver of Binary Gardens, read from the source's "bounded
// coupled-orbit parameter sweep with sampling of received flux": a breadth-first sweep over arrangements (both stars'
// rings, phases and luminosities and the tilt) by the number of legal actions from the start, each arrangement judged
// by the kernel's exact report, which samples every world's received flux at each of the 48 ticks. An action sets a
// control directly, but an action that breaks the stars' minimum separation is refused, so a direct order can force a
// detour; following only the puzzle contract's legal moves makes every depth the exact action distance. Depth 0 is the
// start. Depth d + 1 takes the arrangements of depth d in ascending order of their light loss (ties keep their
// discovery order) and, from each, the moves of `BinaryGardensPuzzle(level:).moves(in:)` in its fixed order (star 1
// ring, phase, luminosity, star 2 ring, phase, luminosity, tilt; values ascending; phases on the level's grid), skipping
// arrangements already reached at any depth, earlier in the same depth included (reachability, never pruning by
// outcome); each new arrangement is judged on discovery. Loss = Σ over worlds of [Σ over ticks 1 … 48 of max(0,
// c_lo − F, F − c_hi) + max(0, B_lo − I, I − B_hi) + 1000·max(0, W − window)], in milliflux. The first winning
// arrangement ends the search; the plan is its parent chain of moves from the start (then `run`, replayed through the
// kernel's play by the generator). Every depth below the winning one is judged in full, so the loss order changes only
// the work and the plan within the winning depth, never the depth. Work = arrangements judged (the start and the
// winning one included), bounded at 5,000 per candidate — above the largest catalog search space up to a plan depth
// (band 5: 1 + 25 + 243 + 1,147 + 2,632 = 4,048) — counted, never timed. The search depth is at most `maxDepth` (the
// band's plan length), never the budget. The minimality proof is the count of arrangements judged at each smaller depth,
// none winning; the nearest miss is the smallest loss among them with its arrangement (the first in judging order among
// equals). Integers only; no clock, no random source. Modelled on `MushroomWeatherSolver` (feature 492).
import VisualCoreSimulation

/// The certifying solver.
public enum BinaryGardensSolver {
    /// The bound on arrangements judged per candidate.
    public static let workBound: Int = 5_000

    /// The light loss of `report` on `level`: Σ over worlds of the flux outside the comfortable band summed over ticks
    /// 1 … 48, plus the integral outside the bloom band, plus 1000 per tick the longest comfortable window falls short of
    /// the required window, in milliflux. 0 for a report inside every band (a loss of 0 does not imply a win: the lethal
    /// walk is judged separately).
    public static func loss(_ level: BinaryGardensLevel, report: BinaryGardensReport) -> Int {
        var total: Int = 0
        for (index, world) in level.worlds.enumerated() {
            let light: BinaryGardensWorldLight = report.worlds[index]
            for flux in light.flux {
                total += max(0, world.comfortLow - flux, flux - world.comfortHigh)
            }
            total += max(0, world.bloomLow - light.integral, light.integral - world.bloomHigh)
            total += BinaryGardensSky.millifluxPerUnit * max(0, world.window - light.window)
        }
        return total
    }

    /// The arrangement after a legal `move` from `arrangement` (the move sets one control; legality comes from the
    /// puzzle contract's move list).
    static func after(_ move: BinaryGardensAction, from arrangement: BinaryGardensArrangement)
        -> BinaryGardensArrangement {
        guard let (control, value) = BinaryGardensControl.of(move) else { return arrangement }
        return control.setting(value, in: arrangement)
    }

    /// The fewest arrangement actions that win `level`, searched by depth up to `maxDepth`, or nil without a win within
    /// `maxDepth` or over `workBound` arrangements judged. A probe level whose start already wins gives a plan of size
    /// 0 (a catalog level never does: the level rules refuse it).
    public static func plan(_ level: BinaryGardensLevel, maxDepth: Int,
                            workBound: Int = workBound) -> BinaryGardensPlan? {
        let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        let start: BinaryGardensArrangement = level.start
        guard workBound >= 1 else { return nil }
        var work: Int = 1
        let startReport: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: start)
        if startReport.wins {
            return BinaryGardensPlan(actions: [], arrangement: start, arrangementsByDepth: [], nearestMiss: 0,
                                     nearestMissArrangement: start, work: work)
        }
        var parents: [BinaryGardensArrangement: (parent: BinaryGardensArrangement, move: BinaryGardensAction)] = [:]
        var seen: Set<BinaryGardensArrangement> = [start]
        var layer: [(arrangement: BinaryGardensArrangement, loss: Int)] = [(start, loss(level, report: startReport))]
        var arrangementsByDepth: [Int] = []
        var nearestMiss: Int = layer[0].loss
        var nearestMissArrangement: BinaryGardensArrangement = start
        var depth: Int = 0
        while depth < maxDepth {
            arrangementsByDepth.append(layer.count)
            let order: [Int] = layer.indices.sorted { (layer[$0].loss, $0) < (layer[$1].loss, $1) }
            var next: [(arrangement: BinaryGardensArrangement, loss: Int)] = []
            for index in order {
                let parent: BinaryGardensArrangement = layer[index].arrangement
                let position = BinaryGardensPuzzle.Position(arrangement: parent, actionsSpent: depth)
                for move in rules.moves(in: position) {
                    let child: BinaryGardensArrangement = after(move, from: parent)
                    guard seen.insert(child).inserted else { continue }
                    parents[child] = (parent, move)
                    guard work < workBound else { return nil }
                    work += 1
                    let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: child)
                    if report.wins {
                        return BinaryGardensPlan(actions: chain(to: child, parents: parents), arrangement: child,
                                                 arrangementsByDepth: arrangementsByDepth, nearestMiss: nearestMiss,
                                                 nearestMissArrangement: nearestMissArrangement, work: work)
                    }
                    next.append((child, loss(level, report: report)))
                }
            }
            // The nearest miss counts only the depths judged in full, below the winning one.
            for item in next where item.loss < nearestMiss {
                nearestMiss = item.loss
                nearestMissArrangement = item.arrangement
            }
            layer = next
            depth += 1
            if layer.isEmpty { return nil }
        }
        return nil
    }

    /// The moves from the start to `arrangement` along `parents`, first move first.
    static func chain(to arrangement: BinaryGardensArrangement,
                      parents: [BinaryGardensArrangement: (parent: BinaryGardensArrangement,
                                                            move: BinaryGardensAction)]) -> [BinaryGardensAction] {
        var moves: [BinaryGardensAction] = []
        var current: BinaryGardensArrangement = arrangement
        while let step = parents[current] {
            moves.append(step.move)
            current = step.parent
        }
        return moves.reversed()
    }

    /// Whether `actions` followed by `run` win `level` through the kernel's play (begin, dismissTutorial when the level
    /// has one, each action against the current fingerprint, then the run).
    public static func replayWins(_ level: BinaryGardensLevel, actions: [BinaryGardensAction]) -> Bool {
        var play: BinaryGardensPlay = BinaryGardensPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
            try play.apply(.run, expecting: play.fingerprint)
        } catch {
            return false
        }
        return play.stage == .won
    }
}
