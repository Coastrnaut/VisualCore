// HarmonicBridgesSceneSnapshot — feature 413 (R02-G12-03) T-R02G1203-002 (FR-R02G1203-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the islands with their drawing
// positions, the strings with their ends, lengths, current pegs and locks, the kernel's exact report (the swing of every
// string at every sample and step, the bridges and the start's reachable islands per step), the resonant modes and
// their tone strengths per step and string (for the presentation-only wave), the threshold, the start and the goal, the
// stage, the failure, the actions left and the budget, the level number and the presentation time; plus the palette and
// the three quality tiers. The renderer never holds the kernel, so no drawing result can change the game (renderer
// purity), and the drawn wave never replaces the kernel's exact swing.
import Foundation

/// The scene's colours, linear 0 … 1 (clarification Q3): warm copper, cyan membranes and mist violet over a dark mist.
public enum HarmonicBridgesPalette {
    /// The mist ground #07060C.
    public static let ground = rgb(0x07, 0x06, 0x0C)
    /// An island prism's faces #7A4A2E.
    public static let islandFace = rgb(0x7A, 0x4A, 0x2E)
    /// An island prism's top edges #E0A070.
    public static let islandEdge = rgb(0xE0, 0xA0, 0x70)
    /// A string #C88A5A.
    public static let string = rgb(0xC8, 0x8A, 0x5A)
    /// A bridge membrane #4FD8E8.
    public static let membrane = rgb(0x4F, 0xD8, 0xE8)
    /// A sample mark whose swing reaches the threshold #B8F4FF.
    public static let markFilled = rgb(0xB8, 0xF4, 0xFF)
    /// A sample mark whose swing is short of the threshold #7A6A9C.
    public static let markHollow = rgb(0x7A, 0x6A, 0x9C)
    /// The start island's ring #F2D2A8.
    public static let start = rgb(0xF2, 0xD2, 0xA8)
    /// The goal island's star #A894FF.
    public static let goal = rgb(0xA8, 0x94, 0xFF)
    /// The glow of reached islands #8FF4FF.
    public static let glow = rgb(0x8F, 0xF4, 0xFF)
    /// A radial wave shell #6FE0F0.
    public static let shell = rgb(0x6F, 0xE0, 0xF0)
    /// The shown step's pip #4FD8E8.
    public static let pip = rgb(0x4F, 0xD8, 0xE8)
    /// Another step's pip #3A3348.
    public static let pipUnlit = rgb(0x3A, 0x33, 0x48)
    /// A lit moves-gauge bar #E0A070.
    public static let gaugeLit = rgb(0xE0, 0xA0, 0x70)
    /// An unlit moves-gauge bar #2A2433.
    public static let gaugeUnlit = rgb(0x2A, 0x24, 0x33)
    /// The outline of a broken string and the cross on a broken step's pip #FF6B4A.
    public static let brokenOutline = rgb(0xFF, 0x6B, 0x4A)

    /// The palette's key colours as hex text, for the registration: ground, island edge, membrane, mist violet, goal.
    public static let hex: [String] = ["#07060C", "#E0A070", "#4FD8E8", "#7A6A9C", "#A894FF"]

    /// An 8-bit sRGB triple as linear 0 … 1 components (the shaders treat the values as given).
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One of the three quality tiers (clarification Q2), richest first; tiers change only string motion, wave shells and
/// glow, never islands, strings, membranes, marks, pips, the gauge, colours or positions.
public struct HarmonicBridgesTier: Sendable, Equatable, Hashable {
    /// 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// Whether resonating strings swing (otherwise they are drawn at rest, straight).
    public let motion: Bool
    /// Radial wave shells per resonating string (2, 0, 0).
    public let waveShells: Int
    /// Glow shells around membranes and reached islands (2, 1, 0).
    public let glowShells: Int

    /// The three tiers, richest first.
    public static let all: [HarmonicBridgesTier] = [
        HarmonicBridgesTier(index: 0, motion: true, waveShells: 2, glowShells: 2),
        HarmonicBridgesTier(index: 1, motion: true, waveShells: 0, glowShells: 1),
        HarmonicBridgesTier(index: 2, motion: false, waveShells: 0, glowShells: 0),
    ]

    /// The tier's name, `level-0` … `level-2`.
    public var name: String { "level-\(index)" }

