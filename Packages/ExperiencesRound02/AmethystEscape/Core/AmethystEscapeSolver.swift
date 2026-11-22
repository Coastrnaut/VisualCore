// AmethystEscapeSolver — feature 362 (R02-G07-02) T-R02G0702-003 (FR-R02G0702-002; clarification Q2). The breadth-first
// search over crystal states (every shell offset and the pearl's pocket) that proves a level's smallest move count. A
// state packs the offsets and the pearl into one integer (offsets in base N, innermost first, then the pearl's shell and
// absolute sector), so the search keeps its depths in an array of N^K × K × N entries. From the opening state it expands
// moves in the rules' fixed order — rotate(r, +1), rotate(r, −1) for each shell r in order, then advance unless it is
// stuck — never continuing from a blocked wedge; the first escape found is at the smallest depth m, and its path is the
// witness. Every state reachable in fewer than m moves was expanded and none escapes: that is the proof, recorded as the
// number of states first reached at each depth 0 … m − 1. Work counts the states expanded. Integers only; no clock, no
// random source.

/// The certified result of the search.
public struct AmethystEscapeSolution: Sendable, Equatable, Hashable, Codable {
    /// The smallest move count m (the witness's length).
    public let smallest: Int
    /// A shortest action sequence; its last action is the advance through the exit gap.
    public let actions: [AmethystEscapeAction]
    /// The states first reached at each depth 0 … m − 1 (the proof that no shorter sequence escapes).
    public let depths: [Int]
    /// The states expanded.
    public let work: Int

    /// A solution of the given values (not checked).
    public init(smallest: Int, actions: [AmethystEscapeAction], depths: [Int], work: Int) {
        self.smallest = smallest
        self.actions = actions
        self.depths = depths
        self.work = work
    }
}

/// The breadth-first search of an Amethyst Escape level.
public enum AmethystEscapeSolver {
    /// The number of crystal states of `level`: N^K × K × N.
    public static func stateCount(_ level: AmethystEscapeLevel) -> Int {
        var count = 1
        for _ in level.shells { count *= level.sectors }
        return count * level.shells.count * level.sectors
    }

    /// The packed integer of `crystal` (offsets in base N innermost first, then the pearl's shell, then its sector).
    public static func encode(_ crystal: AmethystEscapeCrystal, level: AmethystEscapeLevel) -> Int {
        let n: Int = level.sectors
        var value = 0
        for offset in crystal.offsets.reversed() { value = value * n + offset }
        return (value * level.shells.count + crystal.pearl.shell) * n + crystal.pearl.sector
    }

    /// The crystal of the packed integer `state`.
    public static func decode(_ state: Int, level: AmethystEscapeLevel) -> AmethystEscapeCrystal {
        let n: Int = level.sectors
        let k: Int = level.shells.count
        var rest: Int = state
        let sector: Int = rest % n
        rest /= n
        let shell: Int = rest % k
        rest /= k
        var offsets: [Int] = []
        for _ in 0..<k {
            offsets.append(rest % n)
            rest /= n
        }
        return AmethystEscapeCrystal(offsets: offsets, pearl: AmethystEscapePocket(shell: shell, sector: sector))
    }

    /// The moves expanded from any state, in the rules' order (the advance last).
    static func moveOrder(_ level: AmethystEscapeLevel) -> [AmethystEscapeAction] {
        var moves: [AmethystEscapeAction] = []
        for shell in level.shells.indices {
            moves.append(.rotate(shell, 1))
            moves.append(.rotate(shell, -1))
        }
        moves.append(.advance)
        return moves
    }

    /// Whether the pearl escapes when only advanced from the opening crystal (no shell turned): advances until it exits,
    /// is stuck, falls into a wedge or returns to a pocket it has stood in.
    public static func escapesByAdvancing(_ level: AmethystEscapeLevel) -> Bool {
        var crystal = AmethystEscapeCrystal(level: level)
        var seen: Set<AmethystEscapePocket> = [crystal.pearl]
        while true {
            switch crystal.transition(level: level) {
            case .exited: return true
            case .stuck, .wedge: return false
            case let .moved(pocket):
                if seen.contains(pocket) { return false }
                seen.insert(pocket)
                crystal = crystal.placing(pearl: pocket)
            }
        }
    }

