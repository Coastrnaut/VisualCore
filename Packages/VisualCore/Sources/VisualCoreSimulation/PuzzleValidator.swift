// PuzzleValidator — feature 223 (R02-F23) T-R02F23-004 (FR-R02F23-002…004, 006; clarification Q3; research R3, R4).
// Certifies a level against its rules: replays the solution, checks the fairness budget, then runs one breadth-first
// search from the start to the maximum length that proves the uniqueness promise or names the check that fails.

/// Certification of puzzle levels.
public enum PuzzleValidator {
    /// Certifies `level` against `rules`, stopping at the first failed check, in this order:
    ///
    /// 1. the level's rules id equals `rules.rulesID` (else `.wrongRules`);
    /// 2. every solution move is among `rules.moves(in:)` of the current state and `apply` accepts it
    ///    (else `.illegalMove(index)`);
    /// 3. the replay ends in a solved state (else `.notSolved`);
    /// 4. the solution's length lies in `minLength … maxLength` (else `.tooShort(count)` or `.tooLong(count)`);
    /// 5. a breadth-first search from the start, to depth `maxLength`, states deduplicated and moves taken in the rules'
    ///    order: every discovered state counts against the node budget, the start included (`.unproven` as soon as the
    ///    count exceeds it), and every discovered state's move count is checked against the branching bound
    ///    (`.tooBranching(count)`). A solved state ends a path: it is counted but not expanded, so a path that passes
    ///    through a solved state is not a solution of its own;
    /// 6. the shortest solution found is at least `minLength` (else `.tooShort(shortest)`);
    /// 7. the promise: `.goal` needs exactly one solved state found; `.solution` needs the level's solution to be as short
    ///    as the shortest and exactly one shortest path (else `.notUnique`).
    ///
    /// Shortest paths are counted per state with saturation at 2: a state first reached at depth d adds the counts of
    /// all its parents at depth d − 1. The search uses an array queue, so the certificate is the same on every run.
    /// `explored` is 0 when the search did not run; on `.unproven` it is the count that exceeded the budget.
    public static func certify<R: PuzzleRules>(_ level: PuzzleLevel<R>, rules: R) -> PuzzleCertificate {
        guard level.rulesID == rules.rulesID else { return PuzzleCertificate(verdict: .wrongRules) }

        var state: R.State = level.start
        for (index, move) in level.solution.enumerated() {
            guard rules.moves(in: state).contains(move), let next = rules.apply(move, to: state) else {
                return PuzzleCertificate(verdict: .illegalMove(index))
            }
            state = next
        }
        guard rules.isSolved(state) else { return PuzzleCertificate(verdict: .notSolved) }

        let budget: FairnessBudget = level.budget
        let count: Int = level.solution.count
        if count < budget.minLength { return PuzzleCertificate(verdict: .tooShort(count)) }
        if count > budget.maxLength { return PuzzleCertificate(verdict: .tooLong(count)) }

        let search: Search<R> = Search(rules: rules, start: level.start, budget: budget)
        if let failure = search.failure {
            return search.certificate(failure)
        }
        guard let shortest = search.shortest else {
            // Unreachable for a replayed solution within maxLength; reported as unproven rather than trusted.
            return search.certificate(.unproven)
        }
        if shortest < budget.minLength { return search.certificate(.tooShort(shortest)) }
        switch level.uniqueness {
        case .none:
            break
        case .goal:
            if search.solvedStates != 1 { return search.certificate(.notUnique) }
        case .solution:
            if count != shortest || search.shortestPaths != 1 { return search.certificate(.notUnique) }
        }
        return search.certificate(.valid)
    }

    /// One breadth-first certification search and its statistics.
    private struct Search<R: PuzzleRules> {
        var explored: Int = 0
        var shortest: Int?
        var solvedStates: Int = 0
        var shortestPaths: Int = 0
        var maxBranching: Int = 0
        var failure: PuzzleVerdict?

        init(rules: R, start: R.State, budget: FairnessBudget) {
            var index: [R.State: Int] = [:]
            var states: [R.State] = []
            var depths: [Int] = []
            var paths: [Int] = []
            var moveLists: [[R.Move]] = []
            var solved: [Bool] = []

            // Discovers a new state; returns false when the search must stop.
            func discover(_ s: R.State, depth: Int, pathCount: Int) -> Bool {
                explored += 1
                if explored > budget.nodeBudget { failure = .unproven; return false }
                let moves: [R.Move] = rules.moves(in: s)
                if moves.count > maxBranching { maxBranching = moves.count }
                if moves.count > budget.maxBranching { failure = .tooBranching(moves.count); return false }
                let isSolved: Bool = rules.isSolved(s)
                if isSolved {
                    if solvedStates < 2 { solvedStates += 1 }
                    if shortest == nil { shortest = depth }
                }
                index[s] = states.count
                states.append(s)
                depths.append(depth)
                paths.append(pathCount)
                moveLists.append(moves)
                solved.append(isSolved)
                return true
            }

            guard discover(start, depth: 0, pathCount: 1) else { return }
            var head: Int = 0
            while head < states.count {
                let current: Int = head
                head += 1
                let depth: Int = depths[current]
                if solved[current] || depth >= budget.maxLength { continue }
                let moves: [R.Move] = moveLists[current]
                for move in moves {
                    guard let next = rules.apply(move, to: states[current]) else { continue }
                    if let known = index[next] {
                        if depths[known] == depth + 1 { paths[known] = min(2, paths[known] + paths[current]) }
                    } else {
                        guard discover(next, depth: depth + 1, pathCount: paths[current]) else { return }
                    }
                }
            }

            if let shortestDepth = shortest {
                var total: Int = 0
                for i in 0..<states.count where solved[i] && depths[i] == shortestDepth {
                    total = min(2, total + paths[i])
                }
                shortestPaths = total
            }
        }

        /// The certificate of `verdict` with this search's statistics.
        func certificate(_ verdict: PuzzleVerdict) -> PuzzleCertificate {
            PuzzleCertificate(verdict: verdict, explored: explored, shortest: shortest, solvedStates: solvedStates,
                              shortestPaths: shortestPaths, maxBranching: maxBranching)
        }
    }
}
