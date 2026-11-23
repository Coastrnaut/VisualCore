// BackwardsAuroraRegressionGoldenFrameTests — feature 398 (R02-G10-08) T-R02G1008-005 (FR-R02G1008-003, 004;
// SC-R02G1008-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `BackwardsAuroraGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after its
// certified solution's first min(smallest − 1, 2) reversals, plus the hero frame: the manifest seed's level after the
// hero scenario's first reversal, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of
// `BackwardsAuroraTest` with the frame's tier pinned. The still is drawn at the frame's time plus 1 s (`settle`): the
// golden frames are at time 0, and the presenter's eased lights (feature 396) settle within 0.15 s of their last
// change, so the glow rests at its target when the picture is measured; no position depends on the time (the shimmer
// and the pulses are shader uniforms). The panel's section is the opening 0 … 1 of a new level, as in the golden
// snapshot, and the snapshot the presenter shows equals `BackwardsAuroraGolden.snapshot(frame)` in every field but the
// time, so the rendered frame is the described one. The frame's description (`BackwardsAuroraGolden.description`,
// decoded here) names the frame, the size, the quantum, the drawn tier's detail (trailing layers, pulses, glow shells),
// the kink count, the tear, the reversals spent, the budget, the ground colour and every named colour, one position per
// sample and one per checkpoint ring; those agree with the golden snapshot and the Core's CPU reference
// (`BackwardsAuroraTest.pixel`, within one 1/8-pixel quantum). The picture then shows what the description says where
// it says it:
//   - every described sample point inside the picture and clear of the markers (`BackwardsAuroraTest.exclusions`) has a
//     ribbon pixel within 3 px (blue − red at least 0.15, luminance at least 0.15 from the ground's);
//   - every described ring centre inside the picture has, at 5 or more of 8 points of its line (the ring's radius in
//     the ring's plane around the centre), a ring pixel within 3 px (red at least 0.6 and luminance at least 0.3 above
//     the ground's: the emissive lilac-white ring or matched disc; a cross or the ghost may cover a few of the points);
//   - the gauge shows the described spent and total: the first `spent` bars are spent (a pixel within 1.5 px of the
//     bar's centre with luminance at least 0.3 above the ground's and blue − red at least 0.15) and the others are
//     drawn but unspent (the centre pixel more than 0.05 from the ground per channel and less than 0.3 above it in
//     luminance);
// and passes the feature-393 frame checks (`BackwardsAuroraTest.checkFrame`): sample points within 3 px of a ribbon
// pixel, ghost points near a lilac pixel 0.1 from the ground, the gauge's first bar 0.1 from the ground, the two probe
// corners within 0.05 of the ground. Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1;
// reversals go through the session's action port (`wave.reverse`). One test per level plus the hero test and the set
// test, each well under 10 s. Modelled on `NocturneGardenRegressionGoldenFrameTests` (feature 388). Synthetic data,
// explicit types, plain loops, no sleep, no wall-clock assertion.
#if os(iOS)
import Foundation
import BackwardsAuroraCore
import Testing
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct BackwardsAuroraRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The description of one golden frame, decoded from `BackwardsAuroraGolden.description(_:)`. A position is
    /// `[x, y]` in 1/`quantum` pixel, or null when it does not project.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let trailingLayers: Int
        let pulses: Int
        let glowShells: Int
        let kinks: Int
        let tear: Int?
        let spent: Int
        let budget: Int
        let colours: [String: Colour]
        let samples: [[Int]?]
        let rings: [[Int]?]
    }

    /// How long after the frame's time the still is drawn (seconds), so the eased lights rest at their targets.
    static let settle: Double = 1
    /// The search radius (pixels) of the ring and gauge checks.
    static let ringRadius: Double = 3
    /// The points of a ring's line tested, and how many of them must show a ring pixel.
    static let ringPoints: Int = 8
    static let ringPointsNeeded: Int = 5
    /// A ring pixel's least red and least luminance above the ground's.
    static let ringRed: Double = 0.6
    static let ringBrightness: Double = 0.3
    /// A spent bar's least luminance above the ground's (an unspent bar stays below it).
    static let spentBrightness: Double = 0.3
    /// A spent bar's coolness (blue − red).
    static let spentCoolness: Double = 0.15
    /// An unspent bar's least per-channel distance from the ground.
    static let unspentDistance: Double = 0.05

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [BackwardsAuroraGolden.Frame] {
        var list: [BackwardsAuroraGolden.Frame] = []
        for frame in BackwardsAuroraGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port, expecting each to be accepted.
    static func apply(_ actions: [BackwardsAuroraAction], to shell: BackwardsAuroraTest.Shell, _ what: String) {
        for (index, action) in actions.enumerated() {
            let issued: (control: String, values: [Double]) = BackwardsAuroraTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted,
                    "\(what): action \(index) \(issued.control) \(issued.values) gave \(result.code)")
        }
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> BackwardsAuroraTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(BackwardsAuroraExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: BackwardsAuroraTest.Shell = try await BackwardsAuroraTest.open(session, seed: seed)
        let opened: Int = try BackwardsAuroraTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: BackwardsAuroraGolden.Frame) throws -> Description {
        let data: Data = try BackwardsAuroraGolden.description(frame)
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

    /// Every field of `shown` that differs from `golden`, the time left out (the still is drawn `settle` s later).
    static func snapshotMisses(_ shown: BackwardsAuroraSceneSnapshot,
                               _ golden: BackwardsAuroraSceneSnapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber { misses.append("level \(shown.levelNumber)") }
        if shown.samples != golden.samples { misses.append("samples (\(shown.count), golden \(golden.count))") }
        if shown.target != golden.target { misses.append("target samples") }
        if shown.checkpoints != golden.checkpoints { misses.append("checkpoints") }
        if shown.matched != golden.matched { misses.append("matched checkpoints") }
        if shown.bendLimit != golden.bendLimit {
            misses.append("bend limit \(shown.bendLimit), golden \(golden.bendLimit)")
        }
        if shown.kinks != golden.kinks { misses.append("kinks \(shown.kinks), golden \(golden.kinks)") }
        if shown.tear != golden.tear {
            misses.append("tear \(String(describing: shown.tear)), golden \(String(describing: golden.tear))")
        }
        if shown.sectionStart != golden.sectionStart || shown.sectionEnd != golden.sectionEnd {
            misses.append("section \(shown.sectionStart) … \(shown.sectionEnd), golden "
                          + "\(golden.sectionStart) … \(golden.sectionEnd)")
        }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        if shown.spent != golden.spent { misses.append("spent \(shown.spent), golden \(golden.spent)") }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.preview != golden.preview { misses.append("preview \(shown.preview)") }
        return misses
    }

    /// The description check: the frame's identity, size, quantum, tier detail, kinks, tear, spent and budget, the
    /// ground colour and every named colour's presence, and one position per sample and per ring agreeing with the CPU
    /// reference of `golden`. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: BackwardsAuroraGolden.Frame,
                                  golden: BackwardsAuroraSceneSnapshot) -> [String] {
        var misses: [String] = []
        let width: Int = BackwardsAuroraTest.width
        let height: Int = BackwardsAuroraTest.height
        let tier: BackwardsAuroraTier = BackwardsAuroraTier.of(frame.tier)
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != width || described.height != height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if quantum != BackwardsAuroraGolden.quantum { misses.append("quantum \(quantum)") }
        if described.trailingLayers != tier.trailingLayers || described.pulses != tier.pulses
            || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.trailingLayers)/\(described.pulses)/\(described.glowShells)")
        }
        if described.kinks != golden.kinks.count {
            misses.append("kinks \(described.kinks), snapshot \(golden.kinks.count)")
        }
        if described.tear != golden.tear {
            misses.append("tear \(String(describing: described.tear)), snapshot \(String(describing: golden.tear))")
        }
        if described.spent != golden.spent { misses.append("spent \(described.spent), snapshot \(golden.spent)") }
        if described.budget != golden.budget {
            misses.append("budget \(described.budget), snapshot \(golden.budget)")
        }
        if described.colours["ground"] != colour(BackwardsAuroraPalette.ground) {
            misses.append("ground \(String(describing: described.colours["ground"]))")
        }
        for name in BackwardsAuroraGolden.colourNames where described.colours[name] == nil {
            misses.append("colour \(name) missing")
        }
        if described.samples.count != golden.count {
            misses.append("\(described.samples.count) samples described, snapshot \(golden.count)")
        } else {
            for k in 0..<golden.count {
                let reference: SIMD2<Double>? = BackwardsAuroraTest.pixel(
                    BackwardsAuroraSceneGeometry.samplePoint(k, golden), golden, width: width, height: height)
                if !agrees(described.samples[k], reference, quantum: quantum) {
                    misses.append("sample \(k) described \(String(describing: described.samples[k]))")
                }
            }
        }
        if described.rings.count != golden.checkpoints.count {
            misses.append("\(described.rings.count) rings described, snapshot \(golden.checkpoints.count)")
        } else {
            for index in golden.checkpoints.indices {
                let reference: SIMD2<Double>? = BackwardsAuroraTest.pixel(
                    BackwardsAuroraSceneGeometry.ringCentre(index, golden), golden, width: width, height: height)
                if !agrees(described.rings[index], reference, quantum: quantum) {
                    misses.append("ring \(index + 1) described \(String(describing: described.rings[index]))")
                }
            }
        }
        return misses
    }

    /// Whether `c` is a ring pixel: red at least ``ringRed`` and luminance ``ringBrightness`` above the ground's.
    static func isRing(_ c: SIMD3<Double>) -> Bool {
        c.x >= ringRed && BackwardsAuroraTest.luminance(c) - BackwardsAuroraTest.groundLuminance >= ringBrightness
    }

    /// Whether `c` is a spent bar pixel: luminance ``spentBrightness`` above the ground's and cyan.
    static func isSpent(_ c: SIMD3<Double>) -> Bool {
        BackwardsAuroraTest.luminance(c) - BackwardsAuroraTest.groundLuminance >= spentBrightness
            && c.z - c.x >= spentCoolness
    }

    /// The position check of the picture against the description: every described sample point inside the picture and
    /// clear of the markers near a ribbon pixel, and every described ring centre inside the picture with a ring pixel
    /// near enough points of its line. Returns the samples and rings checked and the misses.
    static func positionMisses(_ rgba: [UInt8], described: Description,
                               golden: BackwardsAuroraSceneSnapshot) -> (samples: Int, rings: Int, misses: [String]) {
        let width: Int = described.width
        let height: Int = described.height
        var samples: Int = 0
        var rings: Int = 0
        var misses: [String] = []
        let exclusions: (zones: [BackwardsAuroraTest.Zone], ticks: [(x: Double, half: Double)]) =
            BackwardsAuroraTest.exclusions(golden, width: width, height: height)
        for k in described.samples.indices {
            guard let p: SIMD2<Double> = pixel(described.samples[k], quantum: described.quantum),
                  BackwardsAuroraTest.inside(p, width: width, height: height),
                  !BackwardsAuroraTest.excluded(p, exclusions) else { continue }
            samples += 1
            let found: Bool = BackwardsAuroraTest.anyPixel(rgba, near: p, radius: BackwardsAuroraTest.pointRadius,
                                                           width: width, height: height,
                                                           where: BackwardsAuroraTest.isRibbon)
            if !found {
                misses.append(String(format: "no ribbon at described sample %ld (%.1f, %.1f)", k, p.x, p.y))
            }
        }
        let radius: Double = BackwardsAuroraSceneGeometry.ringRadius
        for index in described.rings.indices {
            guard let p: SIMD2<Double> = pixel(described.rings[index], quantum: described.quantum),
                  BackwardsAuroraTest.inside(p, width: width, height: height) else { continue }
            guard index < golden.checkpoints.count else { continue }
            rings += 1
            let centre: SIMD3<Double> = BackwardsAuroraSceneGeometry.ringCentre(index, golden)
            var shown: Int = 0
            for step in 0..<ringPoints {
                let angle: Double = Double(step) * 2 * Double.pi / Double(ringPoints)
                let point: SIMD3<Double> = centre + SIMD3<Double>(radius * cos(angle), radius * sin(angle), 0)
                guard let q: SIMD2<Double> = BackwardsAuroraTest.pixel(point, golden, width: width, height: height),
                      BackwardsAuroraTest.inside(q, width: width, height: height) else { continue }
                if BackwardsAuroraTest.anyPixel(rgba, near: q, radius: ringRadius, width: width, height: height,
                                                where: isRing) {
                    shown += 1
                }
            }
            if shown < ringPointsNeeded {
                misses.append(String(format: "ring %ld at described (%.1f, %.1f): %ld of %ld line points show it",
                                     index + 1, p.x, p.y, shown, ringPoints))
            }
        }
        return (samples, rings, misses)
    }

    /// The gauge check: the first `spent` of `budget` bars are spent, the others drawn unspent. Returns the misses.
    static func gaugeMisses(_ rgba: [UInt8], described: Description,
                            golden: BackwardsAuroraSceneSnapshot) -> [String] {
        let width: Int = described.width
        let height: Int = described.height
        var misses: [String] = []
        if described.budget <= 0 { return ["gauge: no budget"] }
        let ground: SIMD3<Double> = BackwardsAuroraPalette.ground
        for bar in 0..<described.budget {
            guard let p: SIMD2<Double> = BackwardsAuroraTest.pixel(BackwardsAuroraSceneGeometry.gaugeBar(bar, golden),
                                                                   golden, width: width, height: height),
                  BackwardsAuroraTest.inside(p, width: width, height: height) else {
                misses.append("gauge bar \(bar): off the picture")
                continue
            }
            if bar < described.spent {
                if !BackwardsAuroraTest.anyPixel(rgba, near: p, radius: 1.5, width: width, height: height,
                                                 where: isSpent) {
                    let c: SIMD3<Double> = BackwardsAuroraTest.centre(rgba, p, width: width, height: height)
                    misses.append(String(format: "gauge bar %ld should be spent: (%.3f, %.3f, %.3f)", bar, c.x, c.y,
                                         c.z))
                }
            } else {
                let c: SIMD3<Double> = BackwardsAuroraTest.centre(rgba, p, width: width, height: height)
                let brightness: Double = BackwardsAuroraTest.luminance(c) - BackwardsAuroraTest.groundLuminance
                if BackwardsAuroraTest.channelDistance(c, ground) <= unspentDistance || brightness >= spentBrightness {
                    misses.append(String(format: "gauge bar %ld should be unspent: (%.3f, %.3f, %.3f)", bar, c.x, c.y,
                                         c.z))
                }
            }
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still `settle` s after the frame's time, compares the shown
    /// snapshot with the golden one (time aside), runs the description, position and gauge checks and the feature-393
    /// frame checks; every issue names the frame.
    static func check(_ frame: BackwardsAuroraGolden.Frame, session: ExperienceSession,
                      shell: BackwardsAuroraTest.Shell) throws {
        let width: Int = BackwardsAuroraGolden.width
        let height: Int = BackwardsAuroraGolden.height
        let time: Double = frame.time + settle
        BackwardsAuroraTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try BackwardsAuroraTest.still(session, width: width, height: height, time: time)
        let shown: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                               "\(frame.name): no snapshot")
        let golden: BackwardsAuroraSceneSnapshot = try BackwardsAuroraGolden.snapshot(frame)
        #expect(shown.time == time, "\(frame.name): the still's frame time is \(shown.time)")
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(golden.stage == .playing, "\(frame.name): the level is not playing (stage \(golden.stage))")
        #expect(golden.failure == nil, "\(frame.name): the golden frame has failed")
        #expect(golden.spent == frame.actions.count, "\(frame.name): spent \(golden.spent)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        #expect(shell.presenter.lights.isSettled, "\(frame.name): the lights are still fading")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        let gaugeNote: String = "\(frame.name): gauge described \(described.spent) of \(described.budget), shown "
            + "\(shown.spent) of \(shown.budget)"
        #expect(described.spent == shown.spent && described.budget == shown.budget, "\(gaugeNote)")
        let positions: (samples: Int, rings: Int, misses: [String]) = Self.positionMisses(rgba, described: described,
                                                                                           golden: golden)
        #expect(positions.samples > 0, "\(frame.name): no described sample point clear of the markers")
        #expect(positions.misses.isEmpty, "\(frame.name): \(positions.misses.prefix(8))")
        let gauge: [String] = Self.gaugeMisses(rgba, described: described, golden: golden)
        #expect(gauge.isEmpty, "\(frame.name): \(gauge.prefix(8))")
        BackwardsAuroraTest.checkFrame(rgba, snapshot: golden, width: width, height: height, frame.name)
        print("backwards-aurora golden \(frame.name): spent \(golden.spent) of \(golden.budget), kinks "
              + "\(golden.kinks.count), samples checked \(positions.samples), rings checked \(positions.rings)")
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing a prefix of the certified
    /// solution shorter than it, and the hero frame (the manifest seed's level, tier 0, the hero scenario's first
    /// reversal), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() {
        let frames: [BackwardsAuroraGolden.Frame] = BackwardsAuroraGolden.frames
        #expect(frames.count == 16)
        #expect(BackwardsAuroraGolden.width == BackwardsAuroraTest.width)
        #expect(BackwardsAuroraGolden.height == BackwardsAuroraTest.height)
        let heroSeed: UInt64 = BackwardsAuroraExperienceCore.manifestSeed
        let heroLevel: Int = BackwardsAuroraExperienceCore.levelNumber(forSeed: heroSeed)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0 && frame.actions.count == 1)
            #expect(frame.actions == Array(BackwardsAuroraExperienceCore.inputActions.prefix(1)))
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in BackwardsAuroraGolden.levels {
            let tiers: [BackwardsAuroraGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let certified: [BackwardsAuroraAction] = BackwardsAuroraExperienceCore.certifiedActions(level)
            #expect(!certified.isEmpty, "level \(level) has a certified solution")
            let actions: [BackwardsAuroraAction] = tiers.first?.actions ?? []
            let expected: Int = max(0, min(certified.count - 1, BackwardsAuroraGolden.reversals))
            #expect(actions.count == expected, "level \(level): \(actions.count) certified reversals, not \(expected)")
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
        let frames: [BackwardsAuroraGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: BackwardsAuroraGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: BackwardsAuroraTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their reversals: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their reversals")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    /// The hero frame (the manifest seed's level after the hero scenario's first reversal, tier 0) renders as
    /// described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [BackwardsAuroraGolden.Frame] = []
        for frame in BackwardsAuroraGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: BackwardsAuroraGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: BackwardsAuroraTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try BackwardsAuroraTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try BackwardsAuroraTest.digest(shell)
        #expect(after != before, "the hero reversal changes the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
