// AnatomyRenderTests — feature 125 (A17-P02) T-A17-205 (FR-A17-202, FR-A17-203, FR-A17-206; clarifications Q3, Q5;
// SC-A17-205). The drawn knee inside the one app's session host on the simulator, short runs only (each test well
// under 10 s, no wall-clock assertion): each camera step (turn, tilt and zoom, both ways) changes the frame and Reset
// view restores the opening frame exactly; hiding each layer changes the frame, its meshes are no longer drawn and
// showing it again restores the frame; with every layer hidden no mesh is drawn, only the backdrop is left and the
// description says no layer is shown; a selection changes the frame (the amber material and the framing); drawing
// never changes the digest. Feature 126 (A17-P03) T-A17-307: without an isolate every drawn mesh is solid and no
// ghost is drawn.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

/// The drawn knee.
@MainActor
final class AnatomyRenderTests: XCTestCase {
    func testEachCameraStepChangesTheFrameAndResetRestoresTheOpeningFrame() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let opening = try AnatomyTest.picture(session)
        XCTAssertGreaterThan(AnatomyTest.nonBackdropPixels(opening), 0, "the frame is not blank")
        for control in ["camera.turn", "camera.tilt", "camera.zoom"] {
            for step in [1.0, -1.0] {
                AnatomyTest.accept(shell, control, [step])
                let stepped = try AnatomyTest.picture(session)
                XCTAssertGreaterThan(AnatomyTest.differingPixels(opening.rgba, stepped.rgba), 0,
                                     "\(control) \(step) changes the frame")
                XCTAssertGreaterThan(AnatomyTest.nonBackdropPixels(stepped), 0, "\(control) \(step): still in view")
                AnatomyTest.accept(shell, "view.reset")
                let reset = try AnatomyTest.picture(session)
                XCTAssertEqual(AnatomyTest.differingPixels(opening.rgba, reset.rgba), 0,
                               "Reset view after \(control) \(step) restores the opening frame")
            }
        }
        // Several steps at once, then Reset view.
        AnatomyTest.accept(shell, "camera.turn", [1])
        AnatomyTest.accept(shell, "camera.turn", [1])
        AnatomyTest.accept(shell, "camera.tilt", [-1])
        AnatomyTest.accept(shell, "camera.zoom", [1])
        let moved = try AnatomyTest.picture(session)
        XCTAssertGreaterThan(AnatomyTest.differingPixels(opening.rgba, moved.rgba), 0)
        AnatomyTest.accept(shell, "view.reset")
        XCTAssertEqual(try AnatomyTest.core(shell).view.camera, AnatomyCameraState.opening)
        let reset = try AnatomyTest.picture(session)
        XCTAssertEqual(AnatomyTest.differingPixels(opening.rgba, reset.rgba), 0)
        session.close()
    }

    func testHidingEachLayerChangesTheFrameAndStopsDrawingItsMeshes() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        let all = try AnatomyTest.picture(session)
        let scene = try AnatomyTest.core(shell).scene
        for (index, layer) in AnatomyLayer.allCases.enumerated() {
            let meshes = AnatomyTest.meshIDs(of: layer, in: scene)
            XCTAssertFalse(meshes.isEmpty, "\(layer) has meshes")
            XCTAssertTrue(meshes.isSubset(of: Set(presenter.lastDrawnMeshIDs)), "\(layer) is drawn while shown")
            AnatomyTest.accept(shell, "layer.show", [Double(index), 0])
            let hidden = try AnatomyTest.picture(session)
            XCTAssertGreaterThan(AnatomyTest.differingPixels(all.rgba, hidden.rgba), 0, "hiding \(layer) shows")
            let drawn = Set(presenter.lastDrawnMeshIDs)
            XCTAssertTrue(drawn.isDisjoint(with: meshes), "no mesh of the hidden \(layer) is drawn")
            let core = try AnatomyTest.core(shell)
            XCTAssertEqual(drawn, Set(core.scene.visibleItems(core.visibleLayers).map(\.meshID)))
            XCTAssertEqual(Set(presenter.lastSolidMeshIDs), drawn, "without an isolate every drawn mesh is solid")
            XCTAssertTrue(presenter.lastGhostMeshIDs.isEmpty, "without an isolate no ghost is drawn")
            XCTAssertFalse(core.describe().contains(anatomyLayerWords[layer] ?? "?"), core.describe())
            AnatomyTest.accept(shell, "layer.show", [Double(index), 1])
            let shown = try AnatomyTest.picture(session)
            XCTAssertEqual(AnatomyTest.differingPixels(all.rgba, shown.rgba), 0, "showing \(layer) again restores")
        }
        session.close()
    }

    func testWithEveryLayerHiddenNothingIsDrawn() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        for index in 0..<3 { AnatomyTest.accept(shell, "layer.show", [Double(index), 0]) }
        let empty = try AnatomyTest.picture(session)
        XCTAssertTrue(presenter.lastDrawnMeshIDs.isEmpty, "no mesh is drawn")
        XCTAssertEqual(AnatomyTest.nonBackdropPixels(empty), 0, "only the backdrop is left")
        let core = try AnatomyTest.core(shell)
        XCTAssertTrue(core.describe().contains("no layer shown"), core.describe())
        XCTAssertEqual(core.describe(), anatomyDescription(shown: [], selected: nil))
        XCTAssertEqual(shell.accessibilitySummary, core.describe())
        session.close()
    }

    func testASelectionChangesTheFrame() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let opening = try AnatomyTest.picture(session)
        AnatomyTest.accept(shell, "structure.select", [0])
        let selected = try AnatomyTest.picture(session)
        XCTAssertGreaterThan(AnatomyTest.differingPixels(opening.rgba, selected.rgba), 0)
        XCTAssertEqual(shell.accessibilitySummary,
                       anatomyDescription(shown: Set(AnatomyLayer.allCases), selected: "Femur"))
        session.close()
    }

    func testDrawingDoesNotChangeTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        AnatomyTest.accept(shell, "structure.select", [7])
        AnatomyTest.accept(shell, "camera.turn", [1])
        let digest = try shell.engine.digest()
        let view = try AnatomyTest.core(shell).view
        try AnatomyTest.frames(session, 30)
        let after = try shell.engine.digest()
        XCTAssertEqual(after, digest)
        XCTAssertEqual(try AnatomyTest.core(shell).view, view)
        session.close()
    }
}
