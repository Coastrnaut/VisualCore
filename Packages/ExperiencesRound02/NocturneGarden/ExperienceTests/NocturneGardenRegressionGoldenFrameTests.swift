// NocturneGardenRegressionGoldenFrameTests — feature 388 (R02-G09-08) T-R02G0908-005 (FR-R02G0908-004;
// SC-R02G0908-003; clarification Q3). Through the one app's session host, each of the 16 code-only golden frames of
// `NocturneGardenGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after its certified
// solution's first min(smallest − 1, 2) moves, plus the hero frame: the manifest seed's level after the hero scenario's
// first move, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of `NocturneGardenTest` with the frame's
// tier pinned. The still is drawn at the frame's time plus 1 s (`settle`): the golden frames are at time 0, and the
// presenter's eased lights (feature 386) settle within 0.15 s of the last live frame, so the glow and the leak lights
// rest at their targets when the picture is measured; no position depends on the time (the mist drift and the sway are
// shader uniforms). The snapshot the presenter shows equals `NocturneGardenGolden.snapshot(frame)` in every field
// but the time, so the rendered frame is the described one. The frame's description
// (`NocturneGardenGolden.description`, decoded here) names the frame, the size, the quantum, the drawn tier's detail,
// the shadow cell count, the moves spent, the budget, the ground colour and every named colour, one head centre per
// bloom and the lantern centre; those agree with the golden snapshot and the Core's CPU reference (the lantern within
// one 1/8-pixel quantum). Every described bloom head centre and the lantern centre that is not null lies inside the
// picture. The picture then passes the feature-383 frame checks (`NocturneGardenTest.checkFrame`): shadow cells 0.15
// darker than the mist reference within 3 px, forbidden cells outside the shadow coral (red − blue at least 0.15),
// target cells outside the shadow 0.15 brighter than the shadow reference (the gold rim), the gauge's first visible bar
// 0.1 from the ground, the two probe corners within 0.05 of the ground. Seed s opens level s % 100 + 1, so a frame of
// level L opens at seed L − 1; moves go through the session's action port (`bloom.plant`, `bloom.move`,
// `bloom.resize`, `bloom.remove`, `sun.set`). One test per level plus the hero test and the set test, each well under
// 10 s. Modelled on `FacetedForgeRegressionGoldenFrameTests` (feature 378). Synthetic data, explicit types, plain
// loops, no sleep, no wall-clock assertion.
#if os(iOS)
import Foundation
import NocturneGardenCore
import Testing
@testable import NocturneGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct NocturneGardenRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The description of one golden frame, decoded from `NocturneGardenGolden.description(_:)`. A position is
    /// `[x, y]` in 1/`quantum` pixel, or null off screen.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let mistLayers: Int
        let stemDepth: Int
        let featherHundredths: Int
        let glowShells: Int
        let shadowCells: Int
        let moves: Int
        let budget: Int
        let colours: [String: Colour]
        let blooms: [[Int]?]
        let lantern: [Int]?
    }

    /// How long after the frame's time the still is drawn (seconds), so the eased lights rest at their targets.
    static let settle: Double = 1

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [NocturneGardenGolden.Frame] {
        var list: [NocturneGardenGolden.Frame] = []
        for frame in NocturneGardenGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port, expecting each to be accepted.
    static func apply(_ actions: [NocturneGardenAction], to shell: NocturneGardenTest.Shell, _ what: String) {
        for (index, action) in actions.enumerated() {
            let issued: (control: String, values: [Double]) = NocturneGardenTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted,
                    "\(what): action \(index) \(issued.control) \(issued.values) gave \(result.code)")
        }
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> NocturneGardenTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(NocturneGardenExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: NocturneGardenTest.Shell = try await NocturneGardenTest.open(session, seed: seed)
        let opened: Int = try NocturneGardenTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: NocturneGardenGolden.Frame) throws -> Description {
        let data: Data = try NocturneGardenGolden.description(frame)
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

    /// The described position `q` in pixels, or nil.
    static func pixel(_ q: [Int]?, quantum: Int) -> Vec2? {
        guard let q, q.count == 2, quantum > 0 else { return nil }
        return Vec2(Double(q[0]) / Double(quantum), Double(q[1]) / Double(quantum))
    }

    /// Whether the described position `q` lies within one quantum (per axis) of the pixel `p`; both nil also agree.
    static func agrees(_ q: [Int]?, _ p: Vec2?, quantum: Int) -> Bool {
        if q == nil && p == nil { return true }
        guard let q, let p, q.count == 2 else { return false }
        let x: Double = p.x * Double(quantum)
        let y: Double = p.y * Double(quantum)
        return abs(Double(q[0]) - x) <= 1 && abs(Double(q[1]) - y) <= 1
    }

    /// Every field of `shown` that differs from `golden`, the time left out (the still is drawn `settle` s later).
    static func snapshotMisses(_ shown: NocturneGardenSceneSnapshot,
                               _ golden: NocturneGardenSceneSnapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber { misses.append("level \(shown.levelNumber)") }
        if shown.width != golden.width || shown.height != golden.height {
            misses.append("bed \(shown.width) × \(shown.height)")
        }
        if shown.target != golden.target { misses.append("target cells") }
        if shown.forbidden != golden.forbidden { misses.append("forbidden cells") }
        if shown.shadow != golden.shadow {
            misses.append("shadow \(shown.shadow.count), golden \(golden.shadow.count)")
        }
        if shown.leaking != golden.leaking { misses.append("leaking cells") }
        if shown.blooms != golden.blooms {
            misses.append("blooms \(shown.blooms.count), golden \(golden.blooms.count)")
        }
        if shown.sizes != golden.sizes { misses.append("sizes") }
        if shown.sun != golden.sun { misses.append("sun \(shown.sun), golden \(golden.sun)") }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.moves != golden.moves { misses.append("moves \(shown.moves), golden \(golden.moves)") }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.preview != golden.preview { misses.append("preview \(shown.preview)") }
        return misses
    }

    /// The description check: the frame's identity, size, quantum, tier detail, shadow cells, moves and budget, the
    /// ground colour and every named colour's presence, one head centre per bloom, and the lantern centre against the
    /// CPU reference of `golden`. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: NocturneGardenGolden.Frame,
                                  golden: NocturneGardenSceneSnapshot) -> [String] {
        var misses: [String] = []
        let width: Int = NocturneGardenTest.width
        let height: Int = NocturneGardenTest.height
        let tier: NocturneGardenTier = NocturneGardenTier.of(frame.tier)
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != width || described.height != height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if quantum != NocturneGardenGolden.quantum { misses.append("quantum \(quantum)") }
        let feather: Int = Int((tier.feather * 100).rounded())
        if described.mistLayers != tier.mistLayers || described.stemDepth != tier.stemDepth
            || described.featherHundredths != feather || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.mistLayers)/\(described.stemDepth)/"
                          + "\(described.featherHundredths)/\(described.glowShells)")
        }
        if described.shadowCells != golden.shadow.count {
            misses.append("shadow cells \(described.shadowCells), snapshot \(golden.shadow.count)")
        }
        if described.moves != golden.moves { misses.append("moves \(described.moves), snapshot \(golden.moves)") }
        if described.budget != golden.budget {
            misses.append("budget \(described.budget), snapshot \(golden.budget)")
        }
        if described.colours["ground"] != colour(NocturneGardenPalette.ground) {
            misses.append("ground \(String(describing: described.colours["ground"]))")
        }
        for name in NocturneGardenGolden.colourNames where described.colours[name] == nil {
            misses.append("colour \(name) missing")
        }
        if described.blooms.count != golden.blooms.count {
            misses.append("\(described.blooms.count) blooms described, snapshot \(golden.blooms.count)")
        }
        let lantern: Vec2? = NocturneGardenTest.pixel(NocturneGardenSceneGeometry.lantern(golden), golden,
                                                      width: width, height: height)
        if !agrees(described.lantern, lantern, quantum: quantum) {
            misses.append("lantern described \(String(describing: described.lantern))")
        }
        return misses
    }

    /// The position check: every described bloom head centre and the lantern centre that is not null lies inside the
    /// picture. Returns the positions checked and the misses.
    static func positionMisses(_ described: Description) -> (checked: Int, misses: [String]) {
        var checked: Int = 0
        var misses: [String] = []
        for index in described.blooms.indices {
            guard let p: Vec2 = pixel(described.blooms[index], quantum: described.quantum) else { continue }
            checked += 1
            if !NocturneGardenTest.inside(p, width: described.width, height: described.height) {
                misses.append(String(format: "bloom %ld head centre at (%.1f, %.1f) is off the picture", index + 1,
                                     p.x, p.y))
            }
        }
        if let p: Vec2 = pixel(described.lantern, quantum: described.quantum) {
            checked += 1
            if !NocturneGardenTest.inside(p, width: described.width, height: described.height) {
                misses.append(String(format: "lantern at (%.1f, %.1f) is off the picture", p.x, p.y))
            }
        }
        return (checked, misses)
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still `settle` s after the frame's time, compares the shown
    /// snapshot with the golden one (time aside), runs the description and position checks and the feature-383 frame
    /// checks; every issue names the frame.
    static func check(_ frame: NocturneGardenGolden.Frame, session: ExperienceSession,
                      shell: NocturneGardenTest.Shell) throws {
        let width: Int = NocturneGardenGolden.width
        let height: Int = NocturneGardenGolden.height
        let time: Double = frame.time + settle
        NocturneGardenTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try NocturneGardenTest.still(session, width: width, height: height, time: time)
        let shown: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                              "\(frame.name): no snapshot")
        let golden: NocturneGardenSceneSnapshot = try NocturneGardenGolden.snapshot(frame)
        #expect(shown.time == time, "\(frame.name): the still's frame time is \(shown.time)")
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(golden.stage == .playing, "\(frame.name): the level is not playing (stage \(golden.stage))")
        #expect(golden.failure == nil, "\(frame.name): the golden frame has failed")
        #expect(golden.moves == frame.actions.count, "\(frame.name): moves \(golden.moves)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        #expect(shell.presenter.lights.isSettled, "\(frame.name): the lights are still fading")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        let positions: (checked: Int, misses: [String]) = Self.positionMisses(described)
        #expect(positions.misses.isEmpty, "\(frame.name): \(positions.misses.prefix(8))")
        NocturneGardenTest.checkFrame(rgba, snapshot: golden, width: width, height: height, frame.name)
        print("nocturne-garden golden \(frame.name): moves \(golden.moves) of \(golden.budget), blooms "
              + "\(golden.blooms.count), shadow cells \(golden.shadow.count), positions checked \(positions.checked)")
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing a prefix of the certified
    /// solution shorter than it, and the hero frame (level 1, tier 0, the hero scenario's first move), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() {
        let frames: [NocturneGardenGolden.Frame] = NocturneGardenGolden.frames
        #expect(frames.count == 16)
        #expect(NocturneGardenGolden.width == NocturneGardenTest.width)
        #expect(NocturneGardenGolden.height == NocturneGardenTest.height)
        let heroSeed: UInt64 = NocturneGardenExperienceCore.manifestSeed
        let heroLevel: Int = NocturneGardenExperienceCore.levelNumber(forSeed: heroSeed)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0 && frame.actions.count == 1)
            #expect(frame.actions == Array(NocturneGardenExperienceCore.inputActions.prefix(1)))
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in NocturneGardenGolden.levels {
            let tiers: [NocturneGardenGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let certified: [NocturneGardenAction] = NocturneGardenExperienceCore.certifiedActions(level)
            #expect(!certified.isEmpty, "level \(level) has a certified solution")
            let actions: [NocturneGardenAction] = tiers.first?.actions ?? []
            let expected: Int = max(0, min(certified.count - 1, NocturneGardenGolden.moves))
            #expect(actions.count == expected, "level \(level): \(actions.count) certified moves, not \(expected)")
            #expect(actions == Array(certified.prefix(actions.count)), "level \(level): a prefix of the solution")
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                tierIndex += 1
            }
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    /// The three tier frames of `level` render as described.
    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [NocturneGardenGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: NocturneGardenGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: NocturneGardenTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their moves: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their moves")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    /// The hero frame (the manifest seed's level after the hero scenario's first move, tier 0) renders as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [NocturneGardenGolden.Frame] = []
        for frame in NocturneGardenGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: NocturneGardenGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: NocturneGardenTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try NocturneGardenTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try NocturneGardenTest.digest(shell)
        #expect(after != before, "the hero move changes the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