    /// The tier `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> HarmonicBridgesTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of the kernel's state for drawing (clarification Q4).
public struct HarmonicBridgesSceneSnapshot: Sendable, Equatable {
    /// Seconds each window step is shown while playing (clarification Q1).
    public static let stepSeconds: Double = 1.2
    /// The islands with their drawing positions on the 16 × 10 grid.
    public let islands: [HarmonicBridgesIsland]
    /// The strings with their ends, lengths, starting pegs and locks.
    public let strings: [HarmonicBridgesString]
    /// The current peg of every string.
    public let pegs: [Int]
    /// The kernel's exact report at the current pegs.
    public let report: HarmonicBridgesReport
    /// The resonant modes per step and string, in tone order (presentation wave only).
    public let modes: [[[Int]]]
    /// The strengths of those modes' tones, parallel to `modes`.
    public let strengths: [[[Int]]]
    /// The solidity threshold, in quarters.
    public let threshold: Int
    /// The start island.
    public let start: Int
    /// The goal island.
    public let goal: Int
    /// The play's stage.
    public let stage: HarmonicBridgesStage
    /// The play's failure, if any.
    public let failure: HarmonicBridgesFailure?
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (finite, never negative); it never decides a rule.
    public let time: Double

    /// A snapshot of `play` at presentation time `time` (a non-finite or negative time becomes 0).
    public init(play: HarmonicBridgesPlay, levelNumber: Int, time: Double) {
        let level: HarmonicBridgesLevel = play.level
        islands = level.islands
        strings = level.strings
        pegs = play.pegs
        report = play.report
        var allModes: [[[Int]]] = []
        var allStrengths: [[[Int]]] = []
        for tones in level.steps {
            var stepModes: [[Int]] = []
            var stepStrengths: [[Int]] = []
            for (index, string) in level.strings.enumerated() {
                let peg: Int = index < play.pegs.count ? play.pegs[index] : string.peg
                var found: [Int] = []
                var weights: [Int] = []
                for tone in tones {
                    if let mode = string.mode(of: tone, peg: peg) {
                        found.append(mode)
                        weights.append(tone.strength)
                    }
                }
                stepModes.append(found)
                stepStrengths.append(weights)
            }
            allModes.append(stepModes)
            allStrengths.append(stepStrengths)
        }
        modes = allModes
        strengths = allStrengths
        threshold = level.threshold
        start = level.start
        goal = level.goal
        stage = play.stage
        failure = play.failure
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// The window's step count.
    public var steps: Int { report.bridges.count }

    /// The step drawn now: it cycles every ``stepSeconds`` while playing or after a win (step 0 at time 0); after a
    /// broken test it holds the broken step.
    public var shownStep: Int {
        guard steps > 0 else { return 0 }
        if case let .broken(step, _)? = failure { return min(max(step, 0), steps - 1) }
        return Int(time / Self.stepSeconds) % steps
    }

    /// The step drawn under Reduce Motion: step 0, or the broken step after a broken test.
    public var restingStep: Int {
        if case let .broken(step, _)? = failure, steps > 0 { return min(max(step, 0), steps - 1) }
        return 0
    }

    /// Whether string `index` is a bridge in `step`.
    public func isBridge(_ index: Int, step: Int) -> Bool {
        guard step >= 0, step < report.bridges.count, index >= 0, index < report.bridges[step].count else { return false }
        return report.bridges[step][index]
    }

    /// Whether the start reaches island `index` in `step`.
    public func isReached(_ index: Int, step: Int) -> Bool {
        guard step >= 0, step < report.reached.count, index >= 0, index < report.reached[step].count else { return false }
        return report.reached[step][index]
    }

    /// The broken string named by a broken test, if any.
    public var brokenString: Int? {
        if case let .broken(_, string)? = failure { return string }
        return nil
    }

    /// The failure in words, numbered as the kernel's words number steps and strings (from 0) and actions (from 1); nil
    /// without a failure.
    public static func failureText(_ failure: HarmonicBridgesFailure?) -> String? {
        switch failure {
        case let .broken(step, string?)?: return "The crossing broke in step \(step) at string \(string)."
        case let .broken(step, nil)?: return "The crossing broke in step \(step): no string reaches across."
        case let .budget(action)?: return "The moves ran out on action \(action + 1)."
        case nil: return nil
        }
    }
}
