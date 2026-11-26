// ApsidesWorkshopRegressionGoldenFrameTests — feature 478 (R02-G18-08) T-R02G1808-005 (FR-R02G1808-003, 004;
// SC-R02G1808-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `ApsidesWorkshopGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after all
// of its certified tunings but not the play, so actions are spent from the actions bars and the level is still open,
// with no preview, shown at the tick T / 2; plus the hero frame: the level the hero scenario opens, seed
// `manifestSeed`, after the certified tunings with the hero tick T / 2 shown, tier 0) is drawn off screen at the
// frame-check size 1,152 × 768 of `ApsidesWorkshopTest` with the frame's tier pinned, at the frame's time 0. Seed s
// opens level s % 100 + 1, so a frame of level L opens at seed L − 1; the frame's tunings go through the adapter
// (`orbit.periapsis`, `orbit.size`) as the actions of `Frame.actions`, then its tick through `clock.show [frame.tick]`
// (presentation only: the digest does not change). The snapshot the presenter drew equals
// `ApsidesWorkshopGolden.snapshot(frame)` (every field, the presentation time 0 in both), so the rendered frame is the
// golden one. The frame's description (`ApsidesWorkshopGolden.description`, decoded here) carries the counts, the tick
// and the 18 named colours (each the palette constant of the same name), and puts the star, the orbiter, the periapsis
// and apoapsis markers, every planet centre and the first actions bar where the Core's CPU reference of the golden
// snapshot puts them (within one 1/8-pixel quantum per axis); the star, the orbiter, both markers and every planet are
// on screen. The pixels then show them there: at the described star and orbiter centres (when clear of every element
// drawn after them) a pixel within 3 px is brighter than the backdrop by 0.25 in luminance, and at the described first
// actions bar (lit, clear) a pixel within 3 px has red above blue by 0.08. The picture passes the feature-473 checks
// (`ApsidesWorkshopTest.checkFrame`) against the presenter's last snapshot: at every point at least 6 px from every
// element drawn after it in the painter's order (`ApsidesWorkshopSceneGeometry.paintOrder`), the star's and the
// orbiter's centres brighter than the backdrop by 0.25 in luminance, the first lit actions bar red above blue by 0.08,
// the first gauge track's centre 0.1 from the backdrop, the median of every 9 × 9 backdrop patch within 0.06 of the
// gradient. Each tier measures the star and the orbiter on every level frame. One test for the set, one for the 15
// level frames and one for the hero frame, each well under 10 s. Modelled on
// `CelestialEclipseLabRegressionGoldenFrameTests` (feature 468). Synthetic data, explicit types, plain loops, no
// sleep, no wall-clock assertion.
#if os(iOS)
import ApsidesWorkshopCore
import Foundation
import Testing
@testable import ApsidesWorkshopExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct ApsidesWorkshopRegressionGoldenFrameTests {
    typealias Geometry = ApsidesWorkshopSceneGeometry
    typealias Snapshot = ApsidesWorkshopSceneSnapshot
    typealias Palette = ApsidesWorkshopPalette
    typealias Frame = ApsidesWorkshopGolden.Frame

    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of the description.
    struct Counts: Decodable, Equatable {
        let sectors: Int
        let wedges: Int
        let orbitPoints: Int
        let planets: Int
        let gauges: Int
        let met: Int
        let litActions: Int
        let actions: Int
    }

    /// The description of one golden frame, decoded from `ApsidesWorkshopGolden.description(_:)`. A position is
    /// `[x, y]` in 1/`quantum` pixel, or null when it does not project into the frame.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let tick: Int
        let counts: Counts
        let colours: [String: Colour]
        let star: [Int]?
        let orbiter: [Int]?
        let periapsis: [Int]?
        let apoapsis: [Int]?
        let planets: [[Int]?]
        let firstActionsBar: [Int]?
    }

    /// What the frame checks of one golden frame measured.
    struct Measured {
        /// The feature-473 report.
        var report: ApsidesWorkshopCheckReport
        /// Whether the described star centre was measured in the pixels.
        var describedStar: Bool
        /// Whether the described orbiter centre was measured in the pixels.
        var describedOrbiter: Bool
        /// Whether the described first actions bar was measured in the pixels.
        var describedBar: Bool
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described in units of 1/`quantum` pixel (clarification Q3: 1/8 pixel).
    static let quantum: Int = 8
    /// The named colours of the description and the palette constant each must equal (18, in the described order).
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("midnight", Palette.midnight), ("midnightTop", Palette.midnightTop), ("speck", Palette.speck),
        ("wedge", Palette.wedge), ("targetWedge", Palette.targetWedge), ("compass", Palette.compass),
        ("ghost", Palette.ghost), ("glacial", Palette.glacial), ("deepRose", Palette.deepRose),
        ("planet", Palette.planet), ("hazard", Palette.hazard), ("star", Palette.star), ("met", Palette.met),
        ("unmet", Palette.unmet), ("actionsLit", Palette.actionsLit), ("actionsUnlit", Palette.actionsUnlit),
        ("broken", Palette.broken), ("glow", Palette.glow),
    ]

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [Frame] {
        var list: [Frame] = []
        for frame in ApsidesWorkshopGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Opens `level` (seed level − 1) without showing a tick and checks that the engine shows it, drawn with motion.
    static func open(_ session: ExperienceSession, level: Int) async throws -> ApsidesWorkshopTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(ApsidesWorkshopExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: ApsidesWorkshopTest.Shell = try await ApsidesWorkshopTest.open(session, seed: seed, atHalf: false)
        let opened: Int = try ApsidesWorkshopTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// Sends `frame`'s tunings through the adapter, each expected to be accepted, then shows its tick
    /// (`clock.show [frame.tick]`, presentation only: the digest does not change).
    static func apply(_ frame: Frame, to shell: ApsidesWorkshopTest.Shell) throws {
        let accepted: Int = ApsidesWorkshopTest.issue(shell, frame.actions)
        #expect(accepted == frame.actions.count,
                "\(frame.name): \(accepted) of \(frame.actions.count) tunings accepted")
        let digest: String = try ApsidesWorkshopTest.digest(shell)
        let result: ActionResult = shell.handle(control: "clock.show", values: [Double(frame.tick)])
        #expect(result == .accepted, "\(frame.name): clock.show [\(frame.tick)]: \(result.code)")
        let core: ApsidesWorkshopExperienceCore = try ApsidesWorkshopTest.core(shell)
        #expect(core.shownTick == frame.tick, "\(frame.name): tick \(core.shownTick) shown, not \(frame.tick)")
        let after: String = try ApsidesWorkshopTest.digest(shell)
        #expect(after == digest, "\(frame.name): showing the tick leaves the digest")
    }

    /// The decoded description of `frame`.
    static func description(_ frame: Frame) throws -> Description {
        let data: Data = try ApsidesWorkshopGolden.description(frame)
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

    /// The pixel of the described position `q` (nil when absent or malformed).
    static func pixel(_ q: [Int]?, quantum: Int) -> SIMD2<Double>? {
        guard let q, q.count == 2, quantum > 0 else { return nil }
        return SIMD2<Double>(Double(q[0]) / Double(quantum), Double(q[1]) / Double(quantum))
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
        guard let p: SIMD2<Double> = pixel(q, quantum: quantum) else { return false }
        return ApsidesWorkshopTest.inside(p, width: ApsidesWorkshopGolden.width, height: ApsidesWorkshopGolden.height)
    }

    /// The CPU reference pixel of `point` at the golden size, or nil when it does not project or lies outside the
    /// picture (the description writes null then).
    static func referencePixel(_ point: SIMD3<Double>) -> SIMD2<Double>? {
        let width: Int = ApsidesWorkshopGolden.width
        let height: Int = ApsidesWorkshopGolden.height
        let camera: ApsidesWorkshopCamera = ApsidesWorkshopTest.camera(width: width, height: height)
        guard let p: SIMD2<Double> = ApsidesWorkshopTest.project(point, camera, width: width, height: height),
              p.x >= 0, p.y >= 0, p.x <= Double(width), p.y <= Double(height) else { return nil }
        return p
    }

    /// The described position `described` against the CPU reference pixel of `point` (nil: no reference point);
    /// returns the miss (a disagreement, or a position off screen when `required`) naming `what`, or nil.
    static func positionMiss(_ what: String, described: [Int]?, point: SIMD3<Double>?, quantum: Int,
                             required: Bool) -> String? {
        var reference: SIMD2<Double>?
        if let point { reference = referencePixel(point) }
        if !agrees(described, reference, quantum: quantum) {
            return "\(what) described \(String(describing: described)), reference \(String(describing: reference))"
        }
        if required && !onScreen(described, quantum: quantum) {
            return "\(what) described \(String(describing: described)) is off screen"
        }
        return nil
    }

    /// Every field of `shown` that differs from `golden`.
    static func snapshotMisses(_ shown: Snapshot, _ golden: Snapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.orbit != golden.orbit { misses.append("orbit \(shown.orbit), golden \(golden.orbit)") }
        if shown.positions != golden.positions { misses.append("positions") }
        if shown.ghost != golden.ghost { misses.append("ghost") }
        if shown.orbiter != golden.orbiter { misses.append("orbiter") }
        if shown.shares != golden.shares { misses.append("shares \(shown.shares), golden \(golden.shares)") }
        if shown.planets != golden.planets { misses.append("planets") }
        if shown.gauges != golden.gauges { misses.append("gauges") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.shownTick != golden.shownTick {
            misses.append("tick \(shown.shownTick), golden \(golden.shownTick)")
        }
        if shown.period != golden.period { misses.append("period \(shown.period), golden \(golden.period)") }
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

    /// The counts, tick and colours of `described` against `golden`. Returns the misses.
    static func countMisses(_ described: Description, golden: Snapshot) -> [String] {
        var misses: [String] = []
        let counts: Counts = described.counts
        var wedges: Int = 0
        for share in golden.shares where share > 0 { wedges += 1 }
        var met: Int = 0
        for gauge in golden.gauges where gauge.met { met += 1 }
        let lit: Int = Geometry.litActions(golden)
        if counts.sectors != golden.shares.count {
            misses.append("sectors \(counts.sectors), snapshot \(golden.shares.count)")
        }
        if counts.wedges != wedges { misses.append("wedges \(counts.wedges), snapshot \(wedges)") }
        if counts.orbitPoints != golden.positions.count {
            misses.append("orbit points \(counts.orbitPoints), snapshot \(golden.positions.count)")
        }
        if counts.orbitPoints != golden.period {
            misses.append("orbit points \(counts.orbitPoints), period \(golden.period)")
        }
        if counts.planets != golden.planets.count {
            misses.append("planets \(counts.planets), snapshot \(golden.planets.count)")
        }
        if counts.gauges != golden.gauges.count {
            misses.append("gauges \(counts.gauges), snapshot \(golden.gauges.count)")
        }
        if counts.met != met { misses.append("met \(counts.met), snapshot \(met)") }
        if counts.litActions != lit { misses.append("lit actions \(counts.litActions), snapshot \(lit)") }
        if counts.actions != max(golden.budget, 0) {
            misses.append("actions \(counts.actions), budget \(golden.budget)")
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

    /// The description check: the frame's identity and size, counts, tick, colours and every position agreeing with
    /// the CPU reference of `golden` (the star, the orbiter, both markers and every planet also on screen). Returns
    /// the misses.
    static func descriptionMisses(_ described: Description, frame: Frame, golden: Snapshot) -> [String] {
        var misses: [String] = []
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level { misses.append("level \(described.level)") }
        if described.tier != frame.tier { misses.append("tier \(described.tier)") }
        if described.width != ApsidesWorkshopTest.width { misses.append("width \(described.width)") }
        if described.height != ApsidesWorkshopTest.height { misses.append("height \(described.height)") }
        if quantum != Self.quantum { misses.append("quantum \(quantum)") }
        misses += countMisses(described, golden: golden)
        let ticks: Int = golden.positions.count
        var periapsis: SIMD3<Double>?
        var apoapsis: SIMD3<Double>?
        if ticks > 0 {
            periapsis = Geometry.world(golden.positions[0], depth: Geometry.planeZ)
            apoapsis = Geometry.world(golden.positions[(ticks / 2) % ticks], depth: Geometry.planeZ)
        } else {
            misses.append("the golden snapshot has no orbit positions")
        }
        let singles: [(String, [Int]?, SIMD3<Double>?)] = [
            ("star", described.star, Geometry.starCentre()),
            ("orbiter", described.orbiter, Geometry.orbiterCentre(golden)),
            ("periapsis marker", described.periapsis, periapsis),
            ("apoapsis marker", described.apoapsis, apoapsis),
        ]
        for single in singles {
            if let miss: String = positionMiss(single.0, described: single.1, point: single.2, quantum: quantum,
                                               required: true) {
                misses.append(miss)
            }
        }
        if described.planets.count != golden.planets.count {
            misses.append("\(described.planets.count) planet points described, snapshot \(golden.planets.count)")
        } else {
            for index in golden.planets.indices {
                if let miss: String = positionMiss("planet \(index)", described: described.planets[index],
                                                   point: Geometry.planetCentre(index, golden), quantum: quantum,
                                                   required: true) {
                    misses.append(miss)
                }
            }
        }
        if golden.budget > 0 {
            if let miss: String = positionMiss("first actions bar", described: described.firstActionsBar,
                                               point: Geometry.actionsBar(0, golden), quantum: quantum,
                                               required: false) {
                misses.append(miss)
            }
        } else {
            misses.append("the golden snapshot has no actions budget")
        }
        return misses
    }

    /// The pixel check at the described positions on `rgba` (drawn from `snapshot`): at the described star and
    /// orbiter centres, when clear of every element drawn after them, a pixel within 3 px is brighter than the
    /// backdrop by 0.25 in luminance; at the described first actions bar, when lit and clear, a pixel within 3 px has
    /// red above blue by 0.08. Returns the misses and which points were measured.
    static func describedPixelMisses(_ rgba: [UInt8], _ described: Description,
                                     snapshot: Snapshot) -> (misses: [String], star: Bool, orbiter: Bool, bar: Bool) {
        let width: Int = ApsidesWorkshopTest.width
        let height: Int = ApsidesWorkshopTest.height
        var misses: [String] = []
        let layout: ApsidesWorkshopTestLayout = ApsidesWorkshopTest.layout(snapshot, width: width, height: height)
        guard let sky: ApsidesWorkshopTestBackdrop = ApsidesWorkshopTest.backdrop(width: width, height: height) else {
            return (["an empty target"], false, false, false)
        }
        var measured: [Bool] = []
        let bright: [(String, ApsidesWorkshopElement.Part, [Int]?)] = [
            ("star", .star, described.star), ("orbiter", .orbiter, described.orbiter),
        ]
        for entry in bright {
            guard let p: SIMD2<Double> = pixel(entry.2, quantum: described.quantum),
                  ApsidesWorkshopTest.inside(p, width: width, height: height),
                  let rank: Int = layout.rank(entry.1, 0),
                  layout.isClear(p, after: rank, clearance: ApsidesWorkshopTest.clearance) else {
                measured.append(false)
                continue
            }
            measured.append(true)
            let floor: Double = ApsidesWorkshopTest.luminance(sky.gradient(x: p.x, y: p.y))
                + ApsidesWorkshopTest.brightMargin
            let found: Bool = ApsidesWorkshopTest.anyPixel(rgba, near: p, radius: ApsidesWorkshopTest.pointRadius,
                                                           width: width, height: height,
                                                           where: { ApsidesWorkshopTest.luminance($0) >= floor })
            if !found {
                let c: SIMD3<Double> = ApsidesWorkshopTest.centre(rgba, p, width: width, height: height)
                misses.append("described \(entry.0) at (\(p.x), \(p.y)) is \(c), not bright")
            }
        }
        var bar: Bool = false
        if Geometry.litActions(snapshot) > 0,
           let p: SIMD2<Double> = pixel(described.firstActionsBar, quantum: described.quantum),
           ApsidesWorkshopTest.inside(p, width: width, height: height),
           let rank: Int = layout.rank(.bar, 0),
           layout.isClear(p, after: rank, clearance: ApsidesWorkshopTest.clearance) {
            bar = true
            let found: Bool = ApsidesWorkshopTest.anyPixel(rgba, near: p, radius: ApsidesWorkshopTest.pointRadius,
                                                           width: width, height: height,
                                                           where: ApsidesWorkshopTest.isReddish)
            if !found {
                let c: SIMD3<Double> = ApsidesWorkshopTest.centre(rgba, p, width: width, height: height)
                misses.append("described first actions bar at (\(p.x), \(p.y)) is \(c), not red above blue")
            }
        }
        return (misses, measured[0], measured[1], bar)
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check, the pixel check at the described positions and the feature-473 frame
    /// checks against the presenter's last snapshot; every issue names the frame.
    static func check(_ frame: Frame, session: ExperienceSession,
                      shell: ApsidesWorkshopTest.Shell) throws -> Measured {
        let width: Int = ApsidesWorkshopGolden.width
        let height: Int = ApsidesWorkshopGolden.height
        ApsidesWorkshopTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try ApsidesWorkshopTest.still(session, width: width, height: height, time: frame.time)
        let shown: Snapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: Snapshot = try ApsidesWorkshopGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(shown.time == golden.time, "\(frame.name): the drawn time is \(shown.time)")
        #expect(golden.shownTick == frame.tick, "\(frame.name): golden tick \(golden.shownTick)")
        #expect(!golden.isPreviewing, "\(frame.name): the golden frame previews nothing")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        #expect(shell.presenter.scene.lastPulse == 1, "\(frame.name): frame time 0")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(described.counts.orbitPoints > 0, "\(frame.name): the frame has no orbit loop")
        let pixels = Self.describedPixelMisses(rgba, described, snapshot: shown)
        #expect(pixels.misses.isEmpty, "\(frame.name): \(pixels.misses.prefix(4))")
        #expect(pixels.star && pixels.orbiter, "\(frame.name): the described star and orbiter centres are not clear")
        if Geometry.litActions(shown) > 0 {
            #expect(pixels.bar, "\(frame.name): the described first actions bar is not clear")
        }
        let report: ApsidesWorkshopCheckReport = ApsidesWorkshopTest.checkFrame(
            rgba, snapshot: shown, width: width, height: height, "golden \(frame.name)")
        print("apsides-workshop golden \(frame.name): tick \(golden.shownTick) of \(golden.period), actions left "
              + "\(golden.actionsLeft) of \(golden.budget), wedges \(described.counts.wedges), met "
              + "\(described.counts.met) of \(described.counts.gauges)")
        return Measured(report: report, describedStar: pixels.star, describedOrbiter: pixels.orbiter,
                        describedBar: pixels.bar)
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing their tunings (the certified
    /// tunings, never the play, the level still open) and the tick T / 2, and the hero frame (the hero scenario's
    /// level, tier 0, the certified tunings and the hero tick), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() throws {
        typealias Core = ApsidesWorkshopExperienceCore
        let frames: [Frame] = ApsidesWorkshopGolden.frames
        #expect(frames.count == 16)
        #expect(ApsidesWorkshopGolden.width == ApsidesWorkshopTest.width)
        #expect(ApsidesWorkshopGolden.height == ApsidesWorkshopTest.height)
        #expect(ApsidesWorkshopGolden.quantum == Self.quantum)
        #expect(ApsidesWorkshopGolden.levels == Self.levels)
        #expect(ApsidesWorkshopGolden.levels == ApsidesWorkshopTest.levels)
        var names: [String] = []
        for entry in Self.palette { names.append(entry.name) }
        #expect(names.count == 18, "the palette has 18 named colours")
        #expect(ApsidesWorkshopGolden.colourNames == names, "the described colour names")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        let heroTunings: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(heroLevel)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0)
            #expect(frame.actions == heroTunings, "the hero frame plays the certified tunings")
            #expect(frame.tick == (Core.heroTick(heroLevel) ?? -1), "the hero frame shows the hero tick")
        }
        #expect(heroes == 1)
        for frame in frames {
            #expect(frame.time == 0, "\(frame.name): time \(frame.time)")
            #expect(!frame.actions.contains(.play), "\(frame.name): the frames never play")
        }
        for level in Self.levels {
            let tiers: [Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let expected: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(level)
            let period: Int = try ApsidesWorkshopExperienceCore.level(number: level).period
            let tick: Int = ApsidesWorkshopTest.halfTick(period)
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == expected, "\(frame.name): the frames play the certified tunings")
                #expect(frame.tick == tick, "\(frame.name): tick \(frame.tick), T / 2 is \(tick)")
                tierIndex += 1
            }
            if let first: Frame = tiers.first {
                let golden: Snapshot = try ApsidesWorkshopGolden.snapshot(first)
                #expect(golden.levelNumber == level, "\(first.name): level \(golden.levelNumber)")
                #expect(golden.stage == .playing, "\(first.name): stage \(golden.stage)")
                #expect(golden.actionsLeft == golden.budget - expected.count,
                        "\(first.name): actions left \(golden.actionsLeft)")
                let reference: ApsidesWorkshopExperienceCore = try ApsidesWorkshopTest.coreAfter(level, expected)
                #expect(golden == reference.snapshot(time: 0),
                        "\(first.name): the golden snapshot is the CPU reference's at T / 2")
            }
        }
        var unique: Set<String> = []
        for frame in frames { unique.insert(frame.name) }
        #expect(unique.count == 16, "frame names are unique")
    }

    /// The 15 level frames render as their golden snapshots and descriptions say; every tier measures the star and
    /// the orbiter on every level.
    @Test func everyLevelFrameMatchesItsDescription() async throws {
        var bright: [Int] = [0, 0, 0]
        var bars: [Int] = [0, 0, 0]
        for level in Self.levels {
            let frames: [Frame] = Self.tierFrames(level: level)
            #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
            guard let first: Frame = frames.first else { continue }
            let session = ExperienceSession()
            defer { session.close() }
            let shell: ApsidesWorkshopTest.Shell = try await Self.open(session, level: level)
            // The three tier frames share their tunings and tick: apply them once, then draw each tier.
            try Self.apply(first, to: shell)
            for frame in frames {
                #expect(frame.actions == first.actions && frame.tick == first.tick,
                        "\(frame.name): the tier frames share their tunings and tick")
                let measured: Measured = try Self.check(frame, session: session, shell: shell)
                if frame.tier >= 0 && frame.tier < 3 {
                    let both: Bool = measured.report.starChecked && measured.report.orbiterChecked
                        && measured.describedStar && measured.describedOrbiter
                    bright[frame.tier] += both ? 1 : 0
                    bars[frame.tier] += measured.report.barChecked ? 1 : 0
                }
            }
            session.qualityPin = 0
        }
        print("apsides-workshop golden level frames: star and orbiter per tier \(bright), bars per tier \(bars)")
        for tier in 0..<3 {
            #expect(bright[tier] == Self.levels.count,
                    "tier \(tier): the star and the orbiter measured on \(bright[tier]) of 5 levels")
        }
    }

    /// The hero frame (the hero scenario's level after the certified tunings, the hero tick shown, tier 0) renders as
    /// described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [Frame] = []
        for frame in ApsidesWorkshopGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ApsidesWorkshopTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try ApsidesWorkshopTest.digest(shell)
        try Self.apply(hero, to: shell)
        let after: String = try ApsidesWorkshopTest.digest(shell)
        if !hero.actions.isEmpty { #expect(after != before, "the hero tunings change the digest") }
        _ = try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
