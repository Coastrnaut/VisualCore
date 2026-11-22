// AmethystEscapeSolverTests — feature 362 (R02-G07-02) T-R02G0702-003 (FR-R02G0702-002; SC-R02G0702-002, 005;
// clarification Q2). The breadth-first solver, seed 2_362: hand-built levels with shortest routes worked out by hand (two
// advances through aligned apertures, with the exact depths and work; four advances rolling to an aperture; five moves
// needing three turns to line a walled outer shell's exit gap up) whose witnesses replay through the play to a win; two
// inescapable levels (a blocked exit gap, a pearl walled in shell 0) give nil; escapesByAdvancing on escaping, stuck and
// wedged levels and against an advances-only walk written here; encode and decode round-trip every state of small levels
// and stateCount is N^K × K × N. An independent brute force with its own transition rules (never the crystal's methods)
// runs on ~30 seeded small levels and the small fixtures: no action sequence shorter than the solver's smallest escapes
// and one of that length does (a depth-limited exhaustive search, memoised on the remaining depth), and the solver returns
// nil exactly when no reachable state of the brute force's closure can exit. depths has `smallest` entries, depths[0] is
// 1, every state before the last depth was expanded (sum of the earlier depths < work ≤ sum(depths) ≤ stateCount); the
// solve is deterministic. Explicit types, plain loops; each test well under 3 s.
import Foundation
import Testing
@testable import AmethystEscapeCore

@Suite struct AmethystEscapeSolverTests {
    typealias Level = AmethystEscapeLevel
    typealias Shell = AmethystEscapeShell
    typealias Solver = AmethystEscapeSolver
    typealias Action = AmethystEscapeAction

    /// The solver test seed.
    static let seed: UInt64 = 2_362

    /// The largest state count a sampled level may have (keeps every test fast in a debug build).
    static let smallStates: Int = 30_000

    // MARK: - Hand-built levels

    /// N = 6, K = 2, both shells open at own sector 0, pearl at 0: two advances escape (no move can escape sooner, the
    /// pearl starts in shell 0). From the start, four rotations and the advance reach five new states, and the exit is
    /// found expanding the fifth of them: depths [1, 5], work 6.
    static func aligned() throws(AmethystEscapeError) -> Level {
        try Level(id: "aligned", seed: seed, difficulty: 1, sectors: 6,
                  shells: [Shell(apertures: [0]), Shell(apertures: [0])], start: 0, budget: 4)
    }

    /// N = 6, K = 2, shell 0 open at own 2, shell 1's exit gap at own 2, no walls, pearl at 0: rolling twice and leaving
    /// twice escapes in 4 advances. A turn of shell 0 carries the pearl and keeps its own sector, so no turn can replace a
    /// roll; it is the shortest.
    static func rolling() throws(AmethystEscapeError) -> Level {
        try Level(id: "rolling", seed: seed, difficulty: 1, sectors: 6,
                  shells: [Shell(apertures: [2]), Shell(apertures: [2])], start: 0, budget: 6, tutorial: true)
    }

    /// N = 6, K = 2, shell 0 open at own 0, shell 1's exit gap at own 3 with walls 0 … 4 (only wall 5 absent), pearl at 0.
    /// The pearl arrives in shell 1 at own (x − y) mod 6, x and y the net turns of shells 0 and 1; turning shell 1 with the
    /// pearl in it keeps its own sector. Only own 3 exits at once; own 5 rolls to own 0 and is stuck; every other own
    /// sector is stuck. So |x| + |y| ≥ 3: three turns and two advances, 5 moves.
    static func turning() throws(AmethystEscapeError) -> Level {
        try Level(id: "turning", seed: seed, difficulty: 2, sectors: 6,
                  shells: [Shell(apertures: [0]), Shell(apertures: [3], walls: [0, 1, 2, 3, 4])], start: 0, budget: 8)
    }

