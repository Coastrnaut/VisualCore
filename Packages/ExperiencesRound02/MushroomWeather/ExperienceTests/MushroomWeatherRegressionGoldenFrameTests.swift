// MushroomWeatherRegressionGoldenFrameTests — feature 498 (R02-G20-08) T-R02G2008-005 (FR-R02G2008-003, 004;
// SC-R02G2008-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `MushroomWeatherGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after all
// of the witness's actions but not the run, so actions are spent from the actions bars and the level is still open,
// with no preview, shown at the cycle half the cycles run; plus the hero frame: the level the hero scenario opens, seed
// `manifestSeed`, after the certified actions with the hero cycle shown, tier 0) is drawn off screen at the frame-check
// size 1,152 × 768 of `MushroomWeatherTest` with the frame's tier pinned, at the frame's time 0. Seed s opens level
// s % 100 + 1, so a frame of level L opens at seed L − 1; the frame's actions go through the adapter (`pod.place`,
// `pod.remove`, `vent.set`, `moon.set`; never `weather.run`), then its cycle through `clock.show [frame.cycle]`. The
// snapshot the presenter drew equals `MushroomWeatherGolden.snapshot(frame)` (every field, the presentation time 0 in
// both), so the rendered frame is the golden one. The frame's description (`MushroomWeatherGolden.description`, read
// here as JSON) carries the counts and the 21 named colours (each the palette constant of the same name, as 8-bit
// sRGB), and puts the floor centre, every cap centre (colony order), the moon centre, the first gauge track and the
// first actions bar where the Core's CPU reference of the golden snapshot puts them (within one 1/8-pixel quantum per
// axis); the floor centre, every cap, the moon and the first gauge track are on screen. The pixels then show them there
// with the feature-493 tolerances (`MushroomWeatherTest`): at every described cap centre clear of every element drawn
// after it, a pixel within 3 px is brighter than moss by 0.2 in luminance; at the described moon centre (clear) a pixel
// within 3 px is 0.1 from the backdrop in luminance; at the described first actions bar (lit, clear) a pixel within
// 3 px has red above blue by 0.08; at the described first gauge track (clear) a pixel within 3 px is 0.1 from the
// backdrop. The picture passes the feature-493 checks (`MushroomWeatherTest.checkFrame`) against the presenter's last
// snapshot: every point at least 6 px from every element drawn after it in the painter's order
// (`MushroomWeatherSceneGeometry.paintOrder`), the cap, moon, actions-bar and gauge-track checks above, the median of
// each 9 × 9 lower-corner patch within 0.06 of the gradient. Each tier measures at least one cap on every level frame.
// One test for the set, one for the 15 level frames and one for the hero frame, each well under 10 s. Modelled on
// `MicroscopicAuroraRegressionGoldenFrameTests` (feature 488). Synthetic data, explicit types, plain loops, no sleep,
// no wall-clock assertion.
//
// Out-of-band caps. Levels 61 and 81 have no colony in band at the shown cycle, so every cap there is drawn in the
// out-of-band colour (`MushroomWeatherPalette.capOut`, #3F6E5A). The feature-493 cap check (`checkCaps`) applies the
// same 0.2 margin over moss to every clear cap whatever its band, and so does this file: no cap is exempted and the
// margin is not lowered. The flat out-of-band colour (level-2) has luminance 0.387 against the bound 0.330 (moss 0.130
// + 0.2); `theGoldenSetHasSixteenFrames` asserts that headroom, so a palette change that would make the out-of-band
// check unmeetable fails by name before any pixel is read.
//
// The description is read with `JSONSerialization` (`Description` and `Counts` of the Core are internal): `floor`,
// `moon`, `firstGaugeTrack`, `firstActionsBar` ([x, y] or null), `caps` (a list of [x, y] or null, colony order),
// `counts` (`floor`, `blocked`, `mist`, `sites`, `pods`, `grown`, `vents`, `open`, `colonies`, `inBand`, `litActions`,
// `actions`), `colours` (name → [r, g, b]), `moonlight`, `cycle`, `name`, `level`, `tier`, `width`, `height` and
// `quantum`. A position is in 1/`quantum` pixel from the top-left, y down.
#if os(iOS)
import Foundation
import MushroomWeatherCore
import Testing
@testable import MushroomWeatherExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MushroomWeatherRegressionGoldenFrameTests {
    typealias Geometry = MushroomWeatherSceneGeometry
    typealias Snapshot = MushroomWeatherSceneSnapshot
    typealias Palette = MushroomWeatherPalette
    typealias Frame = MushroomWeatherGolden.Frame

    /// An 8-bit colour of the description.
    struct Colour: Equatable, CustomStringConvertible {
        let r: Int
        let g: Int
        let b: Int

        var description: String { "(\(r), \(g), \(b))" }
    }

    /// The description of one golden frame, read from `MushroomWeatherGolden.description(_:)`. Positions are in pixels
    /// (nil: null, behind the eye, or malformed).
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
        var cycle: Int = -1
        var moonlight: Int = -1
        var floor: SIMD2<Double>?
        var moon: SIMD2<Double>?
        var firstGaugeTrack: SIMD2<Double>?
        var firstActionsBar: SIMD2<Double>?
        var caps: [SIMD2<Double>?] = []
        var counts: [String: Int] = [:]
        var colours: [String: Colour] = [:]
    }

    /// What the pixel checks of one golden frame measured.
    struct Measured {
        /// The feature-493 report.
        var report: MushroomWeatherCheckReport
        /// How many described cap centres were measured in the pixels.
        var describedCaps: Int
        /// Whether the described moon centre was measured.
        var describedMoon: Bool
        /// Whether the described first actions bar was measured.
        var describedBar: Bool
        /// Whether the described first gauge track was measured.
        var describedTrack: Bool
    }

    /// The certified levels of the golden set, one per band (clarification Q3).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// Positions are described at steps of 1/`quantum` pixel (clarification Q3: 1/8 pixel); one step is the tolerance.
    static let quantum: Int = 8
    /// A rounding allowance on top of one quantum (pixels).
    static let slack: Double = 1e-6
    /// The named colours of the description and the palette constant each must equal (21).
    static let palette: [(name: String, colour: SIMD3<Double>)] = [
        ("midnight", Palette.midnight), ("midnightTop", Palette.midnightTop), ("moon", Palette.moon),
        ("moss", Palette.moss), ("log", Palette.log), ("frond", Palette.frond), ("mistLow", Palette.mistLow),
        ("mistHigh", Palette.mistHigh), ("site", Palette.site), ("stalk", Palette.stalk), ("cap", Palette.cap),
        ("capOut", Palette.capOut), ("pod", Palette.pod), ("droplet", Palette.droplet), ("vent", Palette.vent),
        ("band", Palette.band), ("marker", Palette.marker), ("actionsLit", Palette.actionsLit),
        ("actionsUnlit", Palette.actionsUnlit), ("broken", Palette.broken), ("glow", Palette.glow),
    ]
    /// The count keys of the description (clarification Q3).
    static let countKeys: [String] = [
        "floor", "blocked", "mist", "sites", "pods", "grown", "vents", "open", "colonies", "inBand", "litActions",
        "actions",
    ]
    /// The top-level keys of the description.
    static let topKeys: [String] = [
        "caps", "colours", "counts", "cycle", "firstActionsBar", "firstGaugeTrack", "floor", "height", "level", "moon",
        "moonlight", "name", "quantum", "tier", "width",
    ]

    // MARK: Frames

    /// Whether `frame` is the hero frame (its name names the hero scenario).
    static func isHero(_ frame: Frame) -> Bool {
        frame.name.contains("hero")
    }

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [Frame] {
        var list: [Frame] = []
        for frame in MushroomWeatherGolden.frames where frame.level == level && !isHero(frame) {
            list.append(frame)
        }
        return list
    }

    /// The hero frames of the golden set (one expected).
    static func heroFrames() -> [Frame] {
        var list: [Frame] = []
        for frame in MushroomWeatherGolden.frames where isHero(frame) { list.append(frame) }
        return list
    }

    /// Opens `level` (seed level − 1) without showing a cycle and checks that the engine shows it, drawn with motion.
    static func open(_ session: ExperienceSession, level: Int) async throws -> MushroomWeatherTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(MushroomWeatherExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: MushroomWeatherTest.Shell = try await MushroomWeatherTest.open(session, seed: seed, atHalf: false)
        let opened: Int = try MushroomWeatherTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// Sends `frame`'s actions through the adapter, each expected to be accepted, then shows its cycle
    /// (`clock.show [frame.cycle]`).
    static func apply(_ frame: Frame, to shell: MushroomWeatherTest.Shell) throws {
        let accepted: Int = MushroomWeatherTest.issue(shell, frame.actions)
        #expect(accepted == frame.actions.count,
                "\(frame.name): \(accepted) of \(frame.actions.count) actions accepted")
        let result: ActionResult = shell.handle(control: "clock.show", values: [Double(frame.cycle)])
        #expect(result == .accepted, "\(frame.name): clock.show [\(frame.cycle)]: \(result.code)")
        let core: MushroomWeatherExperienceCore = try MushroomWeatherTest.core(shell)
        #expect(core.shownCycle == frame.cycle, "\(frame.name): cycle \(core.shownCycle) shown, not \(frame.cycle)")
    }

    /// The CPU reference of `frame` without the golden type: the opening of its level with its actions applied and
    /// its cycle shown, at time 0.
    static func referenceSnapshot(_ frame: Frame) throws -> Snapshot {
        var core: MushroomWeatherExperienceCore = try MushroomWeatherTest.coreAfter(frame.level, frame.actions,
                                                                                     showHalf: false)
        let result: ActionResult = core.apply(MushroomWeatherTest.showAction(frame.cycle))
        #expect(result == .accepted, "\(frame.name): clock.show [\(frame.cycle)]: \(result.code)")
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

    /// The colour written as `[r, g, b]` (nil otherwise).
    static func colour(_ any: Any?) -> Colour? {
        guard let list = any as? [Any], list.count == 3, let r = integer(list[0]), let g = integer(list[1]),
              let b = integer(list[2]) else { return nil }
        return Colour(r: r, g: g, b: b)
    }

    /// The description of `frame`, read from its JSON.
    static func description(_ frame: Frame) throws -> Description {
        let data: Data = try MushroomWeatherGolden.description(frame)
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
        result.cycle = integer(object["cycle"]) ?? -1
        result.moonlight = integer(object["moonlight"]) ?? -1
        result.floor = position(object["floor"], scale: result.scale)
        result.moon = position(object["moon"], scale: result.scale)
        result.firstGaugeTrack = position(object["firstGaugeTrack"], scale: result.scale)
        result.firstActionsBar = position(object["firstActionsBar"], scale: result.scale)
        result.caps = positions(object, "caps", scale: result.scale)
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
        MushroomWeatherTest.pixel(point, width: MushroomWeatherGolden.width, height: MushroomWeatherGolden.height)
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
        return MushroomWeatherTest.inside(q, width: MushroomWeatherGolden.width, height: MushroomWeatherGolden.height)
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

    /// Every field of `shown` that differs from `golden`.
    static func snapshotMisses(_ shown: Snapshot, _ golden: Snapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.rows != golden.rows || shown.columns != golden.columns {
            misses.append("size \(shown.rows) × \(shown.columns), golden \(golden.rows) × \(golden.columns)")
        }
        if shown.blocked != golden.blocked { misses.append("blocked") }
        if shown.fields != golden.fields { misses.append("fields") }
        if shown.cyclesRun != golden.cyclesRun {
            misses.append("cycles run \(shown.cyclesRun), golden \(golden.cyclesRun)")
        }
        if shown.shownCycle != golden.shownCycle {
            misses.append("cycle \(shown.shownCycle), golden \(golden.shownCycle)")
        }
        if shown.moldBound != golden.moldBound { misses.append("mold bound \(shown.moldBound)") }
        if shown.colonies != golden.colonies { misses.append("colonies") }
        if shown.requiredCycles != golden.requiredCycles { misses.append("required cycles \(shown.requiredCycles)") }
        if shown.pods != golden.pods { misses.append("pods") }
        if shown.grownAt != golden.grownAt { misses.append("grown at") }
        if shown.sites != golden.sites { misses.append("sites") }
        if shown.vents != golden.vents || shown.ventsOpen != golden.ventsOpen { misses.append("vents") }
        if shown.moonlight != golden.moonlight {
            misses.append("moonlight \(shown.moonlight), golden \(golden.moonlight)")
        }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.actionsLeft != golden.actionsLeft {
            misses.append("actions left \(shown.actionsLeft), golden \(golden.actionsLeft)")
        }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.time != golden.time { misses.append("time \(shown.time), golden \(golden.time)") }
        if shown.preview != golden.preview { misses.append("preview") }
        if misses.isEmpty && shown != golden { misses.append("an unnamed field") }
        return misses
    }

    /// The identity, counts and colours of `described` against `frame` and `golden`; the misses.
    static func countMisses(_ described: Description, frame: Frame, golden: Snapshot) -> [String] {
        var misses: [String] = []
        if described.keys != Self.topKeys { misses.append("keys \(described.keys)") }
        if described.name != frame.name || described.level != frame.level || described.tier != frame.tier {
            misses.append("identity \(described.name) level \(described.level) tier \(described.tier)")
        }
        if described.width != MushroomWeatherGolden.width || described.height != MushroomWeatherGolden.height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if described.cycle != golden.shownCycle {
            misses.append("cycle \(described.cycle), golden \(golden.shownCycle)")
        }
        if described.moonlight != golden.moonlight {
            misses.append("moonlight \(described.moonlight), golden \(golden.moonlight)")
        }
        for key in Self.countKeys where described.counts[key] == nil {
            misses.append("count \(key) missing")
        }
        if described.counts.count != Self.countKeys.count {
            misses.append("\(described.counts.count) counts described, \(Self.countKeys.count) expected")
        }
        var pods: Int = 0
        var grown: Int = 0
        for slot in golden.pods.indices where golden.pods[slot] != nil {
            pods += 1
            if golden.isGrown(slot) { grown += 1 }
        }
        var open: Int = 0
        for index in golden.vents.indices where Geometry.ventOpen(index, golden) { open += 1 }
        var inBand: Int = 0
        for colony in golden.colonies where colony.inBand { inBand += 1 }
        let expected: [(String, Int)] = [
            ("floor", Geometry.floorCells(golden).count), ("blocked", golden.blocked.count),
            ("mist", Geometry.mistSquares(golden).count), ("sites", golden.sites.count), ("pods", pods),
            ("grown", grown), ("vents", golden.vents.count), ("open", open), ("colonies", golden.colonies.count),
            ("inBand", inBand), ("litActions", Geometry.litActions(golden)), ("actions", Swift.max(golden.budget, 0)),
        ]
        for entry in expected {
            if let value: Int = described.counts[entry.0], value != entry.1 {
                misses.append("\(entry.0) \(value), snapshot \(entry.1)")
            }
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

    /// The description check: identity, counts, colours and every position agreeing with the CPU reference of `golden`
    /// (the floor centre, every cap, the moon and the first gauge track also on screen). Returns the misses.
    static func descriptionMisses(_ described: Description, frame: Frame, golden: Snapshot) -> [String] {
        var misses: [String] = countMisses(described, frame: frame, golden: golden)
        if let miss: String = positionMiss("floor centre", described: described.floor, point: Geometry.floorCentre(),
                                           required: true) {
            misses.append(miss)
        }
        if described.caps.count != golden.colonies.count {
            misses.append("\(described.caps.count) caps described, snapshot \(golden.colonies.count)")
        } else {
            for index in golden.colonies.indices {
                if let miss: String = positionMiss("cap \(index)", described: described.caps[index],
                                                   point: Geometry.capCentre(index, golden), required: true) {
                    misses.append(miss)
                }
            }
        }
        if let miss: String = positionMiss("moon centre", described: described.moon, point: Geometry.moonCentre(),
                                           required: true) {
            misses.append(miss)
        }
        if golden.colonies.isEmpty {
            misses.append("the golden snapshot has no colonies")
        } else if let miss: String = positionMiss("first gauge track", described: described.firstGaugeTrack,
                                                  point: Geometry.gaugeTrackCentre(0), required: true) {
            misses.append(miss)
        }
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

    /// Whether some pixel within 3 px of `p` is at least 0.1 from the backdrop gradient there in luminance.
    static func offBackdrop(_ rgba: [UInt8], _ p: SIMD2<Double>, sky: MushroomWeatherTestBackdrop) -> Bool {
        let back: Double = MushroomWeatherTest.luminance(sky.gradient(x: p.x, y: p.y))
        return MushroomWeatherTest.anyPixel(
            rgba, near: p, radius: MushroomWeatherTest.pointRadius, width: MushroomWeatherTest.width,
            height: MushroomWeatherTest.height,
            where: { Swift.abs(MushroomWeatherTest.luminance($0) - back) >= MushroomWeatherTest.backdropMargin })
    }

    /// The pixel check at the described positions on `rgba` (drawn from `snapshot` at `tier`) with the feature-493
    /// tolerances: at every described cap centre clear of every element drawn after it, a pixel within 3 px brighter
    /// than moss by 0.2 in luminance (in band or not); at the described moon centre and first gauge track, when clear,
    /// a pixel within 3 px 0.1 from the backdrop; at the described first actions bar, when lit and clear, a pixel
    /// within 3 px with red above blue by 0.08. Returns the misses and what was measured.
    static func describedPixelMisses(_ rgba: [UInt8], _ described: Description, snapshot: Snapshot,
                                     tier: Int) -> (misses: [String], caps: Int, moon: Bool, bar: Bool, track: Bool) {
        let width: Int = MushroomWeatherTest.width
        let height: Int = MushroomWeatherTest.height
        var misses: [String] = []
        let layout: MushroomWeatherTestLayout = MushroomWeatherTest.layout(snapshot, tier: tier, width: width,
                                                                            height: height)
        guard let sky: MushroomWeatherTestBackdrop = MushroomWeatherTest.backdrop(width: width, height: height) else {
            return (["an empty target"], 0, false, false, false)
        }
        let clearance: Double = MushroomWeatherTest.clearance
        let radius: Double = MushroomWeatherTest.pointRadius
        let floor: Double = MushroomWeatherTest.luminance(Palette.moss) + MushroomWeatherTest.brightMargin
        var caps: Int = 0
        for index in described.caps.indices {
            guard let p: SIMD2<Double> = described.caps[index],
                  MushroomWeatherTest.inside(p, width: width, height: height),
                  let rank: Int = layout.rank(.cap, index),
                  layout.isClear(p, after: rank, clearance: clearance) else { continue }
            caps += 1
            let found: Bool = MushroomWeatherTest.anyPixel(
                rgba, near: p, radius: radius, width: width, height: height,
                where: { MushroomWeatherTest.luminance($0) >= floor })
            if !found {
                let c: SIMD3<Double> = MushroomWeatherTest.centre(rgba, p, width: width, height: height)
                let band: String = index < snapshot.colonies.count && snapshot.colonies[index].inBand ? "in" : "out of"
                misses.append("described cap \(index) (\(band) band) at (\(p.x), \(p.y)) is \(c), not 0.2 above moss")
            }
        }
        var moon: Bool = false
        if let p: SIMD2<Double> = described.moon, MushroomWeatherTest.inside(p, width: width, height: height),
           let rank: Int = layout.rank(.moon, 0), layout.isClear(p, after: rank, clearance: clearance) {
            moon = true
            if !offBackdrop(rgba, p, sky: sky) {
                misses.append("described moon centre at (\(p.x), \(p.y)) is backdrop-coloured")
            }
        }
        var bar: Bool = false
        if Geometry.litActions(snapshot) > 0, let p: SIMD2<Double> = described.firstActionsBar,
           MushroomWeatherTest.inside(p, width: width, height: height),
           let rank: Int = layout.rank(.bar, 0), layout.isClear(p, after: rank, clearance: clearance) {
            bar = true
            let found: Bool = MushroomWeatherTest.anyPixel(rgba, near: p, radius: radius, width: width,
                                                           height: height, where: MushroomWeatherTest.isAmber)
            if !found {
                let c: SIMD3<Double> = MushroomWeatherTest.centre(rgba, p, width: width, height: height)
                misses.append("described first actions bar at (\(p.x), \(p.y)) is \(c), not red above blue")
            }
        }
        var track: Bool = false
        if !snapshot.colonies.isEmpty, let p: SIMD2<Double> = described.firstGaugeTrack,
           MushroomWeatherTest.inside(p, width: width, height: height),
           let rank: Int = layout.rank(.gauge, 0), layout.isClear(p, after: rank, clearance: clearance) {
            track = true
            if !offBackdrop(rgba, p, sky: sky) {
                misses.append("described first gauge track at (\(p.x), \(p.y)) is backdrop-coloured")
            }
        }
        return (misses, caps, moon, bar, track)
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check, the pixel check at the described positions and the feature-493 frame
    /// checks against the presenter's last snapshot; every issue names the frame.
    static func check(_ frame: Frame, session: ExperienceSession,
                      shell: MushroomWeatherTest.Shell) throws -> Measured {
        let width: Int = MushroomWeatherGolden.width
        let height: Int = MushroomWeatherGolden.height
        MushroomWeatherTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try MushroomWeatherTest.still(session, width: width, height: height, time: frame.time)
        let shown: Snapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: Snapshot = try MushroomWeatherGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(golden.shownCycle == frame.cycle, "\(frame.name): golden cycle \(golden.shownCycle)")
        #expect(golden.preview == nil, "\(frame.name): the golden frame previews nothing")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        #expect(!golden.colonies.isEmpty, "\(frame.name): the frame has no colonies")
        let pixels = Self.describedPixelMisses(rgba, described, snapshot: shown, tier: frame.tier)
        #expect(pixels.misses.isEmpty, "\(frame.name): \(pixels.misses.prefix(4))")
        #expect(pixels.caps >= 1, "\(frame.name): no described cap centre is clear")
        #expect(pixels.track, "\(frame.name): the described first gauge track is not clear")
        if Geometry.litActions(shown) > 0 {
            #expect(pixels.bar, "\(frame.name): the described first actions bar is not clear")
        }
        let report: MushroomWeatherCheckReport = MushroomWeatherTest.checkFrame(
            rgba, snapshot: shown, tier: frame.tier, width: width, height: height, "golden \(frame.name)")
        print("mushroom-weather golden \(frame.name): cycle \(golden.shownCycle) of \(golden.cyclesRun), actions left "
              + "\(golden.actionsLeft) of \(golden.budget), colonies in band \(described.counts["inBand"] ?? -1) of "
              + "\(described.counts["colonies"] ?? -1), described caps measured \(pixels.caps) of "
              + "\(described.caps.count), moon \(pixels.moon), bar \(pixels.bar), track \(pixels.track)")
        return Measured(report: report, describedCaps: pixels.caps, describedMoon: pixels.moon,
                        describedBar: pixels.bar, describedTrack: pixels.track)
    }

    // MARK: Tests

    /// The golden set has 16 frames with unique names: three tiers per level sharing their actions (the certified
    /// actions, never the run, the level still open) and the cycle half the cycles run, and the hero frame (the hero
    /// scenario's level, tier 0, the certified actions and the hero cycle), all at time 0; each golden snapshot is the
    /// CPU reference's. The flat out-of-band cap colour clears the feature-493 cap margin over moss (see the header).
    @Test func theGoldenSetHasSixteenFrames() throws {
        typealias Core = MushroomWeatherExperienceCore
        let frames: [Frame] = MushroomWeatherGolden.frames
        #expect(frames.count == 16)
        #expect(MushroomWeatherGolden.width == MushroomWeatherTest.width)
        #expect(MushroomWeatherGolden.height == MushroomWeatherTest.height)
        #expect(MushroomWeatherGolden.quantum == Self.quantum)
        #expect(Self.levels == MushroomWeatherTest.levels)
        #expect(Self.levels == MushroomWeatherGolden.levels)
        #expect(Self.palette.count == 21, "the palette has 21 named colours")
        var names: [String] = []
        for entry in Self.palette { names.append(entry.name) }
        #expect(names.sorted() == MushroomWeatherGolden.colourNames.sorted(), "the described colour names")
        let capFloor: Double = MushroomWeatherTest.luminance(Palette.moss) + MushroomWeatherTest.brightMargin
        let capOut: Double = MushroomWeatherTest.luminance(Palette.capOut)
        #expect(capOut >= capFloor, "the out-of-band cap colour \(capOut) is below the cap bound \(capFloor)")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        let heroPlan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(heroLevel)
        let heroes: [Frame] = Self.heroFrames()
        #expect(heroes.count == 1, "\(heroes.count) hero frames")
        for frame in heroes {
            #expect(frame.level == heroLevel && frame.tier == 0,
                    "\(frame.name): level \(frame.level) tier \(frame.tier)")
            #expect(frame.actions == heroPlan, "the hero frame makes the certified actions")
            #expect(frame.cycle == (Core.heroCycle(heroLevel) ?? -1), "the hero frame shows the hero cycle")
        }
        for frame in frames {
            #expect(frame.time == 0, "\(frame.name): time \(frame.time)")
            #expect(!frame.actions.contains(.run), "\(frame.name): the frames never run")
            let digest: String = try MushroomWeatherGolden.digest(frame)
            #expect(digest.count == 64, "\(frame.name): digest \(digest)")
            let golden: Snapshot = try MushroomWeatherGolden.snapshot(frame)
            let reference: Snapshot = try Self.referenceSnapshot(frame)
            let message: String = "\(frame.name): the golden snapshot is the CPU reference's: "
                + "\(Self.snapshotMisses(golden, reference))"
            #expect(golden == reference, Comment(rawValue: message))
            #expect(golden.levelNumber == frame.level, "\(frame.name): level \(golden.levelNumber)")
            #expect(!golden.isWon && golden.stage == .playing, "\(frame.name): the level is still open")
            #expect(golden.actionsLeft == golden.budget - frame.actions.count,
                    "\(frame.name): actions left \(golden.actionsLeft) of \(golden.budget)")
        }
        for level in Self.levels {
            let tiers: [Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let expected: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(level)
            let placed: MushroomWeatherExperienceCore = try MushroomWeatherTest.coreAfter(level, expected,
                                                                                           showHalf: false)
            let cycle: Int = MushroomWeatherTest.halfCycle(placed.play.report.cycles)
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == expected, "\(frame.name): the frames make the certified actions")
                #expect(frame.cycle == cycle, "\(frame.name): cycle \(frame.cycle), half the cycles run is \(cycle)")
                tierIndex += 1
            }
            // All three tiers of a level share every position.
            if tiers.count == 3 {
                let first: Description = try Self.description(tiers[0])
                for frame in tiers.dropFirst() {
                    let other: Description = try Self.description(frame)
                    let same: Bool = other.floor == first.floor && other.caps == first.caps
                        && other.moon == first.moon && other.firstGaugeTrack == first.firstGaugeTrack
                        && other.firstActionsBar == first.firstActionsBar && other.counts == first.counts
                    #expect(same, "\(frame.name): the tier frames share every position and count")
                }
            }
        }
        var unique: Set<String> = []
        for frame in frames { unique.insert(frame.name) }
        #expect(unique.count == 16, "frame names are unique")
    }

    /// The 15 level frames render as their golden snapshots and descriptions say; every tier measures a cap (described
    /// and by the feature-493 checks) and the first gauge track on every level.
    @Test func everyLevelFrameMatchesItsDescription() async throws {
        var caps: [Int] = [0, 0, 0]
        var tracks: [Int] = [0, 0, 0]
        var bars: [Int] = [0, 0, 0]
        var moons: [Int] = [0, 0, 0]
        for level in Self.levels {
            let frames: [Frame] = Self.tierFrames(level: level)
            #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
            guard let first: Frame = frames.first else { continue }
            let session = ExperienceSession()
            defer { session.close() }
            let shell: MushroomWeatherTest.Shell = try await Self.open(session, level: level)
            // The three tier frames share their actions and cycle: apply them once, then draw each tier.
            try Self.apply(first, to: shell)
            for frame in frames {
                #expect(frame.actions == first.actions && frame.cycle == first.cycle,
                        "\(frame.name): the tier frames share their actions and cycle")
                let measured: Measured = try Self.check(frame, session: session, shell: shell)
                if frame.tier >= 0 && frame.tier < 3 {
                    let both: Bool = measured.report.capsChecked >= 1 && measured.describedCaps >= 1
                    caps[frame.tier] += both ? 1 : 0
                    tracks[frame.tier] += measured.report.trackChecked && measured.describedTrack ? 1 : 0
                    bars[frame.tier] += measured.report.barChecked && measured.describedBar ? 1 : 0
                    moons[frame.tier] += measured.report.moonChecked && measured.describedMoon ? 1 : 0
                }
            }
            session.qualityPin = 0
        }
        print("mushroom-weather golden level frames: caps measured per tier \(caps), tracks \(tracks), bars \(bars), "
              + "moons \(moons)")
        for tier in 0..<3 {
            #expect(caps[tier] == Self.levels.count, "tier \(tier): a cap measured on \(caps[tier]) of 5 levels")
            #expect(tracks[tier] == Self.levels.count,
                    "tier \(tier): the first gauge track measured on \(tracks[tier]) of 5 levels")
        }
    }

    /// The hero frame (the hero scenario's level after the certified actions, the hero cycle shown, tier 0) renders
    /// as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        let hero: Frame = try #require(Self.heroFrames().first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: MushroomWeatherTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try MushroomWeatherTest.digest(shell)
        try Self.apply(hero, to: shell)
        let after: String = try MushroomWeatherTest.digest(shell)
        if !hero.actions.isEmpty { #expect(after != before, "the hero actions change the digest") }
        _ = try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
