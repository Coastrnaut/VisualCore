// FacetedForgeSolver — feature 372 (R02-G08-02) T-R02G0802-003 (FR-R02G0802-002; clarification Q2; research R1 … R3).
// The certifying solver of Faceted Forge. Every accepted cut turns one piece into two, so a target of P pieces needs at
// least P − 1 cuts (`lowerBound`); a winning sequence of exactly P − 1 cuts is therefore certified smallest. The solver
// searches depth-first for such a sequence from the crystal alone, in the rules' fixed order (pieces in canonical
// order, directions 0 … 12, crossing depths ascending), keeping a cut only when both halves are at least the sliver
// limit and the pieces can still be partitioned into the target (`canPartition`: every target entry is given to one
// piece, each piece's share is the sum of its entries' shares, and a piece given one entry already has that entry's
// face count). It never continues from a failed state. Work is the number of cuts evaluated, counted and bounded; a
// search over its bound gives nil. Feature 375 (R02-G08-05) T-R02G0805-002 adds the entry point from any pieces with
// any number of cuts left (the hint plan, clarification Q1); the certifying entry point calls it from the crystal, so
// its results are unchanged. Pure and deterministic: exact fractions, no clock, no random source.

/// A certified solution: the smallest cut count, a winning cut sequence of that length and the work spent.
public struct FacetedForgeSolution: Sendable, Equatable, Hashable, Codable {
    /// The smallest cut count (target pieces − 1).
    public let smallest: Int
    /// The winning cuts, in play order (piece indices in the canonical order at the time of each cut).
    public let actions: [FacetedForgeAction]
    /// The cuts evaluated by the search.
    public let work: Int

    /// A solution of the given values.
    public init(smallest: Int, actions: [FacetedForgeAction], work: Int) {
        self.smallest = smallest
        self.actions = actions
        self.work = work
    }
}

/// The certifying solver (see the file header).
public enum FacetedForgeSolver {
    /// The default bound on cut evaluations per level.
    public static let workBound: Int = 20_000

    /// The smallest possible number of cuts: the target's piece count minus one.
    public static func lowerBound(_ level: FacetedForgeLevel) -> Int { level.target.count - 1 }

    /// The share of `piece` in a crystal of volume `crystal`.
    static func share(_ piece: FacetedForgePiece, crystal: FacetedForgeFraction) -> FacetedForgeFraction? {
        try? piece.volume.dividing(by: crystal)
    }

    /// Whether `pieces` can be partitioned into `target`: every entry given to one piece, each piece's share the sum of
    /// its entries' shares, and a piece given exactly one entry has that entry's face count.
    public static func canPartition(_ pieces: [FacetedForgePiece], into target: [FacetedForgeTargetPiece],
                                    crystal: FacetedForgeFraction) -> Bool {
        guard pieces.count <= target.count else { return false }
        var remaining: [FacetedForgeFraction] = []
        for piece in pieces {
            guard let s = share(piece, crystal: crystal) else { return false }
            remaining.append(s)
        }
        let faces: [Int] = pieces.map(\.faceCount)
        let entries: [FacetedForgeTargetPiece] = target.sorted()
        var given: [[Int]] = Array(repeating: [], count: pieces.count)
        return assign(0, entries, &remaining, &given, faces)
    }

    /// Backtracking assignment of `entries[index...]` to pieces with share left (see ``canPartition(_:into:crystal:)``).
    private static func assign(_ index: Int, _ entries: [FacetedForgeTargetPiece], _ remaining: inout [FacetedForgeFraction],
                               _ given: inout [[Int]], _ faces: [Int]) -> Bool {
        if index == entries.count {
            for p in remaining.indices {
                guard remaining[p] == .zero, !given[p].isEmpty else { return false }
                if given[p].count == 1 && entries[given[p][0]].faces != faces[p] { return false }
            }
            return true
        }
        let entry: FacetedForgeTargetPiece = entries[index]
        var tried: Set<String> = []
        for p in remaining.indices where !(remaining[p] < entry.share) {
            // Pieces in the same situation (share left, faces, entries so far) are interchangeable: try one.
            let key: String = "\(remaining[p].text)|\(faces[p])|\(given[p].count)"
            guard tried.insert(key).inserted else { continue }
            guard let left = try? remaining[p].subtracting(entry.share) else { continue }
            let before: FacetedForgeFraction = remaining[p]
            remaining[p] = left
            given[p].append(index)
            if assign(index + 1, entries, &remaining, &given, faces) { return true }
            given[p].removeLast()
            remaining[p] = before
        }
        return false
    }

