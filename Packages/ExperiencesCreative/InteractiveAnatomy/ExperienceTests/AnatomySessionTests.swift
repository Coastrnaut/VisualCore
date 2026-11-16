// AnatomySessionTests — feature 125 (A17-P02) T-A17-205 (FR-A17-202, FR-A17-209, FR-A17-210; clarifications Q1,
// Q5; SC-A17-205). Interactive Anatomy inside the one app's session host on the simulator, short runs only (each test
// well under 10 s, no wall-clock assertion): the session opens running and draws a non-blank frame with one renderer
// per mesh; the core declares two tiers and the shell offers two levels, and a level change through the session's pin
// keeps the camera, layers and selection and draws with the other level's scene; a context recreation rebuilds the
// renderers together once and redraws the same pixels with the state kept; a resize keeps the state and, back at the
// first size, draws the same pixels; the saved state restores in a new session; closing releases the renderers.
// Feature 126 (A17-P03) T-A17-307 (FR-A17-307; SC-A17-305): the saved state (schema 2) carries the isolate and
// restores it with the same pixels; a schema-1 saved state migrates; a damaged one is refused and the opening view
// opens; an unknown selection is dropped with a reason and the rest of the view is kept.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// Interactive Anatomy inside the session host.
@MainActor
final class AnatomySessionTests: XCTestCase {
    /// The number of meshes of the knee: one renderer each.
    private let meshCount = 20

    func testTheSessionOpensRunningAndDrawsANonBlankFrame() async throws {
        XCTAssertEqual(InteractiveAnatomyExperience.id?.rawValue, "a17.interactive-anatomy")
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        let presenter = shell.presenter
        let frame = try AnatomyTest.picture(session)
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(AnatomyTest.nonBackdropPixels(frame), frame.width * frame.height / 50,
                             "the knee covers part of the canvas")
        XCTAssertEqual(presenter.rendererCount, meshCount, "one renderer per mesh, made together")
        XCTAssertEqual(presenter.resourceBuildCount, 1)
        let core = try AnatomyTest.core(shell)
        XCTAssertEqual(Set(presenter.lastDrawnMeshIDs), Set(core.scene.items.map(\.meshID)), "every mesh drawn")
        XCTAssertEqual(presenter.lastDrawnMeshIDs.count, meshCount)
        XCTAssertEqual(shell.accessibilitySummary, core.describe())
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(presenter.rendererCount, 0, "the renderers are released together in teardown")
        XCTAssertEqual(shell.state, .inactive)
    }

    func testTwoLevelsAndALevelChangeKeepsTheViewAndDrawsTheOtherScene() async throws {
        XCTAssertEqual(AnatomyCore.qualityTiers, 2)
        XCTAssertEqual(AnatomyCore.qualityProfile.count, 2)
        let session = ExperienceSession()
        session.qualityPin = 0
        let shell = try await AnatomyTest.open(session)
        XCTAssertEqual(shell.qualityProfile.count, 2, "the shell offers the host two levels")
        let presenter = shell.presenter
        AnatomyTest.accept(shell, "structure.select", [9])
        AnatomyTest.accept(shell, "layer.show", [1, 0])
        AnatomyTest.accept(shell, "camera.turn", [1])
        AnatomyTest.accept(shell, "camera.zoom", [-1])
        try AnatomyTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 0)
        let before = try AnatomyTest.core(shell)
        let digest = try shell.engine.digest()
        let drawn = presenter.lastDrawnMeshIDs
        let fullTriangles = before.scene.triangleCount

