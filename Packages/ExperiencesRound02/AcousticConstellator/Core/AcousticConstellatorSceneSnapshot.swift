// AcousticConstellatorSceneSnapshot — feature 423 (R02-G13-03) T-R02G1303-002 (FR-R02G1303-002, 003, 004;
// clarifications Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the stars with their
// grid positions, natural rates and the play's starting phases, the links, the symbol, the kernel's listen report of
// the current state (phases, snapped links and order parameter per tick, coherence, outcome), the threshold, hold and
// window, the stage, the failure, the actions left and the budget, the level number and the presentation time; plus the
// palette and the three quality tiers. The renderer never holds the kernel, so no drawing result can change the game
// (renderer purity), and the drawn pulse never replaces the kernel's phases.
import Foundation

/// The scene's colours, linear 0 … 1 (clarification Q3): star white, teal resonance and plum over a dark sky.
public enum AcousticConstellatorPalette {
    /// The night sky #05060F.
    public static let sky = rgb(0x05, 0x06, 0x0F)
    /// A star #F4F1E8.
    public static let star = rgb(0xF4, 0xF1, 0xE8)
    /// A star's phase hand #F4F1E8.
    public static let hand = rgb(0xF4, 0xF1, 0xE8)
    /// A link whose gap at the shown tick is above 1 #B8C0D0.
    public static let silver = rgb(0xB8, 0xC0, 0xD0)
    /// A link whose gap at the shown tick is at most 1 #3FD6C6.
    public static let teal = rgb(0x3F, 0xD6, 0xC6)
    /// The dashed guide of an unlinked symbol pair #8A5A9C.
    public static let guide = rgb(0x8A, 0x5A, 0x9C)
    /// The outline of a missing pair's guide or a snapped link after a failure #FF6B4A.
    public static let broken = rgb(0xFF, 0x6B, 0x4A)
    /// A lit coherence bar #3FD6C6.
    public static let coherenceLit = rgb(0x3F, 0xD6, 0xC6)
    /// An unlit coherence bar #2A2433.
    public static let coherenceUnlit = rgb(0x2A, 0x24, 0x33)
    /// The threshold mark over the coherence gauge #F4F1E8.
    public static let thresholdMark = rgb(0xF4, 0xF1, 0xE8)
    /// A lit hold pip #3FD6C6.
    public static let holdLit = rgb(0x3F, 0xD6, 0xC6)
    /// An unlit hold pip #3A3348.
    public static let holdUnlit = rgb(0x3A, 0x33, 0x48)
    /// A lit moves bar #B8C0D0.
    public static let movesLit = rgb(0xB8, 0xC0, 0xD0)
    /// An unlit moves bar #2A2433.
    public static let movesUnlit = rgb(0x2A, 0x24, 0x33)
    /// A radial wave shell #6FE0D8.
    public static let shell = rgb(0x6F, 0xE0, 0xD8)
    /// The glow around teal links and stars #8FF4EA.
    public static let glow = rgb(0x8F, 0xF4, 0xEA)

    /// The palette's key colours as hex text, for the registration: sky, star, teal, guide (plum), silver.
    public static let hex: [String] = ["#05060F", "#F4F1E8", "#3FD6C6", "#8A5A9C", "#B8C0D0"]

    /// An 8-bit sRGB triple as linear 0 … 1 components (the shaders treat the values as given).
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One of the three quality tiers (clarification Q2), richest first; tiers change only the star pulse, wave shells
/// and glow, never stars, hands, links, guides, gauges, colours or positions.
public struct AcousticConstellatorTier: Sendable, Equatable, Hashable {
    /// 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// Whether stars pulse (scale 1 + 0.15 · cos(2π · phase / 12) at the shown tick).
    public let pulse: Bool
    /// Radial wave shells per star on a coherent shown tick (2, 0, 0).
    public let waveShells: Int
    /// Glow shells around teal links and stars (2, 1, 0).
    public let glowShells: Int