    /// The certified shortest escape of `level`, or nil when no sequence of at most `maxDepth` moves escapes (with the
    /// default, when no sequence escapes at all). The generator passes its band's longest allowed route, so a candidate
    /// whose shortest route is longer is refused without searching the rest of its states. The search works on the packed
    /// integers directly (shell lists as bit masks), applying the same rules as `AmethystEscapeCrystal`.
    public static func solve(_ level: AmethystEscapeLevel, maxDepth: Int = Int.max) -> AmethystEscapeSolution? {
        let n: Int = level.sectors
        let k: Int = level.shells.count
        let count: Int = stateCount(level)
        var power: [Int] = [1]
        for _ in 1..<k { power.append(power[power.count - 1] * n) }
        var openMask: [Int] = []
        var wallMask: [Int] = []
        var blockedMask: [Int] = []
        for shell in level.shells {
            var open = 0
            var wall = 0
            var blocked = 0
            for sector in shell.apertures { open |= 1 << sector }
            for sector in shell.walls { wall |= 1 << sector }
            for sector in shell.blocked { blocked |= 1 << sector }
            openMask.append(open)
            wallMask.append(wall)
            blockedMask.append(blocked)
        }
        let start: Int = encode(AmethystEscapeCrystal(level: level), level: level)
        var seen: [Bool] = Array(repeating: false, count: count)
        var parent: [Int32] = Array(repeating: -1, count: count)
        var via: [UInt8] = Array(repeating: 0, count: count)
        let moves: [AmethystEscapeAction] = moveOrder(level)
        let advanceIndex: Int = moves.count - 1
        seen[start] = true
        var frontier: [Int] = [start]
        var depths: [Int] = []
        var work = 0
        var depth = 0
        while !frontier.isEmpty && depth < maxDepth {
            depths.append(frontier.count)
            var next: [Int] = []
            for state in frontier {
                work += 1
                let sector: Int = state % n
                let shell: Int = (state / n) % k
                let offsets: Int = state / (n * k)
                // Rotations, in the rules' order.
                for r in 0..<k {
                    let offset: Int = (offsets / power[r]) % n
                    for (stepIndex, step) in [1, -1].enumerated() {
                        let turned: Int = (offset + step + n) % n
                        let newOffsets: Int = offsets + (turned - offset) * power[r]
                        let newSector: Int = shell == r ? (sector + step + n) % n : sector
                        let code: Int = (newOffsets * k + shell) * n + newSector
                        if !seen[code] {
                            seen[code] = true
                            parent[code] = Int32(state)
                            via[code] = UInt8(2 * r + stepIndex)
                            next.append(code)
                        }
                    }
                }
                // The advance (clarification Q2 of feature 361).
                let own: Int = (sector - (offsets / power[shell]) % n + n) % n
                var destShell: Int
                var destSector: Int
                if openMask[shell] & (1 << own) != 0 {
                    if shell == k - 1 {
                        return solution(level: level, from: state, depths: depths, work: work, parent: parent, via: via,
                                        moves: moves, final: .advance)
                    }
                    destShell = shell + 1
                    destSector = sector
                } else if wallMask[shell] & (1 << own) == 0 {
                    destShell = shell
                    destSector = (sector + 1) % n
                } else {
                    continue
                }
                let destOwn: Int = (destSector - (offsets / power[destShell]) % n + n) % n
                if blockedMask[destShell] & (1 << destOwn) != 0 { continue }
                let code: Int = (offsets * k + destShell) * n + destSector
                if !seen[code] {
                    seen[code] = true
                    parent[code] = Int32(state)
                    via[code] = UInt8(advanceIndex)
                    next.append(code)
                }
            }
            frontier = next
            depth += 1
        }
        return nil
    }

    /// The solution whose path leads from the opening state to `state`, then `final`.
    static func solution(level: AmethystEscapeLevel, from state: Int, depths: [Int], work: Int, parent: [Int32],
                         via: [UInt8], moves: [AmethystEscapeAction], final: AmethystEscapeAction) -> AmethystEscapeSolution {
        var path: [AmethystEscapeAction] = [final]
        var current: Int = state
        while parent[current] >= 0 {
            path.append(moves[Int(via[current])])
            current = Int(parent[current])
        }
        let actions: [AmethystEscapeAction] = path.reversed()
        return AmethystEscapeSolution(smallest: actions.count, actions: actions, depths: depths, work: work)
    }
}
