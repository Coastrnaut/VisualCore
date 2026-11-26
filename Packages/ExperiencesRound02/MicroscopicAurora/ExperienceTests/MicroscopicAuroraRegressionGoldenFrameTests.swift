// MicroscopicAuroraRegressionGoldenFrameTests — feature 488 (R02-G19-08) T-R02G1908-005 (FR-R02G1908-004;
// SC-R02G1908-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `MicroscopicAuroraGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after all
// of the witness's placements but not the play, so actions are spent from the actions bars and the level is still open,
// with no preview and no freeze, shown at the tick half the ticks swum; plus the hero frame: the level the hero
// scenario opens, seed `manifestSeed`, after the certified placements with the hero tick shown, tier 0) is drawn off
// screen at the frame-check size 1,152 × 768 of `MicroscopicAuroraTest` with the frame's tier pinned, at the frame's
// time 0. Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1; the frame's placements go through
// the adapter (`well.place`) as the actions of `Frame.actions`, then its tick through `clock.show [frame.tick]`. The
// snapshot the presenter drew equals `MicroscopicAuroraGolden.snapshot(frame)` (every field, the presentation time 0 in
// both), so the rendered frame is the golden one. The frame's description (`MicroscopicAuroraGolden.description`, read
// here as JSON) carries the counts and the 18 named colours (each the palette constant of the same name, as 8-bit
// sRGB), and puts the dish centre, every swimmer at the shown tick, every placed well, every site and the first actions
// bar where the Core's CPU reference of the golden snapshot puts them (within one 1/8-pixel quantum per axis); the dish
// centre, every swimmer, every well and every site are on screen. The pixels then show them there: at every described
// swimmer centre clear of every element drawn after it, a pixel within 3 px is brighter than the dish field by 0.25 in
// luminance, and at the described first actions bar (lit, clear) a pixel within 3 px has blue above green by 0.08. The
// picture passes the feature-483 checks (`MicroscopicAuroraTest.checkFrame`) against the presenter's last snapshot:
// every point at least 6 px from every element drawn after it in the painter's order
// (`MicroscopicAuroraSceneGeometry.paintOrder`), each swimmer's centre 0.25 brighter than the dish field, the first lit
// actions bar blue above green by 0.08, the coverage track's centre 0.1 from the backdrop, the median of every 9 × 9
// corner patch within 0.06 of the abyss gradient. Each tier measures at least one swimmer on every level frame. One
// test for the set, one for the 15 level frames and one for the hero frame, each well under 10 s. Modelled on
// `ApsidesWorkshopRegressionGoldenFrameTests` (feature 478). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
//
// The description is read with `JSONSerialization`, so it holds whatever key order the Core writes: `dish`,
// `firstActionsBar` ([x, y] or null), `swimmers`, `wells`, `sites` (lists of [x, y] or null, index order), `counts`
// (`stencil`, `lit`, `stray`, `sites`, `wells`, `swimmers`, `ribbonPoints`, `gauges`, `met`, `litActions`, `actions`)
// and `colours` (name → [r, g, b] or {r, g, b}). A position is in pixels at 1/8-pixel steps, or in eighths when the
// description says `quantum` (or, without it, when the dish centre lies beyond the picture's width in pixels).
#if os(iOS)
import Foundation
import MicroscopicAuroraCore
import Testing
@testable import MicroscopicAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MicroscopicAuroraRegressionGoldenFrameTests {
    typealias Geometry = MicroscopicAuroraSceneGeometry
    typealias Snapshot = MicroscopicAuroraSceneSnapshot
    typealias Palette = MicroscopicAuroraPalette
    typealias Frame = MicroscopicAuroraGolden.Frame

    /// An 8-bit colour of the description.
    struct Colour: Equatable, CustomStringConvertible {
        let r: Int
        let g: Int
        let b: Int

        var description: String { "(\(r), \(g), \(b))" }
    }

    /// The description of one golden frame, read from `MicroscopicAuroraGolden.description(_:)`. Positions are in
    /// pixels (nil: null, behind the eye, or malformed).
    struct Description {
        /// Every top-level key of the JSON object.
        var keys: [String] = []
        /// The pixels per written position unit (1 for pixels, 1/8 for eighths).
        var scale: Double = 1
        var dish: SIMD2<Double>?
        var firstActionsBar: SIMD2<Double>?
        var swimmers: [SIMD2<Double>?] = []
        var wells: [SIMD2<Double>?] = []
        var sites: [SIMD2<Double>?] = []
        var counts: [String: Int] = [:]
        var colours: [String: Colour] = [:]
    }

    /// What the frame checks of one golden frame measured.
    struct Measured {
        /// The feature-483 report.
        var report: MicroscopicAuroraCheckReport
        /// How many described swimmer centres were measured in the pixels.
        var describedSwimmers: Int
        /// Whether the described first actions bar was measured in the pixels.
        var describedBar: Bool
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described at steps of 1/`quantum` pixel (clarification Q3: 1/8 pixel); one step is the tolerance.
    static let quantum: Int = 8
    /// A rounding allowance on top of one quantum (pixels).
    static let slack: Double = 1e-6
    /// The named colours of the description and the palette constant each must equal (18).
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("abyss", Palette.abyss), ("abyssTop", Palette.abyssTop), ("field", Palette.field), ("frond", Palette.frond),
        ("rim", Palette.rim), ("stencil", Palette.stencil), ("lit", Palette.lit), ("stray", Palette.stray),
        ("site", Palette.site), ("well", Palette.well), ("ribbon", Palette.ribbon), ("swimmer", Palette.swimmer),
        ("met", Palette.met), ("unmet", Palette.unmet), ("actionsLit", Palette.actionsLit),
        ("actionsUnlit", Palette.actionsUnlit), ("broken", Palette.broken), ("glow", Palette.glow),
    ]
    /// The count keys of the description (clarification Q3).
    static let countKeys: [String] = [
        "stencil", "lit", "stray", "sites", "wells", "swimmers", "ribbonPoints", "gauges", "met", "litActions",
        "actions",
    ]

    // MARK: Frames

    /// Whether `frame` is the hero frame (its name names the hero scenario).
    static func isHero(_ frame: Frame) -> Bool {
        frame.name.contains("hero")
    }

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [Frame] {
        var list: [Frame] = []
        for frame in MicroscopicAuroraGolden.frames where frame.level == level && !isHero(frame) {
            list.append(frame)
        }
        return list
    }

    /// The hero frames of the golden set (one expected).
    static func heroFrames() -> [Frame] {
        var list: [Frame] = []
        for frame in MicroscopicAuroraGolden.frames where isHero(frame) { list.append(frame) }
        return list
    }

    /// Opens `level` (seed level − 1) without showing a tick and checks that the engine shows it, drawn with motion.
    static func open(_ session: ExperienceSession, level: Int) async throws -> MicroscopicAuroraTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(MicroscopicAuroraExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: MicroscopicAuroraTest.Shell = try await MicroscopicAuroraTest.open(session, seed: seed,
                                                                                      atHalf: false)
        let opened: Int = try MicroscopicAuroraTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// Sends `frame`'s placements through the adapter, each expected to be accepted, then shows its tick
    /// (`clock.show [frame.tick]`).
    static func apply(_ frame: Frame, to shell: MicroscopicAuroraTest.Shell) throws {
        let accepted: Int = MicroscopicAuroraTest.issue(shell, frame.actions)
        #expect(accepted == frame.actions.count,
                "\(frame.name): \(accepted) of \(frame.actions.count) placements accepted")
        let result: ActionResult = shell.handle(control: "clock.show", values: [Double(frame.tick)])
        #expect(result == .accepted, "\(frame.name): clock.show [\(frame.tick)]: \(result.code)")
        let core: MicroscopicAuroraExperienceCore = try MicroscopicAuroraTest.core(shell)
        #expect(core.shownTick == frame.tick, "\(frame.name): tick \(core.shownTick) shown, not \(frame.tick)")
    }

    /// The CPU reference of `frame` without the golden type: the opening of its level with its placements applied
    /// and its tick shown, at time 0.
    static func referenceSnapshot(_ frame: Frame) throws -> Snapshot {
        var core: MicroscopicAuroraExperienceCore = try MicroscopicAuroraTest.coreAfter(frame.level, frame.actions,
                                                                                         showHalf: false)
        let result: ActionResult = core.apply(MicroscopicAuroraTest.showAction(frame.tick))
        #expect(result == .accepted, "\(frame.name): clock.show [\(frame.tick)]: \(result.code)")
        return core.snapshot(time: frame.time)
    }

    // MARK: Reading the description

    /// The integer of a JSON number (nil otherwise).
    static func integer(_ any: Any?) -> Int? {
        guard let number = any as? NSNumber else { return nil }
        let value: Double = number.doubleValue
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// The double of a JSON number (nil otherwise).
    static func number(_ any: Any?) -> Double? {
        guard let number = any as? NSNumber else { return nil }
        let value: Double = number.doubleValue
        return value.isFinite ? value : nil
    }

    /// The position `[x, y]` in file units scaled to pixels by `scale` (nil for null or malformed).
    static func position(_ any: Any?, scale: Double) -> SIMD2<Double>? {
        guard let pair = any as? [Any], pair.count == 2, let x = number(pair[0]), let y = number(pair[1]) else {
            return nil
        }
        return SIMD2<Double>(x * scale, y * scale)
    }

    /// The list of positions under `key` (empty when absent).
    static func positions(_ object: [String: Any], _ key: String, scale: Double) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard let list = object[key] as? [Any] else { return result }
        for item in list { result.append(position(item, scale: scale)) }
        return result
    }

    /// The colour written as `[r, g, b]` or `{"r", "g", "b"}` (nil otherwise).
    static func colour(_ any: Any?) -> Colour? {
        if let list = any as? [Any], list.count == 3, let r = integer(list[0]), let g = integer(list[1]),
           let b = integer(list[2]) {
            return Colour(r: r, g: g, b: b)
        }
        if let dictionary = any as? [String: Any], let r = integer(dictionary["r"]), let g = integer(dictionary["g"]),
           let b = integer(dictionary["b"]) {
            return Colour(r: r, g: g, b: b)
        }
        return nil
    }

    /// The pixels per written position unit: 1/q when the file says its quantum q (positions in 1/q pixel), else
    /// 1/8 when the dish centre's written x lies beyond the picture's width (eighths), else 1 (pixels).
    static func scale(_ object: [String: Any]) -> Double {
        if let q = integer(object["quantum"]), q > 0 { return 1 / Double(q) }
        if let raw = position(object["dish"], scale: 1), raw.x > Double(MicroscopicAuroraGolden.width) {
            return 1 / Double(quantum)
        }
        return 1
    }

    /// The description of `frame`, read from its JSON.
    static func description(_ frame: Frame) throws -> Description {
        let data: Data = try MicroscopicAuroraGolden.description(frame)
        let parsed: Any = try JSONSerialization.jsonObject(with: data)
        let object: [String: Any] = try #require(parsed as? [String: Any], "\(frame.name): not a JSON object")
        var result = Description()
        result.keys = object.keys.sorted()
        result.scale = scale(object)
        result.dish = position(object["dish"], scale: result.scale)
        result.firstActionsBar = position(object["firstActionsBar"], scale: result.scale)
        result.swimmers = positions(object, "swimmers", scale: result.scale)
        result.wells = positions(object, "wells", scale: result.scale)
        result.sites = positions(object, "sites", scale: result.scale)
        if let counts = object["counts"] as? [String: Any] {
            for (key, value) in counts {
                if let n = integer(value) { result.counts[key] = n }
            }
        }
        if let colours = object["colours"] as? [String: Any] {
            for (key, value) in colours {
                if let c = colour(value) { result.colours[key] = c }
            }
        }
        return result
    }

    // MARK: Description checks

    /// One channel 0 … 1 as a byte, clamped and rounded.
    static func byte(_ v: Double) -> Int {
        Int((Swift.min(Swift.max(v, 0), 1) * 255).rounded())
    }

    /// `c` in 8 bits per channel.
    static func colour(of c: SIMD3<Double>) -> Colour {
        Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// The CPU reference pixel of `point` at the golden size (nil when it does not project).
    static func referencePixel(_ point: SIMD3<Double>) -> SIMD2<Double>? {
        let width: Int = MicroscopicAuroraGolden.width
        let height: Int = MicroscopicAuroraGolden.height
        let camera: MicroscopicAuroraCamera = MicroscopicAuroraTest.camera(width: width, height: height)
        return MicroscopicAuroraTest.project(point, camera, width: width, height: height)
    }

    /// Whether the described pixel `q` lies within one quantum per axis of the reference pixel `p`; both nil agree.
    static func agrees(_ q: SIMD2<Double>?, _ p: SIMD2<Double>?) -> Bool {
        if q == nil && p == nil { return true }
        guard let q, let p else { return false }
        let tolerance: Double = 1 / Double(quantum) + slack
        return Swift.abs(q.x - p.x) <= tolerance && Swift.abs(q.y - p.y) <= tolerance
    }

    /// Whether `q` is present and inside the 1,152 × 768 picture.
    static func onScreen(_ q: SIMD2<Double>?) -> Bool {
        guard let q else { return false }
        return MicroscopicAuroraTest.inside(q, width: MicroscopicAuroraGolden.width,
                                            height: MicroscopicAuroraGolden.height)
    }

    /// The described position against the CPU reference of `point`; the miss naming `what`, or nil.
    static func positionMiss(_ what: String, described: SIMD2<Double>?, point: SIMD3<Double>?,
                             required: Bool) -> String? {
        var reference: SIMD2<Double>?
        if let point { reference = referencePixel(point) }
        if !agrees(described, reference) {
            return "\(what) described \(String(describing: described)), reference \(String(describing: reference))"
        }
        if required && !onScreen(described) {
            return "\(what) described \(String(describing: described)) is off screen"
        }
        return nil
    }

    /// The described list against the reference points, each required on screen; the misses.
    static func listMisses(_ what: String, described: [SIMD2<Double>?], points: [SIMD3<Double>]) -> [String] {
        var misses: [String] = []
        if described.count != points.count {
            misses.append("\(described.count) \(what) points described, snapshot \(points.count)")
            return misses
        }
        for index in points.indices {
            if let miss: String = positionMiss("\(what) \(index)", described: described[index], point: points[index],
                                               required: true) {
                misses.append(miss)
            }
        }
        return misses
    }

    /// Every field of `shown` that differs from `golden`.
    static func snapshotMisses(_ shown: Snapshot, _ golden: Snapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.radius != golden.radius { misses.append("radius \(shown.radius), golden \(golden.radius)") }
        if shown.positions != golden.positions { misses.append("positions") }
        if shown.velocities != golden.velocities { misses.append("velocities") }
        if shown.ticksSwum != golden.ticksSwum {
            misses.append("ticks swum \(shown.ticksSwum), golden \(golden.ticksSwum)")
        }
        if shown.shownTick != golden.shownTick {
            misses.append("tick \(shown.shownTick), golden \(golden.shownTick)")
        }
        if shown.density != golden.density { misses.append("density") }
        if shown.litStencil != golden.litStencil { misses.append("lit stencil") }
        if shown.stray != golden.stray { misses.append("stray") }
        if shown.stencil != golden.stencil { misses.append("stencil") }
        if shown.sites != golden.sites { misses.append("sites") }
        if shown.wells != golden.wells { misses.append("wells") }
        if shown.coverage != golden.coverage || shown.requiredCoverage != golden.requiredCoverage {
            misses.append("coverage \(shown.coverage)/\(shown.requiredCoverage), golden "
                          + "\(golden.coverage)/\(golden.requiredCoverage)")
        }
        if shown.coherence != golden.coherence || shown.requiredCoherence != golden.requiredCoherence {
            misses.append("coherence \(shown.coherence)/\(shown.requiredCoherence), golden "
                          + "\(golden.coherence)/\(golden.requiredCoherence)")
        }
        if shown.swarm != golden.swarm || shown.coherenceRadius != golden.coherenceRadius { misses.append("swarm") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.actionsLeft != golden.actionsLeft {
            misses.append("actions left \(shown.actionsLeft), golden \(golden.actionsLeft)")
        }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.time != golden.time { misses.append("time \(shown.time), golden \(golden.time)") }
        if shown.preview != golden.preview { misses.append("preview") }
        if shown.frozen != golden.frozen { misses.append("frozen \(shown.frozen)") }
        if misses.isEmpty && shown != golden { misses.append("an unnamed field") }
        return misses
    }

    /// The counts and colours of `described` against `golden`; the misses. The ribbon points, gauges and met gauges
    /// are checked for shape (present, gauges 2, met at most the gauges, ribbon points with swimmers); the rest equal
    /// the snapshot's.
    static func countMisses(_ described: Description, golden: Snapshot) -> [String] {
        var misses: [String] = []
        for key in Self.countKeys where described.counts[key] == nil {
            misses.append("count \(key) missing")
        }
        var placed: Int = 0
        for well in golden.wells where well != nil { placed += 1 }
        let expected: [(String, Int)] = [
            ("stencil", golden.stencil.count), ("lit", golden.litStencil.count), ("stray", golden.stray.count),
            ("sites", golden.sites.count), ("wells", placed), ("swimmers", golden.positions.count),
            ("litActions", Geometry.litActions(golden)), ("actions", Swift.max(golden.budget, 0)),
        ]
        for entry in expected {
            if let value: Int = described.counts[entry.0], value != entry.1 {
                misses.append("\(entry.0) \(value), snapshot \(entry.1)")
            }
        }
        if let gauges: Int = described.counts["gauges"], gauges != 2 {
            misses.append("gauges \(gauges), the scene draws 2 (coverage, coherence)")
        }
        if let met: Int = described.counts["met"], met < 0 || met > (described.counts["gauges"] ?? 2) {
            misses.append("met \(met) of \(described.counts["gauges"] ?? 2) gauges")
        }
        if let points: Int = described.counts["ribbonPoints"], !golden.positions.isEmpty, points <= 0 {
            misses.append("ribbon points \(points) with \(golden.positions.count) swimmers")
        }
        for entry in Self.palette {
            let expectedColour: Colour = colour(of: entry.colour)
            if described.colours[entry.name] != expectedColour {
                misses.append("colour \(entry.name) \(String(describing: described.colours[entry.name])), palette "
                              + "\(expectedColour)")
            }
        }
        if described.colours.count != Self.palette.count {
            misses.append("\(described.colours.count) colours described, \(Self.palette.count) expected")
        }
        return misses
    }

    /// The description check: counts, colours and every position agreeing with the CPU reference of `golden` (the
    /// dish centre, every swimmer, every well and every site also on screen). Returns the misses.
    static func descriptionMisses(_ described: Description, golden: Snapshot) -> [String] {
        var misses: [String] = countMisses(described, golden: golden)
        if let miss: String = positionMiss("dish centre", described: described.dish, point: Geometry.dishCentre(),
                                           required: true) {
            misses.append(miss)
        }
        var swimmers: [SIMD3<Double>] = []
        for index in golden.positions.indices { swimmers.append(Geometry.swimmerCentre(index, golden)) }
        misses += listMisses("swimmer", described: described.swimmers, points: swimmers)
        var wells: [SIMD3<Double>] = []
        for slot in golden.wells.indices {
            if let centre: SIMD3<Double> = Geometry.wellCentre(slot, golden) { wells.append(centre) }
        }
        misses += listMisses("well", described: described.wells, points: wells)
        var sites: [SIMD3<Double>] = []
        for index in golden.sites.indices { sites.append(Geometry.siteCentre(index, golden)) }
        misses += listMisses("site", described: described.sites, points: sites)
        if golden.budget > 0 {
            if let miss: String = positionMiss("first actions bar", described: described.firstActionsBar,
                                               point: Geometry.actionsBar(0, golden), required: false) {
                misses.append(miss)
            }
        } else {
            misses.append("the golden snapshot has no actions budget")
        }
        return misses
    }

    // MARK: Pixel checks

    /// The pixel check at the described positions on `rgba` (drawn from `snapshot`): at every described swimmer
    /// centre clear of every element drawn after it, a pixel within 3 px is brighter than the dish field by 0.25 in
    /// luminance; at the described first actions bar, when lit and clear, a pixel within 3 px has blue above green by
    /// 0.08. Returns the misses, how many swimmers were measured and whether the bar was.
    static func describedPixelMisses(_ rgba: [UInt8], _ described: Description,
                                     snapshot: Snapshot) -> (misses: [String], swimmers: Int, bar: Bool) {
        let width: Int = MicroscopicAuroraTest.width
        let height: Int = MicroscopicAuroraTest.height
        var misses: [String] = []
        let layout: MicroscopicAuroraTestLayout = MicroscopicAuroraTest.layout(snapshot, width: width, height: height)
        let floor: Double = MicroscopicAuroraTest.luminance(Palette.field) + MicroscopicAuroraTest.brightMargin
        var swimmers: Int = 0
        for index in described.swimmers.indices {
            guard let p: SIMD2<Double> = described.swimmers[index],
                  MicroscopicAuroraTest.inside(p, width: width, height: height),
                  let rank: Int = layout.rank(.swimmer, index),
                  layout.isClear(p, after: rank, clearance: MicroscopicAuroraTest.clearance) else { continue }
            swimmers += 1
            let found: Bool = MicroscopicAuroraTest.anyPixel(
                rgba, near: p, radius: MicroscopicAuroraTest.pointRadius, width: width, height: height,
                where: { MicroscopicAuroraTest.luminance($0) >= floor })
            if !found {
                let c: SIMD3<Double> = MicroscopicAuroraTest.centre(rgba, p, width: width, height: height)
                misses.append("described swimmer \(index) at (\(p.x), \(p.y)) is \(c), not bright")
            }
        }
        var bar: Bool = false
        if Geometry.litActions(snapshot) > 0, let p: SIMD2<Double> = described.firstActionsBar,
           MicroscopicAuroraTest.inside(p, width: width, height: height),
           let rank: Int = layout.rank(.bar, 0),
           layout.isClear(p, after: rank, clearance: MicroscopicAuroraTest.clearance) {
            bar = true
            let found: Bool = MicroscopicAuroraTest.anyPixel(
                rgba, near: p, radius: MicroscopicAuroraTest.pointRadius, width: width, height: height,
                where: { MicroscopicAuroraTest.isHeliotrope($0) })
            if !found {
                let c: SIMD3<Double> = MicroscopicAuroraTest.centre(rgba, p, width: width, height: height)
                misses.append("described first actions bar at (\(p.x), \(p.y)) is \(c), not blue above green")
            }
        }
        return (misses, swimmers, bar)
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check, the pixel check at the described positions and the feature-483 frame
    /// checks against the presenter's last snapshot; every issue names the frame.
    static func check(_ frame: Frame, session: ExperienceSession,
                      shell: MicroscopicAuroraTest.Shell) throws -> Measured {
        let width: Int = MicroscopicAuroraGolden.width
        let height: Int = MicroscopicAuroraGolden.height
        MicroscopicAuroraTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try MicroscopicAuroraTest.still(session, width: width, height: height, time: frame.time)
        let shown: Snapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: Snapshot = try MicroscopicAuroraGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(golden.shownTick == frame.tick, "\(frame.name): golden tick \(golden.shownTick)")
        #expect(golden.preview == nil && !golden.frozen, "\(frame.name): the golden frame previews and freezes nothing")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(!golden.positions.isEmpty, "\(frame.name): the frame has no swimmers")
        let pixels = Self.describedPixelMisses(rgba, described, snapshot: shown)
        #expect(pixels.misses.isEmpty, "\(frame.name): \(pixels.misses.prefix(4))")
        #expect(pixels.swimmers >= 1, "\(frame.name): no described swimmer centre is clear")
        if Geometry.litActions(shown) > 0 {
            #expect(pixels.bar, "\(frame.name): the described first actions bar is not clear")
        }
        let report: MicroscopicAuroraCheckReport = MicroscopicAuroraTest.checkFrame(
            rgba, snapshot: shown, width: width, height: height, "golden \(frame.name)")
        print("microscopic-aurora golden \(frame.name): tick \(golden.shownTick) of \(golden.ticksSwum), actions left "
              + "\(golden.actionsLeft) of \(golden.budget), wells \(described.counts["wells"] ?? -1), lit "
              + "\(described.counts["lit"] ?? -1) of \(described.counts["stencil"] ?? -1), described swimmers "
              + "measured \(pixels.swimmers) of \(described.swimmers.count)")
        return Measured(report: report, describedSwimmers: pixels.swimmers, describedBar: pixels.bar)
    }

    // MARK: Tests

    /// The golden set has 16 frames with unique names: three tiers per level sharing their placements (the
    /// certified placements, never the play, the level still open) and the tick half the ticks swum, and the hero
    /// frame (the hero scenario's level, tier 0, the certified placements and the hero tick), all at time 0; each
    /// golden snapshot is the CPU reference's.
    @Test func theGoldenSetHasSixteenFrames() throws {
        typealias Core = MicroscopicAuroraExperienceCore
        let frames: [Frame] = MicroscopicAuroraGolden.frames
        #expect(frames.count == 16)
        #expect(MicroscopicAuroraGolden.width == MicroscopicAuroraTest.width)
        #expect(MicroscopicAuroraGolden.height == MicroscopicAuroraTest.height)
        #expect(Self.levels == MicroscopicAuroraTest.levels)
        #expect(Self.palette.count == 18, "the palette has 18 named colours")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        let heroPlan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(heroLevel)
        let heroes: [Frame] = Self.heroFrames()
        #expect(heroes.count == 1, "\(heroes.count) hero frames")
        for frame in heroes {
            #expect(frame.level == heroLevel && frame.tier == 0,
                    "\(frame.name): level \(frame.level) tier \(frame.tier)")
            #expect(frame.actions == heroPlan, "the hero frame makes the certified placements")
            #expect(frame.tick == (Core.heroTick(heroLevel) ?? -1), "the hero frame shows the hero tick")
        }
        for frame in frames {
            #expect(frame.time == 0, "\(frame.name): time \(frame.time)")
            #expect(!frame.actions.contains(.play), "\(frame.name): the frames never play")
            let digest: String = try MicroscopicAuroraGolden.digest(frame)
            #expect(digest.count == 64, "\(frame.name): digest \(digest)")
            let golden: Snapshot = try MicroscopicAuroraGolden.snapshot(frame)
            let reference: Snapshot = try Self.referenceSnapshot(frame)
            let message: String = "\(frame.name): the golden snapshot is the CPU reference's: "
                + "\(Self.snapshotMisses(golden, reference))"
            #expect(golden == reference, Comment(rawValue: message))
            #expect(golden.levelNumber == frame.level, "\(frame.name): level \(golden.levelNumber)")
            #expect(!golden.isWon, "\(frame.name): the level is still open")
            #expect(golden.actionsLeft == golden.budget - frame.actions.count,
                    "\(frame.name): actions left \(golden.actionsLeft) of \(golden.budget)")
        }
        for level in Self.levels {
            let tiers: [Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let expected: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(level)
            let placed: MicroscopicAuroraExperienceCore = try MicroscopicAuroraTest.coreAfter(level, expected,
                                                                                               showHalf: false)
            let tick: Int = MicroscopicAuroraTest.halfTick(placed.play.report.ticks)
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == expected, "\(frame.name): the frames make the certified placements")
                #expect(frame.tick == tick, "\(frame.name): tick \(frame.tick), half the ticks swum is \(tick)")
                tierIndex += 1
            }
        }
        var unique: Set<String> = []
        for frame in frames { unique.insert(frame.name) }
        #expect(unique.count == 16, "frame names are unique")
    }

    /// The 15 level frames render as their golden snapshots and descriptions say; every tier measures a swimmer
    /// (described and by the feature-483 checks) and the first lit actions bar on every level.
    @Test func everyLevelFrameMatchesItsDescription() async throws {
        var swimmers: [Int] = [0, 0, 0]
        var bars: [Int] = [0, 0, 0]
        for level in Self.levels {
            let frames: [Frame] = Self.tierFrames(level: level)
            #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
            guard let first: Frame = frames.first else { continue }
            let session = ExperienceSession()
            defer { session.close() }
            let shell: MicroscopicAuroraTest.Shell = try await Self.open(session, level: level)
            // The three tier frames share their placements and tick: apply them once, then draw each tier.
            try Self.apply(first, to: shell)
            for frame in frames {
                #expect(frame.actions == first.actions && frame.tick == first.tick,
                        "\(frame.name): the tier frames share their placements and tick")
                let measured: Measured = try Self.check(frame, session: session, shell: shell)
                if frame.tier >= 0 && frame.tier < 3 {
                    let both: Bool = measured.report.swimmersChecked >= 1 && measured.describedSwimmers >= 1
                    swimmers[frame.tier] += both ? 1 : 0
                    bars[frame.tier] += measured.report.barChecked && measured.describedBar ? 1 : 0
                }
            }
            session.qualityPin = 0
        }
        print("microscopic-aurora golden level frames: swimmers measured per tier \(swimmers), bars per tier \(bars)")
        for tier in 0..<3 {
            #expect(swimmers[tier] == Self.levels.count,
                    "tier \(tier): a swimmer measured on \(swimmers[tier]) of 5 levels")
        }
    }

    /// The hero frame (the hero scenario's level after the certified placements, the hero tick shown, tier 0)
    /// renders as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        let hero: Frame = try #require(Self.heroFrames().first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: MicroscopicAuroraTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try MicroscopicAuroraTest.digest(shell)
        try Self.apply(hero, to: shell)
        let after: String = try MicroscopicAuroraTest.digest(shell)
        if !hero.actions.isEmpty { #expect(after != before, "the hero placements change the digest") }
        _ = try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
