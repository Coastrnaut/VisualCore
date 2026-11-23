// EchoCartographerSolver — feature 402 (R02-G11-02) T-R02G1102-003 (FR-R02G1102-002; SC-R02G1102-001, 002, 005;
// clarification Q2). The inference solver of Echo Cartographer. A placement is a set of beacon-count distinct cells of
// the entry's region (the open cells reachable from the entry, the entry itself excluded); it fits the echoes heard when,
// for every pulse heard, the sorted path lengths from that pulse's emitter to its cells equal the reported echoes. The
// fitting placements are counted by a depth-first enumeration over the cells that fit every pulse singly, in cell-index
// order, pruning a partial placement whose distance counts already exceed a pulse's echoes (a full placement is then a
// fit, since every pulse hears every beacon); counts stop at the cap. The plan is greedy: from the opening knowledge, at
// each turn every cell known open and not yet pulsed is tried in cell-index order, and the one whose echo leaves the
// fewest fitting placements is pulsed (ties: lowest index), revealing its rays; the plan ends when exactly one placement
// fits (the true beacons, which always fit) and gives up after `maxPulses`. Work is enumeration nodes, counted and
// bounded. The plan is a witness, not a proven minimum. Integers only; no clock, no random source.
import Foundation

/// The echoes heard from one pulse: its emitter and the sorted path lengths of the beacons.
public struct EchoCartographerObservation: Sendable, Hashable, Codable {
    /// The cell the pulse came from.
    public let emitter: EchoCartographerCell
    /// The beacons' path lengths from the emitter, ascending.
    public let echoes: [Int]

    /// An observation of the given values (echoes sorted).
    public init(emitter: EchoCartographerCell, echoes: [Int]) {
        self.emitter = emitter
        self.echoes = echoes.sorted()
    }
}

/// A certified pulse plan: the pulses, the fitting placements after each, the counterexample one pulse short and the
/// work spent.
public struct EchoCartographerPlan: Sendable, Equatable, Codable {
    /// The pulses, in order; each from a cell known open at its turn.
    public let pulses: [EchoCartographerCell]
    /// The placements fitting after each pulse (capped at ``EchoCartographerSolver/placementCap``); the last is 1.
    public let placements: [Int]
    /// The placements fitting every pulse but the last (capped), at least 2.
    public let placementsBeforeLast: Int
    /// The first two placements, in enumeration order, that fit every pulse but the last.
    public let counterexample: [[EchoCartographerCell]]
    /// The enumeration nodes visited while planning.
    public let work: Int

    /// A plan of the given values (not checked).
    public init(pulses: [EchoCartographerCell], placements: [Int], placementsBeforeLast: Int,
                counterexample: [[EchoCartographerCell]], work: Int) {
        self.pulses = pulses
        self.placements = placements
        self.placementsBeforeLast = placementsBeforeLast
        self.counterexample = counterexample
        self.work = work
    }
}

/// The inference solver (clarification Q2).
public enum EchoCartographerSolver {
    /// The most enumeration nodes a plan may visit.
    public static let workBound: Int = 400_000
    /// Placement counts stop here ("at least 1 000").
    public static let placementCap: Int = 1_000
    /// The most pulses a plan may use.
    public static let maxPulses: Int = 6

    /// The entry's region without the entry: the open cells reachable from it, in cell-index order.
    public static func region(_ level: EchoCartographerLevel) -> [EchoCartographerCell] {
        let chamber: EchoCartographerChamber = level.chamber
        let reach: [Int?] = chamber.pathLengths(from: level.entry)
        let entry: Int = chamber.index(level.entry)
        var cells: [EchoCartographerCell] = []
        for index in 0..<chamber.cellCount where reach[index] != nil && index != entry {
            cells.append(chamber.cell(index))
        }
        return cells
    }