    /// N = 6, K = 2 with shell 1's exit gap (own 0) a blocked wedge: the pearl can only stand in own 0 of shell 1 by
    /// moving into it, which is a wedge, and no turn changes the own sector of the pearl's pocket. Inescapable.
    static func blockedExit() throws(AmethystEscapeError) -> Level {
        try Level(id: "blocked-exit", seed: seed, difficulty: 1, sectors: 6,
                  shells: [Shell(apertures: [0]), Shell(apertures: [0], blocked: [0])], start: 0, budget: 10)
    }

    /// N = 6, K = 3, shell 0 open only at own 3 with wall 0, pearl at 0: own 0 is closed and walled, every turn of shell 0
    /// keeps the pearl in own 0 and other turns do not touch it, so the pearl is stuck forever. Inescapable.
    static func walledIn() throws(AmethystEscapeError) -> Level {
        try Level(id: "walled-in", seed: seed, difficulty: 1, sectors: 6,
                  shells: [Shell(apertures: [3], walls: [0]), Shell(apertures: [1]), Shell(apertures: [2])], start: 0,
                  budget: 10)
    }

    // MARK: - Independent brute force (its own rules; never the crystal's methods)

    /// A crystal state of the brute force: absolute offsets and the pearl's shell and absolute sector.
    struct BruteState: Hashable {
        /// Every shell's offset, innermost first.
        var offsets: [Int]
        /// The pearl's shell.
        var shell: Int
        /// The pearl's absolute sector.
        var sector: Int
    }

    /// The outcome of one action in the brute force.
    enum BruteStep {
        /// The crystal is in a new state.
        case next(BruteState)
        /// The pearl left through the exit gap.
        case exit
        /// The advance was stuck or ended in a blocked wedge: a dead end.
        case dead
    }

    /// `value` mod `n` in 0 ..< n.
    static func modulo(_ value: Int, _ n: Int) -> Int { ((value % n) + n) % n }

    /// The opening state of `level`.
    static func opening(_ level: Level) -> BruteState {
        BruteState(offsets: [Int](repeating: 0, count: level.shells.count), shell: 0, sector: level.start)
    }

    /// Every action, in any fixed order: each shell turned +1 and −1, then the advance.
    static func allActions(_ level: Level) -> [Action] {
        var actions: [Action] = []
        for shell in 0..<level.shells.count {
            actions.append(.rotate(shell, 1))
            actions.append(.rotate(shell, -1))
        }
        actions.append(.advance)
        return actions
    }

    /// `action` applied to `state` by the rules of clarification Q2, written here from the level's data alone.
    static func step(_ level: Level, _ state: BruteState, _ action: Action) -> BruteStep {
        let n: Int = level.sectors
        var next: BruteState = state
        switch action {
        case let .rotate(shell, turn):
            next.offsets[shell] = modulo(state.offsets[shell] + turn, n)
            if state.shell == shell { next.sector = modulo(state.sector + turn, n) }
            return .next(next)
        case .advance:
            let own: Int = modulo(state.sector - state.offsets[state.shell], n)
            let data: Shell = level.shells[state.shell]
            if data.apertures.contains(own) {
                if state.shell == level.shells.count - 1 { return .exit }
                next.shell = state.shell + 1
            } else if !data.walls.contains(own) {
                next.sector = modulo(state.sector + 1, n)
            } else {
                return .dead
            }
            let arrival: Int = modulo(next.sector - next.offsets[next.shell], n)
            if level.shells[next.shell].blocked.contains(arrival) { return .dead }
            return .next(next)
        }
    }

    /// Whether some action sequence of at most `limit` actions from `state` escapes: an exhaustive depth-first search
    /// over every sequence, memoised by the largest remaining depth already searched without an escape from a state.
    static func escapes(_ level: Level, from state: BruteState, within limit: Int, actions: [Action],
                        searched: inout [BruteState: Int]) -> Bool {
        if limit <= 0 { return false }
        if let done = searched[state], done >= limit { return false }
        for action in actions {
            switch step(level, state, action) {
            case .exit:
                return true
            case .dead:
                continue
            case let .next(successor):
                if escapes(level, from: successor, within: limit - 1, actions: actions, searched: &searched) { return true }
            }
        }
        searched[state] = limit
        return false
    }

