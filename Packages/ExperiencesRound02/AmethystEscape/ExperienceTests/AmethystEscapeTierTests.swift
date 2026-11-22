// AmethystEscapeTierTests — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-002, 004, 006; SC-R02G0703-001, 002;
// clarification Q2). The three quality tiers change only the bevel segments, the highlight layers and the glow shells,
// never positions: the camera does not depend on the tier, the pearl, exit and wedge reference points are the same at
// every tier, the pearl core sphere is the last part of the glow mesh at every tier; through the one app's session host
// every tier's off-screen still passes the same reference at the same pixels; the presenter's tier log records the
// first frame and each change with its reason; the presenter's quality levels are the Core's three tiers; drawing at
// every tier and several frame times leaves the state digest and the snapshot payload unchanged (renderer purity). Short
// runs only.
#if os(iOS)
import AmethystEscapeCore
import Foundation
import Testing
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct AmethystEscapeTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var bevels: [Int] = []
        var layers: [Int] = []
        var shells: [Int] = []
        for tier in AmethystEscapeTier.all {
            names.append(tier.name)
            bevels.append(tier.bevelSegments)
            layers.append(tier.highlightLayers)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(bevels == [3, 2, 1])
        #expect(layers == [3, 2, 1])
        #expect(shells == [2, 1, 0])
        #expect(AmethystEscapeExperienceCore.qualityTiers == 3)
    }

    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<AmethystEscapePresenter> = AmethystEscapeExperience.make(id: AmethystEscapeTest.id)
        #expect(shell.qualityProfile.count == AmethystEscapeExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in AmethystEscapeTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in AmethystEscapeExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 21, 41]
        for number in numbers {
            let core: AmethystEscapeExperienceCore = try AmethystEscapeTest.advanced(number)
            let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: 0)
            // The camera and the projection do not depend on the tier; every reference point projects.
            let reference: [Vec2?] = AmethystEscapeTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            let coreSphere: Mesh = try AmethystEscapeSceneGeometry.glowMesh(snapshot, tier: AmethystEscapeTier.of(2))
            for tier in AmethystEscapeTier.all {
                let what: String = "level \(number) \(tier.name)"
                let crystal: Mesh = try AmethystEscapeSceneGeometry.crystalMesh(snapshot, tier: tier)
                #expect(!crystal.indices.isEmpty, "\(what): crystal drawn")
                // The pearl core (the level-2 glow mesh, no shells) ends every tier's glow mesh at the same place.
                let glow: Mesh = try AmethystEscapeSceneGeometry.glowMesh(snapshot, tier: tier)
                #expect(glow.positions.count >= coreSphere.positions.count, "\(what): glow holds the pearl core")
                let tail: [Vec3] = Array(glow.positions.suffix(coreSphere.positions.count))
                #expect(tail == coreSphere.positions, "\(what): the pearl core sits at the same place")
                // The richer tiers add glow shells in front of the core.
                if tier.glowShells > 0 {
                    #expect(glow.positions.count > coreSphere.positions.count, "\(what): glow shells drawn")
                }
            }
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 40)
        AmethystEscapeTest.advance(shell)
        var snapshots: [AmethystEscapeSceneSnapshot] = []
        var pixels: [[Vec2?]] = []
        var pearlsLit: [Bool] = []
        for tier in 0..<3 {
            AmethystEscapeTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try AmethystEscapeTest.still(session)
            let snapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            AmethystEscapeTest.checkFrame(rgba, snapshot: snapshot, "level 41 tier \(tier)")
            pixels.append(AmethystEscapeTest.referencePixels(snapshot))
            pearlsLit.append(AmethystEscapeTest.pearlMisses(rgba, snapshot: snapshot).isEmpty)
        }
        // The same snapshot feeds every tier, so the reference is the same; the pearl shows at the same pixel.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(pearlsLit == [true, true, true])
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 20)
        let presenter: AmethystEscapePresenter = shell.presenter
        #expect(presenter.tierLog == [AmethystEscapeTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            AmethystEscapeTest.pin(session, shell, tier: tier)
            try AmethystEscapeTest.draw(session, frames: 2)
            #expect(presenter.tierLog.last?.tier == tier)
        }
        var tiers: [Int] = []
        for change in presenter.tierLog {
            tiers.append(change.tier)
            #expect(!change.reason.isEmpty, "tier \(change.tier) has a reason")
        }
        #expect(tiers == [0, 1, 2, 0])
        for change in presenter.tierLog.dropFirst() {
            #expect(change.reason == "quality controller changed the tier")
        }
        // Drawing again at the same tier adds nothing.
        try AmethystEscapeTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0)
        AmethystEscapeTest.advance(shell)
        let before: String = try AmethystEscapeTest.digest(shell)
        let payload: Data = try AmethystEscapeTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            AmethystEscapeTest.pin(session, shell, tier: tier)
            try AmethystEscapeTest.draw(session, frames: 3)
            for time in times {
                _ = try AmethystEscapeTest.still(session, width: 96, height: 64, time: time)
                #expect(try AmethystEscapeTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try AmethystEscapeTest.draw(session, frames: 2)
        #expect(try AmethystEscapeTest.digest(shell) == before)
        #expect(try AmethystEscapeTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
