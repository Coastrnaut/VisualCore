// HueCompassTierTests — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-003, 004, 006; SC-R02G0403-001, 002;
// clarification Q2). The three quality tiers change only needle facets, fog layers and glow shells, never coordinates:
// the wheel mesh is identical at every tier, every tier's needle reaches the same tip, every tier's fog prisms reach the
// same tops, the marks do not depend on the tier, and through the one app's session host every tier's off-screen still
// matches the same reference with the needle tip and the band samples at the same pixels; the presenter's tier log
// records the first frame and each change with its reason; drawing at every tier and several frame times leaves the
// state digest and the snapshot payload unchanged (renderer purity). Short runs only.
#if os(iOS)
import Foundation
import HueCompassCore
import Testing
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct HueCompassTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var facets: [Int] = []
        var layers: [Int] = []
        var shells: [Int] = []
        for tier in HueCompassTier.all {
            names.append(tier.name)
            facets.append(tier.facets)
            layers.append(tier.fogLayers)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(facets == [12, 8, 4])
        #expect(layers == [3, 2, 1])
        #expect(shells == [2, 1, 0])
        #expect(HueCompassExperienceCore.qualityTiers == 3)
    }

    /// The vertex of `mesh` farthest from the origin in the compass plane, and that distance.
    static func farthest(_ mesh: Mesh) -> (point: Vec3, radius: Double) {
        var best: (point: Vec3, radius: Double) = (Vec3(0, 0, 0), -1)
        for p in mesh.positions {
            let r: Double = (p.x * p.x + p.y * p.y).squareRoot()
            if r > best.radius { best = (p, r) }
        }
        return best
    }

    /// The highest z of the vertices of `mesh` within 0.5 bearings of bearing `b`'s direction.
    static func top(_ mesh: Mesh, bearing b: Int) -> Double {
        let d: SIMD3<Double> = HueCompassSceneGeometry.direction(b)
        var high: Double = -1
        for p in mesh.positions {
            let r: Double = (p.x * p.x + p.y * p.y).squareRoot()
            guard r > 1e-9 else { continue }
            let cosine: Double = (p.x * d.x + p.y * d.y) / r
            if cosine >= cos(2 * Double.pi * 0.5 / 96) { high = Swift.max(high, p.z) }
        }
        return high
    }

    @Test func everyTierSharesTheSameCoordinates() throws {
        for seed in HueCompassTest.seeds {
            let core = try HueCompassExperienceCore.opening(number: Int(seed) + 1)
            let snapshot: HueCompassSceneSnapshot = core.snapshot(time: 0)
            // The camera and the projection do not depend on the tier.
            let reference: [Vec2?] = HueCompassTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(seed + 1): \(missing) reference points without a projection")
            let tip: SIMD3<Double> = HueCompassSceneGeometry.needleTip(snapshot)
            let wheel0: Mesh = try HueCompassSceneGeometry.wheelMesh(snapshot, tier: HueCompassTier.of(0))
            let marks0: Mesh = try HueCompassSceneGeometry.markMesh(snapshot)
            let fog0: Mesh = try HueCompassSceneGeometry.fogMesh(snapshot, tier: HueCompassTier.of(0))
            for tier in HueCompassTier.all {
                let what: String = "level \(seed + 1) \(tier.name)"
                #expect(try HueCompassSceneGeometry.wheelMesh(snapshot, tier: tier) == wheel0, "\(what): wheel")
                #expect(try HueCompassSceneGeometry.markMesh(snapshot) == marks0, "\(what): marks")
                // The needle's farthest vertex is the same tip.
                let needle: Mesh = try HueCompassSceneGeometry.needleMesh(snapshot, tier: tier)
                let far = Self.farthest(needle)
                let dx: Double = far.point.x - tip.x
                let dy: Double = far.point.y - tip.y
                let dz: Double = far.point.z - tip.z
                #expect((dx * dx + dy * dy + dz * dz).squareRoot() < 1e-9, "\(what): needle tip")
                // The fog prisms reach the same tops at every tier.
                let fog: Mesh = try HueCompassSceneGeometry.fogMesh(snapshot, tier: tier)
                var differing: Int = 0
                for b in stride(from: 0, to: HueCompassWheel.bearings, by: 7) {
                    let want: Double = HueCompassSceneGeometry.fogTop(b, in: snapshot).z
                    if Swift.abs(Self.top(fog, bearing: b) - want) > 1e-9 { differing += 1 }
                    if Swift.abs(Self.top(fog0, bearing: b) - want) > 1e-9 { differing += 1 }
                }
                #expect(differing == 0, "\(what): \(differing) fog tops differ")
            }
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 60)
        _ = try HueCompassTest.probeTwice(shell)
        var snapshots: [HueCompassSceneSnapshot] = []
        var bandSets: [[Int]] = []
        for tier in 0..<3 {
            HueCompassTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try HueCompassTest.still(session)
            let snapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            HueCompassTest.checkFrame(rgba, snapshot: snapshot, "tier \(tier)")
            // The band segments found with their colour at their reference pixels at this tier.
            var found: [Int] = []
            let cam = HueCompassTest.camera(width: HueCompassTest.width, height: HueCompassTest.height)
            for k in HueCompassTest.checkableSegments(snapshot) {
                guard let c = HueCompassSceneGeometry.pixel(HueCompassSceneGeometry.bandSamplePoint(k), camera: cam,
                                                            width: HueCompassTest.width,
                                                            height: HueCompassTest.height) else { continue }
                let want: SIMD3<Double> = HueCompassSceneGeometry.bandSegmentColour(k, in: snapshot)
                let best = HueCompassTest.bestMatch(rgba, near: c.x, c.y, radius: HueCompassTest.centreSearch,
                                                    want: want, width: HueCompassTest.width,
                                                    height: HueCompassTest.height)
                if let best, best.distance <= HueCompassTest.bandTolerance { found.append(k) }
            }
            bandSets.append(found)
        }
        // The same snapshot feeds every tier, so the reference is the same; the same bands show at the same pixels.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(bandSets[0] == bandSets[1] && bandSets[1] == bandSets[2], "\(bandSets)")
        #expect(!bandSets[0].isEmpty)
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 20)
        let presenter: HueCompassPresenter = shell.presenter
        #expect(presenter.tierLog == [HueCompassTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            HueCompassTest.pin(session, shell, tier: tier)
            try HueCompassTest.draw(session, frames: 2)
            #expect(presenter.tierLog.last?.tier == tier)
        }
        var tiers: [Int] = []
        for change in presenter.tierLog {
            tiers.append(change.tier)
            #expect(!change.reason.isEmpty, "tier \(change.tier) has a reason")
        }
        #expect(tiers == [0, 1, 2, 0])
        // Drawing again at the same tier adds nothing.
        try HueCompassTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 40)
        _ = try HueCompassTest.probeTwice(shell)
        let before: String = try HueCompassTest.digest(shell)
        let payload: Data = try HueCompassTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            HueCompassTest.pin(session, shell, tier: tier)
            try HueCompassTest.draw(session, frames: 3)
            for time in times {
                _ = try HueCompassTest.still(session, width: 96, height: 64, time: time)
                #expect(try HueCompassTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try HueCompassTest.draw(session, frames: 2)
        #expect(try HueCompassTest.digest(shell) == before)
        #expect(try HueCompassTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
