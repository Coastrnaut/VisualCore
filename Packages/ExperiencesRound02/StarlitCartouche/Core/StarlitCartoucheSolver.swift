// StarlitCartoucheSolver — feature 452 (R02-G16-02) T-R02G1602-003 (FR-R02G1602-002; SC-R02G1602-001, 002, 005;
// clarification Q2). The certifying solver of Starlit Cartouche: the catalog's "time-expanded graph search over
// navigable star corridors" as a breadth-first search over route states — the ship's star, the beat and the set of
// symbol strokes drawn — from the level's start (star `start`, beat 0, nothing drawn). At each depth the states are
// expanded in the order they were reached; each state's legs in the order corridors by index (those touching the ship's
// star), then waits 0 … 8. A leg reaches a state only when the chart accepts it (flyable, not refused) and finds no
// failure (a stray stroke always fails, so states only hold subsets of the symbol); states are merged by star, beat and
// strokes. The first leg that wins ends the search and its path is the plan. Work = legs tried (every corridor and wait
// considered), counted and bounded; over the bound, or past the most legs asked for, there is no plan. The minimality
// proof is that every state reachable in fewer legs was reached and none won (the states reached at each smaller depth
// are counted). Nothing here reads a clock. Modelled on `VoxelOrigamiSolver` (feature 442).

/// A minimal plan of a level: its legs in order, the states reached at each smaller depth and the work.
public struct StarlitCartouchePlan: Sendable, Equatable, Codable {
    /// The legs of the plan, in order (each `.leg(star, wait)`).
    public let legs: [StarlitCartoucheAction]
    /// The states reached at depths 0 … size − 1 (depth 0 is the start alone: 1); none won.
    public let statesByDepth: [Int]
    /// The legs tried before the plan was found.
    public let work: Int

    /// A plan of the given values.
    public init(legs: [StarlitCartoucheAction], statesByDepth: [Int], work: Int) {
        self.legs = legs
        self.statesByDepth = statesByDepth
        self.work = work
    }

    /// The number of legs.
    public var size: Int { legs.count }

    /// The states reached at every smaller depth together.
    public var statesSearched: Int { statesByDepth.reduce(0, +) }
}

/// The time-expanded breadth-first solver of Starlit Cartouche (see the file header).
public enum StarlitCartoucheSolver {
    /// The most legs tried for one level.
    public static let workBound: Int = 300_000
    /// The most legs a plan may have.
    public static let maxLegs: Int = 7

    /// A route state: the ship's star, the beat and the drawn strokes as a mask over the symbol's strokes.
    struct State: Hashable {
        let star: Int
        let beat: Int
        let mask: Int
    }

    /// The minimal plan of `level` within `maxLegs` legs and `workBound` legs tried, or nil.
    public static func plan(_ level: StarlitCartoucheLevel, maxLegs: Int = maxLegs,
                            workBound: Int = workBound) -> StarlitCartouchePlan? {
        var strokeBit: [Int: Int] = [:]
        for (bit, corridor) in level.symbol.enumerated() { strokeBit[corridor] = bit }
        let full: Int = (1 << level.symbol.count) - 1
        let start = State(star: level.start, beat: 0, mask: 0)
        var parent: [State: (State, StarlitCartoucheAction)] = [:]
        var seen: Set<State> = [start]
        var frontier: [State] = [start]
        var statesByDepth: [Int] = []
        var work: Int = 0
        var depth: Int = 0
        while !frontier.isEmpty, depth < maxLegs {
            statesByDepth.append(frontier.count)
            depth += 1
            var next: [State] = []
            for state in frontier {
                for index in level.corridors.indices {
                    let corridor: StarlitCartoucheCorridor = level.corridors[index]
                    guard corridor.a == state.star || corridor.b == state.star else { continue }
                    let destination: Int = corridor.a == state.star ? corridor.b : corridor.a
                    for wait in StarlitCartoucheChart.waits {
                        work += 1
                        if work > workBound { return nil }
                        guard let leg = try? StarlitCartoucheChart.leg(level, from: state.star, at: state.beat,
                                                                       to: destination, wait: wait),
                              StarlitCartoucheChart.check(level, leg: leg) == nil,
                              let bit = strokeBit[leg.corridor] else { continue }
                        let reached = State(star: destination, beat: leg.arrive, mask: state.mask | (1 << bit))
                        let action: StarlitCartoucheAction = .leg(destination, wait)
                        if reached.mask == full && destination == level.beacon {
                            parent[reached] = parent[reached] ?? (state, action)
                            var legs: [StarlitCartoucheAction] = [action]
                            var current: State = state
                            while current != start, let (previous, step) = parent[current] {
                                legs.append(step)
                                current = previous
                            }
                            return StarlitCartouchePlan(legs: legs.reversed(), statesByDepth: statesByDepth,
                                                        work: work)
                        }
                        guard seen.insert(reached).inserted else { continue }
                        parent[reached] = (state, action)
                        next.append(reached)
                    }
                }
            }
            frontier = next
        }
        return nil
    }

    /// Whether `actions`, applied through the kernel's play from `level`'s start, end with the level won on the last
    /// one.
    public static func wins(_ level: StarlitCartoucheLevel, actions: [StarlitCartoucheAction]) -> Bool {
        var play = StarlitCartouchePlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for (index, action) in actions.enumerated() {
                try play.apply(action, expecting: play.fingerprint)
                if play.stage == .won { return index == actions.count - 1 }
                guard play.stage == .playing else { return false }
            }
        } catch {
            return false
        }
        return false
    }
}
