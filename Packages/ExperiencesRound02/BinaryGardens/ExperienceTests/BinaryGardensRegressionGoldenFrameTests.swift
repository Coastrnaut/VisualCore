// BinaryGardensRegressionGoldenFrameTests — feature 508 (R02-G21-08) T-R02G2108-005 (FR-R02G2108-003, 004;
// SC-R02G2108-003; clarification Q3). User Story 2. Through the one app's session host, each of the 17 code-only golden
// frames of `BinaryGardensGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, then level 25 at
// tier 0 for its full tilt dial, each after all of the witness's actions but not the run, so actions are spent from the
// actions bars and the level is still open, with tick 24 shown, no preview and no inspected world; plus the hero
// frame: the level the hero scenario opens, seed `manifestSeed`, after the certified actions with the hero tick shown,
// tier 0) is drawn off screen at the frame-check size 1,152 × 768 of `BinaryGardensTest` with the frame's tier pinned,
// at the frame's time 0, through the authored camera (no orbit gesture is made). Seed s opens level s % 100 + 1, so a
// frame of level L opens at seed L − 1; the frame's actions go through the adapter (`star.ring`, `star.phase`,
// `star.luminosity`, `orbit.tilt`; never `light.run`), then its tick through `clock.show [frame.tick]`. The snapshot
// the presenter drew equals `BinaryGardensGolden.snapshot(frame)` (every field, the presentation time 0 in both), so the
// rendered frame is the golden one. The frame's description (`BinaryGardensGolden.description`, read here as JSON)
// carries the identity, the tick and tilt, the counts, the star values and world windows of the snapshot, the 27 named
// colours (each the public palette constant of the same name, as 8-bit sRGB) and the 42 materials of
// `BinaryGardensShaders.materials`, and puts the barycentre, every world's centre (world order), both stars' centres,
// the first gauge plate's left margin, the first actions bar and, on level 25, the first tilt pip where the Core's CPU
// reference of the golden snapshot puts them (within one 1/8-pixel quantum per axis); the barycentre, every world,
// both stars, the gauge margin and level 25's first tilt pip are on screen. The pixels then show them there with the
// feature-503 tolerances (`BinaryGardensTest`): at every described world centre clear of every element drawn after it
// (6 px), a pixel within 3 px brighter than the backdrop there by 0.15 in luminance; at every clear star centre by 0.4;
// at the described first actions bar (lit, clear) a pixel within 3 px with red above blue by 0.08; at the described
// gauge margin (clear) a pixel within 3 px 0.05 from the backdrop. Level 25's first tilt pip (step 0, unlit at the
// witness's tilt 3: a ring of outer radius 0.015 whose band spans 0.64 … 1 of it) is checked the same way as the gauge
// margin, a pixel 0.05 from the backdrop, within the larger of 3 px and the pip's projected outer radius, since the
// ring's centre is empty. The picture passes the feature-503 checks (`BinaryGardensTest.checkFrame`) against the
// presenter's last snapshot: every point at least 6 px from every element drawn after it in the painter's order
// (`BinaryGardensSceneGeometry.paintOrder`), the world, star, actions-bar and gauge-margin checks above, the median of
// each 9 × 9 lower-corner patch within 0.06 of the gradient. Every level frame measures at least one world, one star
// and the gauge margin. One test for the set, one for the 15 level frames, one for level 25's dial frame and one for
// the hero frame, each well under 10 s. Modelled on `MushroomWeatherRegressionGoldenFrameTests` (feature 498).
// Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion.
//
// The description is read with `JSONSerialization` (`Description` and `Counts` of the Core are internal): positions
// `barycentre`, `gaugeMargin`, `firstActionsBar`, `firstTiltPip` ([x, y] or null), `worlds`, `stars` (lists of [x, y]
// or null); `counts` (scalars `rings`, `starRings`, `worlds`, `shortBrackets`, `tiltPipsLit`, `tiltPips`,
// `luminosityPipsLit`, `luminosityPips`, `actionsLit`, `actions`, `broken` and five-entry lists `worldsByBand`,
// `cellsByBand`); `starValues` ([{ring, phase, luminosity}]); `windows` ([{integral, window, start}]); `colours`
// (name → [r, g, b]); `materials` ([{code, name, constant}]); `tick`, `tilt`, `name`, `level`, `tier`, `width`,
// `height` and `quantum`. A position is in 1/`quantum` pixel from the top-left, y down.
#if os(iOS)
import BinaryGardensCore
import Foundation
import Testing
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct BinaryGardensRegressionGoldenFrameTests {
    typealias Geometry = BinaryGardensSceneGeometry
    typealias Snapshot = BinaryGardensSceneSnapshot
    typealias Palette = BinaryGardensPalette
    typealias Frame = BinaryGardensGolden.Frame

    /// An 8-bit colour of the description.
    struct Colour: Equatable, CustomStringConvertible {
        let r: Int
        let g: Int
        let b: Int

        var description: String { "(\(r), \(g), \(b))" }
    }

    /// One material entry of the description.
    struct Material: Equatable {
        let code: Int
        let name: String
        let constant: String
    }

    /// The description of one golden frame, read from `BinaryGardensGolden.description(_:)`. Positions are in pixels
    /// (nil: null, behind the eye, absent, or malformed).
    struct Description {
        /// Every top-level key of the JSON object.
        var keys: [String] = []
        /// The pixels per written position unit (1/`quantum`).
        var scale: Double = 1
        var name: String = ""
        var level: Int = -1
        var tier: Int = -1
        var width: Int = -1
        var height: Int = -1
        var tick: Int = -1
        var tilt: Int = -1
        var barycentre: SIMD2<Double>?
        var gaugeMargin: SIMD2<Double>?
        var firstActionsBar: SIMD2<Double>?
        var firstTiltPip: SIMD2<Double>?
        var worlds: [SIMD2<Double>?] = []
        var stars: [SIMD2<Double>?] = []
        var counts: [String: [Int]] = [:]
        var starValues: [[Int]] = []
        var windows: [[Int]] = []
        var colours: [String: Colour] = [:]
        var materials: [Material] = []
    }

    /// What the pixel checks at the described positions of one golden frame measured.
    struct Described {
        var misses: [String] = []
        var worlds: Int = 0
        var stars: Int = 0
        var bar: Bool = false
        var margin: Bool = false
        var pip: Bool = false
    }

    /// The certified levels of the golden set drawn at every tier, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// The level drawn at tier 0 for its full tilt dial.
    static let dialLevel: Int = 25
    /// Positions are described at steps of 1/`quantum` pixel (clarification Q3: 1/8 pixel); one step is the tolerance.
    static let quantum: Int = 8
    /// A rounding allowance on top of one quantum (pixels).
    static let slack: Double = 1e-6
    /// The named colours of the description and the public palette constant each must equal (27).
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("space", Palette.space), ("spaceTop", Palette.spaceTop), ("starfield", Palette.starfield),
        ("ringIdle", Palette.ringIdle), ("orbit", Palette.orbit), ("starOne", Palette.starOne),
        ("starTwo", Palette.starTwo), ("core", Palette.core), ("world", Palette.world), ("frost", Palette.frost),
        ("scorch", Palette.scorch), ("flower", Palette.flower), ("pollen", Palette.pollen),
        ("gaugePlate", Palette.gaugePlate), ("lethalLow", Palette.lethalLow), ("dim", Palette.dim),
        ("comfortable", Palette.comfortable), ("bright", Palette.bright), ("lethalHigh", Palette.lethalHigh),
        ("window", Palette.window), ("marker", Palette.marker), ("tiltLit", Palette.tiltLit),
        ("tiltUnlit", Palette.tiltUnlit), ("actionsLit", Palette.actionsLit), ("actionsUnlit", Palette.actionsUnlit),
        ("broken", Palette.broken), ("glow", Palette.glow),
    ]
    /// The count keys of the description (clarification Q3).
    static let countKeys: [String] = [
        "actions", "actionsLit", "broken", "cellsByBand", "luminosityPips", "luminosityPipsLit", "rings", "shortBrackets",
        "starRings", "tiltPips", "tiltPipsLit", "worlds", "worldsByBand",
    ]
    /// The top-level keys of the description.
    static let topKeys: [String] = [
        "barycentre", "colours", "counts", "firstActionsBar", "firstTiltPip", "gaugeMargin", "height", "level",
        "materials", "name", "quantum", "starValues", "stars", "tick", "tier", "tilt", "width", "windows", "worlds",
    ]

    // MARK: Frames

    /// Whether `frame` is the hero frame (its name names the hero scenario).
    static func isHero(_ frame: Frame) -> Bool {
        frame.name.contains("hero")
    }

    /// The golden frames of `level` other than the hero (its tiers), in their fixed order.
    static func tierFrames(level: Int) -> [Frame] {
        var list: [Frame] = []
        for frame in BinaryGardensGolden.frames where frame.level == level && !isHero(frame) {
            list.append(frame)
        }
        return list
    }

    /// The hero frames of the golden set (one expected).
    static func heroFrames() -> [Frame] {
        var list: [Frame] = []
        for frame in BinaryGardensGolden.frames where isHero(frame) { list.append(frame) }
        return list
    }

    /// Opens `frame`'s level (seed level − 1) without showing a tick, makes the frame's actions through the adapter,
    /// each expected to be accepted, then shows its tick (`clock.show [frame.tick]`); checks the engine shows it,
    /// drawn with motion.
    static func open(_ session: ExperienceSession, frame: Frame) async throws -> BinaryGardensTest.Shell {
        let seed: UInt64 = UInt64(frame.level - 1)
        #expect(BinaryGardensExperienceCore.levelNumber(forSeed: seed) == frame.level)
        let shell: BinaryGardensTest.Shell = try await BinaryGardensTest.open(session, seed: seed,
                                                                              setUp: frame.actions,
                                                                              atCheckTick: false)
        let opened: BinaryGardensExperienceCore = try BinaryGardensTest.core(shell)
        #expect(opened.levelNumber == frame.level, "\(frame.name): seed \(seed) opened level \(opened.levelNumber)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        let result: ActionResult = shell.handle(control: "clock.show", values: [Double(frame.tick)])
        #expect(result == .accepted, "\(frame.name): clock.show [\(frame.tick)]: \(result.code)")
        let core: BinaryGardensExperienceCore = try BinaryGardensTest.core(shell)
        #expect(core.shownTick == frame.tick, "\(frame.name): tick \(core.shownTick) shown, not \(frame.tick)")
        try BinaryGardensTest.draw(session)
        return shell
    }

    /// The CPU reference of `frame` without the golden type: the opening of its level with its actions applied and
    /// its tick shown, at time 0.
    static func referenceSnapshot(_ frame: Frame) throws -> Snapshot {
        var core: BinaryGardensExperienceCore = try BinaryGardensTest.coreAfter(frame.level, frame.actions,
                                                                                showCheckTick: false)
        let result: ActionResult = core.apply(BinaryGardensTest.showAction(frame.tick))
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

    /// The integers of a JSON list (nil when it is not a list of integers).
    static func integers(_ any: Any?) -> [Int]? {
        guard let list = any as? [Any] else { return nil }
        var result: [Int] = []
        for item in list {
            guard let value = integer(item) else { return nil }
            result.append(value)
        }
        return result
    }

    /// The colour written as `[r, g, b]` (nil otherwise).
    static func colour(_ any: Any?) -> Colour? {
        guard let list = integers(any), list.count == 3 else { return nil }
        return Colour(r: list[0], g: list[1], b: list[2])
    }

    /// The integer fields `fields` of each object of the list under `key`, in order (-1 for a missing field).
    static func records(_ object: [String: Any], _ key: String, fields: [String]) -> [[Int]] {
        var result: [[Int]] = []
        guard let list = object[key] as? [Any] else { return result }
        for item in list {
            let record: [String: Any] = item as? [String: Any] ?? [:]
            var values: [Int] = []
            for field in fields { values.append(integer(record[field]) ?? -1) }
            result.append(values)
        }
        return result
    }

    /// The description of `frame`, read from its JSON.
    static func description(_ frame: Frame) throws -> Description {
        let data: Data = try BinaryGardensGolden.description(frame)
        let parsed: Any = try JSONSerialization.jsonObject(with: data)
        let object: [String: Any] = try #require(parsed as? [String: Any], "\(frame.name): not a JSON object")
        var result = Description()
        result.keys = object.keys.sorted()
        let q: Int = try #require(integer(object["quantum"]), "\(frame.name): no quantum")
        #expect(q == Self.quantum, "\(frame.name): quantum \(q), not \(Self.quantum)")
        result.scale = 1 / Double(Swift.max(q, 1))
        result.name = object["name"] as? String ?? ""
        result.level = integer(object["level"]) ?? -1
        result.tier = integer(object["tier"]) ?? -1
        result.width = integer(object["width"]) ?? -1
        result.height = integer(object["height"]) ?? -1
        result.tick = integer(object["tick"]) ?? -1
        result.tilt = integer(object["tilt"]) ?? -1
        result.barycentre = position(object["barycentre"], scale: result.scale)
        result.gaugeMargin = position(object["gaugeMargin"], scale: result.scale)
        result.firstActionsBar = position(object["firstActionsBar"], scale: result.scale)
        result.firstTiltPip = position(object["firstTiltPip"], scale: result.scale)
        result.worlds = positions(object, "worlds", scale: result.scale)
        result.stars = positions(object, "stars", scale: result.scale)
        if let counts = object["counts"] as? [String: Any] {
            for (key, value) in counts {
                if let n = integer(value) {
                    result.counts[key] = [n]
                } else if let list = integers(value) {
                    result.counts[key] = list
                }
            }
        }
        result.starValues = records(object, "starValues", fields: ["ring", "phase", "luminosity"])
        result.windows = records(object, "windows", fields: ["integral", "window", "start"])
        if let colours = object["colours"] as? [String: Any] {
            for (key, value) in colours {
                if let c = colour(value) { result.colours[key] = c }
            }
        }
        if let list = object["materials"] as? [Any] {
            for item in list {
                let record: [String: Any] = item as? [String: Any] ?? [:]
                result.materials.append(Material(code: integer(record["code"]) ?? -1,
                                                 name: record["name"] as? String ?? "",
                                                 constant: record["constant"] as? String ?? ""))
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

    /// The index of `band` in the counts' order (lethal low, dim, comfortable, bright, lethal high).
    static func bandIndex(_ band: BinaryGardensBand) -> Int {
        switch band {
        case .lethalLow: return 0
        case .dim: return 1
        case .comfortable: return 2
        case .bright: return 3
        case .lethalHigh: return 4
        }
    }

    /// The counts `golden` must be described with, computed here from the public snapshot and geometry.
    static func expectedCounts(_ golden: Snapshot) -> [String: [Int]] {
        var standing: Set<Int> = []
        for ring in golden.arrangement.rings where golden.ringRadii.indices.contains(ring) { standing.insert(ring) }
        var worldsByBand: [Int] = [0, 0, 0, 0, 0]
        var cellsByBand: [Int] = [0, 0, 0, 0, 0]
        var short: Int = 0
        for (index, world) in golden.worlds.enumerated() {
            worldsByBand[bandIndex(golden.band(index))] += 1
            for band in world.bands { cellsByBand[bandIndex(band)] += 1 }
            if world.longestWindow < world.window && !Geometry.windowPieces(world).isEmpty { short += 1 }
        }
        var lit: Int = 0
        var pips: Int = 0
        for star in 0..<2 {
            for pip in Geometry.luminosityPips(star, golden) {
                pips += 1
                if pip.lit { lit += 1 }
            }
        }
        let dial: Bool = golden.maxTilt > 0
        var broken: Int = Geometry.lethalMark(golden) == nil ? 0 : 2
        if let world = Geometry.unstableWorld(golden), golden.worlds.indices.contains(world) {
            broken += Swift.max(Geometry.windowPieces(golden.worlds[world]).count, 1)
        }
        if Geometry.bloomWorld(golden) != nil { broken += 1 }
        return [
            "rings": [golden.ringRadii.count], "starRings": [standing.count], "worlds": [golden.worlds.count],
            "worldsByBand": worldsByBand, "cellsByBand": cellsByBand, "shortBrackets": [short],
            "tiltPipsLit": [dial ? 1 : 0], "tiltPips": [dial ? golden.maxTilt + 1 : 0], "luminosityPipsLit": [lit],
            "luminosityPips": [pips], "actionsLit": [Geometry.litActions(golden)],
            "actions": [Swift.max(golden.budget, 0)], "broken": [broken],
        ]
    }

    /// The CPU reference pixel of `point` at the golden size (nil when it does not project).
    static func referencePixel(_ point: SIMD3<Double>) -> SIMD2<Double>? {
        BinaryGardensTest.pixel(point, width: BinaryGardensGolden.width, height: BinaryGardensGolden.height)
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
        return BinaryGardensTest.inside(q, width: BinaryGardensGolden.width, height: BinaryGardensGolden.height)
    }

    /// The described position against the CPU reference of `point` (nil: the description must be null too); the
    /// miss naming `what`, or nil.
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

    /// Every field of `shown` that differs from `golden`.
    static func snapshotMisses(_ shown: Snapshot, _ golden: Snapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.ringRadii != golden.ringRadii { misses.append("ring radii") }
        if shown.luminosityLevels != golden.luminosityLevels { misses.append("luminosity levels") }
        if shown.maxTilt != golden.maxTilt { misses.append("maximum tilt \(shown.maxTilt)") }
        if shown.phaseStep != golden.phaseStep { misses.append("phase step \(shown.phaseStep)") }
        if shown.lethalTolerance != golden.lethalTolerance { misses.append("lethal tolerance") }
        if shown.worlds != golden.worlds { misses.append("worlds") }
        if shown.arrangement != golden.arrangement {
            misses.append("arrangement \(shown.arrangement), golden \(golden.arrangement)")
        }
        if shown.starPositions != golden.starPositions { misses.append("star positions") }
        if shown.shownTick != golden.shownTick { misses.append("tick \(shown.shownTick), golden \(golden.shownTick)") }
        if shown.fitScale != golden.fitScale { misses.append("fit scale") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.actionsLeft != golden.actionsLeft {
            misses.append("actions left \(shown.actionsLeft), golden \(golden.actionsLeft)")
        }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.time != golden.time { misses.append("time \(shown.time), golden \(golden.time)") }
        if shown.starSpeed != golden.starSpeed { misses.append("star speed \(shown.starSpeed)") }
        if shown.freedoms != golden.freedoms { misses.append("freedoms") }
        if shown.preview != golden.preview { misses.append("preview") }
        if shown.inspectedWorld != golden.inspectedWorld { misses.append("inspected world") }
        if misses.isEmpty && shown != golden { misses.append("an unnamed field") }
        return misses
    }

    /// The identity, tick, tilt, counts, values, colours and materials of `described` against `frame` and `golden`;
    /// the misses.
    static func valueMisses(_ described: Description, frame: Frame, golden: Snapshot) -> [String] {
        var misses: [String] = []
        if described.keys != Self.topKeys { misses.append("keys \(described.keys)") }
        if described.name != frame.name || described.level != frame.level || described.tier != frame.tier {
            misses.append("identity \(described.name) level \(described.level) tier \(described.tier)")
        }
        if described.width != BinaryGardensGolden.width || described.height != BinaryGardensGolden.height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if described.tick != golden.shownTick { misses.append("tick \(described.tick), golden \(golden.shownTick)") }
        if described.tilt != golden.arrangement.tilt {
            misses.append("tilt \(described.tilt), golden \(golden.arrangement.tilt)")
        }
        if described.counts.keys.sorted() != Self.countKeys {
            misses.append("count keys \(described.counts.keys.sorted())")
        }
        let expected: [String: [Int]] = expectedCounts(golden)
        for key in Self.countKeys where described.counts[key] != expected[key] {
            misses.append("count \(key) \(described.counts[key] ?? []), snapshot \(expected[key] ?? [])")
        }
        var stars: [[Int]] = []
        for star in 0..<2 {
            let a: BinaryGardensArrangement = golden.arrangement
            stars.append([a.rings.indices.contains(star) ? a.rings[star] : -1,
                          a.phases.indices.contains(star) ? a.phases[star] : -1,
                          a.luminosities.indices.contains(star) ? a.luminosities[star] : -1])
        }
        if described.starValues != stars { misses.append("star values \(described.starValues), snapshot \(stars)") }
        var windows: [[Int]] = []
        for world in golden.worlds { windows.append([world.integral, world.longestWindow, world.windowStart]) }
        if described.windows != windows { misses.append("windows \(described.windows), snapshot \(windows)") }
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
        var materials: [Material] = []
        for entry in BinaryGardensShaders.materials {
            materials.append(Material(code: Int(entry.code), name: entry.name, constant: entry.constant))
        }
        if described.materials != materials {
            misses.append("\(described.materials.count) materials described, the shaders' table has "
                          + "\(materials.count) (or an entry differs)")
        }
        return misses
    }

    /// The description check: identity, values and every position agreeing with the CPU reference of `golden` (the
    /// barycentre, every world, both stars, the gauge margin and a first tilt pip also on screen). Returns the misses.
    static func descriptionMisses(_ described: Description, frame: Frame, golden: Snapshot) -> [String] {
        var misses: [String] = valueMisses(described, frame: frame, golden: golden)
        if let miss: String = positionMiss("barycentre", described: described.barycentre, point: SIMD3(0, 0, 0),
                                           required: true) {
            misses.append(miss)
        }
        if described.worlds.count != golden.worlds.count {
            misses.append("\(described.worlds.count) worlds described, snapshot \(golden.worlds.count)")
        } else {
            for index in golden.worlds.indices {
                if let miss: String = positionMiss("world \(index)", described: described.worlds[index],
                                                   point: Geometry.worldCentre(index, golden), required: true) {
                    misses.append(miss)
                }
            }
        }
        if described.stars.count != 2 {
            misses.append("\(described.stars.count) stars described")
        } else {
            for star in 0..<2 {
                if let miss: String = positionMiss("star \(star)", described: described.stars[star],
                                                   point: Geometry.starCentre(star, golden), required: true) {
                    misses.append(miss)
                }
            }
        }
        let margin: SIMD3<Double>? = golden.worlds.isEmpty ? nil : Geometry.gaugeMargin(0)
        if let miss: String = positionMiss("gauge margin", described: described.gaugeMargin, point: margin,
                                           required: margin != nil) {
            misses.append(miss)
        }
        let bar: SIMD3<Double>? = golden.budget > 0 ? Geometry.actionsBar(0, golden) : nil
        if let miss: String = positionMiss("first actions bar", described: described.firstActionsBar, point: bar,
                                           required: false) {
            misses.append(miss)
        }
        let pip: SIMD3<Double>? = golden.maxTilt > 0 ? Geometry.tiltPipCentre(0) : nil
        if let miss: String = positionMiss("first tilt pip", described: described.firstTiltPip, point: pip,
                                           required: pip != nil) {
            misses.append(miss)
        }
        return misses
    }

    // MARK: Pixel checks

    /// Whether some pixel within `radius` of `p` is at least 0.05 from the backdrop gradient there in luminance.
    static func offBackdrop(_ rgba: [UInt8], _ p: SIMD2<Double>, radius: Double,
                            sky: BinaryGardensTestBackdrop) -> Bool {
        let back: Double = BinaryGardensTest.luminance(sky.gradient(x: p.x, y: p.y))
        return BinaryGardensTest.anyPixel(
            rgba, near: p, radius: radius, width: BinaryGardensTest.width, height: BinaryGardensTest.height,
            where: { Swift.abs(BinaryGardensTest.luminance($0) - back) >= BinaryGardensTest.marginDifference })
    }

    /// Whether some pixel within 3 px of `p` is brighter than the backdrop there by `margin` in luminance.
    static func brighter(_ rgba: [UInt8], _ p: SIMD2<Double>, margin: Double, sky: BinaryGardensTestBackdrop) -> Bool {
        let floor: Double = BinaryGardensTest.luminance(sky.gradient(x: p.x, y: p.y)) + margin
        return BinaryGardensTest.anyPixel(
            rgba, near: p, radius: BinaryGardensTest.pointRadius, width: BinaryGardensTest.width,
            height: BinaryGardensTest.height, where: { BinaryGardensTest.luminance($0) >= floor })
    }

    /// The projected outer radius (pixels) of a tilt pip's shape at the golden size: the distance between the
    /// projections of tilt pip 0's centre and that centre moved one shape half (0.015) to +x.
    static func tiltPipRadius() -> Double {
        let centre: SIMD3<Double> = Geometry.tiltPipCentre(0)
        guard let a = referencePixel(centre),
              let b = referencePixel(centre + SIMD3<Double>(Geometry.tiltPipRadius, 0, 0)) else { return 0 }
        let d: SIMD2<Double> = b - a
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The pixel check at the described positions on `rgba` (drawn from `snapshot` at `tier`) with the feature-503
    /// tolerances: every described world centre clear of every element drawn after it, a pixel within 3 px brighter
    /// than the backdrop by 0.15; every clear star centre by 0.4; the described first actions bar, when lit and
    /// clear, red above blue by 0.08 within 3 px; the described gauge margin, when clear, a pixel within 3 px 0.05 from
    /// the backdrop; the described first tilt pip, when clear, a pixel 0.05 from the backdrop within the larger of
    /// 3 px and the pip's projected outer radius (the ring's centre is empty when the pip is unlit).
    static func describedPixelMisses(_ rgba: [UInt8], _ described: Description, snapshot: Snapshot,
                                     tier: Int) -> Described {
        let width: Int = BinaryGardensTest.width
        let height: Int = BinaryGardensTest.height
        var result = Described()
        let layout: BinaryGardensTestLayout = BinaryGardensTest.layout(snapshot, tier: tier, width: width,
                                                                       height: height)
        guard let sky: BinaryGardensTestBackdrop = BinaryGardensTest.backdrop(width: width, height: height) else {
            result.misses.append("an empty target")
            return result
        }
        let clearance: Double = BinaryGardensTest.clearance
        for index in described.worlds.indices {
            guard let p: SIMD2<Double> = described.worlds[index], BinaryGardensTest.inside(p, width: width,
                                                                                          height: height),
                  let rank: Int = layout.rank(.world, index),
                  layout.isClear(p, after: rank, clearance: clearance) else { continue }
            result.worlds += 1
            if !brighter(rgba, p, margin: BinaryGardensTest.worldMargin, sky: sky) {
                let c: SIMD3<Double> = BinaryGardensTest.centre(rgba, p)
                result.misses.append("described world \(index) at (\(p.x), \(p.y)) is \(c), not 0.15 above the "
                                     + "backdrop")
            }
        }
        for index in described.stars.indices {
            guard let p: SIMD2<Double> = described.stars[index], BinaryGardensTest.inside(p, width: width,
                                                                                         height: height),
                  let rank: Int = layout.rank(.star, index),
                  layout.isClear(p, after: rank, clearance: clearance) else { continue }
            result.stars += 1
            if !brighter(rgba, p, margin: BinaryGardensTest.starMargin, sky: sky) {
                let c: SIMD3<Double> = BinaryGardensTest.centre(rgba, p)
                result.misses.append("described star \(index) at (\(p.x), \(p.y)) is \(c), not 0.4 above the "
                                     + "backdrop")
            }
        }
        if Geometry.litActions(snapshot) > 0, let p: SIMD2<Double> = described.firstActionsBar,
           BinaryGardensTest.inside(p, width: width, height: height),
           let rank: Int = layout.rank(.actions, 0), layout.isClear(p, after: rank, clearance: clearance) {
            result.bar = true
            let found: Bool = BinaryGardensTest.anyPixel(rgba, near: p, radius: BinaryGardensTest.pointRadius,
                                                         width: width, height: height,
                                                         where: BinaryGardensTest.isVermilion)
            if !found {
                let c: SIMD3<Double> = BinaryGardensTest.centre(rgba, p)
                result.misses.append("described first actions bar at (\(p.x), \(p.y)) is \(c), not red above blue")
            }
        }
        if !snapshot.worlds.isEmpty, let p: SIMD2<Double> = described.gaugeMargin,
           BinaryGardensTest.inside(p, width: width, height: height),
           let rank: Int = layout.rank(.gauge, 0), layout.isClear(p, after: rank, clearance: clearance) {
            result.margin = true
            if !offBackdrop(rgba, p, radius: BinaryGardensTest.pointRadius, sky: sky) {
                result.misses.append("described gauge margin at (\(p.x), \(p.y)) is backdrop-coloured")
            }
        }
        if snapshot.maxTilt > 0, let p: SIMD2<Double> = described.firstTiltPip,
           BinaryGardensTest.inside(p, width: width, height: height),
           let rank: Int = layout.rank(.tiltDial, 0), layout.isClear(p, after: rank, clearance: clearance) {
            result.pip = true
            let radius: Double = Swift.max(BinaryGardensTest.pointRadius, tiltPipRadius())
            if !offBackdrop(rgba, p, radius: radius, sky: sky) {
                let c: SIMD3<Double> = BinaryGardensTest.centre(rgba, p)
                result.misses.append("described first tilt pip at (\(p.x), \(p.y)) is \(c): no pixel within "
                                     + "\(radius) px is 0.05 from the backdrop")
            }
        }
        return result
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check, the pixel check at the described positions and the feature-503 frame
    /// checks against the presenter's last snapshot; every issue names the frame.
    static func check(_ frame: Frame, session: ExperienceSession,
                      shell: BinaryGardensTest.Shell) throws -> (report: BinaryGardensCheckReport, described: Described) {
        let width: Int = BinaryGardensGolden.width
        let height: Int = BinaryGardensGolden.height
        BinaryGardensTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try BinaryGardensTest.still(session, width: width, height: height, time: frame.time)
        let shown: Snapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: Snapshot = try BinaryGardensGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(golden.shownTick == frame.tick, "\(frame.name): golden tick \(golden.shownTick)")
        #expect(golden.preview == nil && golden.inspectedWorld == nil,
                "\(frame.name): the golden frame previews and inspects nothing")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        let pixels: Described = Self.describedPixelMisses(rgba, described, snapshot: shown, tier: frame.tier)
        #expect(pixels.misses.isEmpty, "\(frame.name): \(pixels.misses.prefix(4))")
        #expect(pixels.worlds >= 1, "\(frame.name): no described world centre is clear")
        #expect(pixels.stars >= 1, "\(frame.name): no described star centre is clear")
        #expect(pixels.margin, "\(frame.name): the described gauge margin is not clear")
        if Geometry.litActions(shown) > 0 {
            #expect(pixels.bar, "\(frame.name): the described first actions bar is not clear")
        }
        let report: BinaryGardensCheckReport = BinaryGardensTest.checkFrame(
            rgba, snapshot: shown, tier: frame.tier, width: width, height: height, "golden \(frame.name)")
        print("binary-gardens golden \(frame.name): tick \(golden.shownTick), tilt \(golden.arrangement.tilt) of "
              + "\(golden.maxTilt), actions left \(golden.actionsLeft) of \(golden.budget), described worlds "
              + "measured \(pixels.worlds) of \(described.worlds.count), stars \(pixels.stars), bar \(pixels.bar), "
              + "margin \(pixels.margin), tilt pip \(pixels.pip)")
        return (report, pixels)
    }

    // MARK: Tests

    /// The golden set has 17 frames with unique names: three tiers per checked level and level 25 at tier 0, sharing
    /// a level's actions (the certified actions, never the run, the level still open) and tick 24, and the hero frame
    /// (the hero scenario's level, tier 0, the certified actions and the hero tick), all at time 0; each golden
    /// snapshot is the CPU reference's; level 25 alone has a tilt dial.
    @Test func theGoldenSetHasSeventeenFrames() throws {
        typealias Core = BinaryGardensExperienceCore
        let frames: [Frame] = BinaryGardensGolden.frames
        #expect(frames.count == 17)
        #expect(BinaryGardensGolden.width == BinaryGardensTest.width)
        #expect(BinaryGardensGolden.height == BinaryGardensTest.height)
        #expect(BinaryGardensGolden.quantum == Self.quantum)
        #expect(BinaryGardensGolden.tick == BinaryGardensTest.checkTick)
        #expect(Self.levels == BinaryGardensTest.levels)
        #expect(Self.levels == BinaryGardensGolden.levels)
        #expect(BinaryGardensGolden.dialLevel == Self.dialLevel)
        #expect(Self.palette.count == 27, "the palette has 27 named colours")
        var names: [String] = []
        for entry in Self.palette { names.append(entry.name) }
        #expect(names == BinaryGardensGolden.colourNames, "the described colour names")
        #expect(BinaryGardensShaders.materials.count == 42, "the material table has 42 entries")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        let heroPlan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(heroLevel)
        let heroes: [Frame] = Self.heroFrames()
        #expect(heroes.count == 1, "\(heroes.count) hero frames")
        for frame in heroes {
            #expect(frame.level == heroLevel && frame.tier == 0,
                    "\(frame.name): level \(frame.level) tier \(frame.tier)")
            #expect(frame.actions == heroPlan, "the hero frame makes the certified actions")
            #expect(frame.tick == (Core.heroTick(heroLevel) ?? -1), "the hero frame shows the hero tick")
        }
        for frame in frames {
            #expect(frame.time == 0, "\(frame.name): time \(frame.time)")
            #expect(!frame.actions.contains(.run), "\(frame.name): the frames never run")
            let digest: String = try BinaryGardensGolden.digest(frame)
            #expect(digest.count == 64, "\(frame.name): digest \(digest)")
            let golden: Snapshot = try BinaryGardensGolden.snapshot(frame)
            let reference: Snapshot = try Self.referenceSnapshot(frame)
            let message: String = "\(frame.name): the golden snapshot is the CPU reference's: "
                + "\(Self.snapshotMisses(golden, reference))"
            #expect(golden == reference, Comment(rawValue: message))
            #expect(golden.levelNumber == frame.level, "\(frame.name): level \(golden.levelNumber)")
            #expect(!golden.isWon && golden.stage == .playing, "\(frame.name): the level is still open")
            #expect(golden.failure == nil, "\(frame.name): the predicted run wins")
            #expect(golden.actionsLeft == golden.budget - frame.actions.count,
                    "\(frame.name): actions left \(golden.actionsLeft) of \(golden.budget)")
            #expect((golden.maxTilt > 0) == (frame.level == Self.dialLevel),
                    "\(frame.name): maximum tilt \(golden.maxTilt)")
        }
        for level in Self.levels + [Self.dialLevel] {
            let tiers: [Frame] = Self.tierFrames(level: level)
            let count: Int = level == Self.dialLevel ? 1 : 3
            #expect(tiers.count == count, "level \(level) has \(count) tier frames")
            let expected: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(level)
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == expected, "\(frame.name): the frames make the certified actions")
                #expect(frame.tick == BinaryGardensTest.checkTick, "\(frame.name): tick \(frame.tick)")
                tierIndex += 1
            }
            // All tiers of a level share every position and count.
            if tiers.count == 3 {
                let first: Description = try Self.description(tiers[0])
                for frame in tiers.dropFirst() {
                    let other: Description = try Self.description(frame)
                    let same: Bool = other.barycentre == first.barycentre && other.worlds == first.worlds
                        && other.stars == first.stars && other.gaugeMargin == first.gaugeMargin
                        && other.firstActionsBar == first.firstActionsBar && other.firstTiltPip == first.firstTiltPip
                        && other.counts == first.counts
                    #expect(same, "\(frame.name): the tier frames share every position and count")
                }
            }
        }
        // Level 25's dial: four pips, the witness's tilt lit, its first pip on screen at a measurable size.
        let dial: Frame = try #require(Self.tierFrames(level: Self.dialLevel).first, "no level 25 frame")
        let dialDescription: Description = try Self.description(dial)
        #expect(dialDescription.counts["tiltPips"] == [4], "level 25 tilt pips \(dialDescription.counts)")
        #expect(dialDescription.counts["tiltPipsLit"] == [1])
        #expect(Self.onScreen(dialDescription.firstTiltPip), "level 25's first tilt pip is off screen")
        #expect(Self.tiltPipRadius() >= 1, "the tilt pip's projected radius \(Self.tiltPipRadius()) px")
        var unique: Set<String> = []
        for frame in frames { unique.insert(frame.name) }
        #expect(unique.count == 17, "frame names are unique")
    }

    /// The 15 level frames render as their golden snapshots and descriptions say; every tier measures a world, a star
    /// and the gauge margin (described and by the feature-503 checks) on every level.
    @Test func everyLevelFrameMatchesItsDescription() async throws {
        var worlds: [Int] = [0, 0, 0]
        var stars: [Int] = [0, 0, 0]
        var margins: [Int] = [0, 0, 0]
        var bars: [Int] = [0, 0, 0]
        for level in Self.levels {
            let frames: [Frame] = Self.tierFrames(level: level)
            #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
            guard let first: Frame = frames.first else { continue }
            let session = ExperienceSession()
            defer { session.close() }
            // The three tier frames share their actions and tick: open once, then draw each tier.
            let shell: BinaryGardensTest.Shell = try await Self.open(session, frame: first)
            for frame in frames {
                #expect(frame.actions == first.actions && frame.tick == first.tick,
                        "\(frame.name): the tier frames share their actions and tick")
                let measured = try Self.check(frame, session: session, shell: shell)
                if frame.tier >= 0 && frame.tier < 3 {
                    worlds[frame.tier] += measured.report.worldsChecked >= 1 && measured.described.worlds >= 1 ? 1 : 0
                    stars[frame.tier] += measured.report.starsChecked >= 1 && measured.described.stars >= 1 ? 1 : 0
                    margins[frame.tier] += measured.report.marginChecked && measured.described.margin ? 1 : 0
                    bars[frame.tier] += measured.report.barChecked && measured.described.bar ? 1 : 0
                }
            }
            session.qualityPin = 0
        }
        print("binary-gardens golden level frames: worlds measured per tier \(worlds), stars \(stars), margins "
              + "\(margins), bars \(bars)")
        for tier in 0..<3 {
            #expect(worlds[tier] == Self.levels.count, "tier \(tier): a world measured on \(worlds[tier]) of 5 levels")
            #expect(stars[tier] == Self.levels.count, "tier \(tier): a star measured on \(stars[tier]) of 5 levels")
            #expect(margins[tier] == Self.levels.count,
                    "tier \(tier): the gauge margin measured on \(margins[tier]) of 5 levels")
        }
    }

    /// Level 25's frame (the full tilt dial, the witness's tilt 3 lit) renders as described, its first tilt pip
    /// included.
    @Test func theDialFrameMatchesItsDescription() async throws {
        let dial: Frame = try #require(Self.tierFrames(level: Self.dialLevel).first, "no level 25 frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: BinaryGardensTest.Shell = try await Self.open(session, frame: dial)
        let measured = try Self.check(dial, session: session, shell: shell)
        #expect(measured.described.pip, "level 25: the described first tilt pip is not clear")
        session.qualityPin = 0
    }

    /// The hero frame (the hero scenario's level after the certified actions, the hero tick shown, tier 0) renders as
    /// described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        let hero: Frame = try #require(Self.heroFrames().first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let opening: BinaryGardensExperienceCore = try BinaryGardensExperienceCore.opening(number: hero.level)
        let shell: BinaryGardensTest.Shell = try await Self.open(session, frame: hero)
        let arranged: BinaryGardensExperienceCore = try BinaryGardensTest.core(shell)
        if !hero.actions.isEmpty {
            #expect(arranged.play.arrangement != opening.play.arrangement, "the hero actions change the arrangement")
        }
        _ = try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
