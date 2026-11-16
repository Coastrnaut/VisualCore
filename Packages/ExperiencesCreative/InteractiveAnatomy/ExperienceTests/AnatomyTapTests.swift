// AnatomyTapTests — feature 125 (A17-P02) T-A17-205 (FR-A17-204, FR-A17-205, FR-A17-207, FR-A17-208; clarification
// Q4; SC-A17-202, SC-A17-203). Picking through the one app's session host on the simulator, short runs only (each
// test well under 10 s, no wall-clock assertion): for each of the 14 parts a tap at the projected centre of its sphere
// selects exactly what `AnatomyPicker` returns for that line of sight (or clears when it returns nil), and never a part
// on a hidden layer, with every layer shown and with each layer hidden in turn; a tap far outside the model clears;
// choosing a part from the list gives the same state as the tap that picked it; selecting a hidden part from the list
// is refused with `a17.hidden-structure`; hiding the selected part's layer clears the selection; after selecting each
// part its sphere centre projects inside the view, at the aspects 1.5, 0.5 and 2.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Picking parts of the knee through the session host.
@MainActor
final class AnatomyTapTests: XCTestCase {
    /// Clears the selection and the frame, so the camera is the opening one, and draws a frame.
    private func backToOpening(_ session: ExperienceSession, _ shell: ExperienceShell<AnatomyPresenter>) throws {
        _ = shell.presenter.send("structure.clear", through: shell.port)
        _ = shell.presenter.send("view.reset", through: shell.port)
        try AnatomyTest.frames(session, 1)
        let core = try AnatomyTest.core(shell)
        XCTAssertNil(core.view.selection)
        XCTAssertNil(core.view.framed)
    }

    /// Taps the projected centre of each part from the opening camera and checks the selection against the picker,
    /// with `hiddenLayer` hidden (or every layer shown). Returns the parts a tap on their own centre selected.
    @discardableResult
    private func assertTapsPickWhatThePickerReturns(hiddenLayer: AnatomyLayer?) async throws -> Set<Int> {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        if let hiddenLayer, let index = AnatomyLayer.allCases.firstIndex(of: hiddenLayer) {
            AnatomyTest.accept(shell, "layer.show", [Double(index), 0])
        }
        let name = hiddenLayer.map { "\($0) hidden" } ?? "all shown"
        var selfPicked = Set<Int>()
        for index in 0..<14 {
            try backToOpening(session, shell)
            let scene = try AnatomyTest.core(shell).scene
            let center = scene.structureSphere(index).center
            let ndc = try AnatomyTest.projectedNDC(of: center, presenter: presenter)
            let expected = try AnatomyTest.expectedPick(shell, at: ndc)
            _ = presenter.tap(atNDC: ndc, through: shell.port)
            let core = try AnatomyTest.core(shell)
            XCTAssertEqual(core.selectedIndex, expected, "\(name): tap at part \(index)'s centre")
            if let selected = core.selectedIndex {
                let layer = try XCTUnwrap(core.scene.parts[selected].layer)
                XCTAssertTrue(core.visibleLayers.contains(layer), "\(name): part \(selected) is on a shown layer")
                XCTAssertNotEqual(layer, hiddenLayer, "\(name): never a hidden part")
                if selected == index { selfPicked.insert(index) }
            }
        }
        session.close()
        return selfPicked
    }

    func testATapAtEachPartsCentreSelectsWhatThePickerReturns() async throws {
        let picked = try await assertTapsPickWhatThePickerReturns(hiddenLayer: nil)
        XCTAssertFalse(picked.isEmpty, "some parts are picked at their own centre")
    }

    func testWithEachLayerHiddenATapNeverSelectsAHiddenPart() async throws {
        for layer in AnatomyLayer.allCases {
            try await assertTapsPickWhatThePickerReturns(hiddenLayer: layer)
        }
    }

