// WaveKnotKeeperTierTests — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-003, 004, 006; SC-R02G0303-001;
// clarification Q2). The three quality tiers change only tube sides, corner samples and glow shells, never coordinates:
// the CPU projection puts every control point, segment midpoint and gate centre at the same pixel at level-0, level-1
// and level-2, every tier's tube runs through the same straight segment middles (the ends of every rounded corner), and
// through the one app's session host every tier's off-screen still matches the same reference with the handles at the
// same pixels; the presenter's tier log records the first frame and each change with its reason; drawing at every tier
// and several frame times leaves the state digest and the snapshot payload unchanged (renderer purity,
// R2-G03-INV-10). Short runs only.
#if os(iOS)
import Foundation
import Testing
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct WaveKnotKeeperTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var sides: [Int] = []
        var corners: [Int] = []
        var shells: [Int] = []
        for tier in WaveKnotKeeperTier.all {
            names.append(tier.name)
            sides.append(tier.sides)
            corners.append(tier.cornerSamples)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(sides == [16, 10, 6])
        #expect(corners == [8, 4, 2])
        #expect(shells == [2, 1, 0])
        #expect(WaveKnotKeeperExperienceCore.qualityTiers == 3)
    }

    /// The centres of the rings of a rope mesh drawn with `sides` vertices per ring (the mean of each ring).
    static func ringCentres(_ mesh: Mesh, sides: Int) -> [SIMD3<Double>] {
        var centres: [SIMD3<Double>] = []
        var start: Int = 0
        while start + sides <= mesh.positions.count {
            var sum: SIMD3<Double> = .zero
            for k in 0..<sides {
                let p: Vec3 = mesh.positions[start + k]
                sum += SIMD3<Double>(p.x, p.y, p.z)
            }
            centres.append(sum / Double(sides))
            start += sides
        }
        return centres
    }

    @Test func everyTierSharesTheSameCoordinates() throws {
        let w: Int = WaveKnotKeeperTest.width
        let h: Int = WaveKnotKeeperTest.height
        for seed in WaveKnotKeeperTest.seeds {
            let core = try WaveKnotKeeperExperienceCore.opening(number: Int(seed) + 1)
            let snapshot: WaveKnotKeeperSceneSnapshot = core.snapshot(time: 0)
            // The camera and the projection do not depend on the tier.
            let reference: [Vec2?] = WaveKnotKeeperTest.referencePixels(snapshot, width: w, height: h)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(seed + 1): \(missing) reference points without a projection")
            // Every tier's tube passes through the ends of every rounded corner, A_i and B_i, a quarter of the way along
            // the two adjacent segments: the straight middles are the same at every tier.
            let world: [SIMD3<Double>] = WaveKnotKeeperSceneGeometry.worldPoints(snapshot)
            let n: Int = world.count
            var ends: [SIMD3<Double>] = []
            for i in 0..<n {
                let previous: SIMD3<Double> = world[(i + n - 1) % n]
                let next: SIMD3<Double> = world[(i + 1) % n]
                ends.append(world[i] + (previous - world[i]) * 0.25)
                ends.append(world[i] + (next - world[i]) * 0.25)
            }
            for tier in WaveKnotKeeperTier.all {
                let mesh: Mesh = try WaveKnotKeeperSceneGeometry.ropeMesh(snapshot, tier: tier)
                let centres: [SIMD3<Double>] = Self.ringCentres(mesh, sides: tier.sides)
                #expect(!centres.isEmpty, "level \(seed + 1) \(tier.name): rope rings")
                var unmatched: Int = 0
                for end in ends {
                    var found: Bool = false
                    for c in centres {
                        let d: SIMD3<Double> = c - end
                        if (d * d).sum().squareRoot() < 1e-6 {
                            found = true
                            break
                        }
                    }
                    if !found { unmatched += 1 }
                }
                #expect(unmatched == 0, "level \(seed + 1) \(tier.name): \(unmatched) corner ends off the tube axis")
            }
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 60)
        var snapshots: [WaveKnotKeeperSceneSnapshot] = []
        var handleSets: [[Int]] = []
        for tier in 0..<3 {
            WaveKnotKeeperTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try WaveKnotKeeperTest.still(session)
            let snapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            WaveKnotKeeperTest.checkFrame(rgba, snapshot: snapshot, "tier \(tier)")
            // The handles found at their reference pixels at this tier.
            var found: [Int] = []
            let cam = WaveKnotKeeperTest.camera(snapshot, width: WaveKnotKeeperTest.width,
                                                height: WaveKnotKeeperTest.height)
            let world: [SIMD3<Double>] = WaveKnotKeeperSceneGeometry.worldPoints(snapshot)
            for index in WaveKnotKeeperTest.checkableHandles(snapshot) {
                guard let c = WaveKnotKeeperSceneGeometry.pixel(world[index], camera: cam,
                                                                width: WaveKnotKeeperTest.width,
                                                                height: WaveKnotKeeperTest.height) else { continue }
                let best = WaveKnotKeeperTest.bestMatch(rgba, near: c.x, c.y, radius: WaveKnotKeeperTest.centreSearch,
                                                        want: WaveKnotKeeperTest.handleColour(snapshot, index: index),
                                                        width: WaveKnotKeeperTest.width,
                                                        height: WaveKnotKeeperTest.height)
                if let best, best.distance <= WaveKnotKeeperTest.handleTolerance { found.append(index) }
            }
            handleSets.append(found)
        }
        // The same snapshot feeds every tier, so the reference is the same; the same handles show at the same pixels.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(handleSets[0] == handleSets[1] && handleSets[1] == handleSets[2], "\(handleSets)")
        #expect(!handleSets[0].isEmpty)
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 20)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        #expect(presenter.tierLog == [WaveKnotKeeperTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            WaveKnotKeeperTest.pin(session, shell, tier: tier)
            try WaveKnotKeeperTest.draw(session, frames: 2)
            #expect(presenter.tierLog.last?.tier == tier)
        }
        var tiers: [Int] = []
        for change in presenter.tierLog {
            tiers.append(change.tier)
            #expect(!change.reason.isEmpty, "tier \(change.tier) has a reason")
        }
        #expect(tiers == [0, 1, 2, 0])
        // Drawing again at the same tier adds nothing.
        try WaveKnotKeeperTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 40)
        let before: String = try WaveKnotKeeperTest.digest(shell)
        let payload: Data = try WaveKnotKeeperTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            WaveKnotKeeperTest.pin(session, shell, tier: tier)
            try WaveKnotKeeperTest.draw(session, frames: 3)
            for time in times {
                _ = try WaveKnotKeeperTest.still(session, width: 96, height: 64, time: time)
                #expect(try WaveKnotKeeperTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try WaveKnotKeeperTest.draw(session, frames: 2)
        #expect(try WaveKnotKeeperTest.digest(shell) == before)
        #expect(try WaveKnotKeeperTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