    /// The three tiers, richest first.
    public static let all: [AcousticConstellatorTier] = [
        AcousticConstellatorTier(index: 0, pulse: true, waveShells: 2, glowShells: 2),
        AcousticConstellatorTier(index: 1, pulse: true, waveShells: 0, glowShells: 1),
        AcousticConstellatorTier(index: 2, pulse: false, waveShells: 0, glowShells: 0),
    ]

    /// The tier's name, `level-0` … `level-2`.
    public var name: String { "level-\(index)" }

    /// The tier `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> AcousticConstellatorTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of the kernel's state for drawing (clarification Q4).
public struct AcousticConstellatorSceneSnapshot: Sendable, Equatable {
    /// Seconds each listen tick is shown (clarification Q1).
    public static let tickSeconds: Double = 0.25
    /// Seconds the last tick is held before the preview starts again.
    public static let holdSeconds: Double = 1.0
    /// The stars with their grid positions, natural rates and the level's phases.
    public let stars: [AcousticConstellatorStar]
    /// The links (the level's fixed links and the placed ones), sorted by (a, b); the listen's link order.
    public let links: [AcousticConstellatorLink]
    /// The level's fixed links, which the player cannot remove.
    public let fixedLinks: [AcousticConstellatorLink]
    /// The symbol's pairs.
    public let symbol: [AcousticConstellatorLink]
    /// The play's starting phase of every star (after nudges).
    public let phases: [Int]
    /// The kernel's listen of ``links`` from ``phases``.
    public let report: AcousticConstellatorListen
    /// The coherence threshold θ (coherent when n²R² ≥ θ).
    public let threshold: Int
    /// The coherent ticks in a row that win.
    public let hold: Int
    /// The listen window in ticks.
    public let window: Int
    /// The play's stage.
    public let stage: AcousticConstellatorStage
    /// The play's failure, if any.
    public let failure: AcousticConstellatorFailure?
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (finite, never negative); it never decides a rule.
    public let time: Double

