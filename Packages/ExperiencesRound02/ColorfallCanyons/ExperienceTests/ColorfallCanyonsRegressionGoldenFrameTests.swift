// ColorfallCanyonsRegressionGoldenFrameTests — feature 348 (R02-G05-08) T-R02G0508-005 (FR-R02G0508-004;
// SC-R02G0508-003). Through the one app's session host, each of the 16 code-only golden frames of
// `ColorfallCanyonsGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 at presentation time 0,
// each after its witness's carves and valves followed by `step(12)`, plus the hero frame: level 1 after the hero
// scenario's one time step, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of `ColorfallCanyonsTest`
// (clarification Q3). The snapshot the presenter shows equals `ColorfallCanyonsGolden.snapshot(frame)` (heights,
// grounds, springs, basins, masses, stage, tick, level, time 0), so the rendered frame is the described one; the
// frame's description (`ColorfallCanyonsGolden.description(frame)`, decoded here) names the drawn tier's detail, the
// play tick, every cell top, emitter top, basin centre and wet cell's sheet top with its fluid mix, and those agree
// with the CPU reference within one 1/8-pixel quantum; the picture passes the feature-343 frame checks (each flowing
// emitter top within 3 px of a pixel 0.15 brighter than night, every dry spring-free front-row open cell and at least
// 80 % of all open cells at least 0.1 in luminance from night, corners clear of the scene within 0.05 of night). Seed s
// opens level s % 100 + 1, so a frame of level L opens at seed L − 1; actions go through the session's action port as
// `canyon.carve [cell]`, `canyon.valve [spring]` and `time.step [ticks]`. One test per level plus the hero test, each
// well under 10 s. Modelled on `HueCompassRegressionGoldenFrameTests` (feature 338). Synthetic data, explicit types,
// plain loops, no sleep, no wall-clock assertion.
#if os(iOS)
import ColorfallCanyonsCore
import Foundation
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct ColorfallCanyonsRegressionGoldenFrameTests {
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

    /// A projected point of the description: its cell, spring or basin index and its position.
    struct Point: Decodable, Equatable {
        let index: Int
        let position: Position?
    }

    /// A wet cell's fluid sheet of the description.
    struct Sheet: Decodable, Equatable {
        let cell: Int
        let position: Position?
        let colour: Colour
    }

    /// The description of one golden frame, decoded from `ColorfallCanyonsGolden.description(_:)`.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let tick: Int
        let subdivision: Int
        let flowBands: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let night: Colour
        let cells: [Point]
        let emitters: [Point]
        let basins: [Point]
        let sheets: [Sheet]
    }

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [ColorfallCanyonsGolden.Frame] {
        var list: [ColorfallCanyonsGolden.Frame] = []
        for frame in ColorfallCanyonsGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port as `canyon.carve`, `canyon.valve` and `time.step`.
    static func apply(_ actions: [ColorfallCanyonsAction], to shell: ColorfallCanyonsTest.Shell, _ what: String) {
        for action in actions {
            let result: ActionResult
            switch action {
            case .carve(let cell):
                result = shell.handle(control: "canyon.carve", values: [Double(cell)])
            case .valve(let spring):
                result = shell.handle(control: "canyon.valve", values: [Double(spring)])
            case .step(let ticks):
                result = shell.handle(control: "time.step", values: [Double(ticks)])
            }
            #expect(result == .accepted, "\(what): \(action) gave \(result.code)")
        }
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> ColorfallCanyonsTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(ColorfallCanyonsExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: ColorfallCanyonsTest.Shell = try await ColorfallCanyonsTest.open(session, seed: seed)
        #expect(try ColorfallCanyonsTest.core(shell).levelNumber == level)
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: ColorfallCanyonsGolden.Frame) throws -> Description {
        try JSONDecoder().decode(Description.self, from: try ColorfallCanyonsGolden.description(frame))
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

    /// `c` in 8 bits per channel, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> Colour {
        let byte: (Double) -> Int = { v in Int((min(max(v, 0), 1) * 255).rounded()) }
        return Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// The description check: the frame's identity, size, tick and tier detail, the night colour, and every cell top,
    /// emitter top, basin centre and wet cell's sheet (position and fluid mix) against the CPU reference of `golden`.
    /// Returns the misses.
    static func descriptionMisses(_ described: Description, frame: ColorfallCanyonsGolden.Frame,
                                  golden: ColorfallCanyonsSceneSnapshot) -> [String] {
        typealias Geometry = ColorfallCanyonsSceneGeometry
        var misses: [String] = []
        let width: Int = ColorfallCanyonsTest.width
        let height: Int = ColorfallCanyonsTest.height
        let tier: ColorfallCanyonsTier = ColorfallCanyonsTier.of(frame.tier)
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != width || described.height != height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if described.tick != golden.tick { misses.append("tick \(described.tick), snapshot \(golden.tick)") }
        if described.subdivision != tier.subdivision || described.flowBands != tier.flowBands
            || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.subdivision)/\(described.flowBands)/\(described.glowShells)")
        }
        if described.night != colour(ColorfallCanyonsPalette.night) { misses.append("night \(described.night)") }
        let cam: ColorfallCanyonsCamera = ColorfallCanyonsTest.camera(golden, width: width, height: height)
        if described.cells.count != golden.cellCount {
            misses.append("\(described.cells.count) cell tops, snapshot \(golden.cellCount)")
        } else {
            for cell in 0..<golden.cellCount {
                let point: Point = described.cells[cell]
                let p: Vec2? = Geometry.pixel(Geometry.cellTop(cell, golden), camera: cam, width: width,
                                              height: height)
                if point.index != cell || !agrees(point.position, p, quantum: quantum) {
                    misses.append("cell top \(cell): described \(point)")
                }
            }
        }
        if described.emitters.count != golden.springs.count {
            misses.append("\(described.emitters.count) emitters, snapshot \(golden.springs.count)")
        } else {
            for spring in 0..<golden.springs.count {
                let point: Point = described.emitters[spring]
                let p: Vec2? = Geometry.pixel(Geometry.emitterTop(spring, golden), camera: cam, width: width,
                                              height: height)
                if point.index != spring || !agrees(point.position, p, quantum: quantum) {
                    misses.append("emitter \(spring): described \(point)")
                }
            }
        }
        if described.basins.count != golden.basins.count {
            misses.append("\(described.basins.count) basins, snapshot \(golden.basins.count)")
        } else {
            for basin in 0..<golden.basins.count {
                let point: Point = described.basins[basin]
                let p: Vec2? = Geometry.pixel(Geometry.basinCentre(basin, golden), camera: cam, width: width,
                                              height: height)
                if point.index != basin || !agrees(point.position, p, quantum: quantum) {
                    misses.append("basin \(basin): described \(point)")
                }
            }
        }
        var wet: [Int] = []
        for cell in 0..<golden.cellCount where golden.volume(cell) > 0 { wet.append(cell) }
        if described.sheets.count != wet.count {
            misses.append("\(described.sheets.count) sheets, snapshot \(wet.count) wet cells")
        } else {
            for index in 0..<wet.count {
                let sheet: Sheet = described.sheets[index]
                let cell: Int = wet[index]
                var top: SIMD3<Double> = Geometry.cellCentre(cell, golden)
                top.y = Geometry.sheetTop(cell, golden)
                let p: Vec2? = Geometry.pixel(top, camera: cam, width: width, height: height)
                let want: Colour = colour(ColorfallCanyonsPalette.fluid(golden.masses[cell]))
                if sheet.cell != cell || !agrees(sheet.position, p, quantum: quantum) || sheet.colour != want {
                    misses.append("sheet \(cell): described \(sheet)")
                }
            }
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one and runs the description check and the frame checks of clarification Q3.
    static func check(_ frame: ColorfallCanyonsGolden.Frame, session: ExperienceSession,
                      shell: ColorfallCanyonsTest.Shell) throws {
        let width: Int = ColorfallCanyonsGolden.width
        let height: Int = ColorfallCanyonsGolden.height
        ColorfallCanyonsTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try ColorfallCanyonsTest.still(session, width: width, height: height, time: frame.time)
        let shown: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                                "\(frame.name): no snapshot")
        let golden: ColorfallCanyonsSceneSnapshot = try ColorfallCanyonsGolden.snapshot(frame)
        #expect(shown.time == 0, "\(frame.name): the still's frame time is \(shown.time), not 0")
        #expect(shown.levelNumber == golden.levelNumber, "\(frame.name): level \(shown.levelNumber)")
        #expect(shown.heights == golden.heights, "\(frame.name): the shown heights differ from the golden ones")
        #expect(shown.masses == golden.masses, "\(frame.name): the shown masses differ from the golden ones")
        #expect(shown.tick == golden.tick, "\(frame.name): tick \(shown.tick), golden \(golden.tick)")
        #expect(shown.stage == golden.stage, "\(frame.name): stage \(shown.stage), golden \(golden.stage)")
        #expect(shown == golden, "\(frame.name): the shown snapshot differs from the golden one")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        ColorfallCanyonsTest.checkFrame(rgba, snapshot: golden, width: width, height: height, frame.name)
        let emitters = ColorfallCanyonsTest.emitterMisses(rgba, snapshot: golden, width: width, height: height)
        let cells = ColorfallCanyonsTest.cellResults(rgba, snapshot: golden, width: width, height: height)
        print("colorfall-canyons golden \(frame.name): tick \(golden.tick), \(described.sheets.count) wet cells, "
              + "emitters checked \(emitters.checked) (dimmed \(emitters.dimmed)), open cells passed "
              + "\(cells.passed) of \(cells.checked), front-row cells checked \(cells.strictChecked)")
    }

    @Test func theGoldenSetHasSixteenFrames() {
        let frames: [ColorfallCanyonsGolden.Frame] = ColorfallCanyonsGolden.frames
        #expect(frames.count == 16)
        #expect(ColorfallCanyonsGolden.width == ColorfallCanyonsTest.width)
        #expect(ColorfallCanyonsGolden.height == ColorfallCanyonsTest.height)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == 1 && frame.tier == 0 && frame.actions.count == 1)
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in ColorfallCanyonsGolden.levels {
            let tiers: [ColorfallCanyonsGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [ColorfallCanyonsAction] = tiers.first?.actions ?? []
            #expect(actions.last == .step(ColorfallCanyonsGolden.ticks), "level \(level): the frame ends with step(12)")
            var steps: Int = 0
            for action in actions {
                if case .step = action { steps += 1 }
            }
            #expect(steps == 1, "level \(level): the witness's own steps are left out")
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [ColorfallCanyonsGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: ColorfallCanyonsGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ColorfallCanyonsTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their actions: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their actions")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [ColorfallCanyonsGolden.Frame] = []
        for frame in ColorfallCanyonsGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: ColorfallCanyonsGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ColorfallCanyonsTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try ColorfallCanyonsTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        #expect(try ColorfallCanyonsTest.digest(shell) != before, "the hero step changes the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
