// HueCompassRegressionGoldenFrameTests — feature 338 (R02-G04-08) T-R02G0408-005 (FR-R02G0408-004; SC-R02G0408-003).
// Through the one app's session host, each of the 16 code-only golden frames of `HueCompassGolden.frames()` (certified
// levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 at presentation time 0, each after its witness's turns and probes,
// plus the hero frame: level 1 after the hero scenario's one turn, tier 0) is drawn off screen at the frame-check size
// 1,152 × 768 of `HueCompassTest` (clarification Q3). The snapshot the presenter shows equals
// `HueCompassGolden.snapshot(frame)` (level, bearing, clues, selection, stage, target, time 0), so the rendered frame
// is the described one; the frame's description (`HueCompassGolden.description(frame)`, decoded here) names the drawn
// tier's detail, the needle tip, every band sample and every probe mark centre, and those positions agree with the
// CPU reference within one 1/8-pixel quantum; the picture passes the feature-333 frame checks (needle tip and probe
// marks within 3 px of a pixel 0.15 brighter than night, band samples within 0.15 of their band colour, background
// within 0.05 of night). Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1; actions go through
// the session's action port as `compass.turn [steps]` and `compass.probe`. One test per level plus the hero test, each
// well under 10 s. Modelled on `WaveKnotKeeperRegressionGoldenFrameTests` (feature 328). Synthetic data, explicit
// types, plain loops, no sleep, no wall-clock assertion.
#if os(iOS)
import Foundation
import HueCompassCore
import Testing
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct HueCompassRegressionGoldenFrameTests {
    /// A position of the description in 1/8 pixel.
    struct Position: Decodable, Equatable {
        let x: Int
        let y: Int
    }

    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// A band sample of the description.
    struct Band: Decodable, Equatable {
        let segment: Int
        let position: Position?
        let colour: Colour
    }

    /// A mark of the description.
    struct Mark: Decodable, Equatable {
        let bearing: Int
        let position: Position?
    }

    /// The description of one golden frame, decoded from `HueCompassGolden.description(_:)`.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let facets: Int
        let fogLayers: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let night: Colour
        let tip: Position?
        let bands: [Band]
        let probes: [Mark]
        let selection: Mark?
        let ring: Mark?
    }

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) throws -> [HueCompassGolden.Frame] {
        var list: [HueCompassGolden.Frame] = []
        for frame in try HueCompassGolden.frames() where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port as `compass.turn [steps]` and `compass.probe`.
    static func apply(_ actions: [HueCompassAction], to shell: HueCompassTest.Shell, _ what: String) {
        for action in actions {
            let result: ActionResult
            switch action {
            case .turn(let steps):
                result = shell.handle(control: "compass.turn", values: [Double(steps)])
            case .probe:
                result = shell.handle(control: "compass.probe")
            case .select(let bearing, let band):
                Issue.record("\(what): a golden frame holds a selection (\(bearing), \(band))")
                continue
            }
            #expect(result == .accepted, "\(what): \(action) gave \(result.code)")
        }
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> HueCompassTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(HueCompassExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: HueCompassTest.Shell = try await HueCompassTest.open(session, seed: seed)
        #expect(try HueCompassTest.core(shell).levelNumber == level)
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: HueCompassGolden.Frame) throws -> Description {
        try JSONDecoder().decode(Description.self, from: try HueCompassGolden.description(frame))
    }

    /// Whether the described position `q` lies within one quantum (per axis) of the pixel `p`; both nil also agree.
    static func agrees(_ q: Position?, _ p: Vec2?, quantum: Int) -> Bool {
        switch (q, p) {
        case (nil, nil):
            return true
        case let (q?, p?):
            let x: Double = p.x * Double(quantum)
            let y: Double = p.y * Double(quantum)
            return abs(Double(q.x) - x) <= 1 && abs(Double(q.y) - y) <= 1
        default:
            return false
        }
    }

    /// The description check: the frame's identity, size and tier detail, the night colour, and the needle tip, every
    /// band sample and every probe mark centre against the CPU reference of `golden`. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: HueCompassGolden.Frame,
                                  golden: HueCompassSceneSnapshot) -> [String] {
        typealias Geometry = HueCompassSceneGeometry
        var misses: [String] = []
        let width: Int = HueCompassTest.width
        let height: Int = HueCompassTest.height
        let tier: HueCompassTier = HueCompassTier.of(frame.tier)
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != width || described.height != height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if described.facets != tier.facets || described.fogLayers != tier.fogLayers
            || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.facets)/\(described.fogLayers)/\(described.glowShells)")
        }
        let night: SIMD3<Double> = HueCompassPalette.night
        let byte: (Double) -> Int = { v in Int((min(max(v, 0), 1) * 255).rounded()) }
        if described.night != Colour(r: byte(night.x), g: byte(night.y), b: byte(night.z)) {
            misses.append("night \(described.night)")
        }
        if described.selection != nil || golden.selection != nil { misses.append("a selection is drawn") }
        if (described.ring == nil) != (golden.target == nil) {
            misses.append("target ring \(String(describing: described.ring))")
        }
        let cam: HueCompassCamera = HueCompassTest.camera(width: width, height: height)
        let tip: Vec2? = Geometry.pixel(Geometry.needleTip(golden), camera: cam, width: width, height: height)
        if !agrees(described.tip, tip, quantum: described.quantum) {
            misses.append("tip: described \(String(describing: described.tip)), reference \(String(describing: tip))")
        }
        if described.bands.count != HueCompassWheel.bands {
            misses.append("\(described.bands.count) band samples")
        } else {
            for k in 0..<described.bands.count {
                let band: Band = described.bands[k]
                let p: Vec2? = Geometry.pixel(Geometry.bandSamplePoint(k), camera: cam, width: width, height: height)
                let want: SIMD3<Double> = Geometry.bandSegmentColour(k, in: golden)
                if band.segment != k || !agrees(band.position, p, quantum: described.quantum)
                    || band.colour != Colour(r: byte(want.x), g: byte(want.y), b: byte(want.z)) {
                    misses.append("band \(k): described \(band)")
                }
            }
        }
        let bearings: [Int] = Geometry.probeBearings(golden)
        if described.probes.count != bearings.count {
            misses.append("\(described.probes.count) probe marks, snapshot \(bearings.count)")
        } else {
            for index in 0..<bearings.count {
                let mark: Mark = described.probes[index]
                let p: Vec2? = Geometry.pixel(Geometry.probeMarkCentre(bearings[index]), camera: cam, width: width,
                                              height: height)
                if mark.bearing != bearings[index] || !agrees(mark.position, p, quantum: described.quantum) {
                    misses.append("probe mark \(index): described \(mark)")
                }
            }
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one and runs the description check and the frame checks of clarification Q3.
    static func check(_ frame: HueCompassGolden.Frame, session: ExperienceSession,
                      shell: HueCompassTest.Shell) throws {
        let width: Int = HueCompassGolden.width
        let height: Int = HueCompassGolden.height
        HueCompassTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try HueCompassTest.still(session, width: width, height: height, time: frame.time)
        let shown: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: HueCompassSceneSnapshot = try HueCompassGolden.snapshot(frame)
        #expect(shown.time == 0, "\(frame.name): the still's frame time is \(shown.time), not 0")
        #expect(shown.levelNumber == golden.levelNumber, "\(frame.name): level \(shown.levelNumber)")
        #expect(shown.bearing == golden.bearing, "\(frame.name): bearing \(shown.bearing), golden \(golden.bearing)")
        #expect(shown.clues == golden.clues, "\(frame.name): the shown clues differ from the golden ones")
        #expect(shown.stage == golden.stage, "\(frame.name): stage \(shown.stage), golden \(golden.stage)")
        #expect(shown.selection == nil, "\(frame.name): selection \(String(describing: shown.selection))")
        #expect(shown.target == golden.target, "\(frame.name): the shown target differs from the golden one")
        #expect(shown == golden, "\(frame.name): the shown snapshot differs from the golden one")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        HueCompassTest.checkFrame(rgba, snapshot: golden, width: width, height: height, frame.name)
        let marks = HueCompassTest.markMisses(rgba, snapshot: golden)
        print("hue-compass golden \(frame.name): bearing \(golden.bearing), \(golden.clues.count) clues, marks checked "
              + "\(marks.checked), band segments checked \(HueCompassTest.bandMisses(rgba, snapshot: golden).checked)"
              + " of \(HueCompassWheel.bands)")
    }

    @Test func theGoldenSetHasSixteenFrames() throws {
        let frames: [HueCompassGolden.Frame] = try HueCompassGolden.frames()
        #expect(frames.count == 16)
        #expect(HueCompassGolden.width == HueCompassTest.width)
        #expect(HueCompassGolden.height == HueCompassTest.height)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == 1 && frame.tier == 0 && frame.actions.count == 1)
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in HueCompassGolden.levels {
            let tiers: [HueCompassGolden.Frame] = try Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            var probes: Int = 0
            for action in tiers.first?.actions ?? [] where action == .probe { probes += 1 }
            #expect(probes >= 1, "level \(level): the frame shows at least one probe mark")
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [HueCompassGolden.Frame] = try Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: HueCompassGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: HueCompassTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their actions: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their actions")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [HueCompassGolden.Frame] = []
        for frame in try HueCompassGolden.frames() where frame.name == "hero" { heroes.append(frame) }
        let hero: HueCompassGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: HueCompassTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try HueCompassTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        #expect(try HueCompassTest.digest(shell) != before, "the hero turn changes the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