    /// A snapshot of `play` at presentation time `time` (a non-finite or negative time becomes 0).
    public init(play: AcousticConstellatorPlay, levelNumber: Int, time: Double) {
        let level: AcousticConstellatorLevel = play.level
        stars = level.stars
        links = play.links
        fixedLinks = level.fixedLinks.sorted()
        symbol = level.symbol.sorted()
        phases = play.phases
        report = play.report
        threshold = level.threshold
        hold = level.hold
        window = level.window
        stage = play.stage
        failure = play.failure
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// The number of ticks the report holds (tick 0 … ``AcousticConstellatorListen/lastTick``), at least 1.
    public var ticks: Int { max(1, report.phases.count) }

    /// The tick drawn now: one tick per ``tickSeconds``, the last held ``holdSeconds``, looping; 0 at time 0.
    public var shownTick: Int {
        let ticks: Int = self.ticks
        guard ticks > 1 else { return 0 }
        let playing: Double = Double(ticks) * Self.tickSeconds
        let period: Double = playing + Self.holdSeconds
        let local: Double = time.truncatingRemainder(dividingBy: period)
        guard local < playing else { return ticks - 1 }
        return min(ticks - 1, max(0, Int(local / Self.tickSeconds)))
    }

    /// The seconds since `tick` began to be shown in the current loop (0 when it is not the shown tick).
    public var secondsIntoShownTick: Double {
        let ticks: Int = self.ticks
        guard ticks > 1 else { return time }
        let period: Double = Double(ticks) * Self.tickSeconds + Self.holdSeconds
        let local: Double = time.truncatingRemainder(dividingBy: period)
        return max(0, local - Double(shownTick) * Self.tickSeconds)
    }

    /// The phases of every star at `tick` (clamped to the report's ticks); the starting phases if the report is empty.
    public func phases(at tick: Int) -> [Int] {
        guard !report.phases.isEmpty else { return phases }
        return report.phases[min(max(tick, 0), report.phases.count - 1)]
    }

    /// The size of link `index`'s phase gap at `tick` (0 … 6).
    public func gap(_ index: Int, at tick: Int) -> Int {
        guard index >= 0, index < links.count else { return 0 }
        let now: [Int] = phases(at: tick)
        let link: AcousticConstellatorLink = links[index]
        guard link.a < now.count, link.b < now.count else { return 0 }
        return abs(AcousticConstellatorClock.gap(now[link.a], now[link.b]))
    }

    /// Whether link `index` is teal at `tick`: its gap is at most 1.
    public func isTeal(_ index: Int, at tick: Int) -> Bool { gap(index, at: tick) <= 1 }

    /// Whether link `index` has snapped on or before `tick`, as the kernel's report says.
    public func isSnapped(_ index: Int, at tick: Int) -> Bool {
        guard !report.snapped.isEmpty, tick >= 0 else { return false }
        let last: Int = min(tick, report.snapped.count - 1)
        for step in 0...last where report.snapped[step].contains(index) { return true }
        return false
    }

    /// The symbol pairs not among ``links``, sorted: they are drawn as dashed guides.
    public var unlinkedSymbolPairs: [AcousticConstellatorLink] {
        let present: Set<AcousticConstellatorLink> = Set(links)
        return symbol.filter { !present.contains($0) }
    }

    /// The number of stars, n.
    public var starCount: Int { stars.count }

    /// The coherence bars lit at `tick`: ⌊12 · (A + B√3) / n²⌋ clamped to 0 … 12 (presentation arithmetic).
    public func coherenceBars(at tick: Int) -> Int {
        let n: Int = max(1, starCount)
        guard !report.order.isEmpty else { return 0 }
        let parts: [Int] = report.order[min(max(tick, 0), report.order.count - 1)]
        guard parts.count == 2 else { return 0 }
        let value: Double = Double(parts[0]) + Double(parts[1]) * 3.0.squareRoot()
        let bars: Double = (12 * value / Double(n * n)).rounded(.down)
        guard bars.isFinite else { return 0 }
        return min(12, max(0, Int(bars)))
    }

    /// The coherence bar under the threshold mark: ⌈12θ / n²⌉ clamped to 0 … 12.
    public var thresholdBar: Int {
        let n: Int = max(1, starCount)
        let numerator: Int = 12 * max(0, threshold)
        let bar: Int = (numerator + n * n - 1) / (n * n)
        return min(12, max(0, bar))
    }

    /// The coherent run ending on `tick` (hold pips lit), at most ``hold``.
    public func run(at tick: Int) -> Int {
        guard !report.coherent.isEmpty, tick >= 0 else { return 0 }
        var run: Int = 0
        var step: Int = min(tick, report.coherent.count - 1)
        while step >= 0, report.coherent[step] {
            run += 1
            step -= 1
        }
        return min(run, hold)
    }

    /// Whether `tick` is coherent in the report.
    public func isCoherent(at tick: Int) -> Bool {
        guard tick >= 0, tick < report.coherent.count else { return false }
        return report.coherent[tick]
    }

    /// Whether the level is won.
    public var won: Bool { stage == .won }

    /// The symbol pair whose guide a `missing` failure outlines, if any.
    public var brokenGuide: AcousticConstellatorLink? {
        if case let .missing(pair)? = failure { return pair }
        return nil
    }

    /// The link a `disconnected` failure outlines, if any.
    public var brokenLink: AcousticConstellatorLink? {
        if case let .disconnected(_, link)? = failure { return link }
        return nil
    }

    /// The failure in words, numbered as the kernel's words number ticks and stars (from 0) and actions (from 1); nil
    /// without a failure.
    public static func failureText(_ failure: AcousticConstellatorFailure?) -> String? {
        switch failure {
        case let .missing(pair)?: return "The symbol needs a link from star \(pair.a) to star \(pair.b)."
        case let .disconnected(tick, link)?:
            return "On tick \(tick) the link from star \(link.a) to star \(link.b) snapped and the symbol came apart."
        case let .incoherent(longest)?: return "The stars never held together: the longest coherent run was \(longest)."
        case let .budget(action)?: return "The moves ran out on action \(action + 1)."
        case nil: return nil
        }
    }
}
