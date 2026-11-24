// VoxelOrigamiRegressionGoldenFrameTests — feature 448 (R02-G15-08) T-R02G1508-005 (FR-R02G1508-003, 004;
// SC-R02G1508-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `VoxelOrigamiGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after all of
// its witness's turns but the last, so the fold is part done and the level is still open, with hinge 1 chosen; plus the
// hero frame: the manifest seed's level after the hero scenario's actions, the certified turns without the last and
// that turn's hinge chosen, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of `VoxelOrigamiTest` with
// the frame's tier pinned, at the frame's time 0. Seed s opens level s % 100 + 1, so a frame of level L opens at seed
// L − 1; the frame's turns go through the session's action port (`hinge.turn`) and its hinge through `hinge.choose`
// (presentation only). The snapshot the presenter drew equals `VoxelOrigamiGolden.snapshot(frame)` (every field, the
// presentation time 0 in both: the still is drawn at frame time 0), so the rendered frame is the golden one. The
// frame's description (`VoxelOrigamiGolden.description`, decoded here) carries the counts and every named colour and
// puts every cube centre, every hinge mark (lifted towards the eye as drawn), every target cell centre, the first
// covered pip and the first moves bar where the Core's CPU reference of the golden snapshot puts them (within one
// 1/8-pixel quantum), each on screen. The picture then passes the feature-443 checks (`VoxelOrigamiTest.checkFrame`)
// against the presenter's last snapshot: at every point at least 6 px from every element drawn after it in the
// painter's order (`VoxelOrigamiSceneGeometry.paintOrder`) that could hide it, a cube's centre has a pixel within 3 px
// brighter than the night by 0.25 in luminance; the chosen hinge's mark has red above blue by 0.08; the first moves bar
// is 0.1 from the night; the two probe corners are within 0.05 of the night. Each tier measures at least one cube
// centre summed over the level frames. One test for the set, one for the 15 level frames (15 stills, as the feature-443
// render test draws) and one for the hero frame, each well under 10 s. Modelled on
// `MoonlitMechanismRegressionGoldenFrameTests` (feature 438). Synthetic data, explicit types, plain loops, no sleep,
// no wall-clock assertion.
#if os(iOS)
import Foundation
import Testing
@testable import VoxelOrigamiExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VoxelOrigamiCore

