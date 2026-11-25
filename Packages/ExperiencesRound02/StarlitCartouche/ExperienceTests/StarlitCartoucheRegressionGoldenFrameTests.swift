// StarlitCartoucheRegressionGoldenFrameTests — feature 458 (R02-G16-08) T-R02G1608-005 (FR-R02G1608-003, 004;
// SC-R02G1608-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `StarlitCartoucheGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after all
// of its witness's legs but the last, so the symbol is part drawn and the level is still open, with the default
// choice; plus the hero frame: the manifest seed's level after the hero scenario's actions, the certified legs without
// the last and that leg's destination and wait chosen, tier 0) is drawn off screen at the frame-check size
// 1,152 × 768 of `StarlitCartoucheTest` with the frame's tier pinned, at the frame's time 0. Seed s opens level
// s % 100 + 1, so a frame of level L opens at seed L − 1; the frame's legs go through the session's action port
// (`route.fly`) and its choice through `route.choose` (presentation only: the digest does not change). The glide clock
// is primed (`StarlitCartoucheTest.prime`) so the ship rests at its star, as the description places it. The snapshot
// the presenter drew equals `StarlitCartoucheGolden.snapshot(frame)` (every field, the presentation time 0 in both),
// so the rendered frame is the golden one. The frame's description (`StarlitCartoucheGolden.description`, decoded
// here) carries the counts, the choice and every named colour, and puts every star centre, every trail midpoint, the
// ship, the beacon and the first actions bar where the Core's CPU reference of the golden snapshot puts them (within
// one 1/8-pixel quantum); every star, the ship and the beacon are on screen. The picture then passes the feature-453
// checks (`StarlitCartoucheTest.checkFrame`) against the presenter's last snapshot: at every point at least 6 px from
// every element drawn after it in the painter's order (`StarlitCartoucheSceneGeometry.paintOrder`) that could hide
// it, a star's centre has a pixel within 3 px brighter than the backdrop by 0.25 in luminance; the ship's centre has
// blue above red by 0.08; a trail's point red above blue by 0.08; the first actions bar is 0.1 from the backdrop; the
// median of every 9 × 9 backdrop patch is within 0.06 of the firmament gradient. Each tier measures at least one star
// centre summed over the level frames. One test for the set, one for the 15 level frames (15 stills, as the
// feature-453 render test draws) and one for the hero frame, each well under 10 s. Modelled on
// `VoxelOrigamiRegressionGoldenFrameTests` (feature 448). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
#if os(iOS)
import Foundation
import StarlitCartoucheCore
import Testing
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct StarlitCartoucheRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of the description.
    struct Counts: Decodable, Equatable {
        let stars: Int
        let corridors: Int
        let hazards: Int
        let activeHazards: Int
        let symbol: Int
        let drawn: Int
        let litActions: Int
        let actions: Int
    }

    /// The description of one golden frame, decoded from `StarlitCartoucheGolden.description(_:)`. A position is
    /// `[x, y]` in 1/`quantum` pixel, or null when it does not project into the frame.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let chosenStar: Int
        let chosenWait: Int
        let counts: Counts
        let colours: [String: Colour]
        let stars: [[Int]?]
        let trails: [[Int]?]
        let ship: [Int]?
        let beacon: [Int]?
        let firstActionsBar: [Int]?
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described in units of 1/`quantum` pixel (clarification Q3: 1/8 pixel).
    static let quantum: Int = 8
    /// The named colours of the description and the palette colour each must equal.
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("night", StarlitCartouchePalette.night), ("nightTop", StarlitCartouchePalette.nightTop),
        ("speck", StarlitCartouchePalette.speck), ("pearl", StarlitCartouchePalette.pearl),
        ("pearlShade", StarlitCartouchePalette.pearlShade), ("corridor", StarlitCartouchePalette.corridor),
        ("symbolDash", StarlitCartouchePalette.symbolDash), ("trail", StarlitCartouchePalette.trail),
        ("trailGlow", StarlitCartouchePalette.trailGlow), ("ship", StarlitCartouchePalette.ship),
        ("shipGlow", StarlitCartouchePalette.shipGlow), ("beacon", StarlitCartouchePalette.beacon),
        ("chosen", StarlitCartouchePalette.chosen), ("hazardActive", StarlitCartouchePalette.hazardActive),
        ("hazardIdle", StarlitCartouchePalette.hazardIdle), ("actionsLit", StarlitCartouchePalette.actionsLit),
        ("actionsUnlit", StarlitCartouchePalette.actionsUnlit), ("beatTrack", StarlitCartouchePalette.beatTrack),
        ("waitLit", StarlitCartouchePalette.waitLit), ("waitUnlit", StarlitCartouchePalette.waitUnlit),
        ("broken", StarlitCartouchePalette.broken), ("glow", StarlitCartouchePalette.glow),
    ]

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [StarlitCartoucheGolden.Frame] {
        var list: [StarlitCartoucheGolden.Frame] = []
        for frame in StarlitCartoucheGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// The certified legs of `level` without the last (none for a one-leg plan).
    static func openLegs(_ level: Int) throws -> [StarlitCartoucheAction] {
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(level)
        return Array(legs.dropLast())
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it, drawn with motion.
    static func open(_ session: ExperienceSession, level: Int) async throws -> StarlitCartoucheTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(StarlitCartoucheExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: StarlitCartoucheTest.Shell = try await StarlitCartoucheTest.open(session, seed: seed)
        let opened: Int = try StarlitCartoucheTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// Sends `frame`'s legs through the session's action port, each expected to be accepted, then chooses the frame's
    /// destination and wait (`route.choose`, presentation only: the digest does not change) when they differ from the
    /// core's; a frame without a chosen star keeps the default destination. Primes the glide clock afterwards, so the
    /// next still shows the ship at rest.
    static func apply(_ frame: StarlitCartoucheGolden.Frame, to shell: StarlitCartoucheTest.Shell,
                      session: ExperienceSession) throws {
        let accepted: Int = StarlitCartoucheTest.issue(shell, frame.actions)
        #expect(accepted == frame.actions.count, "\(frame.name): \(accepted) of \(frame.actions.count) legs accepted")
        let digest: String = try StarlitCartoucheTest.digest(shell)
        let core: StarlitCartoucheExperienceCore = try StarlitCartoucheTest.core(shell)
        let star: Int = frame.chosenStar ?? core.chosenStar
        if core.chosenStar != star || core.chosenWait != frame.chosenWait {
            let values: [Double] = [Double(star), Double(frame.chosenWait)]
            let result: ActionResult = shell.handle(control: "route.choose", values: values)
            #expect(result == .accepted, "\(frame.name): route.choose \(values): \(result.code)")
        }
        let chosen: StarlitCartoucheExperienceCore = try StarlitCartoucheTest.core(shell)
        #expect(chosen.chosenStar == star, "\(frame.name): star \(chosen.chosenStar) chosen, not \(star)")
        #expect(chosen.chosenWait == frame.chosenWait,
                "\(frame.name): wait \(chosen.chosenWait) chosen, not \(frame.chosenWait)")
        #expect(try StarlitCartoucheTest.digest(shell) == digest, "\(frame.name): choosing leaves the digest")
        try StarlitCartoucheTest.prime(session)
    }

    /// The decoded description of `frame`.
    static func description(_ frame: StarlitCartoucheGolden.Frame) throws -> Description {
        let data: Data = try StarlitCartoucheGolden.description(frame)
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
        return StarlitCartoucheTest.inside(p, width: StarlitCartoucheGolden.width,
                                           height: StarlitCartoucheGolden.height)
    }

    /// The CPU reference pixel of `point` through `camera` at the golden size, or nil when it does not project or
    /// lies outside the picture (the description writes null then).
    static func referencePixel(_ point: SIMD3<Double>, camera: StarlitCartoucheCamera) -> SIMD2<Double>? {
        let width: Int = StarlitCartoucheGolden.width
        let height: Int = StarlitCartoucheGolden.height
        guard let p: SIMD2<Double> = StarlitCartoucheTest.project(point, camera, width: width, height: height),
              p.x >= 0, p.y >= 0, p.x <= Double(width), p.y <= Double(height) else { return nil }
        return p
    }

    /// The described position `described` against the CPU reference pixel of `point`; returns the miss (a
    /// disagreement, or a position off screen when `required`) naming `what`, or nil.
    static func positionMiss(_ what: String, described: [Int]?, point: SIMD3<Double>,
                             camera: StarlitCartoucheCamera, quantum: Int, required: Bool) -> String? {
        let reference: SIMD2<Double>? = referencePixel(point, camera: camera)
        if !agrees(described, reference, quantum: quantum) {
            return "\(what) described \(String(describing: described)), reference \(String(describing: reference))"
        }
        if required && !onScreen(described, quantum: quantum) {
            return "\(what) described \(String(describing: described)) is off screen"
        }
        return nil
    }

    /// The described positions `described` against the CPU reference pixels of `points`; returns the misses, each
    /// naming `what` and the index.
    static func positionMisses(_ what: String, described: [[Int]?], points: [SIMD3<Double>],
                               camera: StarlitCartoucheCamera, quantum: Int, required: Bool) -> [String] {
        if described.count != points.count {
            return ["\(described.count) \(what) points described, reference \(points.count)"]
        }
        var misses: [String] = []
        for index in points.indices {
            if let miss: String = positionMiss("\(what) \(index)", described: described[index], point: points[index],
                                               camera: camera, quantum: quantum, required: required) {
                misses.append(miss)
            }
        }
        return misses
    }

    /// Every field of `shown` that differs from `golden`.
    static func snapshotMisses(_ shown: StarlitCartoucheSceneSnapshot,
                               _ golden: StarlitCartoucheSceneSnapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.stars != golden.stars { misses.append("stars \(shown.stars.count), golden \(golden.stars.count)") }
        if shown.positions != golden.positions { misses.append("positions") }
        if shown.corridors != golden.corridors { misses.append("corridors") }
        if shown.hazards != golden.hazards { misses.append("hazards") }
        if shown.active != golden.active { misses.append("active \(shown.active), golden \(golden.active)") }
        if shown.legs != golden.legs { misses.append("legs \(shown.legs.count), golden \(golden.legs.count)") }
        if shown.departures != golden.departures { misses.append("departures") }
        if shown.arrivals != golden.arrivals { misses.append("arrivals") }
        if shown.drawn != golden.drawn { misses.append("drawn \(shown.drawn), golden \(golden.drawn)") }
        if shown.symbol != golden.symbol { misses.append("symbol \(shown.symbol), golden \(golden.symbol)") }
        if shown.star != golden.star { misses.append("star \(shown.star), golden \(golden.star)") }
        if shown.beat != golden.beat { misses.append("beat \(shown.beat), golden \(golden.beat)") }
        if shown.beacon != golden.beacon { misses.append("beacon \(shown.beacon), golden \(golden.beacon)") }
        if shown.deadline != golden.deadline { misses.append("deadline \(shown.deadline), golden \(golden.deadline)") }
        if shown.chosenStar != golden.chosenStar {
            misses.append("chosen star \(shown.chosenStar), golden \(golden.chosenStar)")
        }
        if shown.chosenWait != golden.chosenWait {
            misses.append("chosen wait \(shown.chosenWait), golden \(golden.chosenWait)")
        }
        if shown.launchBeat != golden.launchBeat {
            misses.append("launch beat \(shown.launchBeat), golden \(golden.launchBeat)")
        }
        if shown.launchPositions != golden.launchPositions { misses.append("launch positions") }
        if shown.report != golden.report { misses.append("report") }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.failedLeg != golden.failedLeg { misses.append("failed leg") }
        if shown.actionsLeft != golden.actionsLeft {
            misses.append("actions left \(shown.actionsLeft), golden \(golden.actionsLeft)")
        }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.time != golden.time { misses.append("time \(shown.time), golden \(golden.time)") }
        if misses.isEmpty && shown != golden { misses.append("an unnamed field") }
        return misses
    }

    /// The counts, choice and colours of `described` against `golden`. Returns the misses.
    static func countMisses(_ described: Description, golden: StarlitCartoucheSceneSnapshot) -> [String] {
        var misses: [String] = []
        let counts: Counts = described.counts
        var active: Int = 0
        for flag in golden.active where flag { active += 1 }
        let lit: Int = StarlitCartoucheSceneGeometry.litActions(golden)
        if counts.stars != golden.stars.count { misses.append("stars \(counts.stars), snapshot \(golden.stars.count)") }
        if counts.corridors != golden.corridors.count {
            misses.append("corridors \(counts.corridors), snapshot \(golden.corridors.count)")
        }
        if counts.hazards != golden.hazards.count {
            misses.append("hazards \(counts.hazards), snapshot \(golden.hazards.count)")
        }
        if counts.activeHazards != active {
            misses.append("active hazards \(counts.activeHazards), snapshot \(active)")
        }
        if counts.symbol != golden.symbol.count {
            misses.append("symbol \(counts.symbol), snapshot \(golden.symbol.count)")
        }
        if counts.drawn != golden.drawn.count { misses.append("drawn \(counts.drawn), snapshot \(golden.drawn.count)") }
        if counts.litActions != lit { misses.append("lit actions \(counts.litActions), snapshot \(lit)") }
        if counts.actions != max(golden.budget, 0) {
            misses.append("actions \(counts.actions), budget \(golden.budget)")
        }
        if described.chosenStar != golden.chosenStar {
            misses.append("chosen star \(described.chosenStar), snapshot \(golden.chosenStar)")
        }
        if described.chosenWait != golden.chosenWait {
            misses.append("chosen wait \(described.chosenWait), snapshot \(golden.chosenWait)")
        }
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
        return misses
    }

    /// The description check: the frame's identity and size, counts, choice, colours and every position agreeing with
    /// the CPU reference of `golden` (stars, ship and beacon also on screen). Returns the misses.
    static func descriptionMisses(_ described: Description, frame: StarlitCartoucheGolden.Frame,
                                  golden: StarlitCartoucheSceneSnapshot) -> [String] {
        typealias Geometry = StarlitCartoucheSceneGeometry
        var misses: [String] = []
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level { misses.append("level \(described.level)") }
        if described.tier != frame.tier { misses.append("tier \(described.tier)") }
        if described.width != StarlitCartoucheTest.width { misses.append("width \(described.width)") }
        if described.height != StarlitCartoucheTest.height { misses.append("height \(described.height)") }
        if quantum != Self.quantum { misses.append("quantum \(quantum)") }
        misses += countMisses(described, golden: golden)
        let camera: StarlitCartoucheCamera = StarlitCartoucheTest.camera(golden, width: StarlitCartoucheGolden.width,
                                                                         height: StarlitCartoucheGolden.height)
        var starPoints: [SIMD3<Double>] = []
        for index in golden.positions.indices { starPoints.append(Geometry.starCentre(index, golden)) }
        var trailPoints: [SIMD3<Double>] = []
        for leg in golden.legs.indices { trailPoints.append(Geometry.trailMidpoint(leg, golden)) }
        misses += positionMisses("star centre", described: described.stars, points: starPoints, camera: camera,
                                 quantum: quantum, required: true)
        misses += positionMisses("trail midpoint", described: described.trails, points: trailPoints, camera: camera,
                                 quantum: quantum, required: false)
        if let miss: String = positionMiss("ship", described: described.ship, point: Geometry.shipCentre(golden),
                                           camera: camera, quantum: quantum, required: true) {
            misses.append(miss)
        }
        if let miss: String = positionMiss("beacon", described: described.beacon,
                                           point: Geometry.starCentre(golden.beacon, golden), camera: camera,
                                           quantum: quantum, required: true) {
            misses.append(miss)
        }
        if golden.budget > 0 {
            if let miss: String = positionMiss("first actions bar", described: described.firstActionsBar,
                                               point: Geometry.actionsBar(0, golden), camera: camera,
                                               quantum: quantum, required: false) {
                misses.append(miss)
            }
        } else {
            misses.append("the golden snapshot has no actions budget")
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check and the feature-453 frame checks against the presenter's last snapshot;
    /// every issue names the frame. Returns the frame-check report.
    static func check(_ frame: StarlitCartoucheGolden.Frame, session: ExperienceSession,
                      shell: StarlitCartoucheTest.Shell) throws -> StarlitCartoucheCheckReport {
        let width: Int = StarlitCartoucheGolden.width
        let height: Int = StarlitCartoucheGolden.height
        StarlitCartoucheTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try StarlitCartoucheTest.still(session, width: width, height: height, time: frame.time)
        let shown: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                                "\(frame.name): no snapshot")
        let golden: StarlitCartoucheSceneSnapshot = try StarlitCartoucheGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(shown.time == golden.time, "\(frame.name): the drawn time is \(shown.time)")
        if let star: Int = frame.chosenStar {
            #expect(golden.chosenStar == star, "\(frame.name): golden star \(golden.chosenStar)")
        }
        #expect(golden.chosenWait == frame.chosenWait, "\(frame.name): golden wait \(golden.chosenWait)")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        #expect(shell.presenter.lastGlide == 1, "\(frame.name): the ship rests at its star")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(described.counts.stars > 1, "\(frame.name): the frame has fewer than two stars")
        let angle: Double = shell.presenter.scene.lastFirmamentAngle
        let report: StarlitCartoucheCheckReport = StarlitCartoucheTest.checkFrame(
            rgba, snapshot: shown, width: width, height: height, requireStar: false, angle: angle, frame.name)
        print("starlit-cartouche golden \(frame.name): actions left \(golden.actionsLeft) of \(golden.budget), legs "
              + "\(golden.legs.count), drawn \(described.counts.drawn) of \(described.counts.symbol), stars checked "
              + "\(report.starsChecked), ship checked \(report.shipChecked), trails checked \(report.trailsChecked), "
              + "actions checked \(report.actionsChecked), patches \(report.patchesChecked)")
        return report
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing their legs (the certified legs
    /// without the last, the level still open) with the default choice, and the hero frame (the manifest seed's level,
    /// tier 0, the hero scenario's legs and the last certified leg's destination and wait), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() throws {
        typealias Core = StarlitCartoucheExperienceCore
        let frames: [StarlitCartoucheGolden.Frame] = StarlitCartoucheGolden.frames
        #expect(frames.count == 16)
        #expect(StarlitCartoucheGolden.width == StarlitCartoucheTest.width)
        #expect(StarlitCartoucheGolden.height == StarlitCartoucheTest.height)
        #expect(StarlitCartoucheGolden.quantum == Self.quantum)
        #expect(StarlitCartoucheGolden.levels == Self.levels)
        var names: [String] = []
        for entry in Self.palette { names.append(entry.name) }
        #expect(StarlitCartoucheGolden.colourNames == names, "the described colour names")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        let heroLegs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(heroLevel)
        let heroLast: StarlitCartoucheAction = try #require(heroLegs.last, "the hero level has a certified plan")
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0)
            #expect(frame.actions == Array(heroLegs.dropLast()), "the hero frame plays the hero scenario's legs")
            #expect(frame.chosenStar == Core.destination(of: heroLast),
                    "the hero frame chooses the destination of the last certified leg")
            #expect(frame.chosenWait == Core.wait(of: heroLast), "the hero frame chooses the last leg's wait")
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in Self.levels {
            let tiers: [StarlitCartoucheGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [StarlitCartoucheAction] = tiers.first?.actions ?? []
            let expected: [StarlitCartoucheAction] = try Self.openLegs(level)
            #expect(actions == expected, "level \(level): the frames play the certified legs without the last")
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == actions, "\(frame.name): the tier frames share their legs")
                #expect(frame.chosenStar == nil, "\(frame.name): the default destination")
                #expect(frame.chosenWait == 0, "\(frame.name): wait \(frame.chosenWait)")
                tierIndex += 1
            }
            if let first: StarlitCartoucheGolden.Frame = tiers.first {
                let golden: StarlitCartoucheSceneSnapshot = try StarlitCartoucheGolden.snapshot(first)
                #expect(golden.levelNumber == level, "\(first.name): level \(golden.levelNumber)")
                #expect(golden.stage == .playing, "\(first.name): stage \(golden.stage)")
                #expect(golden.failure == nil, "\(first.name): the golden frame has failed")
                #expect(golden.legs.count == actions.count, "\(first.name): \(golden.legs.count) trails")
                #expect(golden.actionsLeft == golden.budget - actions.count,
                        "\(first.name): actions left \(golden.actionsLeft)")
            }
        }
        var unique: Set<String> = []
        for frame in frames { unique.insert(frame.name) }
        #expect(unique.count == 16, "frame names are unique")
    }

    /// The 15 level frames render as their golden snapshots and descriptions say; each tier measures at least one
    /// star centre summed over the five levels.
    @Test func everyLevelFrameMatchesItsDescription() async throws {
        var stars: [Int] = [0, 0, 0]
        var ships: [Int] = [0, 0, 0]
        for level in Self.levels {
            let frames: [StarlitCartoucheGolden.Frame] = Self.tierFrames(level: level)
            #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
            guard let first: StarlitCartoucheGolden.Frame = frames.first else { continue }
            let session = ExperienceSession()
            defer { session.close() }
            let shell: StarlitCartoucheTest.Shell = try await Self.open(session, level: level)
            // The three tier frames share their legs and choice: apply them once, then draw each tier.
            try Self.apply(first, to: shell, session: session)
            for frame in frames {
                #expect(frame.actions == first.actions && frame.chosenStar == first.chosenStar
                            && frame.chosenWait == first.chosenWait,
                        "\(frame.name): the tier frames share their legs and choice")
                let report: StarlitCartoucheCheckReport = try Self.check(frame, session: session, shell: shell)
                if frame.tier >= 0 && frame.tier < 3 {
                    stars[frame.tier] += report.starsChecked
                    ships[frame.tier] += report.shipChecked ? 1 : 0
                }
            }
            session.qualityPin = 0
        }
        print("starlit-cartouche golden level frames: stars per tier \(stars), ships per tier \(ships)")
        for tier in 0..<3 {
            #expect(stars[tier] > 0, "tier \(tier): no star centre measured over the golden frames")
        }
    }

    /// The hero frame (the manifest seed's level after the hero scenario's legs, the last leg's destination and wait
    /// chosen, tier 0) renders as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [StarlitCartoucheGolden.Frame] = []
        for frame in StarlitCartoucheGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: StarlitCartoucheGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: StarlitCartoucheTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try StarlitCartoucheTest.digest(shell)
        try Self.apply(hero, to: shell, session: session)
        let after: String = try StarlitCartoucheTest.digest(shell)
        if !hero.actions.isEmpty { #expect(after != before, "the hero legs change the digest") }
        _ = try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
