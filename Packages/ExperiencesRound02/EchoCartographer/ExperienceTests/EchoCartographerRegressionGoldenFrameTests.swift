// EchoCartographerRegressionGoldenFrameTests — feature 408 (R02-G11-08) T-R02G1108-005 (FR-R02G1108-003, 004;
// SC-R02G1108-003; clarification Q3). User Story 2. Through the one app's session host, each of the 16 code-only golden
// frames of `EchoCartographerGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2, each after its
// witness's first min(pulses − 1, 2) pulses (at least one) and one marker on the first known-open cell that is not the
// entry, plus the hero frame: the manifest seed's level after the hero scenario's actions, tier 0) is drawn off screen
// at the frame-check size 1,152 × 768 of `EchoCartographerTest` with the frame's tier pinned, at the frame's time 0.
// Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1; the frame's actions go through the
// session's action port (`cell.pulse`, `cell.mark`). The snapshot the presenter drew equals
// `EchoCartographerGolden.snapshot(frame)` in every field that the picture shows (level, knowledge, markers, located
// beacons, energy, budget, last echo, stage, failure, entry, chamber size; the time is 0 in both: the pulse clock
// restarts on the still's frame), so the rendered frame is the golden one. The frame's description
// (`EchoCartographerGolden.description`, decoded here) names the frame, the size, the quantum, the tier's detail, the
// counts and every named colour and puts every floor tile, wall top, marker ring, located pillar, the entry and the
// first gauge bar where the Core's CPU reference of the golden snapshot puts them (within one 1/8-pixel quantum). The
// picture then passes the feature-403 checks (`EchoCartographerTest.checkFrame`) against the presenter's last snapshot:
// at every point at least 6 px from every other element, a known floor tile's centre has a pixel 0.1 from the ground in
// luminance within 3 px, a known wall's top-face centre one 0.08 from the ground with green above red by 0.05; the
// gauge's first bar is 0.1 from the ground; the two probe corners are within 0.05 of the ground. One test per level
// (three stills) plus the hero test and the set test, each well under 10 s. Modelled on
// `BackwardsAuroraRegressionGoldenFrameTests` (feature 398). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
#if os(iOS)
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct EchoCartographerRegressionGoldenFrameTests {
    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of the description.
    struct Counts: Decodable, Equatable {
        let open: Int
        let walls: Int
        let markers: Int
        let located: Int
        let rays: Int
        let gaugeLit: Int
        let gaugeTotal: Int
    }

    /// The description of one golden frame, decoded from `EchoCartographerGolden.description(_:)`. A position is
    /// `[x, y]` in 1/`quantum` pixel, or null when it does not project.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let rings: Bool
        let flareTrails: Bool
        let glowShells: Int
        let counts: Counts
        let colours: [String: Colour]
        let floors: [[Int]?]
        let walls: [[Int]?]
        let markers: [[Int]?]
        let pillars: [[Int]?]
        let entry: [Int]?
        let firstGaugeBar: [Int]?
    }

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [EchoCartographerGolden.Frame] {
        var list: [EchoCartographerGolden.Frame] = []
        for frame in EchoCartographerGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port, expecting each to be accepted.
    static func apply(_ actions: [EchoCartographerAction], to shell: EchoCartographerTest.Shell, _ what: String) {
        for (index, action) in actions.enumerated() {
            let issued: (control: String, values: [Double]) = EchoCartographerTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted,
                    "\(what): action \(index) \(issued.control) \(issued.values) gave \(result.code)")
        }
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> EchoCartographerTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(EchoCartographerExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: EchoCartographerTest.Shell = try await EchoCartographerTest.open(session, seed: seed)
        let opened: Int = try EchoCartographerTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        #expect(!shell.presenter.reduceMotion, "the golden frames are drawn with motion")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: EchoCartographerGolden.Frame) throws -> Description {
        let data: Data = try EchoCartographerGolden.description(frame)
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

    /// Whether the described position `q` lies within one quantum (per axis) of the pixel `p`; both nil also agree.
    static func agrees(_ q: [Int]?, _ p: SIMD2<Double>?, quantum: Int) -> Bool {
        if q == nil && p == nil { return true }
        guard let q, let p, q.count == 2 else { return false }
        let x: Double = p.x * Double(quantum)
        let y: Double = p.y * Double(quantum)
        return abs(Double(q[0]) - x) <= 1 && abs(Double(q[1]) - y) <= 1
    }

    /// The described positions `described` against the CPU reference pixels of `points` for `golden`; returns the
    /// misses, each naming `what` and the index.
    static func positionMisses(_ what: String, described: [[Int]?], points: [SIMD3<Double>],
                               golden: EchoCartographerSceneSnapshot, quantum: Int) -> [String] {
        if described.count != points.count {
            return ["\(described.count) \(what) points described, reference \(points.count)"]
        }
        var misses: [String] = []
        for index in points.indices {
            let reference: SIMD2<Double>? = EchoCartographerTest.pixel(points[index], golden)
            if !agrees(described[index], reference, quantum: quantum) {
                misses.append("\(what) \(index) described \(String(describing: described[index])), reference "
                              + "\(String(describing: reference))")
            }
        }
        return misses
    }

    /// Every field of `shown` that the picture shows and that differs from `golden` (the time is checked apart).
    static func snapshotMisses(_ shown: EchoCartographerSceneSnapshot,
                               _ golden: EchoCartographerSceneSnapshot) -> [String] {
        var misses: [String] = []
        if shown.levelNumber != golden.levelNumber {
            misses.append("level \(shown.levelNumber), golden \(golden.levelNumber)")
        }
        if shown.width != golden.width || shown.height != golden.height {
            misses.append("chamber \(shown.width) × \(shown.height), golden \(golden.width) × \(golden.height)")
        }
        if shown.knowledge != golden.knowledge {
            misses.append("knowledge (open \(shown.openCells.count), walls \(shown.wallCells.count); golden open "
                          + "\(golden.openCells.count), walls \(golden.wallCells.count))")
        }
        if shown.entry != golden.entry { misses.append("entry") }
        if shown.markers != golden.markers {
            misses.append("markers \(shown.markers.count), golden \(golden.markers.count)")
        }
        if shown.located != golden.located {
            misses.append("located \(shown.located.count), golden \(golden.located.count)")
        }
        if shown.energy != golden.energy { misses.append("energy \(shown.energy), golden \(golden.energy)") }
        if shown.budget != golden.budget { misses.append("budget \(shown.budget), golden \(golden.budget)") }
        if shown.lastEcho != golden.lastEcho { misses.append("last echo") }
        if shown.stage != golden.stage { misses.append("stage \(shown.stage), golden \(golden.stage)") }
        if shown.failure != golden.failure { misses.append("failure \(String(describing: shown.failure))") }
        return misses
    }

    /// The description check: the frame's identity, size, quantum, tier detail, counts, the colours and every position
    /// agreeing with the CPU reference of `golden`. Returns the misses.
    static func descriptionMisses(_ described: Description, frame: EchoCartographerGolden.Frame,
                                  golden: EchoCartographerSceneSnapshot) -> [String] {
        var misses: [String] = []
        let tier: EchoCartographerTier = EchoCartographerTier.of(frame.tier)
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != EchoCartographerTest.width || described.height != EchoCartographerTest.height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if quantum != EchoCartographerGolden.quantum { misses.append("quantum \(quantum)") }
        if described.rings != tier.rings || described.flareTrails != tier.flareTrails
            || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.rings)/\(described.flareTrails)/\(described.glowShells)")
        }
        let counts: Counts = described.counts
        if counts.open != golden.openCells.count { misses.append("open \(counts.open)") }
        if counts.walls != golden.wallCells.count { misses.append("walls \(counts.walls)") }
        if counts.markers != golden.markers.count { misses.append("markers \(counts.markers)") }
        if counts.located != golden.located.count { misses.append("located \(counts.located)") }
        let rays: Int = golden.lastEcho?.rays.count ?? 0
        if counts.rays != rays { misses.append("rays \(counts.rays), snapshot \(rays)") }
        if counts.gaugeLit != EchoCartographerSceneGeometry.litBars(golden) {
            misses.append("lit bars \(counts.gaugeLit)")
        }
        if counts.gaugeTotal != max(golden.budget, 0) { misses.append("gauge total \(counts.gaugeTotal)") }
        if described.colours["ground"] != colour(EchoCartographerPalette.ground) {
            misses.append("ground \(String(describing: described.colours["ground"]))")
        }
        for name in EchoCartographerGolden.colourNames where described.colours[name] == nil {
            misses.append("colour \(name) missing")
        }
        let reference: EchoCartographerReferencePoints = EchoCartographerSceneGeometry.referencePoints(golden)
        var pillars: [SIMD3<Double>] = []
        for cell in golden.located { pillars.append(EchoCartographerSceneGeometry.pillarTop(cell, golden)) }
        misses += positionMisses("floor", described: described.floors, points: reference.floors, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("wall", described: described.walls, points: reference.walls, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("marker", described: described.markers, points: reference.markers, golden: golden,
                                 quantum: quantum)
        misses += positionMisses("pillar", described: described.pillars, points: pillars, golden: golden,
                                 quantum: quantum)
        if !agrees(described.entry, EchoCartographerTest.pixel(reference.entry, golden), quantum: quantum) {
            misses.append("entry described \(String(describing: described.entry))")
        }
        if !agrees(described.firstGaugeBar, EchoCartographerTest.pixel(reference.firstGaugeBar, golden),
                   quantum: quantum) {
            misses.append("first gauge bar described \(String(describing: described.firstGaugeBar))")
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one, runs the description check and the feature-403 frame checks against the presenter's last snapshot;
    /// every issue names the frame.
    static func check(_ frame: EchoCartographerGolden.Frame, session: ExperienceSession,
                      shell: EchoCartographerTest.Shell) throws {
        let width: Int = EchoCartographerGolden.width
        let height: Int = EchoCartographerGolden.height
        EchoCartographerTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try EchoCartographerTest.still(session, width: width, height: height, time: frame.time)
        let shown: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                                "\(frame.name): no snapshot")
        let golden: EchoCartographerSceneSnapshot = try EchoCartographerGolden.snapshot(frame)
        #expect(golden.time == frame.time, "\(frame.name): the golden time is \(golden.time)")
        #expect(shown.time == golden.time, "\(frame.name): the drawn pulse time is \(shown.time)")
        let differences: [String] = Self.snapshotMisses(shown, golden)
        #expect(differences.isEmpty, "\(frame.name): the shown snapshot differs from the golden one: \(differences)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        let known: Bool = !shown.wallCells.isEmpty && shown.openCells.count > 1
        let report: EchoCartographerFrameReport = EchoCartographerTest.checkFrame(rgba, snapshot: shown, width: width,
                                                                                  height: height, known: known,
                                                                                  frame.name)
        print("echo-cartographer golden \(frame.name): energy \(golden.energy) of \(golden.budget), open "
              + "\(golden.openCells.count), walls \(golden.wallCells.count), markers \(golden.markers.count), "
              + "floors checked \(report.floorChecked), walls checked \(report.wallChecked)")
    }

    /// The golden set has 16 frames with unique names: three tiers per level sharing their actions (one to two
    /// certified pulses and at most one marker, the level not won), and the hero frame (the manifest seed's level,
    /// tier 0, the hero scenario's actions), all at time 0.
    @Test func theGoldenSetHasSixteenFrames() throws {
        let frames: [EchoCartographerGolden.Frame] = EchoCartographerGolden.frames
        #expect(frames.count == 16)
        #expect(EchoCartographerGolden.width == EchoCartographerTest.width)
        #expect(EchoCartographerGolden.height == EchoCartographerTest.height)
        let heroLevel: Int = EchoCartographerExperienceCore.levelNumber(
            forSeed: EchoCartographerExperienceCore.manifestSeed)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == heroLevel && frame.tier == 0)
            #expect(frame.actions == EchoCartographerExperienceCore.inputActions)
            #expect(!frame.actions.isEmpty, "the hero frame has actions")
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in EchoCartographerGolden.levels {
            let tiers: [EchoCartographerGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [EchoCartographerAction] = tiers.first?.actions ?? []
            var pulses: Int = 0
            var marks: Int = 0
            for action in actions {
                switch action {
                case .pulse: pulses += 1
                case .mark: marks += 1
                case .claim: Issue.record("level \(level): a golden frame claims")
                }
            }
            #expect(pulses >= 1 && pulses <= EchoCartographerGolden.pulses, "level \(level): \(pulses) pulses")
            #expect(marks <= 1, "level \(level): \(marks) markers")
            var tierIndex: Int = 0
            for frame in tiers {
                #expect(frame.tier == tierIndex, "\(frame.name): tier \(frame.tier), not \(tierIndex)")
                #expect(frame.actions == actions, "\(frame.name): the tier frames share their actions")
                tierIndex += 1
            }
            if let first: EchoCartographerGolden.Frame = tiers.first {
                let golden: EchoCartographerSceneSnapshot = try EchoCartographerGolden.snapshot(first)
                #expect(golden.stage == .playing, "\(first.name): stage \(golden.stage)")
                #expect(golden.failure == nil, "\(first.name): the golden frame has failed")
                #expect(golden.energy == golden.budget - pulses, "\(first.name): energy \(golden.energy)")
                #expect(golden.markers.count == marks, "\(first.name): markers \(golden.markers.count)")
                #expect(!golden.wallCells.isEmpty, "\(first.name): a wall is known")
            }
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    /// The three tier frames of `level` render as the golden snapshot and description say.
    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [EchoCartographerGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: EchoCartographerGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: EchoCartographerTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their actions: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their actions")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    /// The hero frame (the manifest seed's level after the hero scenario's actions, tier 0) renders as described.
    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [EchoCartographerGolden.Frame] = []
        for frame in EchoCartographerGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: EchoCartographerGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: EchoCartographerTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try EchoCartographerTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try EchoCartographerTest.digest(shell)
        #expect(after != before, "the hero actions change the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