    /// Whether the pieces' (share, face count) multiset equals the target.
    static func matches(_ pieces: [FacetedForgePiece], _ target: [FacetedForgeTargetPiece],
                        crystal: FacetedForgeFraction) -> Bool {
        guard pieces.count == target.count else { return false }
        var have: [FacetedForgeTargetPiece] = []
        for piece in pieces {
            guard let s = share(piece, crystal: crystal) else { return false }
            have.append(FacetedForgeTargetPiece(share: s, faces: piece.faceCount))
        }
        return have.sorted() == target.sorted()
    }

    /// The integer depths whose plane of `direction` passes strictly through `piece`, ascending.
    static func crossingDepths(_ piece: FacetedForgePiece, direction: Int) -> [Int] {
        let d: FacetedForgeDirection = FacetedForgeDirection.all[direction]
        var low: FacetedForgeFraction?
        var high: FacetedForgeFraction?
        for p in piece.corners {
            guard let x = try? p.x.multiplying(FacetedForgeFraction(Int64(d.x))),
                  let y = try? p.y.multiplying(FacetedForgeFraction(Int64(d.y))),
                  let z = try? p.z.multiplying(FacetedForgeFraction(Int64(d.z))),
                  let v = try? x.adding(y).adding(z) else { return [] }
            if low.map({ v < $0 }) ?? true { low = v }
            if high.map({ $0 < v }) ?? true { high = v }
        }
        guard let low, let high else { return [] }
        var depths: [Int] = []
        for depth in FacetedForgeHalfSpace.depths {
            guard let value = try? FacetedForgeFraction(Int64(depth)), low < value, value < high else { continue }
            depths.append(depth)
        }
        return depths
    }

    /// A winning sequence of exactly ``lowerBound(_:)`` cuts found from the crystal alone, or nil when none is found
    /// within `workBound` cut evaluations: ``solve(_:from:cutsLeft:workBound:)`` from `[level.crystal]`.
    public static func solve(_ level: FacetedForgeLevel, workBound: Int = workBound) -> FacetedForgeSolution? {
        let cuts: Int = lowerBound(level)
        guard cuts <= level.budget else { return nil }
        return solve(level, from: [level.crystal], cutsLeft: cuts, workBound: workBound)
    }

    /// A winning continuation of exactly `cutsLeft` more cuts from `pieces` (in canonical order), found by the same
    /// bounded depth-first search as ``solve(_:workBound:)`` (same order, same pruning, same sliver rule; feature 375
    /// (R02-G08-05) T-R02G0805-002, clarification Q1), or nil when `cutsLeft` is below 1 or none is found within
    /// `workBound` cut evaluations. The solution's `smallest` is `cutsLeft`; its piece indices are canonical indices at
    /// the time of each cut, starting from `pieces`.
    public static func solve(_ level: FacetedForgeLevel, from pieces: [FacetedForgePiece], cutsLeft: Int,
                             workBound: Int = workBound) -> FacetedForgeSolution? {
        guard cutsLeft >= 1 else { return nil }
        let crystal: FacetedForgeFraction = level.crystal.volume
        var work: Int = 0
        var actions: [FacetedForgeAction] = []
        let found: Bool = search(pieces, cutsLeft: cutsLeft, level: level, crystal: crystal, bound: workBound,
                                 work: &work, actions: &actions)
        guard found else { return nil }
        return FacetedForgeSolution(smallest: cutsLeft, actions: actions, work: work)
    }

    /// The depth-first search: one more cut of some piece, in the rules' order, pruned as in the file header.
    private static func search(_ pieces: [FacetedForgePiece], cutsLeft: Int, level: FacetedForgeLevel,
                               crystal: FacetedForgeFraction, bound: Int, work: inout Int,
                               actions: inout [FacetedForgeAction]) -> Bool {
        if cutsLeft == 0 { return matches(pieces, level.target, crystal: crystal) }
        for index in pieces.indices {
            for direction in FacetedForgeDirection.all.indices {
                for depth in crossingDepths(pieces[index], direction: direction) {
                    guard work < bound else { return false }
                    work += 1
                    guard let halves = try? pieces[index].cut(direction: direction, depth: depth),
                          let below = share(halves.below, crystal: crystal),
                          let above = share(halves.above, crystal: crystal),
                          !(below < level.sliver), !(above < level.sliver) else { continue }
                    var rest: [FacetedForgePiece] = pieces
                    rest.remove(at: index)
                    let next: [FacetedForgePiece] = FacetedForgePiece.canonical(rest + [halves.below, halves.above])
                    guard canPartition(next, into: level.target, crystal: crystal) else { continue }
                    actions.append(.cut(index, direction, depth))
                    if search(next, cutsLeft: cutsLeft - 1, level: level, crystal: crystal, bound: bound,
                              work: &work, actions: &actions) {
                        return true
                    }
                    actions.removeLast()
                    if work >= bound { return false }
                }
            }
        }
        return false
    }
}
