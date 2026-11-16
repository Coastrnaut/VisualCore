// AutomatonRule — feature 117 (A16-P01) T-A16-103 (FR-A16-101; SC-A16-101; clarification Q1). The CPU reference of
// the cellular automaton: two states on a square grid, the eight-cell (Moore) neighbourhood and an outer-totalistic
// birth/survival rule written B…/S… (for example B3/S23), with a wrap boundary (opposite edges are neighbours).
// A dead cell with a neighbour count in `birth` becomes alive; a live cell with a count in `survival` stays alive;
// every other cell is dead. A cell is alive when its channel-0 value is at least 0.5; the result is written as exact
// 0 and 1, which `unorm8` storage holds without rounding. Presets: Life B3/S23, HighLife B36/S23 and Seeds B2/S.
import VisualCoreSimulation

/// An outer-totalistic two-state rule on the Moore neighbourhood with a wrap boundary.
public struct AutomatonRule: Equatable, Sendable {
    /// Neighbour counts (0…8) that make a dead cell alive.
    public let birth: Set<Int>
    /// Neighbour counts (0…8) that keep a live cell alive.
    public let survival: Set<Int>

    /// Conway's Life, B3/S23.
    public static let life = AutomatonRule(birth: [3], survival: [2, 3])
    /// HighLife, B36/S23.
    public static let highLife = AutomatonRule(birth: [3, 6], survival: [2, 3])
    /// Seeds, B2/S (no cell survives).
    public static let seeds = AutomatonRule(birth: [2], survival: [])
    /// The presets by index: 0 Life, 1 HighLife, 2 Seeds.
    public static let presets: [AutomatonRule] = [life, highLife, seeds]

    /// A rule from neighbour-count sets (counts outside 0…8 are dropped).
    public init(birth: Set<Int>, survival: Set<Int>) {
        self.birth = birth.filter { (0...8).contains($0) }
        self.survival = survival.filter { (0...8).contains($0) }
    }

    /// Parses B/S notation such as "B3/S23" or "b2/s" (letters in either case, digits 0…8 in any order); nil for
    /// anything else (a missing part or letter, a digit 9, a repeated digit, other characters).
    public init?(notation: String) {
        let parts = notation.uppercased().split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].first == "B", parts[1].first == "S",
              let birth = Self.counts(parts[0].dropFirst()), let survival = Self.counts(parts[1].dropFirst()) else {
            return nil
        }
        self.init(birth: birth, survival: survival)
    }

    /// The rule in B/S notation with ascending digits, for example "B36/S23".
    public var notation: String {
        "B" + birth.sorted().map(String.init).joined() + "/S" + survival.sorted().map(String.init).joined()
    }

    /// The neighbour counts in `digits`, or nil for a non-digit, a digit above 8 or a repeated digit.
    private static func counts(_ digits: Substring) -> Set<Int>? {
        var result = Set<Int>()
        for ch in digits {
            guard let d = ch.wholeNumberValue, ch.isASCII, (0...8).contains(d), result.insert(d).inserted else {
                return nil
            }
        }
        return result
    }

    /// One generation of `grid` (channel 0; other channels are copied unchanged) with a wrap boundary.
    public func step(_ grid: FieldGrid) -> FieldGrid {
        let w = grid.width, h = grid.height
        var out = grid
        for y in 0..<h {
            let down = (y + h - 1) % h, up = (y + 1) % h
            for x in 0..<w {
                let left = (x + w - 1) % w, right = (x + 1) % w
                var n = 0
                if grid[left, down, 0] >= 0.5 { n += 1 }
                if grid[x, down, 0] >= 0.5 { n += 1 }
                if grid[right, down, 0] >= 0.5 { n += 1 }
                if grid[left, y, 0] >= 0.5 { n += 1 }
                if grid[right, y, 0] >= 0.5 { n += 1 }
                if grid[left, up, 0] >= 0.5 { n += 1 }
                if grid[x, up, 0] >= 0.5 { n += 1 }
                if grid[right, up, 0] >= 0.5 { n += 1 }
                let alive = grid[x, y, 0] >= 0.5
                out[x, y, 0] = (alive ? survival.contains(n) : birth.contains(n)) ? 1 : 0
            }
        }
        return out
    }

    /// The number of live cells (channel 0 at least 0.5) of `grid`.
    public static func liveCount(_ grid: FieldGrid) -> Int {
        var n = 0
        for cell in 0..<(grid.width * grid.height) where grid.values[cell * grid.channels] >= 0.5 { n += 1 }
        return n
    }
}
