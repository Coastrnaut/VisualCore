// HueCompassHints — feature 335 (R02-G04-05) T-R02G0405-002 (FR-R02G0405-002, 003; clarifications Q1, Q5; research
// R1, R2). Progressive hints computed only from the clues the player has seen — the consistent set is every candidate
// target whose clues at the probed bearings equal the clues seen, derived from the wheel and the fog, never from the
// hidden target — and the plain-English explanation of a failure. Hints never change a play, are unlimited and do not
// affect stars; the hint level is presentation (held by the presenter, reset to 1 after any change of the play).
// Rules (clarification Q1): when one selection accepts the whole consistent set (``HueCompassSolver/selection(for:in:)``)
// the hint is that selection; otherwise, with at least two units left, a probe at the first bearing (from 0) after which
// every class of the consistent set is acceptable, else at the bearing whose largest class is smallest (lowest on a
// tie); with one unit left, the best guess: the selection accepting the most members (lowest bearing, then band, on a
// tie). Directions are named by octant, the eighth of the compass with north = bearing 24 (bearing 0 is east and
// bearings grow counter-clockwise): octant k (0 … 7, "east", "north-east", "north", "north-west", "west", "south-west",
// "south", "south-east") is the 12 bearings 12k − 6 … 12k + 5 (mod 96), so each octant is centred on bearing 12k and
// a half-way bearing 12k + 6 belongs to the next octant counter-clockwise.

/// What a hint suggests (clarification Q1).
public enum HueCompassHintKind: String, Sendable, Codable {
    /// Turn to a bearing and probe there.
    case probe
    /// Select a bearing and band that accept every target still consistent with the clues.
    case select
    /// With one unit left, select the bearing and band that accept the most consistent targets.
    case guess
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct HueCompassHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names what to do, 2 adds where (the octant), 3 is exact.
    public let level: Int
    /// What the hint suggests.
    public let kind: HueCompassHintKind
    /// The bearing to probe at (`probe`) or to select (`select`, `guess`), 0 … 95.
    public let bearing: Int
    /// The band to select (`select`, `guess`), 0 … 23; nil for a probe.
    public let band: Int?
    /// The number of candidate targets consistent with every clue seen.
    public let consistent: Int

    /// A hint of the given values (not checked).
    public init(level: Int, kind: HueCompassHintKind, bearing: Int, band: Int?, consistent: Int) {
        self.level = level
        self.kind = kind
        self.bearing = bearing
        self.band = band
        self.consistent = consistent
    }

    /// The octant names, counter-clockwise from east (octant 0).
    public static let octantNames: [String] = ["east", "north-east", "north", "north-west", "west", "south-west",
                                               "south", "south-east"]

    /// The octant of `bearing` (taken modulo 96), 0 … 7: ⌊(bearing + 6) / 12⌋ mod 8, so octant k is the bearings
    /// 12k − 6 … 12k + 5 and north (octant 2) is centred on bearing 24.
    public static func octant(of bearing: Int) -> Int {
        (HueCompassWheel.mod(bearing, HueCompassWheel.bearings) + 6) / 12 % 8
    }

    /// The player-facing octant name of `bearing`, such as "north" for bearings 18 … 29.
    public static func octantName(of bearing: Int) -> String { octantNames[octant(of: bearing)] }

    /// The hint in plain English (clarification Q1), with b, h the bearing and band and o the bearing's octant name:
    /// - select: "Every clue now points to one place: select", "Select near o", "Select bearing b with band h"
    /// - probe: "Probe once more", "Probe toward o", "Turn to bearing b and probe"
    /// - guess: "Best guess: select", "Best guess: select near o", "Best guess: select bearing b with band h"
    public var text: String {
        let octant: String = Self.octantName(of: bearing)
        let selected: String = "bearing \(bearing) with band \(band ?? 0)"
        switch (kind, level) {
        case (.select, 1): return "Every clue now points to one place: select"
        case (.select, 2): return "Select near " + octant
        case (.select, _): return "Select " + selected
        case (.probe, 1): return "Probe once more"
        case (.probe, 2): return "Probe toward " + octant
        case (.probe, _): return "Turn to bearing \(bearing) and probe"
        case (.guess, 1): return "Best guess: select"
        case (.guess, 2): return "Best guess: select near " + octant
        case (.guess, _): return "Best guess: select " + selected
        }
    }
}

