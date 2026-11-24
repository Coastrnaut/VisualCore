// AcousticConstellatorRegressionGoldenFrameTests — feature 428 (R02-G13-08) T-R02G1308-005 (FR-R02G1308-003, 004;
// SC-R02G1308-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `AcousticConstellatorGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after
// its witness's links and nudges and before its listen, so links, gauges and a partly spent moves gauge show, plus the
// hero frame: the manifest seed's level after the hero scenario's certified moves, tier 0) is drawn off screen at the
// frame-check size 1,152 × 768 of `AcousticConstellatorTest` with the frame's tier pinned, at the frame's time 0 (tick
// 0 shown). Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1; the frame's actions go through
// the session's action port (`link.add`, `star.nudge`). The snapshot the presenter drew equals
// `AcousticConstellatorGolden.snapshot(frame)` in every field that the picture shows (level, stars, links, fixed links,
// symbol, phases, report, threshold, hold, window, stage, failure, actions left, budget; the time is 0 in both: the
// tick clock restarts on the still's frame), so the rendered frame is the golden one. The frame's description
// (`AcousticConstellatorGolden.description`, decoded here) carries the counts and every named colour and puts every
// star centre, every link check point, the first coherence bar, the first hold pip and the first moves bar where the
// Core's CPU reference of the golden snapshot puts them (within one 1/8-pixel quantum), each on screen. The picture
// then passes the feature-423 checks (`AcousticConstellatorTest.checkFrame`) against the presenter's last snapshot: at
// every point at least 6 px from every other element, a star's centre has a pixel within 3 px 0.15 from the sky in
// luminance with red, green and blue within 0.1 of each other; a teal link's check point reaches a pixel 0.08 from the
// sky with green above red by 0.05; the first moves bar is 0.1 from the sky; the two probe corners are within 0.05 of
// the sky. One test per level (three stills) plus the hero test and the set test, each well under 10 s. Modelled on
// `HarmonicBridgesRegressionGoldenFrameTests` (feature 418). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
#if os(iOS)
import Foundation
import AcousticConstellatorCore
import Testing
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct AcousticConstellatorRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of the description.
    struct Counts: Decodable, Equatable {
        let stars: Int
        let links: Int
        let tealLinks: Int
        let guides: Int
        let coherenceLit: Int
        let holdLit: Int
        let movesLit: Int
        let movesTotal: Int
    }

    /// The description of one golden frame, decoded from `AcousticConstellatorGolden.description(_:)`. A position is
    /// `[x, y]` in 1/`quantum` pixel, or null when it does not project into the frame. The identity fields are read
    /// when present.
    struct Description: Decodable, Equatable {
        let name: String?
        let level: Int?
        let tier: Int?
        let width: Int?
        let height: Int?
        let quantum: Int?
        let counts: Counts
        let colours: [String: Colour]
        let starCentres: [[Int]?]
        let linkCheckPoints: [[Int]?]
        let firstCoherenceBar: [Int]?
        let firstHoldPip: [Int]?
        let firstMovesBar: [Int]?
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described in units of 1/`quantum` pixel (clarification Q3: 1/8 pixel).
    static let quantum: Int = 8
    /// The named colours of the description and the palette colour each must equal.
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("sky", AcousticConstellatorPalette.sky), ("star", AcousticConstellatorPalette.star),
        ("hand", AcousticConstellatorPalette.hand), ("silver", AcousticConstellatorPalette.silver),
        ("teal", AcousticConstellatorPalette.teal), ("guide", AcousticConstellatorPalette.guide),
        ("coherenceLit", AcousticConstellatorPalette.coherenceLit),
        ("coherenceUnlit", AcousticConstellatorPalette.coherenceUnlit),
        ("thresholdMark", AcousticConstellatorPalette.thresholdMark),
        ("holdLit", AcousticConstellatorPalette.holdLit), ("holdUnlit", AcousticConstellatorPalette.holdUnlit),
        ("movesLit", AcousticConstellatorPalette.movesLit), ("movesUnlit", AcousticConstellatorPalette.movesUnlit),
    ]

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [AcousticConstellatorGolden.Frame] {
        var list: [AcousticConstellatorGolden.Frame] = []
        for frame in AcousticConstellatorGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port, expecting each to be accepted.
    static func apply(_ actions: [AcousticConstellatorAction], to shell: AcousticConstellatorTest.Shell,
                      _ what: String) {
        let accepted: Int = AcousticConstellatorTest.issue(shell, actions)
        #expect(accepted == actions.count, "\(what): \(accepted) of \(actions.count) actions accepted")
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> AcousticConstellatorTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(AcousticConstellatorExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: AcousticConstellatorTest.Shell = try await AcousticConstellatorTest.open(session, seed: seed)
        let opened: Int = try AcousticConstellatorTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: AcousticConstellatorGolden.Frame) throws -> Description {
        let data: Data = try AcousticConstellatorGolden.description(frame)
        return try JSONDecoder().decode(Description.self, from: data)
    }

    /// One channel 0 … 1 as a byte, clamped and rounded.
    static func byte(_ v: Double) -> Int {
        Int((min(max(v, 0), 1) * 255).rounded())
    }

    /// `c` in 8 bits per channel.
    static func colour(_ c: SIMD3<Double>) -> Colour {
        Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// Whether the described position `q` lies within one quantum (per axis) of the pixel `p`; both nil also agree.
    static func agrees(_ q: [Int]?, _ p: SIMD2<Double>?, quantum: Int) -> Bool {
        if q == nil && p == nil { return true }
        guard let q, let p, q.count == 2 else { return false }
        let x: Double = p.x * Double(quantum)
        let y: Double = p.y * Double(quantum)
        return abs(Double(q[0]) - x) <= 1 && abs(Double(q[1]) - y) <= 1
    }

    /// Whether the described position `q` is present and lies inside the 1,152 × 768 picture.
    static func onScreen(_ q: [Int]?, quantum: Int) -> Bool {
        guard let q, q.count == 2, quantum > 0 else { return false }
        let p = SIMD2<Double>(Double(q[0]) / Double(quantum), Double(q[1]) / Double(quantum))
        return AcousticConstellatorTest.inside(p, width: AcousticConstellatorGolden.width,
                                               height: AcousticConstellatorGolden.height)
    }

    /// The described position `described` against the CPU reference pixel of `point` for `golden`; returns the miss
    /// (a disagreement or a position off screen) naming `what`, or nil.
    static func positionMiss(_ what: String, described: [Int]?, point: SIMD3<Double>,
                             golden: AcousticConstellatorSceneSnapshot, quantum: Int) -> String? {
        let reference: SIMD2<Double>? = AcousticConstellatorTest.pixel(point, golden)
        if !agrees(described, reference, quantum: quantum) {
            return "\(what) described \(String(describing: described)), reference \(String(describing: reference))"
        }
        if !onScreen(described, quantum: quantum) {
            return "\(what) described \(String(describing: described)) is off screen"
        }
        return nil
    }

    /// The described positions `described` against the CPU reference pixels of `points` for `golden`; returns the
    /// misses, each naming `what` and the index.
    static func positionMisses(_ what: String, described: [[Int]?], points: [SIMD3<Double>],
                               golden: AcousticConstellatorSceneSnapshot, quantum: Int) -> [String] {
        if described.count != points.count {
            return ["\(described.count) \(what) points described, reference \(points.count)"]
        }
        var misses: [String] = []
        for index in points.indices {
            if let miss: String = positionMiss("\(what) \(index)", described: described[index], point: points[index],
                                               golden: golden, quantum: quantum) {
                misses.append(miss)
            }
        }
        return misses
    }

    /// Every field of `shown` that the picture shows and that differs from `golden` (the time is checked apart).
    static func snapshotMisses(_ shown: AcousticConstellatorSceneSnapshot,
                               _ golden: AcousticConstellatorSceneSnapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.stars != golden.stars { misses.append("stars \(shown.stars.count), golden \(golden.stars.count)") }
        if shown.links != golden.links { misses.append("links \(shown.links.count), golden \(golden.links.count)") }
        if shown.fixedLinks != golden.fixedLinks { misses.append("fixed links") }
        if shown.symbol != golden.symbol { misses.append("symbol") }
        if shown.phases != golden.phases { misses.append("phases \(shown.phases), golden \(golden.phases)") }
        if shown.report != golden.report { misses.append("report") }
        if shown.threshold != golden.threshold {
            misses.append("threshold \(shown.threshold), golden \(golden.threshold)")
        }
        if shown.hold != golden.hold { misses.append("hold \(shown.hold), golden \(golden.hold)") }
        if shown.window != golden.window { misses.append("window \(shown.window), golden \(golden.window)") }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.actionsLeft != golden.actionsLeft {
            misses.append("actions left \(shown.actionsLeft), golden \(golden.actionsLeft)")
        }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        return misses
    }

    /// The description check: the frame's identity and size (when described), counts, colours and every position
    /// agreeing with the CPU reference of `golden` and on screen. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: AcousticConstellatorGolden.Frame,
                                  golden: AcousticConstellatorSceneSnapshot) -> [String] {
        typealias Geometry = AcousticConstellatorSceneGeometry
        var misses: [String] = []
        let quantum: Int = described.quantum ?? Self.quantum
        if let name = described.name, name != frame.name { misses.append("name \(name)") }
        if let level = described.level, level != frame.level { misses.append("level \(level)") }
        if let tier = described.tier, tier != frame.tier { misses.append("tier \(tier)") }
        if let width = described.width, width != AcousticConstellatorTest.width { misses.append("width \(width)") }
        if let height = described.height, height != AcousticConstellatorTest.height {
            misses.append("height \(height)")
        }
        if quantum != Self.quantum { misses.append("quantum \(quantum)") }
        var teal: Int = 0
        for index in golden.links.indices where golden.isTeal(index, at: 0) { teal += 1 }
        let counts: Counts = described.counts
        if counts.stars != golden.stars.count { misses.append("stars \(counts.stars), snapshot \(golden.stars.count)") }
        if counts.links != golden.links.count { misses.append("links \(counts.links), snapshot \(golden.links.count)") }
        if counts.tealLinks != teal { misses.append("teal links \(counts.tealLinks), snapshot \(teal)") }
        if counts.guides != golden.unlinkedSymbolPairs.count {
            misses.append("guides \(counts.guides), snapshot \(golden.unlinkedSymbolPairs.count)")
        }
        if counts.coherenceLit != golden.coherenceBars(at: 0) {
            misses.append("coherence lit \(counts.coherenceLit), snapshot \(golden.coherenceBars(at: 0))")
        }
        if counts.holdLit != golden.run(at: 0) { misses.append("hold lit \(counts.holdLit), \(golden.run(at: 0))") }
        if counts.movesLit != Geometry.litMoves(golden) {
            misses.append("moves lit \(counts.movesLit), snapshot \(Geometry.litMoves(golden))")
        }
        if counts.movesTotal != max(golden.budget, 0) { misses.append("moves total \(counts.movesTotal)") }
        for entry in Self.palette {
            let expected: Colour = colour(entry.colour)
            if described.colours[entry.name] != expected {
                misses.append("colour \(entry.name) \(String(describing: described.colours[entry.name])), palette "
                              + "\(expected)")
            }
        }
        if described.colours.count != Self.palette.count {
            misses.append("\(described.colours.count) colours described, \(Self.palette.count) expected")
        }
        var centres: [SIMD3<Double>] = []
        for index in golden.stars.indices { centres.append(Geometry.starCentre(index, golden)) }
        var checkPoints: [SIMD3<Double>] = []
        for index in golden.links.indices { checkPoints.append(Geometry.linkCheckPoint(index, golden)) }
        misses += positionMisses("star centre", described: described.starCentres, points: centres, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("link check point", described: described.linkCheckPoints, points: checkPoints,
                                 golden: golden, quantum: quantum)
        if let miss: String = positionMiss("first coherence bar", described: described.firstCoherenceBar,
                                           point: Geometry.coherenceBar(0, golden), golden: golden,
                                           quantum: quantum) {
            misses.append(miss)
        }
        if golden.hold > 0 {
            if let miss: String = positionMiss("first hold pip", described: described.firstHoldPip,
                                               point: Geometry.holdPip(0, golden), golden: golden, quantum: quantum) {
                misses.append(miss)
            }
        } else if described.firstHoldPip != nil {
            misses.append("first hold pip described without a hold")
        }
        if golden.budget > 0 {
            if let miss: String = positionMiss("first moves bar", described: described.firstMovesBar,
                                               point: Geometry.movesBar(0, golden), golden: golden, quantum: quantum) {
                misses.append(miss)
            }
        } else {
            misses.append("the golden snapshot has no moves budget")
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check and the feature-423 frame checks against the presenter's last snapshot;
    /// every issue names the frame.
    static func check(_ frame: AcousticConstellatorGolden.Frame, session: ExperienceSession,
                      shell: AcousticConstellatorTest.Shell) throws {
        let width: Int = AcousticConstellatorGolden.width
        let height: Int = AcousticConstellatorGolden.height
        AcousticConstellatorTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try AcousticConstellatorTest.still(session, width: width, height: height,
                                                               time: frame.time)
        let shown: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                                    "\(frame.name): no snapshot")
        let golden: AcousticConstellatorSceneSnapshot = try AcousticConstellatorGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(shown.time == golden.time, "\(frame.name): the drawn time is \(shown.time)")
        #expect(shown.shownTick == 0 && golden.shownTick == 0, "\(frame.name): tick \(shown.shownTick) shown")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(described.counts.links > 0, "\(frame.name): the frame shows no link")
        let lit: Int = described.counts.movesLit
        let total: Int = described.counts.movesTotal
        #expect(lit < total, "\(frame.name): the moves gauge is not partly spent (\(lit) of \(total) lit)")
        let report: AcousticConstellatorFrameReport = AcousticConstellatorTest.checkFrame(
            rgba, snapshot: shown, mode: .tier(frame.tier), width: width, height: height, require: false, frame.name)
        #expect(report.starChecked + report.tealChecked > 0,
                "\(frame.name): no star centre or teal link check point is clear of the other elements")
        print("acoustic-constellator golden \(frame.name): actions left \(golden.actionsLeft) of \(golden.budget), "
              + "links \(described.counts.links) (teal \(described.counts.tealLinks)), guides "
              + "\(described.counts.guides), stars checked \(report.starChecked), teal checked \(report.tealChecked)")
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing their actions (the witness's
    /// links and nudges without its listen, the level not won), and the hero frame (the manifest seed's level, tier 0,
    /// the hero scenario's certified moves), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() throws {
        let frames: [AcousticConstellatorGolden.Frame] = AcousticConstellatorGolden.frames
        #expect(frames.count == 16)
        #expect(AcousticConstellatorGolden.width == AcousticConstellatorTest.width)
        #expect(AcousticConstellatorGolden.height == AcousticConstellatorTest.height)
        #expect(AcousticConstellatorGolden.quantum == Self.quantum)
        #expect(AcousticConstellatorGolden.levels == Self.levels)
        let heroLevel: Int = AcousticConstellatorExperienceCore.levelNumber(
            forSeed: AcousticConstellatorExperienceCore.manifestSeed)
        let heroMoves: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedArrangement(heroLevel)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0)
            #expect(frame.actions == heroMoves, "the hero frame plays the hero scenario's certified moves")
            #expect(!frame.actions.isEmpty, "the hero frame has actions")
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in Self.levels {
            let tiers: [AcousticConstellatorGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [AcousticConstellatorAction] = tiers.first?.actions ?? []
            let moves: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedArrangement(level)
            #expect(actions == moves, "level \(level): the frames play the witness's links and nudges")
            #expect(!actions.isEmpty, "level \(level): the frames have actions")
            for action in actions where action == .listen { Issue.record("level \(level): a golden frame listens") }
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == actions, "\(frame.name): the tier frames share their actions")
                tierIndex += 1
            }
            if let first: AcousticConstellatorGolden.Frame = tiers.first {
                let golden: AcousticConstellatorSceneSnapshot = try AcousticConstellatorGolden.snapshot(first)
                #expect(golden.levelNumber == level, "\(first.name): level \(golden.levelNumber)")
                #expect(golden.stage == .playing, "\(first.name): stage \(golden.stage)")
                #expect(golden.failure == nil, "\(first.name): the golden frame has failed")
                #expect(golden.actionsLeft == golden.budget - actions.count,
                        "\(first.name): actions left \(golden.actionsLeft)")
                #expect(!golden.links.isEmpty, "\(first.name): the golden frame shows no link")
            }
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    /// The three tier frames of `level` render as the golden snapshot and description say.
    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [AcousticConstellatorGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: AcousticConstellatorGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: AcousticConstellatorTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their actions: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their actions")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    /// The hero frame (the manifest seed's level after the hero scenario's certified moves, tier 0) renders as
    /// described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [AcousticConstellatorGolden.Frame] = []
        for frame in AcousticConstellatorGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: AcousticConstellatorGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: AcousticConstellatorTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try AcousticConstellatorTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try AcousticConstellatorTest.digest(shell)
        #expect(after != before, "the hero actions change the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