        session.qualityPin = 1
        XCTAssertEqual(shell.engine.qualityTier, 1)
        try AnatomyTest.frames(session, 1)
        let after = try AnatomyTest.core(shell)
        XCTAssertEqual(after.tier, 1)
        XCTAssertEqual(after.scene.quality.level, 1)
        XCTAssertEqual(presenter.lastTier, 1, "drawn with the reduced scene")
        XCTAssertLessThan(after.scene.triangleCount, fullTriangles)
        XCTAssertEqual(after.view.camera, before.view.camera, "the camera is kept")
        XCTAssertEqual(after.view.visibleLayers, before.view.visibleLayers, "the layers are kept")
        XCTAssertEqual(after.view.selection, before.view.selection, "the selection is kept")
        XCTAssertEqual(after.view, before.view)
        XCTAssertEqual(presenter.lastDrawnMeshIDs, drawn, "the same meshes are drawn")
        let afterDigest = try shell.engine.digest()
        XCTAssertEqual(afterDigest, digest, "the level is not state")
        let frame = try AnatomyTest.picture(session)
        XCTAssertGreaterThan(AnatomyTest.nonBackdropPixels(frame), 0, "the reduced level draws the knee")

        session.qualityPin = 0
        try AnatomyTest.frames(session, 1)
        XCTAssertEqual(presenter.lastTier, 0)
        XCTAssertEqual(try AnatomyTest.core(shell).view, before.view)
        session.close()
    }

    func testAContextRecreationRebuildsTheRenderersAndRedrawsTheSamePixels() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        AnatomyTest.accept(shell, "structure.select", [3])
        AnatomyTest.accept(shell, "layer.show", [2, 0])
        AnatomyTest.accept(shell, "camera.tilt", [1])
        let before = try AnatomyTest.picture(session)
        let view = try AnatomyTest.core(shell).view
        let digest = try shell.engine.digest()
        let builds = presenter.resourceBuildCount

        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        let after = try AnatomyTest.picture(session)
        XCTAssertEqual(presenter.resourceBuildCount, builds + 1, "one rebuild")
        XCTAssertEqual(presenter.rendererCount, meshCount, "the renderers are made together again")
        XCTAssertEqual(try AnatomyTest.core(shell).view, view, "the state is kept")
        let afterDigest = try shell.engine.digest()
        XCTAssertEqual(afterDigest, digest)
        XCTAssertEqual(after.width, before.width)
        XCTAssertEqual(after.height, before.height)
        XCTAssertEqual(AnatomyTest.differingPixels(before.rgba, after.rgba), 0, "the same frame is drawn")
        session.close()
    }

    func testAResizeKeepsTheStateAndTheFirstSizeDrawsTheSameFrameAgain() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        AnatomyTest.accept(shell, "structure.select", [11])
        AnatomyTest.accept(shell, "camera.turn", [-1])
        let first = try AnatomyTest.picture(session)
        let view = try AnatomyTest.core(shell).view
        let digest = try shell.engine.digest()
        XCTAssertEqual(presenter.lastAspect, Double(first.width) / Double(first.height), accuracy: 1e-3)

        try AnatomyTest.resize(session, to: CGSize(width: 160, height: 300))
        let tall = try AnatomyTest.picture(session)
        XCTAssertEqual(presenter.lastAspect, Double(tall.width) / Double(tall.height), accuracy: 1e-3)
        XCTAssertLessThan(presenter.lastAspect, 1, "the tall canvas")
        XCTAssertGreaterThan(AnatomyTest.nonBackdropPixels(tall), 0)
        XCTAssertEqual(try AnatomyTest.core(shell).view, view, "a resize keeps the state")
        let tallDigest = try shell.engine.digest()
        XCTAssertEqual(tallDigest, digest)
        XCTAssertEqual(presenter.rendererCount, meshCount)

        try AnatomyTest.resize(session, to: CGSize(width: 240, height: 160))
        let back = try AnatomyTest.picture(session)
        XCTAssertEqual(back.width, first.width)
        XCTAssertEqual(back.height, first.height)
        XCTAssertEqual(AnatomyTest.differingPixels(first.rgba, back.rgba), 0, "the first size draws the same frame")
        session.close()
    }

    func testTheSavedStateRestoresInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await AnatomyTest.open(first)
        AnatomyTest.accept(shell, "structure.select", [12])
        AnatomyTest.accept(shell, "layer.show", [0, 0])
        AnatomyTest.accept(shell, "camera.zoom", [1])
        AnatomyTest.accept(shell, "isolate.layer", [2])
        let snapshot = try shell.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, AnatomyViewState.schemaVersion)
        XCTAssertEqual(try AnatomyTest.core(shell).view.isolate, AnatomyIsolate(target: .layer(.ligaments)))
        let saved = try AnatomyTest.core(shell)
        let picture = try AnatomyTest.picture(first)
        first.close()

        let second = ExperienceSession()
        let restored = try await AnatomyTest.open(second, snapshot: snapshot)
        XCTAssertNil(second.lastRestoreRefusal)
        XCTAssertEqual(try AnatomyTest.core(restored).view, saved.view)
        let again = try AnatomyTest.picture(second)
        XCTAssertEqual(AnatomyTest.differingPixels(picture.rgba, again.rgba), 0, "the restored view draws alike")
        XCTAssertEqual(restored.accessibilitySummary, saved.describe())
        second.close()
    }

    func testADamagedSavedStateIsRefusedAndTheOpeningViewOpens() async throws {
        let first = ExperienceSession()
        let shell = try await AnatomyTest.open(first)
        AnatomyTest.accept(shell, "structure.select", [1])
        let saved = try shell.snapshot()
        first.close()
        let camera: [String: Any] = ["turn": 2, "tilt": 9, "zoom": 0]
        let damaged = try anatomyEnvelope(anatomyPayload(saved.payload, key: "camera", value: camera), like: saved)
        let second = ExperienceSession()
        let opened = try await AnatomyTest.open(second, snapshot: damaged)
        XCTAssertNotNil(second.lastRestoreRefusal, "a camera out of range is refused")
        XCTAssertEqual(try AnatomyTest.core(opened).view, AnatomyViewState.opening)
        second.close()
    }

    /// T-A17-307: a session snapshot whose payload was edited (an unknown selection id) no longer matches its recorded
    /// digest, so the host refuses it as a whole and the experience opens at the opening view. Dropping unknown ids
    /// with a reason applies to the view file and to the core's own restore (AnatomyViewFileTests, AnatomyCoreTests).
    func testAnEditedSnapshotIsRefusedByTheHostAndOpensTheOpeningView() async throws {
        let first = ExperienceSession()
        let shell = try await AnatomyTest.open(first)
        AnatomyTest.accept(shell, "structure.select", [1])
        AnatomyTest.accept(shell, "camera.turn", [1])
        let saved = try shell.snapshot()
        first.close()
        let edited = try anatomyEnvelope(anatomyPayload(saved.payload, key: "selection", value: "knee.bogus"),
                                         like: saved)
        let second = ExperienceSession()
        let opened = try await AnatomyTest.open(second, snapshot: edited)
        XCTAssertNotNil(second.lastRestoreRefusal, "the host's digest check refuses the edited snapshot")
        let core = try AnatomyTest.core(opened)
        XCTAssertEqual(core.view, AnatomyViewState.opening, "the experience opens at the opening view")
        second.close()
    }

    /// T-A17-307: a schema-1 (A17-P02) saved state opens migrated, with no isolate, and draws like the same view
    /// saved at schema 2.
    func testASchemaOneSavedStateOpensMigrated() async throws {
        let first = ExperienceSession()
        let shell = try await AnatomyTest.open(first)
        AnatomyTest.accept(shell, "structure.select", [4])
        AnatomyTest.accept(shell, "layer.show", [2, 0])
        AnatomyTest.accept(shell, "camera.tilt", [-1])
        let saved = try shell.snapshot()
        let view = try AnatomyTest.core(shell).view
        let picture = try AnatomyTest.picture(first)
        first.close()
        let old = try anatomyEnvelope(anatomySchema1Payload(view), like: saved, schema: 1)
        let second = ExperienceSession()
        let opened = try await AnatomyTest.open(second, snapshot: old)
        XCTAssertNil(second.lastRestoreRefusal)
        let core = try AnatomyTest.core(opened)
        XCTAssertEqual(core.view, view)
        XCTAssertNil(core.view.isolate)
        let again = try AnatomyTest.picture(second)
        XCTAssertEqual(AnatomyTest.differingPixels(picture.rgba, again.rgba), 0)
        second.close()
    }
}
