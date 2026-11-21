// ColorfallCanyonsTierTests — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-003, 004, 006; SC-R02G0503-001, 002;
// clarification Q2). The three quality tiers change only the block-top subdivision, the flow bands and the glow shells,
// never coordinates: the camera does not depend on the tier, the feature (emitters, target arcs) and fluid meshes are
// identical at every tier, every vertex of a coarser terrain is a vertex of the richest one and every tier's block tops
// lie at the cell tops; through the one app's session host every tier's off-screen still matches the same reference;
// the presenter's tier log records the first frame and each change with its reason; the presenter's quality levels are
// the Core's three tiers; drawing at every tier and several frame times leaves the state digest and the snapshot
// payload unchanged (renderer purity). Short runs only.
#if os(iOS)
import ColorfallCanyonsCore
import Foundation
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct ColorfallCanyonsTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var subdivisions: [Int] = []
        var bands: [Int] = []
        var shells: [Int] = []
        for tier in ColorfallCanyonsTier.all {
            names.append(tier.name)
            subdivisions.append(tier.subdivision)
            bands.append(tier.flowBands)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(subdivisions == [4, 2, 1])
        #expect(bands == [3, 2, 1])
        #expect(shells == [2, 1, 0])
        #expect(ColorfallCanyonsExperienceCore.qualityTiers == 3)
    }

    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<ColorfallCanyonsPresenter> =
            ColorfallCanyonsExperience.make(id: ColorfallCanyonsTest.id)
        #expect(shell.qualityProfile.count == ColorfallCanyonsExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in ColorfallCanyonsTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
    }

    /// A key of `p` exact to about 1e-9 world units, for comparing vertex sets built with different subdivisions.
    static func key(_ p: Vec3) -> [Int64] {
        [Int64((p.x * 1e9).rounded()), Int64((p.y * 1e9).rounded()), Int64((p.z * 1e9).rounded())]
    }

    @Test func everyTierSharesTheSameCoordinates() throws {
        let numbers: [Int] = [1, 21, 41]
        for number in numbers {
            let core: ColorfallCanyonsExperienceCore = try ColorfallCanyonsTest.flowing(number)
            let snapshot: ColorfallCanyonsSceneSnapshot = core.snapshot(time: 0)
            // The camera and the projection do not depend on the tier; every reference point projects.
            let reference: [Vec2?] = ColorfallCanyonsTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            let best: ColorfallCanyonsTier = ColorfallCanyonsTier.of(0)
            let feature0: Mesh = try ColorfallCanyonsSceneGeometry.featureMesh(snapshot, tier: best)
            let fluid0: Mesh = try ColorfallCanyonsSceneGeometry.fluidMesh(snapshot, tier: best)
            let terrain0: Mesh = try ColorfallCanyonsSceneGeometry.terrainMesh(snapshot, tier: best)
            var richest: Set<[Int64]> = []
            for p in terrain0.positions { richest.insert(Self.key(p)) }
            for tier in ColorfallCanyonsTier.all {
                let what: String = "level \(number) \(tier.name)"
                #expect(try ColorfallCanyonsSceneGeometry.featureMesh(snapshot, tier: tier) == feature0,
                        "\(what): emitters and arcs")
                #expect(try ColorfallCanyonsSceneGeometry.fluidMesh(snapshot, tier: tier) == fluid0, "\(what): fluid")
                // Every terrain vertex of this tier is a vertex of the richest tier.
                let terrain: Mesh = try ColorfallCanyonsSceneGeometry.terrainMesh(snapshot, tier: tier)
                var stray: Int = 0
                for p in terrain.positions where !richest.contains(Self.key(p)) { stray += 1 }
                #expect(stray == 0, "\(what): \(stray) terrain vertices not on the richest tier")
                // Every cell's top centre height is reached by vertices of this tier's terrain.
                var heights: Set<Int64> = []
                for p in terrain.positions { heights.insert(Int64((p.y * 1e9).rounded())) }
                var absent: Int = 0
                for cell in 0..<snapshot.cellCount {
                    let top: SIMD3<Double> = ColorfallCanyonsSceneGeometry.cellTop(cell, snapshot)
                    if !heights.contains(Int64((top.y * 1e9).rounded())) { absent += 1 }
                }
                #expect(absent == 0, "\(what): \(absent) cell tops without a block top")
            }
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 40)
        try ColorfallCanyonsTest.flow(shell)
        var snapshots: [ColorfallCanyonsSceneSnapshot] = []
        var passing: [[Int]] = []
        for tier in 0..<3 {
            ColorfallCanyonsTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try ColorfallCanyonsTest.still(session)
            let snapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            ColorfallCanyonsTest.checkFrame(rgba, snapshot: snapshot, "level 41 tier \(tier)")
            // The front-row dry cells found non-night at their reference pixels at this tier.
            var found: [Int] = []
            let cam = ColorfallCanyonsTest.camera(snapshot, width: ColorfallCanyonsTest.width,
                                                  height: ColorfallCanyonsTest.height)
            for cell in ColorfallCanyonsTest.strictCells(snapshot) {
                guard let p = ColorfallCanyonsSceneGeometry.pixel(ColorfallCanyonsSceneGeometry.cellTop(cell, snapshot),
                                                                  camera: cam, width: ColorfallCanyonsTest.width,
                                                                  height: ColorfallCanyonsTest.height) else { continue }
                let c: SIMD3<Double> = ColorfallCanyonsTest.pixelAt(rgba, p.x, p.y, width: ColorfallCanyonsTest.width,
                                                                   height: ColorfallCanyonsTest.height)
                let lit: Double = ColorfallCanyonsTest.luminance(c)
                let difference: Double = Swift.abs(lit - ColorfallCanyonsTest.nightLuminance)
                if difference >= ColorfallCanyonsTest.cellMargin { found.append(cell) }
            }
            passing.append(found)
        }
        // The same snapshot feeds every tier, so the reference is the same; the same cells show at the same pixels.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(passing[0] == passing[1] && passing[1] == passing[2], "\(passing)")
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 20)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        #expect(presenter.tierLog == [ColorfallCanyonsTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            ColorfallCanyonsTest.pin(session, shell, tier: tier)
            try ColorfallCanyonsTest.draw(session, frames: 2)
            #expect(presenter.tierLog.last?.tier == tier)
        }
        var tiers: [Int] = []
        for change in presenter.tierLog {
            tiers.append(change.tier)
            #expect(!change.reason.isEmpty, "tier \(change.tier) has a reason")
        }
        #expect(tiers == [0, 1, 2, 0])
        // Drawing again at the same tier adds nothing.
        try ColorfallCanyonsTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 0)
        try ColorfallCanyonsTest.flow(shell)
        let before: String = try ColorfallCanyonsTest.digest(shell)
        let payload: Data = try ColorfallCanyonsTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            ColorfallCanyonsTest.pin(session, shell, tier: tier)
            try ColorfallCanyonsTest.draw(session, frames: 3)
            for time in times {
                _ = try ColorfallCanyonsTest.still(session, width: 96, height: 64, time: time)
                #expect(try ColorfallCanyonsTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try ColorfallCanyonsTest.draw(session, frames: 2)
        #expect(try ColorfallCanyonsTest.digest(shell) == before)
        #expect(try ColorfallCanyonsTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
