// ChronoConstellatorTimeline — feature 351 (R02-G06-01) T-R02G0601-002 (FR-R02G0601-002 … 005; clarifications Q2 … Q5).
// The timeline of a play: each star's start phase and its holds, an event log of tick-indexed actions that replays with
// a fixed step. Star i stands at tick t on loop_i[(φ_i + t − h_i(t)) mod L_i], where h_i(t) counts its held ticks among
// ticks 1 … t; a hold (star, start s, length k) holds the star on ticks s … s + k − 1 (k 1 … 60, s ≥ 1,
// s + k − 1 ≤ tick limit) and a star's holds neither overlap nor touch. The edits in use are the stars whose phase differs
// from the level's default plus the holds. The timeline's fingerprint (phases and holds) is the signed snapshot replays
// are compared by. After every tick t ≥ 1 the evaluation decides collision first (two stars on one cell, naming the
// lower-numbered pair and the cell), then win (every star on its own target), then time (t reaches the tick limit);
// nothing is judged at tick 0. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// A hold: star `star` stays where it is on ticks `start` … `start + length − 1`.
public struct ChronoConstellatorHold: Sendable, Hashable, Codable, Comparable {
    /// The star held.
    public let star: Int
    /// The first held tick, ≥ 1.
    public let start: Int
    /// The number of held ticks, 1 … 60.
    public let length: Int

    /// A hold (not checked; the timeline checks it).
    public init(star: Int, start: Int, length: Int) {
        self.star = star
        self.start = start
        self.length = length
    }

    /// The last held tick.
    public var end: Int { start + length - 1 }

    /// Holds are ordered by star, then start.
    public static func < (lhs: ChronoConstellatorHold, rhs: ChronoConstellatorHold) -> Bool {
        (lhs.star, lhs.start) < (rhs.star, rhs.start)
    }
}

/// Why an undecided play failed.
public enum ChronoConstellatorFailure: Sendable, Hashable, Codable {
    /// Stars `a` < `b` stood on `cell` on the same tick before a win.
    case collision(Int, Int, Int)
    /// The tick limit was reached without a win.
    case time

    /// The failure's code: `collision` or `time`.
    public var code: String {
        switch self {
        case .collision: "collision"
        case .time: "time"
        }
    }
}

/// The verdict after a tick.
public enum ChronoConstellatorVerdict: Sendable, Equatable {
    /// Undecided.
    case running
    /// Every star stands on its own target.
    case won
    /// The play failed.
    case failed(ChronoConstellatorFailure)
}

/// The start phases and holds of a play.
public struct ChronoConstellatorTimeline: Sendable, Hashable, Codable {
    /// The allowed hold lengths.
    public static let holdLengths: ClosedRange<Int> = 1...60

    /// The start phase of every star.
    public private(set) var phases: [Int]
    /// The holds, sorted by star, then start.
    public private(set) var holds: [ChronoConstellatorHold]

    /// The timeline of `level` with its default phases and no holds.
    public init(level: ChronoConstellatorLevel) {
        phases = level.stars.map(\.phase)
        holds = []
    }

    /// The edits in use: the stars whose phase differs from the level's default plus the holds.
    public func editsInUse(level: ChronoConstellatorLevel) -> Int {
        var changed = 0
        for index in level.stars.indices where phases[index] != level.stars[index].phase { changed += 1 }
        return changed + holds.count
    }

    /// The number of ticks among 1 … `tick` on which star `star` is held.
    public func held(star: Int, through tick: Int) -> Int {
        var total = 0
        for hold in holds where hold.star == star && hold.start <= tick {
            total += min(hold.end, tick) - hold.start + 1
        }
        return total
    }

    /// Whether star `star` is held on tick `tick`.
    public func isHeld(star: Int, on tick: Int) -> Bool {
        holds.contains { $0.star == star && $0.start <= tick && tick <= $0.end }
    }