    func testATapFarOutsideTheModelClears() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        AnatomyTest.accept(shell, "structure.select", [0])
        AnatomyTest.accept(shell, "view.reset")
        try AnatomyTest.frames(session, 1)
        let corner = Vec2(0.98, 0.98)
        let expected = try AnatomyTest.expectedPick(shell, at: corner)
        XCTAssertNil(expected, "nothing lies under the corner")
        _ = presenter.tap(atNDC: corner, through: shell.port)
        XCTAssertNil(try AnatomyTest.core(shell).selectedIndex, "a tap on empty canvas clears the selection")
        XCTAssertNil(try AnatomyTest.core(shell).view.selection)
        session.close()
    }

    func testChoosingFromTheListEqualsTheTapThatPickedThePart() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        var compared = 0
        for index in 0..<14 {
            try backToOpening(session, shell)
            let center = try AnatomyTest.core(shell).scene.structureSphere(index).center
            let ndc = try AnatomyTest.projectedNDC(of: center, presenter: presenter)
            guard try AnatomyTest.expectedPick(shell, at: ndc) == index else { continue }
            _ = presenter.tap(atNDC: ndc, through: shell.port)
            let tapped = try AnatomyTest.core(shell).view
            let tappedDigest = try shell.engine.digest()
            try backToOpening(session, shell)
            AnatomyTest.accept(shell, "structure.select", [Double(index)])
            let listed = try AnatomyTest.core(shell).view
            let listedDigest = try shell.engine.digest()
            XCTAssertEqual(listed, tapped, "part \(index): the list equals the tap")
            XCTAssertEqual(listedDigest, tappedDigest, "part \(index)")
            compared += 1
        }
        XCTAssertGreaterThan(compared, 0, "at least one part was compared")
        session.close()
    }

    func testAHiddenPartIsRefusedAndHidingTheSelectedLayerClearsIt() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        AnatomyTest.accept(shell, "structure.select", [0])
        XCTAssertEqual(try AnatomyTest.core(shell).selectedIndex, 0)
        AnatomyTest.accept(shell, "layer.show", [0, 0])
        XCTAssertNil(try AnatomyTest.core(shell).selectedIndex, "hiding bones clears the femur")
        let refused = presenter.send("structure.select", [1], through: shell.port)
        XCTAssertEqual(refused.code, "action.rule.a17.hidden-structure")
        XCTAssertNil(try AnatomyTest.core(shell).selectedIndex, "a refused choice changes nothing")
        AnatomyTest.accept(shell, "structure.select", [9])
        AnatomyTest.accept(shell, "layer.show", [1, 0])
        XCTAssertEqual(try AnatomyTest.core(shell).selectedIndex, 9, "hiding cartilage keeps a ligament")
        AnatomyTest.accept(shell, "layer.show", [2, 0])
        XCTAssertNil(try AnatomyTest.core(shell).selectedIndex, "hiding ligaments clears the ligament")
        try AnatomyTest.frames(session, 1)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("selected: nothing selected."),
                      shell.accessibilitySummary)
        session.close()
    }

    func testAfterSelectingEachPartItsCentreIsInsideTheView() async throws {
        let sizes: [CGSize] = [CGSize(width: 240, height: 160), CGSize(width: 120, height: 240),
                               CGSize(width: 240, height: 120)]
        for size in sizes {
            let session = ExperienceSession()
            let shell = try await AnatomyTest.open(session, size: size)
            let presenter = shell.presenter
            for index in 0..<14 {
                AnatomyTest.accept(shell, "structure.select", [Double(index)])
                try AnatomyTest.frames(session, 1)
                let core = try AnatomyTest.core(shell)
                XCTAssertEqual(core.view.framed, core.scene.parts[index].id)
                XCTAssertTrue(core.view.camera.isValid, "the camera stays within its limits")
                let ndc = try AnatomyTest.projectedNDC(of: core.scene.structureSphere(index).center,
                                                       presenter: presenter)
                let where_ = "\(size.width)×\(size.height) part \(index) at \(ndc.x), \(ndc.y)"
                XCTAssertLessThanOrEqual(abs(ndc.x), 1, where_)
                XCTAssertLessThanOrEqual(abs(ndc.y), 1, where_)
            }
            session.close()
        }
    }

    /// T-A17-214 (spec edge case "a drag or a multi-touch gesture"): through the presenter's `pointer`, a single tap at
    /// the patella's projected centre selects what the picker returns there; a drag from the same point and a
    /// two-finger touch send nothing and leave the view state as it was.
    func testOnlyASingleTapPicksThroughThePointer() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        let viewSize = Vec2(240, 160)
        let center = try AnatomyTest.core(shell).scene.structureSphere(3).center
        let ndc = try AnatomyTest.projectedNDC(of: center, presenter: presenter)
        let point = Vec2((ndc.x + 1) / 2 * viewSize.x, (1 - ndc.y) / 2 * viewSize.y)
        let expected = try AnatomyTest.expectedPick(shell, at: ndc)
        XCTAssertNotNil(expected, "the patella's centre hits a part from the opening camera")
        func event(_ id: Int, _ phase: PointerPhase, _ at: Vec2, _ time: Double) -> PointerEvent {
            PointerEvent(id: id, phase: phase, location: at, timestamp: time)
        }

        let before = try AnatomyTest.core(shell).view
        let drag = [event(1, .began, point, 0), event(1, .moved, Vec2(point.x + 30, point.y), 0.05),
                    event(1, .moved, Vec2(point.x + 60, point.y + 10), 0.1),
                    event(1, .ended, Vec2(point.x + 60, point.y + 10), 0.15)]
        for item in drag { presenter.pointer(item, viewSize: viewSize, port: shell.port) }
        try AnatomyTest.frames(session, 1)
        let afterDrag = try AnatomyTest.core(shell).view
        XCTAssertEqual(afterDrag, before, "a drag sends nothing")

        let pair = [event(2, .began, point, 1), event(3, .began, Vec2(point.x + 4, point.y), 1.01),
                    event(2, .ended, point, 1.05), event(3, .ended, Vec2(point.x + 4, point.y), 1.06)]
        for item in pair { presenter.pointer(item, viewSize: viewSize, port: shell.port) }
        try AnatomyTest.frames(session, 1)
        let afterPair = try AnatomyTest.core(shell).view
        XCTAssertEqual(afterPair, before, "a two-finger touch sends nothing")

        let tap = [event(4, .began, point, 2), event(4, .ended, point, 2.05)]
        for item in tap { presenter.pointer(item, viewSize: viewSize, port: shell.port) }
        try AnatomyTest.frames(session, 1)
        let afterTap = try AnatomyTest.core(shell)
        XCTAssertEqual(afterTap.selectedIndex, expected, "a single tap selects what the picker returns")
    }
}
