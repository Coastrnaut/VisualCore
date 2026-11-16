// AnatomyIsolateRenderTests — feature 126 (A17-P03) T-A17-307 (FR-A17-304, FR-A17-305; SC-A17-303, SC-A17-304;
// clarification Q3). Isolate and ghosts drawn inside the one app's session host on the simulator, short runs only
// (each test well under 10 s, no wall-clock assertion): for each layer and for a part, in the ghost and the hide
// mode, the presenter's solid and ghost mesh lists are the meshes of the core's solid and ghost parts and the drawn
// list is both; the selection stays solid when something else is isolated; the ghost mode draws a frame different
// from the hide mode and from no isolate; a tap at a ghost's projected centre never selects a ghost; a translucent
// draw that throws (`failNextTranslucentDraw`) turns the ghosts off, draws no ghost and the session keeps running;
// isolate.clear restores the A17-P02 frame exactly.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

/// Isolate and ghosts through the session host.
@MainActor
final class AnatomyIsolateRenderTests: XCTestCase {
    /// One isolate to draw: the action and its value, and a name for messages.
    private struct Target {
        let control: String
        let value: Double
        let name: String
    }

    /// Each layer and the femur.
    private let targets = [Target(control: "isolate.layer", value: 0, name: "bones"),
                           Target(control: "isolate.layer", value: 1, name: "cartilage"),
                           Target(control: "isolate.layer", value: 2, name: "ligaments"),
                           Target(control: "isolate.part", value: 0, name: "femur")]

    /// Checks that the last frame's solid, ghost and drawn mesh lists are those of the core's sets.
    private func assertDrawListsMatch(_ shell: ExperienceShell<AnatomyPresenter>, _ name: String,
                                      file: StaticString = #filePath, line: UInt = #line) throws {
        let presenter = shell.presenter
        let core = try AnatomyTest.core(shell)
        let solid = AnatomyTest.meshIDs(ofParts: core.solidIndices, in: core.scene)
        let ghost = AnatomyTest.meshIDs(ofParts: core.ghostIndices, in: core.scene)
        let drawnSolid = Set(presenter.lastSolidMeshIDs)
        let drawnGhost = Set(presenter.lastGhostMeshIDs)
        let drawn = Set(presenter.lastDrawnMeshIDs)
        XCTAssertEqual(drawnSolid, solid, "\(name): solid meshes", file: file, line: line)
        XCTAssertEqual(drawnGhost, ghost, "\(name): ghost meshes", file: file, line: line)
        XCTAssertEqual(drawn, solid.union(ghost), "\(name): the drawn list is solid and ghost", file: file, line: line)
        XCTAssertTrue(solid.isDisjoint(with: ghost), "\(name): no mesh is both", file: file, line: line)
    }