    /// Whether some sequence of at most `limit` actions from the opening state of `level` escapes.
    static func escapes(_ level: Level, within limit: Int) -> Bool {
        var searched: [BruteState: Int] = [:]
        return escapes(level, from: opening(level), within: limit, actions: allActions(level), searched: &searched)
    }

    /// Whether any state reachable from the opening state of `level` (with any number of actions) can exit.
    static func anyEscape(_ level: Level) -> Bool {
        let actions: [Action] = allActions(level)
        var seen: Set<BruteState> = [opening(level)]
        var stack: [BruteState] = [opening(level)]
        while let state = stack.popLast() {
            for action in actions {
                switch step(level, state, action) {
                case .exit:
                    return true
                case .dead:
                    continue
                case let .next(successor):
                    if seen.insert(successor).inserted { stack.append(successor) }
                }
            }
        }
        return false
    }

    /// Whether advances alone from the opening state of `level` exit (stopping at a dead end or a repeated pocket).
    static func advancesEscape(_ level: Level) -> Bool {
        var state: BruteState = opening(level)
        var seen: Set<BruteState> = [state]
        while true {
            switch step(level, state, .advance) {
            case .exit: return true
            case .dead: return false
            case let .next(successor):
                if !seen.insert(successor).inserted { return false }
                state = successor
            }
        }
    }

    /// Whether `actions` from the opening state of `level` exit exactly on the last action (brute-force rules).
    static func bruteWins(_ level: Level, _ actions: [Action]) -> Bool {
        var state: BruteState = opening(level)
        for index in actions.indices {
            switch step(level, state, actions[index]) {
            case .exit: return index == actions.count - 1
            case .dead: return false
            case let .next(successor): state = successor
            }
        }
        return false
    }

    // MARK: - Sampled levels

    /// A seeded small level for index `index`: N = 6 … 7, K = 2 … 3, random apertures, walls and blocked wedges.
    static func small(_ index: Int) throws(AmethystEscapeError) -> Level {
        var random = AmethystEscapeRandom(seed: seed &+ UInt64(index) &* 6_151)
        let n: Int = random.int(6...7)
        let k: Int = random.int(2...3)
        var shells: [Shell] = []
        for shell in 0..<k {
            var apertures: Set<Int> = [random.int(0..<n)]
            if shell + 1 < k {
                for sector in 0..<n where random.int(0...4) == 0 { apertures.insert(sector) }
            }
            var walls: Set<Int> = []
            for wall in 0..<n where random.int(0...2) == 0 { walls.insert(wall) }
            if walls.count >= n { walls.remove(0) }
            var blocked: Set<Int> = []
            for sector in 0..<n where random.int(0...4) == 0 { blocked.insert(sector) }
            if blocked.count >= n { blocked.remove(0) }
            shells.append(Shell(apertures: Array(apertures), walls: Array(walls), blocked: Array(blocked)))
        }
        var open: [Int] = []
        for sector in 0..<n where !shells[0].isBlocked(sector) { open.append(sector) }
        let start: Int = open[random.int(0..<open.count)]
        return try Level(id: "small-\(index)", seed: seed &+ UInt64(index), difficulty: 1 + index % 5, sectors: n,
                         shells: shells, start: start, budget: 60, tutorial: index % 2 == 0)
    }

    /// The sampled levels: 30 seeded small levels and the fixtures 0 … 39 with at most ``smallStates`` states.
    static func sampled() throws(AmethystEscapeError) -> [Level] {
        var levels: [Level] = []
        for index in 0..<30 { levels.append(try small(index)) }
        for index in 0..<40 {
            let level: Level = AmethystEscapeFixtures.fixture(index).level
            if Solver.stateCount(level) <= smallStates { levels.append(level) }
        }
        return levels
    }

