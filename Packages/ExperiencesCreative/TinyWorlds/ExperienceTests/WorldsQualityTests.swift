// WorldsQualityTests — feature 093 (A12-P05) T-A12-504, T-A12-507 (FR-A12-501, FR-A12-502, FR-A12-505; SC-A12-501,
// SC-A12-502; clarifications Q1–Q3; research D1–D3). The detail tiers in the drawn experience: the declared three levels
// agree with the presenter's levels and the profile's names; the terrain's vertices and the draws of each tier match
// `DetailTier`; a memory warning draws the lightest tier on the next frame until 30 s of frame time after it (the clock
// is advanced through `applyPressure(hostTier:delta:)`, never by waiting); Low Power Mode draws the lightest tier from
// the first frame; repeated warnings rebuild the terrain at most once; the world's digest never changes; and the edge
// cases: a context recreation right after a tier change rebuilds once at the new tier, and a thumbnail saved at the
// lightest tier is 160 × 120. Every test is short; nothing is timed.
import TinyWorldsCore
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
import XCTest
@testable import TinyWorldsExperience

@MainActor
final class WorldsQualityTests: XCTestCase {
    /// The declared levels, the presenter's levels and the profile's names agree (three, `level-0`…`level-2`).
    func testTheDeclaredLevelsAgreeEverywhere() async throws {
        XCTAssertEqual(WorldsCore.qualityTiers, 3)
        XCTAssertEqual(WorldsCore.qualityTiers, DetailTier.tiers.count)
        XCTAssertEqual(WorldsCore.qualityTiers, TerrainDetail.levels.count)
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        XCTAssertEqual(shell.qualityProfile.names, ["level-0", "level-1", "level-2"])
        XCTAssertEqual(shell.qualityProfile.levels.count, WorldsCore.qualityTiers)
        session.close()
    }

    /// Each pack's terrain vertices and draws per host tier equal the tier table; lower tiers never raise them.
    func testTheDrawnCountsFollowTheTierTable() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        let presenter = shell.presenter
        for pack in 0..<3 {
            XCTAssertTrue(shell.handle(control: "world.pack", values: [Double(pack)]).isAccepted, "pack \(pack)")
            var previous: Int?
            for tier in 0..<3 {
                try shell.setQualityTier(tier)
                try WorldsTest.frames(session, 1)
                let core = try WorldsTest.core(shell)
                let row = try XCTUnwrap(DetailTier(index: tier, preset: core.preset))
                XCTAssertEqual(presenter.lastTier, tier)
                XCTAssertEqual(presenter.terrainVertices, row.terrainVertices, "pack \(pack), tier \(tier)")
                XCTAssertEqual(presenter.lastPartsDrawn + presenter.lastPropsDrawn, row.draws(props: core.props.count))
                if let previous { XCTAssertLessThan(row.terrainVertices, previous) }
                previous = row.terrainVertices
            }
        }
        session.close()
    }

    /// A memory warning draws the lightest tier on the next frame and holds it until 30 s of frame time after it; the
    /// digest stays.
    func testAMemoryWarningDrawsTheLowestTierUntilTheHoldEnds() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        let presenter = shell.presenter
        let digest = try shell.engine.digest()
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 0)
        try shell.shedCaches()
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 2, "the lightest tier within one frame")
        XCTAssertEqual(presenter.terrainLevel, 2)
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertEqual(presenter.applyPressure(hostTier: 0, delta: 29.5), 2, "still held before 30 s")
        XCTAssertEqual(presenter.applyPressure(hostTier: 0, delta: 0.5), 0, "released 30 s after the warning")
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 0)
        XCTAssertEqual(presenter.terrainLevel, 0, "full detail returns")
        XCTAssertEqual(try shell.engine.digest(), digest, "the world never changed")
        session.close()
    }

    /// The system's memory warning, posted to a running session, reaches the presenter through the host: the next
    /// frame draws the lightest tier and the world is unchanged (feature 093 T-A12-515).
    func testTheSystemMemoryWarningReachesThePresenterThroughTheSession() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        let presenter = shell.presenter
        let digest = try shell.engine.digest()
        XCTAssertEqual(presenter.lastTier, 0)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertEqual(session.state, .running, "the world is small enough to stay open")
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 2, "the lightest tier on the next frame")
        XCTAssertEqual(presenter.terrainLevel, 2)
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
    }

    /// Repeated warnings keep the lightest tier and rebuild the terrain renderer at most once.
    func testRepeatedWarningsRebuildTheTerrainAtMostOnce() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        let presenter = shell.presenter
        let builds = presenter.terrainBuildCount, allBuilds = presenter.rebuildCount
        for _ in 0..<5 {
            try shell.shedCaches()
            try WorldsTest.frames(session, 2)
            XCTAssertEqual(presenter.lastTier, 2)
        }
        XCTAssertEqual(presenter.terrainBuildCount, builds + 1, "one rebuild for the one tier change")
        XCTAssertEqual(presenter.rebuildCount, allBuilds, "the other renderers stay")
        session.close()
    }

    /// Low Power Mode draws the lightest tier from the first frame and full detail again once it ends.
    func testLowPowerModeDrawsTheLightestTierFromTheFirstFrame() async throws {
        let lowPower = LowPowerSwitch(on: true)
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, lowPowerMode: { lowPower.on })
        let presenter = shell.presenter
        XCTAssertEqual(presenter.lastTier, 2, "the first frame is drawn at the lightest tier")
        XCTAssertEqual(presenter.terrainLevel, 2)
        XCTAssertEqual(presenter.lastHostTier, 0)
        let digest = try shell.engine.digest()
        lowPower.on = false
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 0)
        XCTAssertEqual(presenter.terrainLevel, 0)
        try shell.setQualityTier(1)
        lowPower.on = true
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 2, "Low Power Mode wins over the host's tier")
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
    }

    /// A context recreation right after a tier change rebuilds the renderers once, at the new tier.
    func testAContextRecreationAfterATierChangeRebuildsOnceAtTheNewTier() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        let presenter = shell.presenter
        try shell.setQualityTier(1)
        let builds = presenter.rebuildCount
        session.recreateContext()
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.rebuildCount, builds + 1, "made again once on the new context")
        XCTAssertEqual(presenter.terrainLevel, 1, "at the new tier")
        try WorldsTest.frames(session, 2)
        XCTAssertEqual(presenter.rebuildCount, builds + 1)
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }

    /// A thumbnail saved at the lightest tier is 160 × 120 like every other.
    func testAThumbnailSavedAtTheLightestTierKeepsItsSize() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, store: WorldStore(storage: nil))
        try shell.shedCaches()
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(shell.presenter.lastTier, 2)
        XCTAssertEqual(shell.presenter.saveWorld(slot: 0, still: WorldsTest.stillRenderer(session)),
                       "Saved “Island, seed 1”.")
        let png = try XCTUnwrap(shell.presenter.store.thumbnail(slot: 0))
        XCTAssertLessThanOrEqual(png.count, WorldStore.maxThumbnailBytes)
        let image = try XCTUnwrap(UIImage(data: png)?.cgImage)
        XCTAssertEqual(image.width, DetailTier.thumbnailWidth)
        XCTAssertEqual(image.height, DetailTier.thumbnailHeight)
        session.close()
    }
}

/// A Low Power Mode answer the test can switch (read on the main actor by the presenter).
@MainActor
private final class LowPowerSwitch {
    var on: Bool
    init(on: Bool) { self.on = on }
}
