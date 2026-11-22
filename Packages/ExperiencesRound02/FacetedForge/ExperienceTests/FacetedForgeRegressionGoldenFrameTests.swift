// FacetedForgeRegressionGoldenFrameTests — feature 378 (R02-G08-08) T-R02G0808-005 (FR-R02G0808-004;
// SC-R02G0808-003; clarification Q3). Through the one app's session host, each of the 16 code-only golden frames of
// `FacetedForgeGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 at presentation time 1 s, each
// after its certified solution's first min(smallest − 1, 2) cuts, plus the hero frame: level 1 after the hero
// scenario's first cut, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of `FacetedForgeTest` with the
// authored camera and the initial preview choice (`FacetedForgePreviewChoice.initial`, set on the presenter's mirror
// after the cuts, since the mirror otherwise keeps its earlier choice clamped to the new play). The snapshot the
// presenter shows equals `FacetedForgeGolden.snapshot(frame)`, so the rendered frame is the described one; the frame's
// description (`FacetedForgeGolden.description(frame)`, decoded here) names the drawn tier's detail, the cuts spent,
// the budget, the ground colour, every piece centre and the preview centre, and those agree with the CPU reference
// within one 1/8-pixel quantum. The picture is then checked against the description with the feature-373 tolerances:
// every on-screen described piece centre within 3 px of a pixel 0.1 away from the ground in luminance; the described
// preview centre within 3 px of a pixel at least 0.05 away from the ground; the cut mark's first bar (found as
// `FacetedForgeRenderTests` finds it, `FacetedForgeTest.markMisses`) within 3 px of a pixel at least 0.1 away from the
// ground; the two probe corners within 0.05 per channel of the ground. The feature-373 `FacetedForgeTest.checkFrame`
// runs on the golden snapshot too (without the cut-face check, which clarification Q3 of this feature does not name).
// Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1; cuts go through the session's action port
// as `piece.cut`. One test per level plus the hero test, each well under 10 s. Modelled on
// `AmethystEscapeRegressionGoldenFrameTests` (feature 368). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
#if os(iOS)
import FacetedForgeCore
import Foundation
import Testing
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct FacetedForgeRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The description of one golden frame, decoded from `FacetedForgeGolden.description(_:)`. A position is `[x, y]`
    /// in 1/`quantum` pixel, or null off screen.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let bevelSegments: Int
        let dispersionLayers: Int
        let glowShells: Int
        let cuts: Int
        let budget: Int
        let colours: [String: Colour]
        let pieces: [[Int]?]
        let preview: [Int]?
    }

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [FacetedForgeGolden.Frame] {
        var list: [FacetedForgeGolden.Frame] = []
        for frame in FacetedForgeGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port (`piece.cut`), expecting each to be accepted.
    static func apply(_ actions: [FacetedForgeAction], to shell: FacetedForgeTest.Shell, _ what: String) {
        for (index, action) in actions.enumerated() {
            let issued: (control: String, values: [Double]) = FacetedForgeTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted,
                    "\(what): action \(index) \(issued.control) \(issued.values) gave \(result.code)")
        }
    }

    /// Draws one live frame so the presenter's mirror follows the current play, then sets the mirror's preview choice
    /// to the play's initial one (`FacetedForgePreviewChoice.initial`), the choice the golden snapshot uses.
    static func useInitialChoice(_ session: ExperienceSession, _ shell: FacetedForgeTest.Shell) throws {
        try FacetedForgeTest.draw(session)
        let play: FacetedForgePlay = try FacetedForgeTest.core(shell).play
        shell.presenter.mirror.choice = FacetedForgePreviewChoice.initial(play)
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> FacetedForgeTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(FacetedForgeExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: FacetedForgeTest.Shell = try await FacetedForgeTest.open(session, seed: seed)
        let opened: Int = try FacetedForgeTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: FacetedForgeGolden.Frame) throws -> Description {
        let data: Data = try FacetedForgeGolden.description(frame)
        return try JSONDecoder().decode(Description.self, from: data)
    }

    /// Whether the described position `q` lies within one quantum (per axis) of the pixel `p`; both nil also agree.
    static func agrees(_ q: [Int]?, _ p: Vec2?, quantum: Int) -> Bool {
        if q == nil && p == nil { return true }
        guard let q, let p, q.count == 2 else { return false }
        let x: Double = p.x * Double(quantum)
        let y: Double = p.y * Double(quantum)
        return abs(Double(q[0]) - x) <= 1 && abs(Double(q[1]) - y) <= 1
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

    /// Whether `p` lies inside a `width` × `height` picture.
    static func onScreen(_ p: Vec2, width: Int, height: Int) -> Bool {
        p.x >= 0 && p.x < Double(width) && p.y >= 0 && p.y < Double(height)
    }

    /// The description check: the frame's identity, size, quantum, cuts, budget and tier detail, the ground colour and
    /// every named colour's presence, and every piece centre and the preview centre against the CPU reference of
    /// `golden`. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: FacetedForgeGolden.Frame,
                                  golden: FacetedForgeSceneSnapshot) -> [String] {
        typealias Geometry = FacetedForgeSceneGeometry
        var misses: [String] = []
        let width: Int = FacetedForgeTest.width
        let height: Int = FacetedForgeTest.height
        let tier: FacetedForgeTier = FacetedForgeTier.of(frame.tier)
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != width || described.height != height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if quantum != FacetedForgeGolden.quantum { misses.append("quantum \(quantum)") }
        if described.cuts != golden.cuts { misses.append("cuts \(described.cuts), snapshot \(golden.cuts)") }
        if described.budget != golden.budget {
            misses.append("budget \(described.budget), snapshot \(golden.budget)")
        }
        if described.bevelSegments != tier.bevelSegments || described.dispersionLayers != tier.dispersionLayers
            || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.bevelSegments)/\(described.dispersionLayers)/"
                          + "\(described.glowShells)")
        }
        if described.colours["ground"] != colour(FacetedForgePalette.ground) {
            misses.append("ground \(String(describing: described.colours["ground"]))")
        }
        for name in FacetedForgeGolden.colourNames where described.colours[name] == nil {
            misses.append("colour \(name) missing")
        }
        guard described.pieces.count == golden.pieces.count else {
            misses.append("\(described.pieces.count) pieces described, snapshot \(golden.pieces.count)")
            return misses
        }
        for index in golden.pieces.indices {
            let centre: SIMD3<Double> = Geometry.pieceCentre(index, golden)
            let p: Vec2? = FacetedForgeTest.pixel(centre, golden, width: width, height: height)
            if !agrees(described.pieces[index], p, quantum: quantum) {
                misses.append("piece \(index) described \(String(describing: described.pieces[index]))")
            }
        }
        var preview: Vec2? = nil
        if let centre: SIMD3<Double> = Geometry.previewCentre(golden) {
            preview = FacetedForgeTest.pixel(centre, golden, width: width, height: height)
        }
        if !agrees(described.preview, preview, quantum: quantum) {
            misses.append("preview described \(String(describing: described.preview))")
        }
        return misses
    }

    /// The picture check against the description with the feature-373 tolerances: every on-screen described piece
    /// centre within 3 px of a pixel 0.1 away from the ground in luminance, the described preview centre within 3 px of
    /// a pixel at least 0.05 away from the ground, the cut mark's first bar of `golden` within 3 px of a pixel at least
    /// 0.1 away from the ground, the two probe corners within 0.05 per channel of the ground. Returns the pieces
    /// checked and the misses.
    static func pictureMisses(_ rgba: [UInt8], described: Description,
                              golden: FacetedForgeSceneSnapshot) -> (pieces: Int, misses: [String]) {
        let width: Int = described.width
        let height: Int = described.height
        var misses: [String] = []
        guard rgba.count == width * height * 4 else { return (0, ["picture has \(rgba.count) bytes"]) }
        var checked: Int = 0
        for index in described.pieces.indices {
            guard let p: Vec2 = pixel(described.pieces[index], quantum: described.quantum),
                  onScreen(p, width: width, height: height) else { continue }
            checked += 1
            if !FacetedForgeTest.differsFromGround(rgba, near: p.x, p.y, margin: FacetedForgeTest.pieceMargin,
                                                   width: width, height: height) {
                misses.append(String(format: "piece %ld at (%.1f, %.1f) is ground", index, p.x, p.y))
            }
        }
        if let p: Vec2 = pixel(described.preview, quantum: described.quantum) {
            if !FacetedForgeTest.differsFromGround(rgba, near: p.x, p.y, margin: FacetedForgeTest.previewMargin,
                                                   width: width, height: height) {
                misses.append(String(format: "preview at (%.1f, %.1f) is ground", p.x, p.y))
            }
        } else {
            misses.append("preview: no described position")
        }
        if described.budget != golden.budget { misses.append("cut mark: budget \(described.budget)") }
        misses.append(contentsOf: FacetedForgeTest.markMisses(rgba, snapshot: golden, width: width, height: height))
        let corners: (checked: Int, misses: [String]) = FacetedForgeTest.backgroundMisses(rgba, width: width,
                                                                                          height: height)
        if corners.checked != FacetedForgeTest.backgroundPoints.count { misses.append("corners \(corners.checked)") }
        misses.append(contentsOf: corners.misses)
        return (checked, misses)
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check and checks the picture against the description and against the
    /// feature-373 frame checks; every issue names the frame.
    static func check(_ frame: FacetedForgeGolden.Frame, session: ExperienceSession,
                      shell: FacetedForgeTest.Shell) throws {
        let width: Int = FacetedForgeGolden.width
        let height: Int = FacetedForgeGolden.height
        FacetedForgeTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try FacetedForgeTest.still(session, width: width, height: height, time: frame.time)
        let shown: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: FacetedForgeSceneSnapshot = try FacetedForgeGolden.snapshot(frame)
        #expect(shown.time == frame.time, "\(frame.name): the still's frame time is \(shown.time)")
        #expect(shown.levelNumber == golden.levelNumber, "\(frame.name): level \(shown.levelNumber)")
        #expect(shown.cuts == golden.cuts, "\(frame.name): cuts \(shown.cuts), golden \(golden.cuts)")
        #expect(shown.pieces == golden.pieces, "\(frame.name): the shown pieces differ from the golden ones")
        #expect(shown.choice == golden.choice, "\(frame.name): choice \(shown.choice), golden \(golden.choice)")
        #expect(shown.stage == golden.stage, "\(frame.name): stage \(shown.stage), golden \(golden.stage)")
        #expect(shown == golden, "\(frame.name): the shown snapshot differs from the golden one")
        #expect(golden.stage == .playing, "\(frame.name): the level is not playing (stage \(golden.stage))")
        #expect(!golden.won, "\(frame.name): the golden frame is not won")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        let picture: (pieces: Int, misses: [String]) = Self.pictureMisses(rgba, described: described, golden: golden)
        #expect(picture.misses.isEmpty, "\(frame.name): \(picture.misses.prefix(8))")
        #expect(picture.pieces > 0, "\(frame.name): some described piece centre is on screen")
        FacetedForgeTest.checkFrame(rgba, snapshot: golden, reduceMotion: false, width: width, height: height,
                                    cutFaces: false, frame.name)
        print("faceted-forge golden \(frame.name): cuts \(golden.cuts) of \(golden.budget), piece centres checked "
              + "\(picture.pieces) of \(described.pieces.count) described, preview "
              + "\(described.preview == nil ? "none" : "described")")
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing a prefix of the certified
    /// solution shorter than it, and the hero frame (level 1, tier 0, the hero scenario's first cut), all at 1 s.
    @Test func theGoldenSetHasSixteenFrames() {
        let frames: [FacetedForgeGolden.Frame] = FacetedForgeGolden.frames
        #expect(frames.count == 16)
        #expect(FacetedForgeGolden.width == FacetedForgeTest.width)
        #expect(FacetedForgeGolden.height == FacetedForgeTest.height)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == 1 && frame.tier == 0 && frame.actions.count == 1)
            #expect(frame.actions == Array(FacetedForgeExperienceCore.inputActions.prefix(1)))
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 1, "\(frame.name): time \(frame.time)") }
        for level in FacetedForgeGolden.levels {
            let tiers: [FacetedForgeGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let certified: [FacetedForgeAction] = FacetedForgeExperienceCore.certifiedActions(level)
            #expect(!certified.isEmpty, "level \(level) has a certified solution")
            let actions: [FacetedForgeAction] = tiers.first?.actions ?? []
            let expected: Int = max(0, min(certified.count - 1, FacetedForgeGolden.cuts))
            #expect(actions.count == expected, "level \(level): \(actions.count) certified cuts, not \(expected)")
            #expect(actions == Array(certified.prefix(actions.count)), "level \(level): a prefix of the solution")
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    /// The three tier frames of `level` render as described.
    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [FacetedForgeGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: FacetedForgeGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: FacetedForgeTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their cuts: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        try Self.useInitialChoice(session, shell)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their cuts")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    /// The hero frame (level 1 after the hero scenario's first cut, tier 0) renders as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [FacetedForgeGolden.Frame] = []
        for frame in FacetedForgeGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: FacetedForgeGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: FacetedForgeTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try FacetedForgeTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try FacetedForgeTest.digest(shell)
        #expect(after != before, "the hero cut changes the digest")
        try Self.useInitialChoice(session, shell)
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
