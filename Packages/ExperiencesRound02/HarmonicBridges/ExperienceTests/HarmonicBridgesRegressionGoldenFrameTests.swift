// HarmonicBridgesRegressionGoldenFrameTests — feature 418 (R02-G12-08) T-R02G1208-005 (FR-R02G1208-003, 004;
// SC-R02G1208-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `HarmonicBridgesGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after its
// witness's tunings and before its test, so bridges, filled marks, pips and a partly spent gauge show, plus the hero
// frame: the manifest seed's level after the hero scenario's tunings, tier 0) is drawn off screen at the frame-check
// size 1,152 × 768 of `HarmonicBridgesTest` with the frame's tier pinned, at the frame's time 0 (the step shown is
// step 0). Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1; the frame's actions go through the
// session's action port (`string.tune`). The snapshot the presenter drew equals `HarmonicBridgesGolden.snapshot(frame)`
// in every field that the picture shows (level, islands, strings, pegs, report, modes, strengths, threshold, start,
// goal, stage, failure, actions left, budget; the time is 0 in both: the step clock restarts on the still's frame), so
// the rendered frame is the golden one. The frame's description (`HarmonicBridgesGolden.description`, decoded here)
// carries the counts and every named colour and puts every island top, string midpoint, membrane check point of the
// shown step's bridges, step pip and the gauge's first bar where the Core's CPU reference of the golden snapshot puts
// them (within one 1/8-pixel quantum), each on screen. The picture then passes the feature-413 checks
// (`HarmonicBridgesTest.checkFrame`) against the presenter's last snapshot: at every point at least 6 px from every
// other element, an island's top centre has a pixel 0.1 from the ground in luminance within 3 px with red above blue by
// 0.05 (the hue where no glow shell lies over it), a drawn membrane's check point one 0.08 from the ground with blue
// above red by 0.05; the gauge's first bar is 0.1 from the ground; the two probe corners are within 0.05 of the ground.
// One test per level (three stills) plus the hero test and the set test, each well under 10 s. Modelled on
// `EchoCartographerRegressionGoldenFrameTests` (feature 408). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
#if os(iOS)
import Foundation
import HarmonicBridgesCore
import Testing
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct HarmonicBridgesRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of the description.
    struct Counts: Decodable, Equatable {
        let islands: Int
        let strings: Int
        let bridges: Int
        let filledMarks: Int
        let hollowMarks: Int
        let pips: Int
        let gaugeLit: Int
        let gaugeTotal: Int
    }

    /// The description of one golden frame, decoded from `HarmonicBridgesGolden.description(_:)`. A position is
    /// `[x, y]` in 1/`quantum` pixel, or null when it does not project. The identity fields are read when present.
    struct Description: Decodable, Equatable {
        let name: String?
        let level: Int?
        let tier: Int?
        let width: Int?
        let height: Int?
        let quantum: Int?
        let counts: Counts
        let colours: [String: Colour]
        let islandTops: [[Int]?]
        let stringMidpoints: [[Int]?]
        let membranes: [[Int]?]
        let pips: [[Int]?]
        let firstGaugeBar: [Int]?
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described in units of 1/`quantum` pixel (clarification Q3: 1/8 pixel).
    static let quantum: Int = 8
    /// The named colours of the description and the palette colour each must equal.
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("ground", HarmonicBridgesPalette.ground), ("islandFace", HarmonicBridgesPalette.islandFace),
        ("islandEdge", HarmonicBridgesPalette.islandEdge), ("string", HarmonicBridgesPalette.string),
        ("membrane", HarmonicBridgesPalette.membrane), ("markFilled", HarmonicBridgesPalette.markFilled),
        ("markHollow", HarmonicBridgesPalette.markHollow), ("start", HarmonicBridgesPalette.start),
        ("goal", HarmonicBridgesPalette.goal), ("pip", HarmonicBridgesPalette.pip),
        ("pipUnlit", HarmonicBridgesPalette.pipUnlit), ("gaugeLit", HarmonicBridgesPalette.gaugeLit),
        ("gaugeUnlit", HarmonicBridgesPalette.gaugeUnlit),
    ]

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [HarmonicBridgesGolden.Frame] {
        var list: [HarmonicBridgesGolden.Frame] = []
        for frame in HarmonicBridgesGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port, expecting each to be accepted.
    static func apply(_ actions: [HarmonicBridgesAction], to shell: HarmonicBridgesTest.Shell, _ what: String) {
        let accepted: Int = HarmonicBridgesTest.issue(shell, actions)
        #expect(accepted == actions.count, "\(what): \(accepted) of \(actions.count) actions accepted")
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> HarmonicBridgesTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(HarmonicBridgesExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: HarmonicBridgesTest.Shell = try await HarmonicBridgesTest.open(session, seed: seed)
        let opened: Int = try HarmonicBridgesTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: HarmonicBridgesGolden.Frame) throws -> Description {
        let data: Data = try HarmonicBridgesGolden.description(frame)
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
        return HarmonicBridgesTest.inside(p, width: HarmonicBridgesGolden.width, height: HarmonicBridgesGolden.height)
    }

    /// The described positions `described` against the CPU reference pixels of `points` for `golden`; returns the
    /// misses (a disagreement or a position off screen), each naming `what` and the index.
    static func positionMisses(_ what: String, described: [[Int]?], points: [SIMD3<Double>],
                               golden: HarmonicBridgesSceneSnapshot, quantum: Int) -> [String] {
        if described.count != points.count {
            return ["\(described.count) \(what) points described, reference \(points.count)"]
        }
        var misses: [String] = []
        for index in points.indices {
            let reference: SIMD2<Double>? = HarmonicBridgesTest.pixel(points[index], golden)
            if !agrees(described[index], reference, quantum: quantum) {
                misses.append("\(what) \(index) described \(String(describing: described[index])), reference "
                              + "\(String(describing: reference))")
            } else if !onScreen(described[index], quantum: quantum) {
                misses.append("\(what) \(index) described \(String(describing: described[index])) is off screen")
            }
        }
        return misses
    }

    /// Every field of `shown` that the picture shows and that differs from `golden` (the time is checked apart).
    static func snapshotMisses(_ shown: HarmonicBridgesSceneSnapshot,
                               _ golden: HarmonicBridgesSceneSnapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.islands != golden.islands {
            misses.append("islands \(shown.islands.count), golden \(golden.islands.count)")
        }
        if shown.strings != golden.strings {
            misses.append("strings \(shown.strings.count), golden \(golden.strings.count)")
        }
        if shown.pegs != golden.pegs { misses.append("pegs \(shown.pegs), golden \(golden.pegs)") }
        if shown.report != golden.report { misses.append("report") }
        if shown.modes != golden.modes { misses.append("modes") }
        if shown.strengths != golden.strengths { misses.append("strengths") }
        if shown.threshold != golden.threshold {
            misses.append("threshold \(shown.threshold), golden \(golden.threshold)")
        }
        if shown.start != golden.start || shown.goal != golden.goal {
            misses.append("start \(shown.start) goal \(shown.goal), golden \(golden.start) \(golden.goal)")
        }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.actionsLeft != golden.actionsLeft {
            misses.append("actions left \(shown.actionsLeft), golden \(golden.actionsLeft)")
        }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        return misses
    }

    /// The filled and hollow sample marks of `snapshot` in `step` (five per string).
    static func marks(_ snapshot: HarmonicBridgesSceneSnapshot, step: Int) -> (filled: Int, hollow: Int) {
        var filled: Int = 0
        var hollow: Int = 0
        for index in snapshot.strings.indices {
            for k in 1...HarmonicBridgesSwing.samples {
                if HarmonicBridgesSceneGeometry.isFilled(index, sample: k, step: step, snapshot) {
                    filled += 1
                } else {
                    hollow += 1
                }
            }
        }
        return (filled, hollow)
    }

    /// The description check: the frame's identity and size (when described), counts, colours and every position
    /// agreeing with the CPU reference of `golden` and on screen. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: HarmonicBridgesGolden.Frame,
                                  golden: HarmonicBridgesSceneSnapshot) -> [String] {
        typealias Geometry = HarmonicBridgesSceneGeometry
        var misses: [String] = []
        let quantum: Int = described.quantum ?? Self.quantum
        if let name = described.name, name != frame.name { misses.append("name \(name)") }
        if let level = described.level, level != frame.level { misses.append("level \(level)") }
        if let tier = described.tier, tier != frame.tier { misses.append("tier \(tier)") }
        if let width = described.width, width != HarmonicBridgesTest.width { misses.append("width \(width)") }
        if let height = described.height, height != HarmonicBridgesTest.height { misses.append("height \(height)") }
        if quantum != Self.quantum { misses.append("quantum \(quantum)") }
        let step: Int = golden.shownStep
        var bridges: [Int] = []
        for index in golden.strings.indices where golden.isBridge(index, step: step) { bridges.append(index) }
        let marks: (filled: Int, hollow: Int) = Self.marks(golden, step: step)
        let counts: Counts = described.counts
        if counts.islands != golden.islands.count { misses.append("islands \(counts.islands)") }
        if counts.strings != golden.strings.count { misses.append("strings \(counts.strings)") }
        if counts.bridges != bridges.count { misses.append("bridges \(counts.bridges), snapshot \(bridges.count)") }
        if counts.filledMarks != marks.filled { misses.append("filled marks \(counts.filledMarks), \(marks.filled)") }
        if counts.hollowMarks != marks.hollow { misses.append("hollow marks \(counts.hollowMarks), \(marks.hollow)") }
        if counts.pips != golden.steps { misses.append("pips \(counts.pips), steps \(golden.steps)") }
        if counts.gaugeLit != Geometry.litBars(golden) { misses.append("lit bars \(counts.gaugeLit)") }
        if counts.gaugeTotal != max(golden.budget, 0) { misses.append("gauge total \(counts.gaugeTotal)") }
        for entry in Self.palette {
            let expected: Colour = colour(entry.colour)
            if described.colours[entry.name] != expected {
                misses.append("colour \(entry.name) \(String(describing: described.colours[entry.name])), palette "
                              + "\(expected)")
            }
        }
        var tops: [SIMD3<Double>] = []
        for index in golden.islands.indices { tops.append(Geometry.islandTop(index, golden)) }
        var midpoints: [SIMD3<Double>] = []
        for index in golden.strings.indices { midpoints.append(Geometry.stringMidpoint(index, golden)) }
        var membranes: [SIMD3<Double>] = []
        for index in bridges { membranes.append(Geometry.membraneMidpoint(index, golden)) }
        var pips: [SIMD3<Double>] = []
        for index in 0..<golden.steps { pips.append(Geometry.stepPip(index, golden)) }
        misses += positionMisses("island top", described: described.islandTops, points: tops, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("string midpoint", described: described.stringMidpoints, points: midpoints,
                                 golden: golden, quantum: quantum)
        misses += positionMisses("membrane", described: described.membranes, points: membranes, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("pip", described: described.pips, points: pips, golden: golden, quantum: quantum)
        let gauge: SIMD2<Double>? = HarmonicBridgesTest.gaugePixel(golden)
        if !agrees(described.firstGaugeBar, gauge, quantum: quantum) {
            misses.append("first gauge bar described \(String(describing: described.firstGaugeBar)), reference "
                          + "\(String(describing: gauge))")
        } else if !onScreen(described.firstGaugeBar, quantum: quantum) {
            misses.append("first gauge bar described \(String(describing: described.firstGaugeBar)) is off screen")
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check and the feature-413 frame checks against the presenter's last snapshot;
    /// every issue names the frame.
    static func check(_ frame: HarmonicBridgesGolden.Frame, session: ExperienceSession,
                      shell: HarmonicBridgesTest.Shell) throws {
        let width: Int = HarmonicBridgesGolden.width
        let height: Int = HarmonicBridgesGolden.height
        HarmonicBridgesTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try HarmonicBridgesTest.still(session, width: width, height: height, time: frame.time)
        let shown: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                               "\(frame.name): no snapshot")
        let golden: HarmonicBridgesSceneSnapshot = try HarmonicBridgesGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(shown.time == golden.time, "\(frame.name): the drawn step time is \(shown.time)")
        #expect(shown.shownStep == 0 && golden.shownStep == 0, "\(frame.name): step \(shown.shownStep) shown")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(described.counts.bridges > 0, "\(frame.name): the shown step has no bridge")
        let report: HarmonicBridgesFrameReport = HarmonicBridgesTest.checkFrame(
            rgba, snapshot: shown, mode: .tier(frame.tier), width: width, height: height, require: false, frame.name)
        #expect(report.topChecked + report.membraneChecked > 0,
                "\(frame.name): no island top or membrane check point is clear of the other elements")
        print("harmonic-bridges golden \(frame.name): actions left \(golden.actionsLeft) of \(golden.budget), "
              + "bridges \(described.counts.bridges), filled marks \(described.counts.filledMarks), "
              + "tops checked \(report.topChecked) (copper \(report.copperChecked)), "
              + "membranes checked \(report.membraneChecked)")
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing their actions (the witness's
    /// tunings without its test, the level not won), and the hero frame (the manifest seed's level, tier 0, the hero
    /// scenario's tunings), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() throws {
        let frames: [HarmonicBridgesGolden.Frame] = HarmonicBridgesGolden.frames
        #expect(frames.count == 16)
        #expect(HarmonicBridgesGolden.width == HarmonicBridgesTest.width)
        #expect(HarmonicBridgesGolden.height == HarmonicBridgesTest.height)
        let heroLevel: Int = HarmonicBridgesExperienceCore.levelNumber(
            forSeed: HarmonicBridgesExperienceCore.manifestSeed)
        let heroTunings: [HarmonicBridgesAction] = try HarmonicBridgesTest.certifiedTunings(heroLevel)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0)
            #expect(frame.actions == heroTunings, "the hero frame plays the hero scenario's tunings")
            #expect(!frame.actions.isEmpty, "the hero frame has actions")
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in Self.levels {
            let tiers: [HarmonicBridgesGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [HarmonicBridgesAction] = tiers.first?.actions ?? []
            let tunings: [HarmonicBridgesAction] = try HarmonicBridgesTest.certifiedTunings(level)
            #expect(actions == tunings, "level \(level): the frames play the witness's tunings")
            for action in actions where action == .test { Issue.record("level \(level): a golden frame tests") }
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == actions, "\(frame.name): the tier frames share their actions")
                tierIndex += 1
            }
            if let first: HarmonicBridgesGolden.Frame = tiers.first {
                let golden: HarmonicBridgesSceneSnapshot = try HarmonicBridgesGolden.snapshot(first)
                #expect(golden.levelNumber == level, "\(first.name): level \(golden.levelNumber)")
                #expect(golden.stage == .playing, "\(first.name): stage \(golden.stage)")
                #expect(golden.failure == nil, "\(first.name): the golden frame has failed")
                #expect(golden.actionsLeft == golden.budget - actions.count,
                        "\(first.name): actions left \(golden.actionsLeft)")
                #expect(golden.report.bridges.first?.contains(true) == true, "\(first.name): step 0 has a bridge")
            }
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    /// The three tier frames of `level` render as the golden snapshot and description say.
    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [HarmonicBridgesGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: HarmonicBridgesGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: HarmonicBridgesTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their actions: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their actions")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    /// The hero frame (the manifest seed's level after the hero scenario's tunings, tier 0) renders as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [HarmonicBridgesGolden.Frame] = []
        for frame in HarmonicBridgesGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: HarmonicBridgesGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: HarmonicBridgesTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try HarmonicBridgesTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try HarmonicBridgesTest.digest(shell)
        #expect(after != before, "the hero actions change the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