    func testEachIsolateInBothModesDrawsTheCoresSolidAndGhostSets() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let none = try AnatomyTest.picture(session)
        for target in targets {
            AnatomyTest.accept(shell, target.control, [target.value])
            AnatomyTest.accept(shell, "isolate.mode", [1])
            let ghostFrame = try AnatomyTest.picture(session)
            let ghostCore = try AnatomyTest.core(shell)
            XCTAssertEqual(ghostCore.view.isolate?.mode, .ghost, target.name)
            XCTAssertFalse(ghostCore.ghostIndices.isEmpty, "\(target.name): something is a ghost")
            try assertDrawListsMatch(shell, "\(target.name) ghost")

            AnatomyTest.accept(shell, "isolate.mode", [0])
            let hideFrame = try AnatomyTest.picture(session)
            let hideCore = try AnatomyTest.core(shell)
            XCTAssertEqual(hideCore.view.isolate?.mode, .hide, target.name)
            XCTAssertTrue(hideCore.ghostIndices.isEmpty, "\(target.name): the hide mode has no ghost")
            try assertDrawListsMatch(shell, "\(target.name) hide")
            XCTAssertTrue(shell.presenter.lastGhostMeshIDs.isEmpty, "\(target.name): only the solid set is drawn")

            XCTAssertGreaterThan(AnatomyTest.differingPixels(ghostFrame.rgba, hideFrame.rgba), 0,
                                 "\(target.name): ghosts change the frame")
            XCTAssertGreaterThan(AnatomyTest.differingPixels(ghostFrame.rgba, none.rgba), 0,
                                 "\(target.name): the ghost frame differs from no isolate")
            XCTAssertGreaterThan(AnatomyTest.differingPixels(hideFrame.rgba, none.rgba), 0,
                                 "\(target.name): the hide frame differs from no isolate")
            XCTAssertGreaterThan(AnatomyTest.nonBackdropPixels(hideFrame), 0, "\(target.name): the set is drawn")
            AnatomyTest.accept(shell, "isolate.clear")
        }
    }

    func testTheSelectionStaysSolidWhenSomethingElseIsIsolated() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let acl = 8
        AnatomyTest.accept(shell, "structure.select", [Double(acl)])
        let aclMeshes = AnatomyTest.meshIDs(ofParts: [acl], in: try AnatomyTest.core(shell).scene)
        XCTAssertFalse(aclMeshes.isEmpty)
        let others = [Target(control: "isolate.layer", value: 0, name: "bones"),
                      Target(control: "isolate.layer", value: 1, name: "cartilage"),
                      Target(control: "isolate.part", value: 3, name: "patella")]
        for target in others {
            AnatomyTest.accept(shell, target.control, [target.value])
            for mode in [1.0, 0.0] {
                AnatomyTest.accept(shell, "isolate.mode", [mode])
                try AnatomyTest.frames(session, 1)
                let core = try AnatomyTest.core(shell)
                let name = "\(target.name) mode \(mode)"
                XCTAssertEqual(core.selectedIndex, acl, name)
                XCTAssertTrue(core.solidIndices.contains(acl), "\(name): the selection is solid")
                XCTAssertFalse(core.ghostIndices.contains(acl), "\(name): the selection is never a ghost")
                XCTAssertTrue(aclMeshes.isSubset(of: Set(shell.presenter.lastSolidMeshIDs)), name)
                try assertDrawListsMatch(shell, name)
            }
            AnatomyTest.accept(shell, "isolate.clear")
        }
    }

    func testATapAtAGhostsCentreNeverSelectsAGhost() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        AnatomyTest.accept(shell, "isolate.layer", [0])
        try AnatomyTest.frames(session, 1)
        let ghosts = try AnatomyTest.core(shell).ghostIndices
        XCTAssertFalse(ghosts.isEmpty, "cartilage and ligaments are ghosts")
        for index in ghosts.sorted() {
            _ = presenter.send("structure.clear", through: shell.port)
            try AnatomyTest.frames(session, 1)
            let center = try AnatomyTest.core(shell).scene.structureSphere(index).center
            let ndc = try AnatomyTest.projectedNDC(of: center, presenter: presenter)
            _ = presenter.tap(atNDC: ndc, through: shell.port)
            let core = try AnatomyTest.core(shell)
            XCTAssertEqual(presenter.mirror.message, "", "tap at ghost \(index): no ghost was sent as a selection")
            if let selected = core.selectedIndex {
                XCTAssertFalse(core.ghostIndices.contains(selected), "tap at ghost \(index) selected ghost \(selected)")
                XCTAssertTrue(core.solidIndices.contains(selected), "tap at ghost \(index): \(selected) is solid")
            }
            XCTAssertNotNil(core.view.isolate, "a tap keeps the isolate")
        }
    }

    func testAThrowingTranslucentDrawTurnsTheGhostsOffAndTheSessionGoesOn() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        AnatomyTest.accept(shell, "isolate.layer", [0])
        try AnatomyTest.frames(session, 1)
        XCTAssertFalse(presenter.ghostsOff)
        XCTAssertFalse(presenter.lastGhostMeshIDs.isEmpty, "ghosts are drawn before the failure")

        presenter.failNextTranslucentDraw = true
        let host = try XCTUnwrap(session.renderHost)
        _ = host.renderOneFrame(present: false)
        XCTAssertFalse(presenter.failNextTranslucentDraw, "the seam clears itself")
        XCTAssertTrue(presenter.ghostsOff, "the ghosts are off")
        XCTAssertTrue(presenter.lastGhostMeshIDs.isEmpty, "no ghost is drawn")
        XCTAssertEqual(session.state, .running)
        let core = try AnatomyTest.core(shell)
        let solid = AnatomyTest.meshIDs(ofParts: core.solidIndices, in: core.scene)
        XCTAssertEqual(Set(presenter.lastSolidMeshIDs), solid, "the solid set is still drawn")

        let next = try AnatomyTest.picture(session)
        XCTAssertGreaterThan(AnatomyTest.nonBackdropPixels(next), 0, "the next frame draws")
        XCTAssertEqual(session.state, .running)
        AnatomyTest.accept(shell, "camera.turn", [1])
        try AnatomyTest.frames(session, 1)
        XCTAssertEqual(session.state, .running)
    }

    func testIsolateClearRestoresThePhaseTwoFrameExactly() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        AnatomyTest.accept(shell, "structure.select", [3])
        let before = try AnatomyTest.picture(session)
        let view = try AnatomyTest.core(shell).view
        for target in targets {
            for mode in [1.0, 0.0] {
                AnatomyTest.accept(shell, target.control, [target.value])
                AnatomyTest.accept(shell, "isolate.mode", [mode])
                let isolated = try AnatomyTest.picture(session)
                XCTAssertGreaterThan(AnatomyTest.differingPixels(before.rgba, isolated.rgba), 0,
                                     "\(target.name) mode \(mode) changes the frame")
                AnatomyTest.accept(shell, "isolate.clear")
                let cleared = try AnatomyTest.picture(session)
                XCTAssertEqual(AnatomyTest.differingPixels(before.rgba, cleared.rgba), 0,
                               "\(target.name) mode \(mode): Show all restores the frame")
                XCTAssertEqual(try AnatomyTest.core(shell).view, view, "\(target.name) mode \(mode)")
                XCTAssertTrue(shell.presenter.lastGhostMeshIDs.isEmpty)
            }
        }
    }
}
