// MoonlitMechanismSolver — feature 432 (R02-G14-02) T-R02G1402-003 (FR-R02G1402-002; SC-R02G1402-001, 002, 005;
// clarification Q2; research R1 … R3, R5). The minimal plan of a Moonlit Mechanism level. Every action adds to one
// vector — the net handle turns t, the net lamp steps h and the net re-seat rᵢ of each gear (the driver's is 0) — so
// actions commute and a lamp path that moves one way stays in range whenever its end does: a plan is a vector and its
// length is the vector's L1 norm |t| + |h| + Σ|rᵢ|. The solver tries the vectors (t, h, r₁ … rₙ₋₁) by norm c = 0, 1,
// 2, …; at each norm in a fixed order (each coordinate from −left to +left in the order t, h, r₁, …, the last
// coordinate +left before −left). A vector whose lamp height leaves the range is skipped; a vector that leaves a mesh
// misaligned is skipped without a run (a turn moves meshing gears by +t and −t, so alignments depend only on the
// re-seats, and a jammed machine never wins: the gear-ratio constraint); every other vector is judged by the kernel's
// run of the set-up it reaches. The first winning vector is the plan; every vector of a smaller norm was tried and lost
// (their count is the minimality proof). Work = runs, bounded; over the bound there is no plan. The witness is |t|
// turns of t's sign, then each gear's |rᵢ| re-seats of rᵢ's sign in gear order, then |h| lamp steps of h's sign, then
// the run. Feature 435 (R02-G14-05) T-R02G1405-002 adds the same search from a state of play
// (`plan(_:phases:height:maxActions:workBound:)`, clarification Q1); `plan(_:)` is that entry at the level's starting
// phases and height, so certification is unchanged.

/// A minimal plan: the net turns, lamp steps and re-seats, the vectors of smaller norms tried and the work.
public struct MoonlitMechanismPlan: Sendable, Equatable, Codable {
    /// The net handle turns t.
    public let turns: Int
    /// The net lamp steps h.
    public let lamp: Int
    /// The net re-seat of every gear (the driver's is 0).
    public let reseats: [Int]
    /// The vectors of smaller norms tried, none of which wins.
    public let smallerVectors: Int
    /// The runs judged in all.
    public let work: Int

    /// A plan of the given values.
    public init(turns: Int, lamp: Int, reseats: [Int], smallerVectors: Int, work: Int) {
        self.turns = turns
        self.lamp = lamp
        self.reseats = reseats
        self.smallerVectors = smallerVectors
        self.work = work
    }

    /// The number of actions before the run: |t| + |h| + Σ|rᵢ|.
    public var size: Int { abs(turns) + abs(lamp) + reseats.reduce(0) { $0 + abs($1) } }
}

/// The minimal-plan solver of Moonlit Mechanism levels.
public enum MoonlitMechanismSolver {
    /// The bound on runs per search.
    public static let workBound: Int = 400_000
    /// The largest plan the content pipeline certifies (band 5's upper end).
    public static let maxActions: Int = 6

    /// The minimal plan of `level` with at most `maxActions` actions before the run, or nil when there is none
    /// within `workBound` runs (see the file header). It is ``plan(_:phases:height:maxActions:workBound:)`` at the
    /// level's starting phases and starting height.
    public static func plan(_ level: MoonlitMechanismLevel, maxActions: Int = maxActions,
                            workBound: Int = workBound) -> MoonlitMechanismPlan? {
        plan(level, phases: level.startingPhases, height: level.startingHeight, maxActions: maxActions,
             workBound: workBound)
    }

