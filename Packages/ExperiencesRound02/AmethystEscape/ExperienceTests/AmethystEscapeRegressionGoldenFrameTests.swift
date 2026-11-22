// AmethystEscapeRegressionGoldenFrameTests — feature 368 (R02-G07-08) T-R02G0708-005 (FR-R02G0708-004;
// SC-R02G0708-003; clarification Q3). Through the one app's session host, each of the 16 code-only golden frames of
// `AmethystEscapeGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 at presentation time 0, each
// after its witness's first min(smallest − 1, 3) actions, plus the hero frame: level 1 after the hero scenario's first
// turn, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of `AmethystEscapeTest` with the authored
// camera. The snapshot the presenter shows equals `AmethystEscapeGolden.snapshot(frame)`, so the rendered frame is the
// described one; the frame's description (`AmethystEscapeGolden.description(frame)`, decoded here) names the drawn
// tier's detail, the move count, the move bar's length, the backdrop, the pearl centre, the exit arrow centre and every
// wedge top centre, and those agree with the CPU reference within one quantum. The picture is then checked against the
// description with the feature-363 tolerances: the described pearl centre within 3 px of a pixel 0.15 brighter than
// the backdrop; the described exit arrow within 3 px of a pixel at least 0.1 from the backdrop in luminance; every
// described open wedge top that lies on screen within 3 px of a pixel at least 0.05 from the backdrop in luminance; the
// two probe corners within 0.05 per channel of the backdrop. The feature-363 `AmethystEscapeTest.checkFrame` (which
// also checks the move bar) runs on the golden snapshot too. Seed s opens level s % 100 + 1, so a frame of level L
// opens at seed L − 1; actions go through the session's action port as `shell.rotate` and `pearl.advance`. One test per
// level plus the hero test, each well under 10 s. Modelled on `ChronoConstellatorRegressionGoldenFrameTests` (feature
// 358). Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion.
#if os(iOS)
import AmethystEscapeCore
import Foundation
import Testing
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct AmethystEscapeRegressionGoldenFrameTests {
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

    /// A described wedge top: its shell, its own sector, whether it is open and its position (nil off screen).
    struct Wedge: Decodable, Equatable {
        let shell: Int
        let sector: Int
        let open: Bool
        let position: Position?
    }

    /// The description of one golden frame, decoded from `AmethystEscapeGolden.description(_:)` (the colours other than
    /// the backdrop are left undecoded).
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let moves: Int
        let moveBar: Int
        let bevelSegments: Int
        let highlightLayers: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let backdrop: Colour
        let pearl: Position?
        let exit: Position?
        let wedges: [Wedge]
    }

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [AmethystEscapeGolden.Frame] {
        var list: [AmethystEscapeGolden.Frame] = []
        for frame in AmethystEscapeGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port (`shell.rotate`, `pearl.advance`), expecting each to be
    /// accepted.
    static func apply(_ actions: [AmethystEscapeAction], to shell: AmethystEscapeTest.Shell, _ what: String) {
        for (index, action) in actions.enumerated() {
            let issued = AmethystEscapeTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted,
                    "\(what): action \(index) \(issued.control) \(issued.values) gave \(result.code)")
        }
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> AmethystEscapeTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(AmethystEscapeExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: AmethystEscapeTest.Shell = try await AmethystEscapeTest.open(session, seed: seed)
        let opened: Int = try AmethystEscapeTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: AmethystEscapeGolden.Frame) throws -> Description {
        let data: Data = try AmethystEscapeGolden.description(frame)
        return try JSONDecoder().decode(Description.self, from: data)
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

    /// The described position `q` in pixels (x, y), or nil.
    static func pixel(_ q: Position?, quantum: Int) -> (x: Double, y: Double)? {
        guard let q, quantum > 0 else { return nil }
        return (Double(q.x) / Double(quantum), Double(q.y) / Double(quantum))
    }

    /// The description check: the frame's identity, size, move count, move bar length and tier detail, the backdrop
    /// colour, and the pearl centre, the exit arrow centre and every wedge top (shell, sector, open, position) against
    /// the CPU reference of `golden`. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: AmethystEscapeGolden.Frame,
                                  golden: AmethystEscapeSceneSnapshot) -> [String] {
        typealias Geometry = AmethystEscapeSceneGeometry
        var misses: [String] = []
        let width: Int = AmethystEscapeTest.width
        let height: Int = AmethystEscapeTest.height
        let tier: AmethystEscapeTier = AmethystEscapeTier.of(frame.tier)
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != width || described.height != height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if quantum != AmethystEscapeGolden.quantum { misses.append("quantum \(quantum)") }
        if described.moves != golden.moves { misses.append("moves \(described.moves), snapshot \(golden.moves)") }
        if described.bevelSegments != tier.bevelSegments || described.highlightLayers != tier.highlightLayers
            || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.bevelSegments)/\(described.highlightLayers)/\(described.glowShells)")
        }
        if described.backdrop != colour(AmethystEscapePalette.backdrop) {
            misses.append("backdrop \(described.backdrop)")
        }
        let bar: Double = Geometry.moveBarLength(golden) * Double(AmethystEscapeGolden.lengthQuantum)
        if abs(Double(described.moveBar) - bar) > 1 {
            misses.append("move bar \(described.moveBar), CPU reference \(bar)")
        }
        let pearl: Vec2? = AmethystEscapeTest.pearlPixel(golden, width: width, height: height)
        if !agrees(described.pearl, pearl, quantum: quantum) {
            misses.append("pearl described \(String(describing: described.pearl))")
        }
        let exit: Vec2? = AmethystEscapeTest.exitPixel(golden, width: width, height: height)
        if !agrees(described.exit, exit, quantum: quantum) {
            misses.append("exit described \(String(describing: described.exit))")
        }
        let cam: AmethystEscapeCamera = AmethystEscapeTest.camera(golden, width: width, height: height)
        var expected: [(shell: Int, sector: Int, open: Bool, pixel: Vec2?)] = []
        for shell in golden.shells.indices {
            for sector in 0..<golden.sectors {
                let top: SIMD3<Double> = Geometry.wedgeTopCentre(shell: shell, sector: sector, golden)
                let p: Vec2? = Geometry.pixel(top, camera: cam, width: width, height: height)
                expected.append((shell, sector, !golden.shells[shell].blocked.contains(sector), p))
            }
        }
        guard described.wedges.count == expected.count else {
            misses.append("\(described.wedges.count) wedges described, CPU reference \(expected.count)")
            return misses
        }
        for k in 0..<expected.count {
            let wedge: Wedge = described.wedges[k]
            let want = expected[k]
            if wedge.shell != want.shell || wedge.sector != want.sector || wedge.open != want.open
                || !agrees(wedge.position, want.pixel, quantum: quantum) {
                misses.append("wedge \(want.shell)/\(want.sector): described \(wedge)")
            }
        }
        return misses
    }

    /// The picture check against the description with the feature-363 tolerances: the pearl centre within 3 px of a
    /// pixel 0.15 brighter than the backdrop, the exit arrow within 3 px of a pixel at least 0.1 from the backdrop in
    /// luminance, every open on-screen wedge top within 3 px of a pixel at least 0.05 from the backdrop, the two probe
    /// corners within 0.05 per channel of the backdrop. Returns the open wedges checked and the misses.
    static func pictureMisses(_ rgba: [UInt8], described: Description) -> (wedges: Int, misses: [String]) {
        let width: Int = described.width
        let height: Int = described.height
        let radius: Double = AmethystEscapeTest.pointRadius
        let backdrop: Double = AmethystEscapeTest.backdropLuminance
        var misses: [String] = []
        guard rgba.count == width * height * 4 else { return (0, ["picture has \(rgba.count) bytes"]) }
        if let p = pixel(described.pearl, quantum: described.quantum) {
            if !AmethystEscapeTest.anyPixel(rgba, near: p.x, p.y, radius: radius, width: width, height: height,
                                            minimum: backdrop + AmethystEscapeTest.pearlMargin, above: true,
                                            reference: 0) {
                misses.append(String(format: "pearl at (%.1f, %.1f) without a lit pixel", p.x, p.y))
            }
        } else {
            misses.append("pearl: no described position")
        }
        if let p = pixel(described.exit, quantum: described.quantum) {
            if !AmethystEscapeTest.anyPixel(rgba, near: p.x, p.y, radius: radius, width: width, height: height,
                                            minimum: AmethystEscapeTest.exitMargin, above: false,
                                            reference: backdrop) {
                misses.append(String(format: "exit arrow at (%.1f, %.1f) is backdrop", p.x, p.y))
            }
        } else {
            misses.append("exit: no described position")
        }
        var checked: Int = 0
        for wedge in described.wedges where wedge.open {
            guard let p = pixel(wedge.position, quantum: described.quantum),
                  p.x >= 0, p.x < Double(width), p.y >= 0, p.y < Double(height) else { continue }
            checked += 1
            if !AmethystEscapeTest.anyPixel(rgba, near: p.x, p.y, radius: radius, width: width, height: height,
                                            minimum: AmethystEscapeTest.wedgeMargin, above: false,
                                            reference: backdrop) {
                misses.append(String(format: "wedge %ld/%ld at (%.1f, %.1f) is backdrop", wedge.shell, wedge.sector,
                                     p.x, p.y))
            }
        }
        let corners = AmethystEscapeTest.backgroundMisses(rgba, width: width, height: height)
        if corners.checked != AmethystEscapeTest.backgroundPoints.count { misses.append("corners \(corners.checked)") }
        misses.append(contentsOf: corners.misses)
        return (checked, misses)
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check and checks the picture against the description and against the
    /// feature-363 frame checks; every issue names the frame.
    static func check(_ frame: AmethystEscapeGolden.Frame, session: ExperienceSession,
                      shell: AmethystEscapeTest.Shell) throws {
        let width: Int = AmethystEscapeGolden.width
        let height: Int = AmethystEscapeGolden.height
        AmethystEscapeTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try AmethystEscapeTest.still(session, width: width, height: height, time: frame.time)
        let shown: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                              "\(frame.name): no snapshot")
        let golden: AmethystEscapeSceneSnapshot = try AmethystEscapeGolden.snapshot(frame)
        #expect(shown.time == 0, "\(frame.name): the still's frame time is \(shown.time), not 0")
        #expect(shown.levelNumber == golden.levelNumber, "\(frame.name): level \(shown.levelNumber)")
        #expect(shown.moves == golden.moves, "\(frame.name): moves \(shown.moves), golden \(golden.moves)")
        #expect(shown.shells == golden.shells, "\(frame.name): the shown shells differ from the golden ones")
        #expect(shown.pearl == golden.pearl, "\(frame.name): the shown pearl differs from the golden one")
        #expect(shown.stage == golden.stage, "\(frame.name): stage \(shown.stage), golden \(golden.stage)")
        #expect(shown == golden, "\(frame.name): the shown snapshot differs from the golden one")
        #expect(golden.stage == .playing, "\(frame.name): the pearl is still inside (stage \(golden.stage))")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        let picture = Self.pictureMisses(rgba, described: described)
        #expect(picture.misses.isEmpty, "\(frame.name): \(picture.misses.prefix(8))")
        #expect(picture.wedges > 0, "\(frame.name): some open wedge top is on screen")
        AmethystEscapeTest.checkFrame(rgba, snapshot: golden, width: width, height: height, frame.name)
        print("amethyst-escape golden \(frame.name): moves \(golden.moves), open wedge tops checked "
              + "\(picture.wedges) of \(described.wedges.count) described, shells \(golden.shells.count), "
              + "sectors \(golden.sectors)")
    }

    @Test func theGoldenSetHasSixteenFrames() {
        let frames: [AmethystEscapeGolden.Frame] = AmethystEscapeGolden.frames
        #expect(frames.count == 16)
        #expect(AmethystEscapeGolden.width == AmethystEscapeTest.width)
        #expect(AmethystEscapeGolden.height == AmethystEscapeTest.height)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == 1 && frame.tier == 0 && frame.actions.count == 1)
            #expect(frame.actions == Array(AmethystEscapeExperienceCore.inputActions.prefix(1)))
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in AmethystEscapeGolden.levels {
            let tiers: [AmethystEscapeGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let certified: [AmethystEscapeAction] = AmethystEscapeExperienceCore.certifiedActions(level)
            #expect(!certified.isEmpty, "level \(level) has a certified escape")
            let actions: [AmethystEscapeAction] = tiers.first?.actions ?? []
            let expected: Int = max(0, min(certified.count - 1, AmethystEscapeGolden.moves))
            #expect(actions.count == expected, "level \(level): \(actions.count) witness actions, not \(expected)")
            #expect(actions == Array(certified.prefix(actions.count)), "level \(level): a prefix of the witness")
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [AmethystEscapeGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: AmethystEscapeGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: AmethystEscapeTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their actions: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their actions")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [AmethystEscapeGolden.Frame] = []
        for frame in AmethystEscapeGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: AmethystEscapeGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: AmethystEscapeTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try AmethystEscapeTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try AmethystEscapeTest.digest(shell)
        #expect(after != before, "the hero action changes the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