    // MARK: - Helpers

    /// Plays `actions` through a new play of `level` (begin, the tutorial dismissed, each action naming the current
    /// fingerprint) and returns the play.
    static func play(_ level: Level, _ actions: [Action]) throws(AmethystEscapeError) -> AmethystEscapePlay {
        var play = AmethystEscapePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for action in actions {
            let previous: String = play.fingerprint
            try play.apply(action, expecting: previous)
        }
        return play
    }

    /// The number of rotations in `actions`.
    static func turns(_ actions: [Action]) -> Int {
        var count: Int = 0
        for action in actions {
            if case .rotate = action { count += 1 }
        }
        return count
    }

    /// Checks the proof invariants of `solution` for `level`.
    static func checkProof(_ solution: AmethystEscapeSolution, level: Level) {
        #expect(solution.actions.count == solution.smallest)
        #expect(solution.actions.last == .advance)
        #expect(solution.depths.count == solution.smallest)
        #expect(solution.depths.first == 1)
        var earlier: Int = 0
        for depth in solution.depths.dropLast() { earlier += depth }
        let total: Int = earlier + (solution.depths.last ?? 0)
        #expect(earlier < solution.work)
        #expect(solution.work <= total)
        #expect(total <= Solver.stateCount(level))
        for depth in solution.depths { #expect(depth > 0) }
    }

    // MARK: - Tests

    @Test func alignedApertures() throws {
        let level: Level = try Self.aligned()
        let solution: AmethystEscapeSolution = try #require(Solver.solve(level))
        #expect(solution.smallest == 2)
        #expect(solution.actions == [.advance, .advance])
        #expect(solution.depths == [1, 5])
        #expect(solution.work == 6)
        Self.checkProof(solution, level: level)
        let play: AmethystEscapePlay = try Self.play(level, solution.actions)
        #expect(play.stage == .won)
        #expect(play.moves == 2)
    }

    @Test func rollingToTheAperture() throws {
        let level: Level = try Self.rolling()
        let solution: AmethystEscapeSolution = try #require(Solver.solve(level))
        #expect(solution.smallest == 4)
        #expect(solution.actions == [.advance, .advance, .advance, .advance])
        Self.checkProof(solution, level: level)
        let play: AmethystEscapePlay = try Self.play(level, solution.actions)
        #expect(play.stage == .won)
        #expect(play.moves == 4)
    }

    @Test func turnsLineUpTheExitGap() throws {
        let level: Level = try Self.turning()
        let solution: AmethystEscapeSolution = try #require(Solver.solve(level))
        #expect(solution.smallest == 5)
        #expect(Self.turns(solution.actions) == 3)
        Self.checkProof(solution, level: level)
        let play: AmethystEscapePlay = try Self.play(level, solution.actions)
        #expect(play.stage == .won)
        #expect(play.moves == 5)
        // Four moves never escape; the brute force agrees.
        #expect(!Self.escapes(level, within: 4))
        #expect(Self.escapes(level, within: 5))
    }

    @Test func inescapableLevelsGiveNil() throws {
        let blocked: Level = try Self.blockedExit()
        let walled: Level = try Self.walledIn()
        #expect(Solver.solve(blocked) == nil)
        #expect(Solver.solve(walled) == nil)
        #expect(!Self.anyEscape(blocked))
        #expect(!Self.anyEscape(walled))
        #expect(!Self.escapes(blocked, within: 8))
        #expect(!Self.escapes(walled, within: 8))
    }

    @Test func escapesByAdvancing() throws {
        #expect(Solver.escapesByAdvancing(try Self.aligned()))
        #expect(Solver.escapesByAdvancing(try Self.rolling()))
        #expect(!Solver.escapesByAdvancing(try Self.turning()))
        #expect(!Solver.escapesByAdvancing(try Self.blockedExit()))
        #expect(!Solver.escapesByAdvancing(try Self.walledIn()))
        for level in try Self.sampled() {
            let advancing: Bool = Solver.escapesByAdvancing(level)
            #expect(advancing == Self.advancesEscape(level), "\(level.id)")
            if advancing {
                let solution: AmethystEscapeSolution? = Solver.solve(level)
                #expect(solution != nil, "\(level.id)")
            }
        }
    }

    @Test func encodeDecodeRoundTrip() throws {
        let levels: [Level] = [try Self.aligned(), try Self.walledIn(), try Self.small(0), try Self.small(1)]
        for level in levels {
            let n: Int = level.sectors
            let k: Int = level.shells.count
            var expected: Int = k * n
            for _ in 0..<k { expected *= n }
            let count: Int = Solver.stateCount(level)
            #expect(count == expected, "\(level.id)")
            var seen: Set<AmethystEscapeCrystal> = []
            for state in 0..<count {
                let crystal: AmethystEscapeCrystal = Solver.decode(state, level: level)
                #expect(crystal.offsets.count == k)
                for offset in crystal.offsets { #expect((0..<n).contains(offset)) }
                #expect((0..<k).contains(crystal.pearl.shell))
                #expect((0..<n).contains(crystal.pearl.sector))
                #expect(Solver.encode(crystal, level: level) == state)
                seen.insert(crystal)
            }
            #expect(seen.count == count, "\(level.id): decode is one-to-one")
        }
        #expect(Solver.stateCount(try Self.aligned()) == 432)
        #expect(Solver.encode(AmethystEscapeCrystal(level: try Self.aligned()), level: try Self.aligned()) == 0)
    }

    @Test func bruteForceAgreesOnSampledLevels() throws {
        let levels: [Level] = try Self.sampled()
        #expect(levels.count >= 40)
        var solved: Int = 0
        var unsolved: Int = 0
        for level in levels {
            let solution: AmethystEscapeSolution? = Solver.solve(level)
            if let solution {
                solved += 1
                #expect(!Self.escapes(level, within: solution.smallest - 1), "\(level.id): nothing shorter escapes")
                #expect(Self.escapes(level, within: solution.smallest), "\(level.id): one of the smallest length escapes")
                #expect(Self.bruteWins(level, solution.actions), "\(level.id): witness escapes by the brute force rules")
                #expect(AmethystEscapeFixtures.wins(level: level, actions: solution.actions), "\(level.id)")
                Self.checkProof(solution, level: level)
                if solution.smallest <= level.budget {
                    let play: AmethystEscapePlay = try Self.play(level, solution.actions)
                    #expect(play.stage == .won, "\(level.id)")
                }
            } else {
                unsolved += 1
                #expect(!Self.anyEscape(level), "\(level.id): no reachable state exits")
                #expect(!Self.escapes(level, within: 8), "\(level.id)")
            }
        }
        // Both outcomes are exercised.
        #expect(solved >= 10)
        #expect(unsolved >= 3)
    }

    @Test func fixturesSolveWithinTheirRoute() throws {
        for index in 0..<40 {
            let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(index)
            if Solver.stateCount(fixture.level) > Self.smallStates { continue }
            let solution: AmethystEscapeSolution = try #require(Solver.solve(fixture.level))
            #expect(solution.smallest <= fixture.actions.count, "fixture \(index)")
            let play: AmethystEscapePlay = try Self.play(fixture.level, solution.actions)
            #expect(play.stage == .won, "fixture \(index)")
        }
    }

    @Test func solveIsDeterministic() throws {
        var levels: [Level] = [try Self.aligned(), try Self.rolling(), try Self.turning(), try Self.blockedExit()]
        for index in 0..<10 { levels.append(try Self.small(index)) }
        for level in levels {
            let first: AmethystEscapeSolution? = Solver.solve(level)
            let second: AmethystEscapeSolution? = Solver.solve(level)
            #expect(first == second, "\(level.id)")
        }
    }
}