    /// The cell of star `star` at tick `tick` ≥ 0: loop[(φ + t − h(t)) mod L].
    public func position(star: Int, at tick: Int, level: ChronoConstellatorLevel) -> Int {
        let loop: [Int] = level.stars[star].loop
        let step: Int = phases[star] + tick - held(star: star, through: tick)
        return loop[((step % loop.count) + loop.count) % loop.count]
    }

    /// The cells of every star at tick `tick`.
    public func positions(at tick: Int, level: ChronoConstellatorLevel) -> [Int] {
        level.stars.indices.map { position(star: $0, at: tick, level: level) }
    }

    /// The timeline with star `star`'s start phase set to `offset`.
    ///
    /// - Throws: `.action("range")` for a star or offset out of range; `.action("same-phase")` when the phase is already
    ///   `offset`; `.budget` when the edits in use would exceed the budget.
    public func settingPhase(star: Int, to offset: Int,
                             level: ChronoConstellatorLevel) throws(ChronoConstellatorError) -> ChronoConstellatorTimeline {
        guard level.stars.indices.contains(star), (0..<level.stars[star].length).contains(offset) else {
            throw .action("range")
        }
        guard phases[star] != offset else { throw .action("same-phase") }
        var next = self
        next.phases[star] = offset
        guard next.editsInUse(level: level) <= level.budget else { throw .budget }
        return next
    }

    /// The timeline with `hold` added.
    ///
    /// - Throws: `.action("range")` for a star, start or length out of range or a hold past the tick limit;
    ///   `.action("overlap")` when it overlaps or touches another hold of the same star; `.budget` when the edits in use
    ///   would exceed the budget.
    public func adding(_ hold: ChronoConstellatorHold,
                       level: ChronoConstellatorLevel) throws(ChronoConstellatorError) -> ChronoConstellatorTimeline {
        guard level.stars.indices.contains(hold.star), hold.start >= 1, Self.holdLengths.contains(hold.length),
              hold.end <= level.tickLimit else { throw .action("range") }
        for other in holds where other.star == hold.star {
            // Overlapping or touching: no tick of gap between them.
            if hold.start <= other.end + 1 && other.start <= hold.end + 1 { throw .action("overlap") }
        }
        var next = self
        next.holds.append(hold)
        next.holds.sort()
        guard next.editsInUse(level: level) <= level.budget else { throw .budget }
        return next
    }

    /// The timeline without the hold of star `star` that starts at `start`.
    ///
    /// - Throws: `.action("range")` for a star out of range; `.action("no-hold")` when no such hold exists.
    public func releasing(star: Int, start: Int,
                          level: ChronoConstellatorLevel) throws(ChronoConstellatorError) -> ChronoConstellatorTimeline {
        guard level.stars.indices.contains(star) else { throw .action("range") }
        guard let index = holds.firstIndex(where: { $0.star == star && $0.start == start }) else {
            throw .action("no-hold")
        }
        var next = self
        next.holds.remove(at: index)
        return next
    }

    /// The SHA-256 hex of the timeline's canonical JSON (phases and holds): the signed snapshot replays are compared by.
    public var fingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else {
            preconditionFailure("a timeline of integers always encodes")
        }
        return StableHash.sha256Hex(Array(data))
    }
}

/// The end-of-tick evaluation (clarification Q4).
public enum ChronoConstellatorEvaluation {
    /// The verdict for the star `positions` after tick `tick`: running at tick 0; else collision (the first pair a < b in
    /// order on one cell), then win (every star on its own target), then time (`tick` reaches the tick limit).
    public static func verdict(positions: [Int], tick: Int, level: ChronoConstellatorLevel) -> ChronoConstellatorVerdict {
        guard tick >= 1 else { return .running }
        for a in positions.indices {
            for b in positions.indices where b > a && positions[a] == positions[b] {
                return .failed(.collision(a, b, positions[a]))
            }
        }
        var aligned = true
        for index in level.stars.indices where positions[index] != level.stars[index].target { aligned = false }
        if aligned { return .won }
        if tick >= level.tickLimit { return .failed(.time) }
        return .running
    }
}