    /// The minimal plan of `level` from a state of play (feature 435 (R02-G14-05) T-R02G1405-002, clarification Q1):
    /// the plan-vector search of ``plan(_:maxActions:workBound:)`` with `phases` (one per gear, each in
    /// 0 … teeth − 1) in place of the starting phases and `height` in place of the starting height, pruned by the lamp
    /// range and the mesh alignments in the same way. The plan's turns, lamp steps and re-seats are relative to
    /// `phases` and `height`. Nil when `phases` does not hold one phase per gear in range, when `height` is outside
    /// 0 … L − 1, when `maxActions` is negative, when no vector of norm at most `maxActions` wins, or when more than
    /// `workBound` runs would be judged.
    public static func plan(_ level: MoonlitMechanismLevel, phases: [Int], height: Int,
                            maxActions: Int = maxActions, workBound: Int = workBound) -> MoonlitMechanismPlan? {
        let gears: [MoonlitMechanismGear] = level.gears
        let count: Int = gears.count
        guard phases.count == count, maxActions >= 0, height >= 0, height < level.lampHeights else { return nil }
        for gear in 0..<count where phases[gear] < 0 || phases[gear] >= gears[gear].teeth { return nil }
        let dimensions: Int = count + 1
        let start: [Int] = phases
        let startHeight: Int = height
        var work: Int = 0
        var tried: Int = 0
        var smaller: Int = 0
        var vector: [Int] = Array(repeating: 0, count: dimensions)
        var found: [Int]?
        var exhausted: Bool = false

        func judge() {
            tried += 1
            let height: Int = startHeight + vector[1]
            guard height >= 0, height < level.lampHeights else { return }
            var phases: [Int] = start
            for gear in 1..<count {
                phases[gear] = MoonlitMechanismTrain.mod(phases[gear] + vector[gear + 1], gears[gear].teeth)
            }
            for gear in 1..<count where MoonlitMechanismTrain.alignmentError(gears, phases: phases, child: gear) != 0 {
                return
            }
            guard work < workBound else {
                exhausted = true
                return
            }
            work += 1
            let turned: [Int] = MoonlitMechanismTrain.turned(gears, phases: phases, by: vector[0])
            if level.run(phases: turned, height: height).outcome == .won { found = vector }
        }

        func fill(_ index: Int, _ left: Int) {
            guard found == nil, !exhausted else { return }
            if index == dimensions - 1 {
                vector[index] = left
                judge()
                if left != 0, found == nil, !exhausted {
                    vector[index] = -left
                    judge()
                }
                return
            }
            for value in stride(from: -left, through: left, by: 1) {
                vector[index] = value
                fill(index + 1, left - abs(value))
                if found != nil || exhausted { return }
            }
        }

        for norm in 0...maxActions {
            let before: Int = tried
            fill(0, norm)
            if exhausted { return nil }
            if let winner = found {
                var reseats: [Int] = [0]
                for gear in 1..<count { reseats.append(winner[gear + 1]) }
                return MoonlitMechanismPlan(turns: winner[0], lamp: winner[1], reseats: reseats,
                                            smallerVectors: smaller, work: work)
            }
            smaller += tried - before
        }
        return nil
    }

    /// The witness actions of `plan`: its turns, its re-seats in gear order, its lamp steps, then the run.
    public static func actions(_ plan: MoonlitMechanismPlan) -> [MoonlitMechanismAction] {
        var actions: [MoonlitMechanismAction] = []
        let turn: Int = plan.turns < 0 ? -1 : 1
        for _ in 0..<abs(plan.turns) { actions.append(.turn(turn)) }
        for (gear, reseat) in plan.reseats.enumerated() where reseat != 0 {
            let step: Int = reseat < 0 ? -1 : 1
            for _ in 0..<abs(reseat) { actions.append(.reseat(gear, step)) }
        }
        let lamp: Int = plan.lamp < 0 ? -1 : 1
        for _ in 0..<abs(plan.lamp) { actions.append(.lamp(lamp)) }
        actions.append(.run)
        return actions
    }

    /// Whether `actions`, applied to a fresh play of `level` (begun, its tutorial dismissed), end in a win.
    public static func wins(_ level: MoonlitMechanismLevel, actions: [MoonlitMechanismAction]) -> Bool {
        var play = MoonlitMechanismPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
        } catch {
            return false
        }
        return play.stage == .won
    }
}