    /// The placements of `level`'s beacon count on its region that fit every observation: their number (stopping at
    /// `cap`) and the first `collect` of them in enumeration order. Every enumeration node adds 1 to `work`; the
    /// enumeration stops early once `work` exceeds `limit`.
    public static func fitting(_ level: EchoCartographerLevel, observations: [EchoCartographerObservation], cap: Int,
                               work: inout Int, collect: Int = 0,
                               limit: Int = Int.max) -> (count: Int, first: [[EchoCartographerCell]]) {
        let chamber: EchoCartographerChamber = level.chamber
        let k: Int = level.beacons.count
        let span: Int = chamber.cellCount + 1
        var distances: [[Int?]] = []
        var wanted: [[Int]] = []
        for observation in observations {
            distances.append(chamber.pathLengths(from: observation.emitter))
            var counts: [Int] = Array(repeating: 0, count: span)
            for echo in observation.echoes where echo >= 0 && echo < span { counts[echo] += 1 }
            wanted.append(counts)
        }
        var candidates: [Int] = []
        for cell in region(level) {
            let index: Int = chamber.index(cell)
            var fits: Bool = true
            for j in 0..<observations.count {
                guard let d = distances[j][index], wanted[j][d] > 0 else {
                    fits = false
                    break
                }
            }
            if fits { candidates.append(index) }
        }
        var counts: [[Int]] = Array(repeating: Array(repeating: 0, count: span), count: observations.count)
        var chosen: [Int] = []
        var found: Int = 0
        var first: [[EchoCartographerCell]] = []

        func descend(_ from: Int) {
            work += 1
            if found >= cap || work > limit { return }
            if chosen.count == k {
                found += 1
                if first.count < collect { first.append(chosen.map { chamber.cell($0) }) }
                return
            }
            let needed: Int = k - chosen.count
            var t: Int = from
            while t <= candidates.count - needed {
                let index: Int = candidates[t]
                var allowed: Bool = true
                for j in 0..<observations.count {
                    let d: Int = distances[j][index] ?? 0
                    if counts[j][d] + 1 > wanted[j][d] {
                        allowed = false
                        break
                    }
                }
                if allowed {
                    for j in 0..<observations.count { counts[j][distances[j][index] ?? 0] += 1 }
                    chosen.append(index)
                    descend(t + 1)
                    chosen.removeLast()
                    for j in 0..<observations.count { counts[j][distances[j][index] ?? 0] -= 1 }
                    if found >= cap || work > limit { return }
                }
                t += 1
            }
        }
        descend(0)
        return (min(found, cap), first)
    }

    /// The greedy plan of `level` (clarification Q2), or nil when no plan of at most ``maxPulses`` pulses singles out
    /// the beacons within `workBound` enumeration nodes.
    public static func plan(_ level: EchoCartographerLevel, workBound: Int = workBound) -> EchoCartographerPlan? {
        let chamber: EchoCartographerChamber = level.chamber
        var knowledge: EchoCartographerKnowledge = level.openingKnowledge
        var pulsed: Set<Int> = []
        var observations: [EchoCartographerObservation] = []
        var pulses: [EchoCartographerCell] = []
        var placements: [Int] = []
        var work: Int = 0
        while pulses.count < maxPulses {
            var best: (count: Int, cell: EchoCartographerCell, echo: EchoCartographerEcho)? = nil
            for index in 0..<chamber.cellCount where knowledge[index] == .open && !pulsed.contains(index) {
                let cell: EchoCartographerCell = chamber.cell(index)
                let echo: EchoCartographerEcho = level.echo(from: cell)
                let trial: [EchoCartographerObservation] = observations
                    + [EchoCartographerObservation(emitter: cell, echoes: echo.beaconDistances)]
                let count: Int = fitting(level, observations: trial, cap: placementCap, work: &work,
                                         limit: workBound).count
                if work > workBound { return nil }
                if best == nil || count < best!.count { best = (count, cell, echo) }
            }
            guard let chosen = best else { return nil }
            knowledge.reveal(chosen.echo)
            pulsed.insert(chamber.index(chosen.cell))
            let heard = EchoCartographerObservation(emitter: chosen.cell, echoes: chosen.echo.beaconDistances)
            let before: [EchoCartographerObservation] = observations
            observations.append(heard)
            pulses.append(chosen.cell)
            placements.append(chosen.count)
            if chosen.count == 1 {
                let short = fitting(level, observations: before, cap: placementCap, work: &work, collect: 2,
                                    limit: workBound)
                if work > workBound { return nil }
                return EchoCartographerPlan(pulses: pulses, placements: placements, placementsBeforeLast: short.count,
                                            counterexample: short.first, work: work)
            }
        }
        return nil
    }

    /// The witness actions of `plan` on `level`: its pulses, then one claim on each beacon's own cell in beacon order.
    public static func actions(_ level: EchoCartographerLevel, plan: EchoCartographerPlan) -> [EchoCartographerAction] {
        var actions: [EchoCartographerAction] = []
        for pulse in plan.pulses { actions.append(.pulse(pulse.x, pulse.y)) }
        for beacon in level.beacons { actions.append(.claim(beacon.x, beacon.y)) }
        return actions
    }

    /// Whether `actions`, played through the kernel's play from the start (begin, the tutorial dismissed when the level
    /// has one), are all accepted and the level is won on the last.
    public static func wins(_ level: EchoCartographerLevel, actions: [EchoCartographerAction]) -> Bool {
        var play = EchoCartographerPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for (index, action) in actions.enumerated() {
                guard play.stage == .playing else { return false }
                try play.apply(action, expecting: play.fingerprint)
                if play.stage == .won { return index == actions.count - 1 }
            }
        } catch {
            return false
        }
        return false
    }
}
