// StarlitCartoucheRenderTests — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-001 … 004, 007;
// clarifications Q1–Q4). Through the one app's session host, drawn off screen at the frame-check size of
// `StarlitCartoucheTest` (1,152 × 768) at frame time 0: catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80)
// at their opening, at each quality tier level-0, level-1 and level-2, match the Core's CPU reference of the
// presenter's last snapshot: at every point at least 6 px from every element drawn after it in the painter's order
// that could hide it, a star's centre is brighter than the backdrop by 0.25 in luminance, the ship's centre has blue
// above red by 0.08, the first actions bar is 0.1 from the backdrop, and the median of every 9 × 9 backdrop patch is
// within 0.06 of the firmament gradient at its height; the reference pixels and the drawn snapshot are the same at
// every tier; each tier measures star centres and the ship summed over the five levels. With the first leg of each
// level's certified plan flown, the trail's midpoint (or another clear point of it) has red above blue by 0.08 at
// every tier. The presenter declares no frame probe before it drew a snapshot and two dark corners after, which match
// the drawn still at every tier. A leg the chart fails (found by a short search through the adapter) draws the failed
// leg in the broken colour #FF6B4A, leaves the ship and the trails where they were, is named in words, and undo draws
// the frame before it again; flying level 1's certified plan wins, the won frame keeps every position the kernel's and
// passes the same checks. Each test well under 10 s.
#if os(iOS)
import Foundation
import StarlitCartoucheCore
import Testing
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct StarlitCartoucheRenderTests {
    /// The catalog levels searched for a failing leg, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 81, 11, 31, 51, 71, 91]

    /// Every tier of the five levels' openings matches the CPU reference at the same reference pixels; each tier
    /// measures star centres and the ship summed over the levels.
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var stars: [Int] = [0, 0, 0]
        var ships: [Int] = [0, 0, 0]
        var actions: [Int] = [0, 0, 0]
        for seed in StarlitCartoucheTest.seeds {
            let counts = try await checkOpening(seed: seed)
            for tier in 0..<3 {
                stars[tier] += counts.stars[tier]
                ships[tier] += counts.ships[tier]
                actions[tier] += counts.actions[tier]
            }
        }
        print("starlit-cartouche five openings: stars per tier \(stars), ships per tier \(ships)")
        for tier in 0..<3 {
            #expect(stars[tier] > 0, "tier \(tier): no star centre measured on the five levels")
            #expect(ships[tier] > 0, "tier \(tier): the ship was not measured on the five levels")
            // A star may project over the first actions bar (stars and gauges share the screen), so the bar is
            // required on most levels rather than on every one.
            #expect(actions[tier] >= 3, "tier \(tier): the first actions bar was measured on \(actions[tier]) levels")
        }
    }

    /// With the first certified leg flown on each of the five levels, the trail is meteor gold at every tier (the
    /// same trail points at every tier); at least one level measures it.
    @Test func aFlownTrailIsGoldAtEveryTier() async throws {
        var trails: [Int] = [0, 0, 0]
        for seed in StarlitCartoucheTest.seeds {
            let number: Int = StarlitCartoucheExperienceCore.levelNumber(forSeed: seed)
            let first: StarlitCartoucheAction = try #require(try StarlitCartoucheTest.certifiedLegs(number).first,
                                                             "level \(number) has a certified leg")
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await StarlitCartoucheTest.open(session, seed: seed)
            #expect(StarlitCartoucheTest.issue(shell, [first]) == 1)
            let expected: StarlitCartoucheSceneSnapshot = try StarlitCartoucheTest.coreAfter(number, [first])
                .snapshot(time: 0)
            try StarlitCartoucheTest.prime(session)
            var references: [[SIMD2<Double>?]] = []
            var measured: [Int] = []
            for tier in 0..<3 {
                StarlitCartoucheTest.pin(session, shell, tier: tier)
                let rgba: [UInt8] = try StarlitCartoucheTest.still(session)
                let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                let what: String = "level \(number) first leg tier \(tier)"
                #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
                #expect(snapshot.legs.count == 1, "\(what): one trail")
                #expect(shell.presenter.lastGlide == 1, "\(what): the ship rests at its star")
                let report: StarlitCartoucheCheckReport = StarlitCartoucheTest.checkFrame(rgba, snapshot: snapshot,
                                                                                          what)
                measured.append(report.trailsChecked)
                trails[tier] += report.trailsChecked
                references.append(StarlitCartoucheTest.referencePixels(snapshot))
            }
            #expect(references[0] == references[1] && references[1] == references[2],
                    "level \(number): tier coordinates")
            #expect(measured[0] == measured[1] && measured[1] == measured[2], "level \(number): trails \(measured)")
            session.qualityPin = 0
        }
        print("starlit-cartouche first legs: trails measured per tier \(trails)")
        for tier in 0..<3 {
            #expect(trails[tier] > 0, "tier \(tier): no trail point clear of the later elements on the five levels")
        }
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two dark corners match the drawn still at every
    /// tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<StarlitCartouchePresenter> = StarlitCartoucheExperience.make(
            id: StarlitCartoucheTest.id)
        let opening: StarlitCartoucheExperienceCore = try StarlitCartoucheExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 40)
        for tier in 0..<3 {
            StarlitCartoucheTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try StarlitCartoucheTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = StarlitCartoucheTest.bottomUp(still, width: StarlitCartoucheTest.width,
                                                              height: StarlitCartoucheTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try StarlitCartoucheTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two dark corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: StarlitCartoucheTest.width,
                                              height: StarlitCartoucheTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A leg the chart fails draws the failed leg in the broken colour; nothing moves; the words name it; undo draws
    /// the frame before the failure again.
    @Test func aFailedLegIsDrawnBroken() async throws {
        let found = try #require(try StarlitCartoucheTest.failureCase(candidates: Self.failureLevels, maxDepth: 2),
                                 "a catalog level with a failing leg within two legs")
        print("starlit-cartouche failure: level \(found.number), set-up \(found.setUp), failing \(found.failing)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: UInt64(found.number - 1))
        // Level-2: nothing glows, so the failed leg's centre line is exactly the broken colour.
        StarlitCartoucheTest.pin(session, shell, tier: 2)
        #expect(StarlitCartoucheTest.issue(shell, found.setUp) == found.setUp.count)
        let digest: String = try StarlitCartoucheTest.digest(shell)
        try StarlitCartoucheTest.prime(session)
        let clean: [UInt8] = try StarlitCartoucheTest.still(session)
        let before: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let failing = StarlitCartoucheTest.control(found.failing)
        #expect(shell.handle(control: failing.control, values: failing.values) == .accepted)
        let core: StarlitCartoucheExperienceCore = try StarlitCartoucheTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)")
        let failure: StarlitCartoucheFailure = try #require(core.play.failure)
        #expect(core.outcome?.code == StarlitCartoucheExperienceCore.failedCode)
        // The words name what the kernel's reason names.
        let named: String = try #require(StarlitCartoucheMirror.failureText(failure))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // The frame: the drawn snapshot is the CPU reference's, the ship did not move, the failed leg is broken.
        try StarlitCartoucheTest.prime(session)
        let rgba: [UInt8] = try StarlitCartoucheTest.still(session)
        let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        let leg: StarlitCartoucheLeg = try #require(snapshot.failedLeg, "the snapshot carries the failed leg")
        #expect(leg.from == before.star, "the failed leg leaves the ship's star")
        #expect(snapshot.star == before.star && snapshot.beat == before.beat, "a failed leg moves no ship")
        #expect(snapshot.legs == before.legs && snapshot.positions == before.positions, "and no trail or star")
        let reference: StarlitCartoucheExperienceCore = try StarlitCartoucheTest.coreAfter(
            found.number, found.setUp + [found.failing])
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's")
        StarlitCartoucheTest.checkFrame(rgba, snapshot: snapshot, "failed leg")
        let hits: Int = StarlitCartoucheTest.brokenHits(rgba, found.samples)
        let cleanHits: Int = StarlitCartoucheTest.brokenHits(clean, found.samples)
        print("starlit-cartouche failed leg: \(hits) of \(found.samples.count) samples broken (before \(cleanHits))")
        #expect(hits * 2 > found.samples.count,
                "the failed leg is drawn in #FF6B4A (\(hits) of \(found.samples.count))")
        #expect(cleanHits < hits, "the broken colour comes with the failure")
        // Undo returns the failed play to the moment before the leg, without the broken leg.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try StarlitCartoucheTest.digest(shell) == digest)
        try StarlitCartoucheTest.prime(session)
        let undone: [UInt8] = try StarlitCartoucheTest.still(session)
        #expect(StarlitCartoucheTest.brokenHits(undone, found.samples) == cleanHits, "undo removes it")
        #expect(undone == clean, "undo draws the frame before the failure")
        session.qualityPin = 0
    }

    /// Flying the certified plan of level 1 through the shell wins; the won frame keeps every star at the kernel's
    /// position and the ship at rest at the beacon, the won flag is set, the reference pixels are the same at level-0
    /// and level-2, and the won frames pass the checks.
    @Test func aWonLevelIsDrawnWithoutMovingPositions() async throws {
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(1)
        #expect(!legs.isEmpty, "level 1 has a certified plan")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 0)
        #expect(StarlitCartoucheTest.issue(shell, Array(legs.dropLast())) == legs.count - 1)
        try StarlitCartoucheTest.prime(session)
        _ = try StarlitCartoucheTest.still(session, width: 96, height: 64)
        let arranged: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(StarlitCartoucheSceneGeometry.wonFlag(arranged) == 0)
        #expect(StarlitCartoucheTest.issue(shell, Array(legs.suffix(1))) == 1)
        let core: StarlitCartoucheExperienceCore = try StarlitCartoucheTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage)")
        #expect(core.outcome?.code == StarlitCartoucheExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.failureText == nil)
        let reference: StarlitCartoucheSceneSnapshot = try StarlitCartoucheTest.coreAfter(1, legs).snapshot(time: 0)
        try StarlitCartoucheTest.prime(session)
        var pixels: [[SIMD2<Double>?]] = []
        for tier in [0, 2] {
            StarlitCartoucheTest.pin(session, shell, tier: tier)
            let won: [UInt8] = try StarlitCartoucheTest.still(session)
            let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level 1 won, tier \(tier)"
            #expect(snapshot.stage == .won, "\(what)")
            #expect(StarlitCartoucheSceneGeometry.wonFlag(snapshot) == 1, "\(what): the won flag")
            #expect(snapshot == reference, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.positions == StarlitCartoucheTest.kernelPositions(core.play),
                    "\(what): the drawn stars are the kernel's positions")
            #expect(snapshot.legs.count == legs.count, "\(what): every leg leaves a trail")
            #expect(snapshot.star == snapshot.beacon, "\(what): the ship rests at the beacon")
            #expect(shell.presenter.lastGlide == 1, "\(what): the ship is at rest")
            let ship: SIMD3<Double> = StarlitCartoucheSceneGeometry.shipCentre(snapshot)
            #expect(ship == StarlitCartoucheSceneGeometry.starCentre(snapshot.beacon, snapshot), "\(what): ship")
            StarlitCartoucheTest.checkFrame(won, snapshot: snapshot, what)
            pixels.append(StarlitCartoucheTest.referencePixels(snapshot))
        }
        #expect(pixels.count == 2 && pixels[0] == pixels[1], "the tier moves no reference point of the won frame")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// Draws the opening of the level `seed` prepares at the three tiers and checks it against the CPU reference;
    /// returns the star centres measured and whether the ship was measured, per tier.
    private func checkOpening(seed: UInt64) async throws -> (stars: [Int], ships: [Int], actions: [Int]) {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: seed)
        let level: Int = StarlitCartoucheExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try StarlitCartoucheTest.core(shell).levelNumber == level)
        let expectedCore: StarlitCartoucheExperienceCore = try StarlitCartoucheExperienceCore.opening(number: level)
        let expected: StarlitCartoucheSceneSnapshot = expectedCore.snapshot(time: 0)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [StarlitCartoucheSceneSnapshot] = []
        var stars: [Int] = []
        var ships: [Int] = []
        var actions: [Int] = []
        for tier in 0..<3 {
            StarlitCartoucheTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try StarlitCartoucheTest.still(session)
            let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget, "\(what): nothing spent at the opening")
            #expect(snapshot.failure == nil && snapshot.failedLeg == nil)
            #expect(snapshot.legs.isEmpty, "\(what): no trail at the opening")
            #expect(snapshot.chosenStar == StarlitCartoucheSceneSnapshot.defaultChoice(expectedCore.play.level,
                                                                                      star: snapshot.star),
                    "\(what): the default destination is chosen")
            #expect(snapshot.chosenWait == 0)
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.positions == StarlitCartoucheTest.kernelPositions(expectedCore.play),
                    "\(what): the drawn stars are the kernel's positions")
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            #expect(shell.presenter.lastGlide == 1, "\(what): no glide before the first leg")
            #expect(shell.presenter.scene.lastFirmamentAngle == 0, "\(what): frame time 0")
            let report: StarlitCartoucheCheckReport = StarlitCartoucheTest.checkFrame(rgba, snapshot: snapshot, what)
            actions.append(report.actionsChecked ? 1 : 0)
            stars.append(report.starsChecked)
            ships.append(report.shipChecked ? 1 : 0)
            references.append(StarlitCartoucheTest.referencePixels(snapshot))
            snapshots.append(snapshot)
        }
        // The tier changes no coordinate and nothing measured.
        #expect(references[0] == references[1] && references[1] == references[2], "level \(level): tier coordinates")
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2], "level \(level): tier snapshots")
        #expect(stars[0] == stars[1] && stars[1] == stars[2], "level \(level): stars measured \(stars)")
        #expect(ships[0] == ships[1] && ships[1] == ships[2], "level \(level): ship measured \(ships)")
        session.qualityPin = 0
        return (stars, ships, actions)
    }
}
#endif