/// The hint engine of Hue Compass (clarification Q1; research R1, R2).
public enum HueCompassHints {
    /// The candidate targets (``HueCompassSolver/candidates(_:)``) consistent with every clue of `play`, ascending: a
    /// candidate t stays when, for each clue seen, the hue gap between the probed bearing's band and t's band and the
    /// fog depth of the shorter arc from the probed bearing to t (counter-clockwise on a tie) equal the clue's — what
    /// `level.clue(at:)` gives when t is the target. The hidden target is never read, and is always a member.
    public static func consistent(_ play: HueCompassPlay) -> [Int] {
        let level: HueCompassLevel = play.level
        var result: [Int] = []
        for t in HueCompassSolver.candidates(level) {
            var matches: Bool = true
            for clue in play.clues {
                let gap: Int = HueCompassWheel.bandDistance(level.band(of: clue.bearing), level.band(of: t))
                guard gap == clue.hueGap else {
                    matches = false
                    break
                }
                var depth: Int = 0
                for inside in HueCompassWheel.arc(from: clue.bearing, to: t) { depth += level.fog[inside] }
                guard depth == clue.depth else {
                    matches = false
                    break
                }
            }
            if matches { result.append(t) }
        }
        return result
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`, or nil unless the play is in stage `playing` (no hint while
    /// loading, in the tutorial, paused, won, failed or showing the result).
    ///
    /// With C = ``consistent(_:)``: when ``HueCompassSolver/selection(for:in:)`` accepts all of C the hint is that
    /// selection (`select`); otherwise, with at least two units left, a probe (`probe`) at the first bearing 0 … 95 after
    /// which every class of C (C split by the clue at that bearing) has a selection, else at the bearing whose largest
    /// class is smallest (lowest on a tie); with one unit left the selection accepting the most members of C (`guess`,
    /// lowest bearing, then band, on a tie). A probe hint is never given with one unit left, so it never spends the last
    /// unit. The same action is returned at every level.
    public static func hint(level: Int, play: HueCompassPlay) -> HueCompassHint? {
        guard play.stage == .playing else { return nil }
        let clamped: Int = min(3, max(1, level))
        let lvl: HueCompassLevel = play.level
        let members: [Int] = consistent(play)
        if let selection = HueCompassSolver.selection(for: members, in: lvl) {
            return HueCompassHint(level: clamped, kind: .select, bearing: selection.bearing, band: selection.band,
                                  consistent: members.count)
        }
        if play.remaining >= 2 {
            return HueCompassHint(level: clamped, kind: .probe, bearing: probeBearing(members, in: lvl), band: nil,
                                  consistent: members.count)
        }
        let guess: HueCompassSelection = bestGuess(members, in: lvl)
        return HueCompassHint(level: clamped, kind: .guess, bearing: guess.bearing, band: guess.band,
                              consistent: members.count)
    }

    /// The probe bearing for the consistent set `members` of `level`: the first bearing after which every class has a
    /// selection, else the bearing whose largest class is smallest (lowest on a tie).
    static func probeBearing(_ members: [Int], in level: HueCompassLevel) -> Int {
        let table: [[Int]] = HueCompassSolver.clueTable(level)
        let masks: HueCompassSolver.Masks = HueCompassSolver.Masks(level)
        var best: Int = 0
        var bestLargest: Int = Int.max
        for p in 0..<HueCompassWheel.bearings {
            let groups: [[Int]] = HueCompassSolver.refine([members], by: table[p])
            if masks.settles(groups) { return p }
            var largest: Int = 0
            for g in groups where g.count > largest { largest = g.count }
            if largest < bestLargest {
                bestLargest = largest
                best = p
            }
        }
        return best
    }

    /// The selection accepting the most members of `members` in `level`, lowest bearing then band on a tie. A bearing
    /// and band accept a member when both are within the level's tolerances of it.
    static func bestGuess(_ members: [Int], in level: HueCompassLevel) -> HueCompassSelection {
        var best: HueCompassSelection = HueCompassSelection(bearing: 0, band: 0)
        var bestCount: Int = -1
        for b in 0..<HueCompassWheel.bearings {
            var near: [Int] = []
            for t in members where HueCompassWheel.bearingDistance(b, t) <= level.bearingTolerance { near.append(t) }
            if near.count <= bestCount { continue }
            for band in 0..<HueCompassWheel.bands {
                var count: Int = 0
                for t in near where HueCompassWheel.bandDistance(band, level.band(of: t)) <= level.bandTolerance {
                    count += 1
                }
                if count > bestCount {
                    bestCount = count
                    best = HueCompassSelection(bearing: b, band: band)
                }
            }
        }
        return best
    }
}

/// The plain-English explanation of a failed play (FR-R02G0405-003; clarification Q5).
public struct HueCompassFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: HueCompassFailure
    /// The target bearing, 0 … 95.
    public let target: Int
    /// The target's band, 0 … 23.
    public let targetBand: Int
    /// The circular bearing distance from the selection to the target (0 … 48); nil for a `probes` failure.
    public let bearingDistance: Int?
    /// The circular band distance from the selected band to the target's (0 … 12); nil for a `probes` failure.
    public let bandDistance: Int?
    /// The level's bearing tolerance.
    public let bearingTolerance: Int
    /// The level's band tolerance.
    public let bandTolerance: Int

    /// The explanation of `play`'s failure, or nil unless the play is `failed`, or `result` after a failure.
    public init?(play: HueCompassPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: HueCompassLevel = play.level
        self.failure = failure
        target = level.target
        targetBand = level.targetBand
        bearingTolerance = level.bearingTolerance
        bandTolerance = level.bandTolerance
        if failure == .selection, let selection = play.selection {
            bearingDistance = HueCompassWheel.bearingDistance(selection.bearing, level.target)
            bandDistance = HueCompassWheel.bandDistance(selection.band, level.targetBand)
        } else {
            bearingDistance = nil
            bandDistance = nil
        }
    }

    /// The explanation (clarification Q5), each followed by " Retry the level." (probes and selections cannot be
    /// undone):
    /// - selection: "The target was bearing T (band B). Your selection was d bearings and e bands away; the tolerances
    ///   are t and u."
    /// - probes: "The last unit went to a probe; keep one for the selection."
    public var text: String {
        let retry: String = " Retry the level."
        switch failure {
        case .probes:
            return "The last unit went to a probe; keep one for the selection." + retry
        case .selection:
            return "The target was bearing \(target) (band \(targetBand)). Your selection was \(bearingDistance ?? 0) "
                + "bearings and \(bandDistance ?? 0) bands away; the tolerances are \(bearingTolerance) and "
                + "\(bandTolerance)." + retry
        }
    }
}
