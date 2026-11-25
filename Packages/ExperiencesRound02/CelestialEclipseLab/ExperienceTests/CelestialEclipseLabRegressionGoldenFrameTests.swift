// CelestialEclipseLabRegressionGoldenFrameTests — feature 468 (R02-G17-08) T-R02G1708-005 (FR-R02G1708-003, 004;
// SC-R02G1708-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `CelestialEclipseLabGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after
// all of its certified phase changes but not the run, so actions are spent and the level is still open, with the
// default chosen body at the first tick of the predicted timeline at which an eclipse is under way; plus the hero
// frame: the manifest seed's level after the certified phase changes, the last moved body chosen and the hero tick
// shown, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of `CelestialEclipseLabTest` with the frame's
// tier pinned, at the frame's time 0. Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1; the
// frame's phase changes go through the session's action port (`orbit.phase`), its body through `orbit.choose` and its
// tick through `clock.show` (presentation only: the digest does not change). There is no glide: the shown tick is the
// adapter's presentation state. The snapshot the presenter drew equals `CelestialEclipseLabGolden.snapshot(frame)`
// (every field, the presentation time 0 in both), so the rendered frame is the golden one. The frame's description
// (`CelestialEclipseLabGolden.description`, decoded here) carries the counts, the chosen body, the tick and every named
// colour, and puts every body centre, every shadow lens centre, every halo, the playhead and the first actions bar
// where the Core's CPU reference of the golden snapshot puts them (within one 1/8-pixel quantum); every body, halo and
// the playhead are on screen. The picture then passes the feature-463 checks (`CelestialEclipseLabTest.checkFrame`)
// against the presenter's last snapshot: at every point at least 6 px from every element drawn after it in the
// painter's order (`CelestialEclipseLabSceneGeometry.paintOrder`) that could hide it, the centre of a body not covered
// at the shown tick has a pixel within 3 px brighter than the backdrop by 0.25 in luminance; the first lit actions bar
// red above blue by 0.08; the timeline strip's centre 0.1 from the backdrop; the median of every 9 × 9 backdrop patch
// within 0.06 of the gradient. Each tier measures at least one body centre summed over the level frames. One test for
// the set, one for the 15 level frames and one for the hero frame, each well under 10 s. Modelled on
// `StarlitCartoucheRegressionGoldenFrameTests` (feature 458). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
#if os(iOS)
import CelestialEclipseLabCore
import Foundation
import Testing
@testable import CelestialEclipseLabExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct CelestialEclipseLabRegressionGoldenFrameTests {
    typealias Geometry = CelestialEclipseLabSceneGeometry
    typealias Snapshot = CelestialEclipseLabSceneSnapshot
    typealias Palette = CelestialEclipseLabPalette

    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of the description.
    struct Counts: Decodable, Equatable {
        let bodies: Int
        let rings: Int
        let lenses: Int
        let halos: Int
        let targets: Int
        let matched: Int
        let litActions: Int
        let actions: Int
    }

    /// The description of one golden frame, decoded from `CelestialEclipseLabGolden.description(_:)`. A position is
    /// `[x, y]` in 1/`quantum` pixel, or null when it does not project into the frame.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let chosenBody: Int
        let tick: Int
        let counts: Counts
        let colours: [String: Colour]
        let bodies: [[Int]?]
        let lenses: [[Int]?]
        let halos: [[Int]?]
        let playhead: [Int]?
        let firstActionsBar: [Int]?
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described in units of 1/`quantum` pixel (clarification Q3: 1/8 pixel).
    static let quantum: Int = 8
    /// The named colours of the description and the palette colour each must equal (21, in the described order).
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("ink", Palette.ink), ("inkTop", Palette.inkTop), ("speck", Palette.speck), ("disc", Palette.disc),
        ("discShade", Palette.discShade), ("orbit", Palette.orbit), ("fixedFrame", Palette.fixedFrame),
        ("chosen", Palette.chosen), ("corona", Palette.corona), ("coronaGlow", Palette.coronaGlow),
        ("crescentShadow", Palette.crescentShadow), ("ember", Palette.ember), ("window", Palette.window),
        ("matched", Palette.matched), ("unwanted", Palette.unwanted), ("faintEvent", Palette.faintEvent),
        ("playhead", Palette.playhead), ("actionsLit", Palette.actionsLit), ("actionsUnlit", Palette.actionsUnlit),
        ("broken", Palette.broken), ("glow", Palette.glow),
    ]

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [CelestialEclipseLabGolden.Frame] {
        var list: [CelestialEclipseLabGolden.Frame] = []
        for frame in CelestialEclipseLabGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// The first tick of `level`'s predicted timeline after its certified phase changes at which an eclipse is under
    /// way (0 when there is none), computed here from the CPU reference core.
    static func firstEclipseTick(_ level: Int) throws -> Int {
        let actions: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(level)
        let play: CelestialEclipseLabPlay = try CelestialEclipseLabTest.coreAfter(level, actions).play
        for tick in 0..<play.level.horizon
        where !Snapshot.eclipses(play.level, phases: play.phases, tick: tick).isEmpty {
            return tick
        }
        return 0
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it, drawn with motion.
    static func open(_ session: ExperienceSession, level: Int) async throws -> CelestialEclipseLabTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(CelestialEclipseLabExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: CelestialEclipseLabTest.Shell = try await CelestialEclipseLabTest.open(session, seed: seed)
        let opened: Int = try CelestialEclipseLabTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// Sends `frame`'s phase changes through the session's action port, each expected to be accepted, then chooses the
    /// frame's body (the default choice when none is given) and shows its tick (`orbit.choose`, `clock.show`,
    /// presentation only: the digest does not change) when they differ from the core's.
    static func apply(_ frame: CelestialEclipseLabGolden.Frame, to shell: CelestialEclipseLabTest.Shell) throws {
        let accepted: Int = CelestialEclipseLabTest.issue(shell, frame.actions)
        #expect(accepted == frame.actions.count,
                "\(frame.name): \(accepted) of \(frame.actions.count) phase changes accepted")
        let digest: String = try CelestialEclipseLabTest.digest(shell)
        let core: CelestialEclipseLabExperienceCore = try CelestialEclipseLabTest.core(shell)
        let body: Int = frame.chosenBody ?? Snapshot.defaultChoice(core.play.level)
        if core.chosenBody != body {
            let result: ActionResult = shell.handle(control: "orbit.choose", values: [Double(body)])
            #expect(result == .accepted, "\(frame.name): orbit.choose \(body): \(result.code)")
        }
        if core.shownTick != frame.tick {
            let result: ActionResult = shell.handle(control: "clock.show", values: [Double(frame.tick)])
            #expect(result == .accepted, "\(frame.name): clock.show \(frame.tick): \(result.code)")
        }
        let chosen: CelestialEclipseLabExperienceCore = try CelestialEclipseLabTest.core(shell)
        #expect(chosen.chosenBody == body, "\(frame.name): body \(chosen.chosenBody) chosen, not \(body)")
        #expect(chosen.shownTick == frame.tick, "\(frame.name): tick \(chosen.shownTick) shown, not \(frame.tick)")
        let after: String = try CelestialEclipseLabTest.digest(shell)
        #expect(after == digest, "\(frame.name): choosing and showing leave the digest")
    }

    /// The decoded description of `frame`.
    static func description(_ frame: CelestialEclipseLabGolden.Frame) throws -> Description {
        let data: Data = try CelestialEclipseLabGolden.description(frame)
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
        return CelestialEclipseLabTest.inside(p, width: CelestialEclipseLabGolden.width,
                                              height: CelestialEclipseLabGolden.height)
    }

    /// The CPU reference pixel of `point` through `camera` at the golden size, or nil when it does not project or
    /// lies outside the picture (the description writes null then).
    static func referencePixel(_ point: SIMD3<Double>, camera: CelestialEclipseLabCamera) -> SIMD2<Double>? {
        let width: Int = CelestialEclipseLabGolden.width
        let height: Int = CelestialEclipseLabGolden.height
        guard let p: SIMD2<Double> = CelestialEclipseLabTest.project(point, camera, width: width, height: height),
              p.x >= 0, p.y >= 0, p.x <= Double(width), p.y <= Double(height) else { return nil }
        return p
    }

    /// The described position `described` against the CPU reference pixel of `point` (nil: no reference point);
    /// returns the miss (a disagreement, or a position off screen when `required`) naming `what`, or nil.
    static func positionMiss(_ what: String, described: [Int]?, point: SIMD3<Double>?,
                             camera: CelestialEclipseLabCamera, quantum: Int, required: Bool) -> String? {
        var reference: SIMD2<Double>?
        if let point { reference = referencePixel(point, camera: camera) }
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
    static func positionMisses(_ what: String, described: [[Int]?], points: [SIMD3<Double>?],
                               camera: CelestialEclipseLabCamera, quantum: Int, required: Bool) -> [String] {
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

    /// The centre of `eclipse`'s shadow lens in `snapshot`: the mean of its outline at the shadow's depth; nil for an
    /// empty lens.
    static func lensCentre(_ eclipse: CelestialEclipseLabEclipse, _ snapshot: Snapshot) -> SIMD3<Double>? {
        let outline: [SIMD2<Double>] = Geometry.shadowLens(eclipse, snapshot)
        guard !outline.isEmpty else { return nil }
        var sum = SIMD2<Double>(0, 0)
        for point in outline { sum += point }
        let mean: SIMD2<Double> = sum / Double(outline.count)
        return SIMD3<Double>(mean.x, mean.y, Geometry.shadowZ(eclipse, snapshot))
    }

    /// Every field of `shown` that differs from `golden`.
    static func snapshotMisses(_ shown: Snapshot, _ golden: Snapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.bodies != golden.bodies {
            misses.append("bodies \(shown.bodies.count), golden \(golden.bodies.count)")
        }
        if shown.phases != golden.phases { misses.append("phases \(shown.phases), golden \(golden.phases)") }
        if shown.positions != golden.positions { misses.append("positions") }
        if shown.eclipses != golden.eclipses {
            misses.append("eclipses \(shown.eclipses.count), golden \(golden.eclipses.count)")
        }
        if shown.target != golden.target { misses.append("target") }
        if shown.intervals != golden.intervals { misses.append("intervals") }
        if shown.matched != golden.matched { misses.append("matched \(shown.matched), golden \(golden.matched)") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.shownTick != golden.shownTick {
            misses.append("tick \(shown.shownTick), golden \(golden.shownTick)")
        }
        if shown.horizon != golden.horizon { misses.append("horizon \(shown.horizon), golden \(golden.horizon)") }
        if shown.chosenBody != golden.chosenBody {
            misses.append("chosen body \(shown.chosenBody), golden \(golden.chosenBody)")
        }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.actionsLeft != golden.actionsLeft {
            misses.append("actions left \(shown.actionsLeft), golden \(golden.actionsLeft)")
        }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.time != golden.time { misses.append("time \(shown.time), golden \(golden.time)") }
        if shown.isPreviewing != golden.isPreviewing { misses.append("preview \(shown.isPreviewing)") }
        if misses.isEmpty && shown != golden { misses.append("an unnamed field") }
        return misses
    }

    /// The counts, chosen body, tick and colours of `described` against `golden`. Returns the misses.
    static func countMisses(_ described: Description, golden: Snapshot) -> [String] {
        var misses: [String] = []
        let counts: Counts = described.counts
        var halos: Int = 0
        for eclipse in golden.eclipses where Geometry.hasHalo(eclipse) { halos += 1 }
        let lit: Int = Geometry.litActions(golden)
        if counts.bodies != golden.bodies.count {
            misses.append("bodies \(counts.bodies), snapshot \(golden.bodies.count)")
        }
        if counts.rings != golden.bodies.count {
            misses.append("rings \(counts.rings), snapshot \(golden.bodies.count)")
        }
        if counts.lenses != golden.eclipses.count {
            misses.append("lenses \(counts.lenses), snapshot \(golden.eclipses.count)")
        }
        if counts.halos != halos { misses.append("halos \(counts.halos), snapshot \(halos)") }
        if counts.targets != golden.target.count {
            misses.append("targets \(counts.targets), snapshot \(golden.target.count)")
        }
        if counts.matched != golden.matched { misses.append("matched \(counts.matched), snapshot \(golden.matched)") }
        if counts.litActions != lit { misses.append("lit actions \(counts.litActions), snapshot \(lit)") }
        if counts.actions != max(golden.budget, 0) {
            misses.append("actions \(counts.actions), budget \(golden.budget)")
        }
        if described.chosenBody != golden.chosenBody {
            misses.append("chosen body \(described.chosenBody), snapshot \(golden.chosenBody)")
        }
        if described.tick != golden.shownTick { misses.append("tick \(described.tick), snapshot \(golden.shownTick)") }
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

    /// The description check: the frame's identity and size, counts, choice, tick, colours and every position
    /// agreeing with the CPU reference of `golden` (bodies, halos and the playhead also on screen). Returns the misses.
    static func descriptionMisses(_ described: Description, frame: CelestialEclipseLabGolden.Frame,
                                  golden: Snapshot) -> [String] {
        var misses: [String] = []
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level { misses.append("level \(described.level)") }
        if described.tier != frame.tier { misses.append("tier \(described.tier)") }
        if described.width != CelestialEclipseLabTest.width { misses.append("width \(described.width)") }
        if described.height != CelestialEclipseLabTest.height { misses.append("height \(described.height)") }
        if quantum != Self.quantum { misses.append("quantum \(quantum)") }
        misses += countMisses(described, golden: golden)
        let camera: CelestialEclipseLabCamera = CelestialEclipseLabTest.camera(
            golden, width: CelestialEclipseLabGolden.width, height: CelestialEclipseLabGolden.height)
        var bodyPoints: [SIMD3<Double>?] = []
        for index in golden.positions.indices { bodyPoints.append(Geometry.bodyCentre(index, golden)) }
        var lensPoints: [SIMD3<Double>?] = []
        var haloPoints: [SIMD3<Double>?] = []
        for eclipse in golden.eclipses {
            lensPoints.append(lensCentre(eclipse, golden))
            if Geometry.hasHalo(eclipse) { haloPoints.append(Geometry.bodyCentre(eclipse.front, golden)) }
        }
        misses += positionMisses("body centre", described: described.bodies, points: bodyPoints, camera: camera,
                                 quantum: quantum, required: true)
        misses += positionMisses("shadow lens", described: described.lenses, points: lensPoints, camera: camera,
                                 quantum: quantum, required: false)
        misses += positionMisses("halo", described: described.halos, points: haloPoints, camera: camera,
                                 quantum: quantum, required: true)
        if let miss: String = positionMiss("playhead", described: described.playhead,
                                           point: Geometry.playhead(golden), camera: camera, quantum: quantum,
                                           required: true) {
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
    /// golden one, runs the description check and the feature-463 frame checks against the presenter's last snapshot;
    /// every issue names the frame. Returns the frame-check report.
    static func check(_ frame: CelestialEclipseLabGolden.Frame, session: ExperienceSession,
                      shell: CelestialEclipseLabTest.Shell) throws -> CelestialEclipseLabCheckReport {
        let width: Int = CelestialEclipseLabGolden.width
        let height: Int = CelestialEclipseLabGolden.height
        CelestialEclipseLabTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try CelestialEclipseLabTest.still(session, width: width, height: height, time: frame.time)
        let shown: Snapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: Snapshot = try CelestialEclipseLabGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(shown.time == golden.time, "\(frame.name): the drawn time is \(shown.time)")
        if let body: Int = frame.chosenBody {
            #expect(golden.chosenBody == body, "\(frame.name): golden body \(golden.chosenBody)")
        }
        #expect(golden.shownTick == frame.tick, "\(frame.name): golden tick \(golden.shownTick)")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        #expect(shell.presenter.scene.lastPulse == 1, "\(frame.name): frame time 0")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(described.counts.bodies > 1, "\(frame.name): the frame has fewer than two bodies")
        let report: CelestialEclipseLabCheckReport = CelestialEclipseLabTest.checkFrame(
            rgba, snapshot: shown, width: width, height: height, requireBody: false, "golden \(frame.name)")
        print("celestial-eclipse-lab golden \(frame.name): tick \(golden.shownTick), actions left "
              + "\(golden.actionsLeft) of \(golden.budget), lenses \(described.counts.lenses), halos "
              + "\(described.counts.halos), matched \(described.counts.matched) of \(described.counts.targets)")
        return report
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing their phase changes (the certified
    /// phase changes, the level still open), the default body and the first eclipse tick, and the hero frame (the
    /// manifest seed's level, tier 0, the certified phase changes, the last moved body and the hero tick), all at time
    /// 0.
    @Test func theGoldenSetHasSixteenFrames() throws {
        typealias Core = CelestialEclipseLabExperienceCore
        let frames: [CelestialEclipseLabGolden.Frame] = CelestialEclipseLabGolden.frames
        #expect(frames.count == 16)
        #expect(CelestialEclipseLabGolden.width == CelestialEclipseLabTest.width)
        #expect(CelestialEclipseLabGolden.height == CelestialEclipseLabTest.height)
        #expect(CelestialEclipseLabGolden.quantum == Self.quantum)
        #expect(CelestialEclipseLabGolden.levels == Self.levels)
        var names: [String] = []
        for entry in Self.palette { names.append(entry.name) }
        #expect(names.count == 21, "the palette has 21 colours")
        #expect(CelestialEclipseLabGolden.colourNames == names, "the described colour names")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        let heroChanges: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(heroLevel)
        let heroLast: CelestialEclipseLabAction = try #require(heroChanges.last, "the hero level has a certified plan")
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0)
            #expect(frame.actions == heroChanges, "the hero frame plays the certified phase changes")
            #expect(frame.chosenBody == Core.phaseBody(of: heroLast), "the hero frame chooses the last moved body")
            #expect(frame.tick == (Core.heroTick(heroLevel) ?? 0), "the hero frame shows the hero tick")
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in Self.levels {
            let tiers: [CelestialEclipseLabGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [CelestialEclipseLabAction] = tiers.first?.actions ?? []
            let expected: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(level)
            #expect(actions == expected, "level \(level): the frames play the certified phase changes")
            #expect(!actions.contains(.run), "level \(level): the frames never run")
            let tick: Int = try Self.firstEclipseTick(level)
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == actions, "\(frame.name): the tier frames share their phase changes")
                #expect(frame.chosenBody == nil, "\(frame.name): the default body")
                #expect(frame.tick == tick, "\(frame.name): tick \(frame.tick), first eclipse tick \(tick)")
                tierIndex += 1
            }
            if let first: CelestialEclipseLabGolden.Frame = tiers.first {
                let golden: Snapshot = try CelestialEclipseLabGolden.snapshot(first)
                #expect(golden.levelNumber == level, "\(first.name): level \(golden.levelNumber)")
                #expect(golden.stage == .playing, "\(first.name): stage \(golden.stage)")
                #expect(golden.actionsLeft == golden.budget - actions.count,
                        "\(first.name): actions left \(golden.actionsLeft)")
                let reference: CelestialEclipseLabExperienceCore = try CelestialEclipseLabTest.coreAfter(level,
                                                                                                         actions)
                #expect(golden.chosenBody == Snapshot.defaultChoice(reference.play.level),
                        "\(first.name): golden body \(golden.chosenBody)")
                #expect(golden.positions == CelestialEclipseLabTest.kernelPositions(reference.play, tick: tick),
                        "\(first.name): the golden bodies are the kernel's positions at tick \(tick)")
            }
        }
        var unique: Set<String> = []
        for frame in frames { unique.insert(frame.name) }
        #expect(unique.count == 16, "frame names are unique")
    }

    /// The 15 level frames render as their golden snapshots and descriptions say; each tier measures at least one
    /// body centre summed over the five levels.
    @Test func everyLevelFrameMatchesItsDescription() async throws {
        var bodies: [Int] = [0, 0, 0]
        var bars: [Int] = [0, 0, 0]
        for level in Self.levels {
            let frames: [CelestialEclipseLabGolden.Frame] = Self.tierFrames(level: level)
            #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
            guard let first: CelestialEclipseLabGolden.Frame = frames.first else { continue }
            let session = ExperienceSession()
            defer { session.close() }
            let shell: CelestialEclipseLabTest.Shell = try await Self.open(session, level: level)
            // The three tier frames share their phase changes, body and tick: apply them once, then draw each tier.
            try Self.apply(first, to: shell)
            for frame in frames {
                #expect(frame.actions == first.actions && frame.chosenBody == first.chosenBody
                            && frame.tick == first.tick,
                        "\(frame.name): the tier frames share their phase changes, body and tick")
                let report: CelestialEclipseLabCheckReport = try Self.check(frame, session: session, shell: shell)
                if frame.tier >= 0 && frame.tier < 3 {
                    bodies[frame.tier] += report.bodiesChecked
                    bars[frame.tier] += report.barChecked ? 1 : 0
                }
            }
            session.qualityPin = 0
        }
        print("celestial-eclipse-lab golden level frames: bodies per tier \(bodies), bars per tier \(bars)")
        for tier in 0..<3 {
            #expect(bodies[tier] > 0, "tier \(tier): no body centre measured over the golden frames")
        }
    }

    /// The hero frame (the manifest seed's level after the certified phase changes, the last moved body chosen and the
    /// hero tick shown, tier 0) renders as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [CelestialEclipseLabGolden.Frame] = []
        for frame in CelestialEclipseLabGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: CelestialEclipseLabGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: CelestialEclipseLabTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try CelestialEclipseLabTest.digest(shell)
        try Self.apply(hero, to: shell)
        let after: String = try CelestialEclipseLabTest.digest(shell)
        if !hero.actions.isEmpty { #expect(after != before, "the hero phase changes change the digest") }
        _ = try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