@MainActor
@Suite(.serialized) struct VoxelOrigamiRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of the description.
    struct Counts: Decodable, Equatable {
        let cubes: Int
        let hinges: Int
        let targets: Int
        let inPlace: Int
        let litPips: Int
        let litMoves: Int
        let moves: Int
    }

    /// The description of one golden frame, decoded from `VoxelOrigamiGolden.description(_:)`. A position is `[x, y]`
    /// in 1/`quantum` pixel, or null when it does not project into the frame.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let counts: Counts
        let colours: [String: Colour]
        let cubeCentres: [[Int]?]
        let hingeMarks: [[Int]?]
        let targetCentres: [[Int]?]
        let firstPip: [Int]?
        let firstMovesBar: [Int]?
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described in units of 1/`quantum` pixel (clarification Q3: 1/8 pixel).
    static let quantum: Int = 8
    /// The hinge every level frame chooses.
    static let chosenHinge: Int = 1
    /// The named colours of the description and the palette colour each must equal.
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("night", VoxelOrigamiPalette.night), ("ivory", VoxelOrigamiPalette.ivory),
        ("ivoryShade", VoxelOrigamiPalette.ivoryShade), ("target", VoxelOrigamiPalette.target),
        ("targetGlow", VoxelOrigamiPalette.targetGlow), ("hinge", VoxelOrigamiPalette.hinge),
        ("hingeChosen", VoxelOrigamiPalette.hingeChosen), ("glyphSolid", VoxelOrigamiPalette.glyphSolid),
        ("glyphHollow", VoxelOrigamiPalette.glyphHollow), ("dots", VoxelOrigamiPalette.dots),
        ("coveredLit", VoxelOrigamiPalette.coveredLit), ("coveredUnlit", VoxelOrigamiPalette.coveredUnlit),
        ("movesLit", VoxelOrigamiPalette.movesLit), ("movesUnlit", VoxelOrigamiPalette.movesUnlit),
        ("broken", VoxelOrigamiPalette.broken), ("glow", VoxelOrigamiPalette.glow),
    ]

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [VoxelOrigamiGolden.Frame] {
        var list: [VoxelOrigamiGolden.Frame] = []
        for frame in VoxelOrigamiGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// The certified turns of `level` without the last (none for a one-turn plan).
    static func openTurns(_ level: Int) throws -> [VoxelOrigamiAction] {
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(level)
        return Array(turns.dropLast())
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> VoxelOrigamiTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(VoxelOrigamiExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: VoxelOrigamiTest.Shell = try await VoxelOrigamiTest.open(session, seed: seed)
        let opened: Int = try VoxelOrigamiTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// Sends `frame`'s turns through the session's action port, each expected to be accepted, then chooses the frame's
    /// hinge (`hinge.choose`, presentation only: the digest does not change).
    static func apply(_ frame: VoxelOrigamiGolden.Frame, to shell: VoxelOrigamiTest.Shell) throws {
        let accepted: Int = VoxelOrigamiTest.issue(shell, frame.actions)
        #expect(accepted == frame.actions.count, "\(frame.name): \(accepted) of \(frame.actions.count) turns accepted")
        let digest: String = try VoxelOrigamiTest.digest(shell)
        if try VoxelOrigamiTest.core(shell).chosenHinge != frame.hinge {
            let result: ActionResult = shell.handle(control: "hinge.choose", values: [Double(frame.hinge)])
            #expect(result == .accepted, "\(frame.name): hinge.choose \(frame.hinge): \(result.code)")
        }
        let chosen: Int = try VoxelOrigamiTest.core(shell).chosenHinge
        #expect(chosen == frame.hinge, "\(frame.name): hinge \(chosen) chosen, not \(frame.hinge)")
        #expect(try VoxelOrigamiTest.digest(shell) == digest, "\(frame.name): choosing a hinge leaves the digest")
    }

    /// The decoded description of `frame`.
    static func description(_ frame: VoxelOrigamiGolden.Frame) throws -> Description {
        let data: Data = try VoxelOrigamiGolden.description(frame)
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
        return VoxelOrigamiTest.inside(p, width: VoxelOrigamiGolden.width, height: VoxelOrigamiGolden.height)
    }

    /// The CPU reference pixel of `point` through `camera` at the golden size, or nil when it does not project or
    /// lies outside the picture (the description writes null then).
    static func referencePixel(_ point: SIMD3<Double>, camera: VoxelOrigamiCamera) -> SIMD2<Double>? {
        let width: Int = VoxelOrigamiGolden.width
        let height: Int = VoxelOrigamiGolden.height
        guard let p: SIMD2<Double> = VoxelOrigamiTest.project(point, camera, width: width, height: height),
              p.x >= 0, p.y >= 0, p.x <= Double(width), p.y <= Double(height) else { return nil }
        return p
    }

    /// The described position `described` against the CPU reference pixel of `point`; returns the miss (a
    /// disagreement or a position off screen) naming `what`, or nil.
    static func positionMiss(_ what: String, described: [Int]?, point: SIMD3<Double>, camera: VoxelOrigamiCamera,
                             quantum: Int) -> String? {
        let reference: SIMD2<Double>? = referencePixel(point, camera: camera)
        if !agrees(described, reference, quantum: quantum) {
            return "\(what) described \(String(describing: described)), reference \(String(describing: reference))"
        }
        if !onScreen(described, quantum: quantum) {
            return "\(what) described \(String(describing: described)) is off screen"
        }
        return nil
    }

    /// The described positions `described` against the CPU reference pixels of `points`; returns the misses, each
    /// naming `what` and the index.
    static func positionMisses(_ what: String, described: [[Int]?], points: [SIMD3<Double>],
                               camera: VoxelOrigamiCamera, quantum: Int) -> [String] {
        if described.count != points.count {
            return ["\(described.count) \(what) points described, reference \(points.count)"]
        }
        var misses: [String] = []
        for index in points.indices {
            if let miss: String = positionMiss("\(what) \(index)", described: described[index], point: points[index],
                                               camera: camera, quantum: quantum) {
                misses.append(miss)
            }
        }
        return misses
    }

    /// Every field of `shown` that differs from `golden`.
    static func snapshotMisses(_ shown: VoxelOrigamiSceneSnapshot, _ golden: VoxelOrigamiSceneSnapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.cubes != golden.cubes { misses.append("cubes \(shown.cubes.count), golden \(golden.cubes.count)") }
        if shown.cells != golden.cells { misses.append("cells") }
        if shown.orientations != golden.orientations { misses.append("orientations") }
        if shown.turns != golden.turns { misses.append("turns \(shown.turns), golden \(golden.turns)") }
        if shown.turnable != golden.turnable {
            misses.append("turnable \(shown.turnable), golden \(golden.turnable)")
        }
        if shown.chosenHinge != golden.chosenHinge {
            misses.append("chosen hinge \(shown.chosenHinge), golden \(golden.chosenHinge)")
        }
        if shown.target != golden.target { misses.append("target") }
        if shown.report != golden.report { misses.append("report") }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.actionsLeft != golden.actionsLeft {
            misses.append("actions left \(shown.actionsLeft), golden \(golden.actionsLeft)")
        }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.time != golden.time { misses.append("time \(shown.time), golden \(golden.time)") }
        if misses.isEmpty && shown != golden { misses.append("an unnamed field") }
        return misses
    }

    /// The description check: the frame's identity and size, counts, colours and every position agreeing with the CPU
    /// reference of `golden` and on screen. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: VoxelOrigamiGolden.Frame,
                                  golden: VoxelOrigamiSceneSnapshot) -> [String] {
        typealias Geometry = VoxelOrigamiSceneGeometry
        var misses: [String] = []
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level { misses.append("level \(described.level)") }
        if described.tier != frame.tier { misses.append("tier \(described.tier)") }
        if described.width != VoxelOrigamiTest.width { misses.append("width \(described.width)") }
        if described.height != VoxelOrigamiTest.height { misses.append("height \(described.height)") }
        if quantum != Self.quantum { misses.append("quantum \(quantum)") }
        let counts: Counts = described.counts
        let cubes: Int = golden.cubes.count
        if counts.cubes != cubes { misses.append("cubes \(counts.cubes), snapshot \(cubes)") }
        if counts.hinges != max(cubes - 1, 0) { misses.append("hinges \(counts.hinges), snapshot \(cubes - 1)") }
        if counts.targets != golden.target.count {
            misses.append("targets \(counts.targets), snapshot \(golden.target.count)")
        }
        if counts.inPlace != golden.report.covered {
            misses.append("in place \(counts.inPlace), snapshot \(golden.report.covered)")
        }
        if counts.litPips != Geometry.litPips(golden) {
            misses.append("lit pips \(counts.litPips), snapshot \(Geometry.litPips(golden))")
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
        let camera: VoxelOrigamiCamera = VoxelOrigamiTest.camera(golden, width: VoxelOrigamiGolden.width,
                                                                 height: VoxelOrigamiGolden.height)
        var cubePoints: [SIMD3<Double>] = []
        for index in golden.cells.indices { cubePoints.append(Geometry.cubeCentre(index, golden)) }
        var markPoints: [SIMD3<Double>] = []
        var hinge: Int = 1
        while hinge < cubes {
            markPoints.append(Geometry.hingeMark(hinge, golden, camera: camera))
            hinge += 1
        }
        var targetPoints: [SIMD3<Double>] = []
        for cell in golden.target { targetPoints.append(Geometry.world(cell, golden)) }
        misses += positionMisses("cube centre", described: described.cubeCentres, points: cubePoints, camera: camera,
                                 quantum: quantum)
        misses += positionMisses("hinge mark", described: described.hingeMarks, points: markPoints, camera: camera,
                                 quantum: quantum)
        misses += positionMisses("target centre", described: described.targetCentres, points: targetPoints,
                                 camera: camera, quantum: quantum)
        if cubes > 0 {
            if let miss: String = positionMiss("first pip", described: described.firstPip,
                                               point: Geometry.coveredPip(0, golden), camera: camera,
                                               quantum: quantum) {
                misses.append(miss)
            }
        } else if described.firstPip != nil {
            misses.append("first pip described without a cube")
        }
        if golden.budget > 0 {
            if let miss: String = positionMiss("first moves bar", described: described.firstMovesBar,
                                               point: Geometry.movesBar(0, golden), camera: camera,
                                               quantum: quantum) {
                misses.append(miss)
            }
        } else {
            misses.append("the golden snapshot has no moves budget")
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check and the feature-443 frame checks against the presenter's last snapshot;
    /// every issue names the frame. Returns the frame-check report.
    static func check(_ frame: VoxelOrigamiGolden.Frame, session: ExperienceSession,
                      shell: VoxelOrigamiTest.Shell) throws -> VoxelOrigamiCheckReport {
        let width: Int = VoxelOrigamiGolden.width
        let height: Int = VoxelOrigamiGolden.height
        VoxelOrigamiTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try VoxelOrigamiTest.still(session, width: width, height: height, time: frame.time)
        let shown: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: VoxelOrigamiSceneSnapshot = try VoxelOrigamiGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(shown.time == golden.time, "\(frame.name): the drawn time is \(shown.time)")
        #expect(golden.chosenHinge == frame.hinge, "\(frame.name): golden hinge \(golden.chosenHinge)")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(described.counts.cubes > 1, "\(frame.name): the frame has no hinge")
        let report: VoxelOrigamiCheckReport = VoxelOrigamiTest.checkFrame(
            rgba, snapshot: shown, width: width, height: height, require: false, frame.name)
        print("voxel-origami golden \(frame.name): actions left \(golden.actionsLeft) of \(golden.budget), cubes "
              + "\(described.counts.cubes), in place \(described.counts.inPlace), cubes checked "
              + "\(report.cubeChecked), hinge \(frame.hinge) checked \(report.hingeChecked), moves checked "
              + "\(report.movesChecked)")
        return report
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing their turns (the certified turns
    /// without the last, the level still open) with hinge 1 chosen, and the hero frame (the manifest seed's level, tier
    /// 0, the hero scenario's turns and the last certified turn's hinge), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() throws {
        let frames: [VoxelOrigamiGolden.Frame] = VoxelOrigamiGolden.frames
        #expect(frames.count == 16)
        #expect(VoxelOrigamiGolden.width == VoxelOrigamiTest.width)
        #expect(VoxelOrigamiGolden.height == VoxelOrigamiTest.height)
        #expect(VoxelOrigamiGolden.quantum == Self.quantum)
        #expect(VoxelOrigamiGolden.levels == Self.levels)
        #expect(VoxelOrigamiGolden.chosenHinge == Self.chosenHinge)
        var names: [String] = []
        for entry in Self.palette { names.append(entry.name) }
        #expect(VoxelOrigamiGolden.colourNames == names, "the described colour names")
        let heroLevel: Int = VoxelOrigamiExperienceCore.levelNumber(forSeed: VoxelOrigamiExperienceCore.manifestSeed)
        let heroTurns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(heroLevel)
        let heroLast: VoxelOrigamiAction = try #require(heroTurns.last, "the hero level has a certified plan")
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0)
            #expect(frame.actions == Array(heroTurns.dropLast()), "the hero frame plays the hero scenario's turns")
            #expect(frame.hinge == VoxelOrigamiExperienceCore.hinge(of: heroLast),
                    "the hero frame chooses the hinge of the last certified turn")
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in Self.levels {
            let tiers: [VoxelOrigamiGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [VoxelOrigamiAction] = tiers.first?.actions ?? []
            let expected: [VoxelOrigamiAction] = try Self.openTurns(level)
            #expect(actions == expected, "level \(level): the frames play the certified turns without the last")
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == actions, "\(frame.name): the tier frames share their turns")
                #expect(frame.hinge == Self.chosenHinge, "\(frame.name): hinge \(frame.hinge)")
                tierIndex += 1
            }
            if let first: VoxelOrigamiGolden.Frame = tiers.first {
                let golden: VoxelOrigamiSceneSnapshot = try VoxelOrigamiGolden.snapshot(first)
                #expect(golden.levelNumber == level, "\(first.name): level \(golden.levelNumber)")
                #expect(golden.stage == .playing, "\(first.name): stage \(golden.stage)")
                #expect(golden.failure == nil, "\(first.name): the golden frame has failed")
                #expect(golden.actionsLeft == golden.budget - actions.count,
                        "\(first.name): actions left \(golden.actionsLeft)")
            }
        }
        var unique: Set<String> = []
        for frame in frames { unique.insert(frame.name) }
        #expect(unique.count == 16, "frame names are unique")
    }

    /// The 15 level frames render as their golden snapshots and descriptions say; each tier measures at least one
    /// cube centre summed over the five levels.
    @Test func everyLevelFrameMatchesItsDescription() async throws {
        var cubes: [Int] = [0, 0, 0]
        var hinges: [Int] = [0, 0, 0]
        for level in Self.levels {
            let frames: [VoxelOrigamiGolden.Frame] = Self.tierFrames(level: level)
            #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
            guard let first: VoxelOrigamiGolden.Frame = frames.first else { continue }
            let session = ExperienceSession()
            defer { session.close() }
            let shell: VoxelOrigamiTest.Shell = try await Self.open(session, level: level)
            // The three tier frames share their turns and hinge: apply them once, then draw each tier.
            try Self.apply(first, to: shell)
            for frame in frames {
                #expect(frame.actions == first.actions && frame.hinge == first.hinge,
                        "\(frame.name): the tier frames share their turns and hinge")
                let report: VoxelOrigamiCheckReport = try Self.check(frame, session: session, shell: shell)
                if frame.tier >= 0 && frame.tier < 3 {
                    cubes[frame.tier] += report.cubeChecked
                    hinges[frame.tier] += report.hingeChecked ? 1 : 0
                }
            }
            session.qualityPin = 0
        }
        print("voxel-origami golden level frames: cubes per tier \(cubes), hinges per tier \(hinges)")
        for tier in 0..<3 {
            #expect(cubes[tier] > 0, "tier \(tier): no cube centre measured over the golden frames")
        }
    }

    /// The hero frame (the manifest seed's level after the hero scenario's turns, the last turn's hinge chosen, tier
    /// 0) renders as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [VoxelOrigamiGolden.Frame] = []
        for frame in VoxelOrigamiGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: VoxelOrigamiGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: VoxelOrigamiTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try VoxelOrigamiTest.digest(shell)
        try Self.apply(hero, to: shell)
        let after: String = try VoxelOrigamiTest.digest(shell)
        if !hero.actions.isEmpty { #expect(after != before, "the hero turns change the digest") }
        _ = try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
