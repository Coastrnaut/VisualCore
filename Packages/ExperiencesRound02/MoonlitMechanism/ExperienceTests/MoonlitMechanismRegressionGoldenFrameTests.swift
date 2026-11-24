// MoonlitMechanismRegressionGoldenFrameTests — feature 438 (R02-G14-08) T-R02G1408-005 (FR-R02G1408-003, 004;
// SC-R02G1408-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `MoonlitMechanismGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after its
// witness's turns, re-seats and lamp steps and before its run, so the set-up casts its shadows and a partly spent moves
// gauge shows while the level is still open, plus the hero frame: the manifest seed's level after the hero scenario's
// certified moves, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of `MoonlitMechanismTest` with the
// frame's tier pinned, at the frame's time 0 (key frame 0 shown). Seed s opens level s % 100 + 1, so a frame of level L
// opens at seed L − 1; the frame's actions go through the session's action port (`handle.turn`, `gear.reseat`,
// `lamp.step`). The snapshot the presenter drew equals `MoonlitMechanismGolden.snapshot(frame)` in every field that the
// picture shows (level, gears, phases, set-up phases, height, lamp heights, wall size, shown key frame, key frames,
// cast, target, forbidden, report, stage, failure, actions left, budget; the time is 0 in both: the presentation clock
// restarts on the still's frame), so the rendered frame is the golden one. The frame's description
// (`MoonlitMechanismGolden.description`, decoded here) carries the counts and every named colour and puts every
// cast-cell centre, every gear centre and rim check point, every key-frame card centre, the first alignment pip, the
// lamp and the first moves bar where the Core's CPU reference of the golden snapshot puts them (within one 1/8-pixel
// quantum), each on screen. The picture then passes the feature-433 checks (`MoonlitMechanismTest.checkFrame`) against
// the presenter's last snapshot: at every point at least 6 px from every element drawn over it that could hide it (the
// render tests' own clearance rules), a cast cell's centre has a pixel within 3 px darker than the paper by 0.25 in
// luminance; a gear's rim point has red above blue by 0.08; the first moves bar is 0.1 from the paper; the two probe
// corners are within 0.05 of the night. One test per level (three stills) plus the hero test and the set test, each
// well under 10 s. Modelled on `AcousticConstellatorRegressionGoldenFrameTests` (feature 428). Synthetic data, explicit
// types, plain loops, no sleep, no wall-clock assertion.
#if os(iOS)
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MoonlitMechanismRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of the description.
    struct Counts: Decodable, Equatable {
        let gears: Int
        let cast: Int
        let targets: Int
        let missing: Int
        let stray: Int
        let forbidden: Int
        let litCards: Int
        let alignedPips: Int
        let litMoves: Int
        let moves: Int
    }

    /// The description of one golden frame, decoded from `MoonlitMechanismGolden.description(_:)`. A position is
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
        let castCentres: [[Int]?]
        let gearCentres: [[Int]?]
        let rimPoints: [[Int]?]
        let cardCentres: [[Int]?]
        let firstPip: [Int]?
        let lamp: [Int]?
        let firstMovesBar: [Int]?
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described in units of 1/`quantum` pixel (clarification Q3: 1/8 pixel).
    static let quantum: Int = 8
    /// The named colours of the description and the palette colour each must equal (`pip` is the lit alignment pip).
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("night", MoonlitMechanismPalette.night), ("paper", MoonlitMechanismPalette.paper),
        ("ink", MoonlitMechanismPalette.ink), ("gear", MoonlitMechanismPalette.gear),
        ("rim", MoonlitMechanismPalette.rim), ("blade", MoonlitMechanismPalette.blade),
        ("lamp", MoonlitMechanismPalette.lamp), ("cardLit", MoonlitMechanismPalette.cardLit),
        ("cardUnlit", MoonlitMechanismPalette.cardUnlit), ("pip", MoonlitMechanismPalette.alignLit),
        ("movesLit", MoonlitMechanismPalette.movesLit), ("movesUnlit", MoonlitMechanismPalette.movesUnlit),
        ("broken", MoonlitMechanismPalette.broken),
    ]

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [MoonlitMechanismGolden.Frame] {
        var list: [MoonlitMechanismGolden.Frame] = []
        for frame in MoonlitMechanismGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port, expecting each to be accepted.
    static func apply(_ actions: [MoonlitMechanismAction], to shell: MoonlitMechanismTest.Shell, _ what: String) {
        let accepted: Int = MoonlitMechanismTest.issue(shell, actions)
        #expect(accepted == actions.count, "\(what): \(accepted) of \(actions.count) actions accepted")
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> MoonlitMechanismTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(MoonlitMechanismExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: MoonlitMechanismTest.Shell = try await MoonlitMechanismTest.open(session, seed: seed)
        let opened: Int = try MoonlitMechanismTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: MoonlitMechanismGolden.Frame) throws -> Description {
        let data: Data = try MoonlitMechanismGolden.description(frame)
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
        return MoonlitMechanismTest.inside(p, width: MoonlitMechanismGolden.width,
                                           height: MoonlitMechanismGolden.height)
    }

    /// The CPU reference pixel of `point` for `golden` at the golden size, or nil when it does not project or lies
    /// outside the picture (the description writes null then).
    static func referencePixel(_ point: SIMD3<Double>, golden: MoonlitMechanismSceneSnapshot) -> SIMD2<Double>? {
        let width: Int = MoonlitMechanismGolden.width
        let height: Int = MoonlitMechanismGolden.height
        guard let p: SIMD2<Double> = MoonlitMechanismTest.pixel(point, golden, width: width, height: height),
              p.x >= 0, p.y >= 0, p.x <= Double(width), p.y <= Double(height) else { return nil }
        return p
    }

    /// The described position `described` against the CPU reference pixel of `point` for `golden`; returns the miss
    /// (a disagreement or a position off screen) naming `what`, or nil.
    static func positionMiss(_ what: String, described: [Int]?, point: SIMD3<Double>,
                             golden: MoonlitMechanismSceneSnapshot, quantum: Int) -> String? {
        let reference: SIMD2<Double>? = referencePixel(point, golden: golden)
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
                               golden: MoonlitMechanismSceneSnapshot, quantum: Int) -> [String] {
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
    static func snapshotMisses(_ shown: MoonlitMechanismSceneSnapshot,
                               _ golden: MoonlitMechanismSceneSnapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.gears != golden.gears { misses.append("gears \(shown.gears.count), golden \(golden.gears.count)") }
        if shown.phases != golden.phases { misses.append("phases \(shown.phases), golden \(golden.phases)") }
        if shown.setUpPhases != golden.setUpPhases {
            misses.append("set-up phases \(shown.setUpPhases), golden \(golden.setUpPhases)")
        }
        if shown.height != golden.height { misses.append("height \(shown.height), golden \(golden.height)") }
        if shown.lampHeights != golden.lampHeights { misses.append("lamp heights \(shown.lampHeights)") }
        if shown.width != golden.width || shown.rows != golden.rows {
            misses.append("wall \(shown.width) × \(shown.rows), golden \(golden.width) × \(golden.rows)")
        }
        if shown.shownFrame != golden.shownFrame {
            misses.append("shown key frame \(shown.shownFrame), golden \(golden.shownFrame)")
        }
        if shown.keyFrames != golden.keyFrames { misses.append("key frames") }
        if shown.cast != golden.cast { misses.append("cast \(shown.cast.count), golden \(golden.cast.count)") }
        if shown.target != golden.target {
            misses.append("target \(shown.target.count), golden \(golden.target.count)")
        }
        if shown.forbidden != golden.forbidden { misses.append("forbidden") }
        if shown.report != golden.report { misses.append("report") }
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
    static func descriptionMisses(_ described: Description, frame: MoonlitMechanismGolden.Frame,
                                  golden: MoonlitMechanismSceneSnapshot) -> [String] {
        typealias Geometry = MoonlitMechanismSceneGeometry
        var misses: [String] = []
        let quantum: Int = described.quantum ?? Self.quantum
        if let name = described.name, name != frame.name { misses.append("name \(name)") }
        if let level = described.level, level != frame.level { misses.append("level \(level)") }
        if let tier = described.tier, tier != frame.tier { misses.append("tier \(tier)") }
        if let width = described.width, width != MoonlitMechanismTest.width { misses.append("width \(width)") }
        if let height = described.height, height != MoonlitMechanismTest.height { misses.append("height \(height)") }
        if quantum != Self.quantum { misses.append("quantum \(quantum)") }
        var litCards: Int = 0
        for index in golden.keyFrames.indices where Geometry.cardFraction(index, golden) > 0 { litCards += 1 }
        let pips: Int = Geometry.pipCount(golden)
        var alignedPips: Int = 0
        for index in 0..<pips where Geometry.isPipLit(index, golden) { alignedPips += 1 }
        let counts: Counts = described.counts
        if counts.gears != golden.gears.count { misses.append("gears \(counts.gears), snapshot \(golden.gears.count)") }
        if counts.cast != golden.cast.count { misses.append("cast \(counts.cast), snapshot \(golden.cast.count)") }
        if counts.targets != golden.target.count {
            misses.append("targets \(counts.targets), snapshot \(golden.target.count)")
        }
        if counts.missing != golden.missingCells.count {
            misses.append("missing \(counts.missing), snapshot \(golden.missingCells.count)")
        }
        if counts.stray != golden.strayCells.count {
            misses.append("stray \(counts.stray), snapshot \(golden.strayCells.count)")
        }
        if counts.forbidden != golden.forbidden.count {
            misses.append("forbidden \(counts.forbidden), snapshot \(golden.forbidden.count)")
        }
        if counts.litCards != litCards { misses.append("lit cards \(counts.litCards), snapshot \(litCards)") }
        if counts.alignedPips != alignedPips {
            misses.append("aligned pips \(counts.alignedPips), snapshot \(alignedPips)")
        }
        if counts.litMoves != Geometry.litMoves(golden) {
            misses.append("lit moves \(counts.litMoves), snapshot \(Geometry.litMoves(golden))")
        }
        if counts.moves != max(golden.budget, 0) { misses.append("moves \(counts.moves), budget \(golden.budget)") }
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
        var castPoints: [SIMD3<Double>] = []
        for cell in golden.cast { castPoints.append(Geometry.cellCentre(cell, golden)) }
        var gearPoints: [SIMD3<Double>] = []
        var rimPoints: [SIMD3<Double>] = []
        for index in golden.gears.indices {
            gearPoints.append(Geometry.gearCentre(index, golden))
            rimPoints.append(Geometry.gearRimCheckPoint(index, golden))
        }
        var cardPoints: [SIMD3<Double>] = []
        for index in golden.keyFrames.indices { cardPoints.append(Geometry.card(index, golden)) }
        misses += positionMisses("cast centre", described: described.castCentres, points: castPoints, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("gear centre", described: described.gearCentres, points: gearPoints, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("rim point", described: described.rimPoints, points: rimPoints, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("card centre", described: described.cardCentres, points: cardPoints, golden: golden,
                                 quantum: quantum)
        if pips > 0 {
            if let miss: String = positionMiss("first pip", described: described.firstPip,
                                               point: Geometry.alignmentPip(0, golden), golden: golden,
                                               quantum: quantum) {
                misses.append(miss)
            }
        } else if described.firstPip != nil {
            misses.append("first pip described without a mesh")
        }
        if let miss: String = positionMiss("lamp", described: described.lamp, point: Geometry.lampCentre(golden),
                                           golden: golden, quantum: quantum) {
            misses.append(miss)
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
    /// golden one, runs the description check and the feature-433 frame checks against the presenter's last snapshot;
    /// every issue names the frame.
    static func check(_ frame: MoonlitMechanismGolden.Frame, session: ExperienceSession,
                      shell: MoonlitMechanismTest.Shell) throws {
        let width: Int = MoonlitMechanismGolden.width
        let height: Int = MoonlitMechanismGolden.height
        MoonlitMechanismTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try MoonlitMechanismTest.still(session, width: width, height: height, time: frame.time)
        let shown: MoonlitMechanismSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                                "\(frame.name): no snapshot")
        let golden: MoonlitMechanismSceneSnapshot = try MoonlitMechanismGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(shown.time == golden.time, "\(frame.name): the drawn time is \(shown.time)")
        #expect(shown.shownFrame == MoonlitMechanismGolden.shownFrame && golden.shownFrame == 0,
                "\(frame.name): key frame \(shown.shownFrame) shown")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(described.counts.cast > 0, "\(frame.name): the frame casts no shadow")
        let lit: Int = described.counts.litMoves
        let total: Int = described.counts.moves
        #expect(lit < total, "\(frame.name): the moves gauge is not partly spent (\(lit) of \(total) lit)")
        let report: MoonlitMechanismCheckReport = MoonlitMechanismTest.checkFrame(
            rgba, snapshot: shown, mode: .lit, width: width, height: height, require: false, frame.name)
        #expect(report.cellChecked + report.rimChecked > 0,
                "\(frame.name): no cast-cell centre or rim check point is clear of the other elements")
        print("moonlit-mechanism golden \(frame.name): actions left \(golden.actionsLeft) of \(golden.budget), "
              + "cast \(described.counts.cast), gears \(described.counts.gears), cells checked "
              + "\(report.cellChecked), rims checked \(report.rimChecked)")
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing their actions (the witness's
    /// turns, re-seats and lamp steps without its run, the level still open), and the hero frame (the manifest seed's
    /// level, tier 0, the hero scenario's certified moves), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() throws {
        let frames: [MoonlitMechanismGolden.Frame] = MoonlitMechanismGolden.frames
        #expect(frames.count == 16)
        #expect(MoonlitMechanismGolden.width == MoonlitMechanismTest.width)
        #expect(MoonlitMechanismGolden.height == MoonlitMechanismTest.height)
        #expect(MoonlitMechanismGolden.quantum == Self.quantum)
        #expect(MoonlitMechanismGolden.levels == Self.levels)
        var names: [String] = []
        for entry in Self.palette { names.append(entry.name) }
        #expect(MoonlitMechanismGolden.colourNames == names, "the described colour names")
        let heroLevel: Int = MoonlitMechanismExperienceCore.levelNumber(
            forSeed: MoonlitMechanismExperienceCore.manifestSeed)
        let heroMoves: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedMoves(heroLevel)
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
            let tiers: [MoonlitMechanismGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [MoonlitMechanismAction] = tiers.first?.actions ?? []
            let moves: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedMoves(level)
            #expect(actions == moves, "level \(level): the frames play the witness's turns, re-seats and lamp steps")
            #expect(!actions.isEmpty, "level \(level): the frames have actions")
            for action in actions where action == .run { Issue.record("level \(level): a golden frame runs") }
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == actions, "\(frame.name): the tier frames share their actions")
                tierIndex += 1
            }
            if let first: MoonlitMechanismGolden.Frame = tiers.first {
                let golden: MoonlitMechanismSceneSnapshot = try MoonlitMechanismGolden.snapshot(first)
                #expect(golden.levelNumber == level, "\(first.name): level \(golden.levelNumber)")
                #expect(golden.stage == .playing, "\(first.name): stage \(golden.stage)")
                #expect(golden.failure == nil, "\(first.name): the golden frame has failed")
                #expect(golden.actionsLeft == golden.budget - actions.count,
                        "\(first.name): actions left \(golden.actionsLeft)")
                #expect(!golden.cast.isEmpty, "\(first.name): the golden frame casts no shadow")
            }
        }
        var unique: Set<String> = []
        for frame in frames { unique.insert(frame.name) }
        #expect(unique.count == 16, "frame names are unique")
    }

    /// The three tier frames of `level` render as the golden snapshot and description say.
    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [MoonlitMechanismGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: MoonlitMechanismGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: MoonlitMechanismTest.Shell = try await Self.open(session, level: level)
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
        var heroes: [MoonlitMechanismGolden.Frame] = []
        for frame in MoonlitMechanismGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: MoonlitMechanismGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: MoonlitMechanismTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try MoonlitMechanismTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try MoonlitMechanismTest.digest(shell)
        #expect(after != before, "the hero actions change the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
