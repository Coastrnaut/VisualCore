// AnatomyLabelTests — feature 127 (A17-P04) T-A17-406 (FR-A17-402; clarification Q2; SC-A17-402; edge cases "Many parts
// crowded in one corner", "Labels at the canvas edge", "The canvas is smaller than one label box"). The in-scene labels
// of Interactive Anatomy, short runs only (each test well under 10 s): over turn 0…23 step 4 × tilt −6…6 step 3 × zoom
// {−4, 0, 6} (90 cameras, each with a selection) on the canvases 240 × 160 and 160 × 320 points (aspects 1.5 and 0.5),
// no two placed labels overlap by a positive area, at most 16 are placed, every box lies inside the canvas, only solid
// parts are labelled, and the selection is placed first whenever its box fits the canvas; under an isolate ghosted and
// hidden parts get no label; a canvas smaller than one box places none; after a drawn frame the presenter's labels are
// this layout for the frame's camera and its mirror names them in English.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

/// The label layout of the knee.
@MainActor
final class AnatomyLabelTests: XCTestCase {
    /// The two canvases in points.
    private let canvases = [Vec2(240, 160), Vec2(160, 320)]

    /// Whether the box of `candidate` at its projected anchor would lie inside `canvas`.
    private func fits(_ candidate: AnchoredLabelLayout.Candidate, camera: OrbitCamera, aspect: Double,
                      canvas: Vec2) -> Bool {
        guard let point = AnchoredLabelLayout.canvasPoint(of: candidate.anchor, camera: camera, aspect: aspect,
                                                          canvas: canvas) else { return false }
        let minX = point.x + AnchoredLabelLayout.offset, maxY = point.y - AnchoredLabelLayout.offset
        return minX >= 0 && maxY - candidate.size.y >= 0 && minX + candidate.size.x <= canvas.x && maxY <= canvas.y
    }

    /// Checks the layout rules for `core` on `canvas`; returns whether the selection was placed.
    @discardableResult
    private func assertLayoutRules(_ core: AnatomyCore, canvas: Vec2, _ name: String) -> Bool {
        let aspect = canvas.x / canvas.y
        let camera = core.camera(aspect: aspect)
        let placed = AnatomyPresenter.labelPlacements(core, camera: camera, aspect: aspect, canvas: canvas)
        let solid = core.solidIndices
        XCTAssertLessThanOrEqual(placed.count, 16, name)
        XCTAssertLessThanOrEqual(placed.count, core.scene.quality.maxLabels, name)
        var overlaps = 0
        for i in placed.indices {
            let box = placed[i]
            if !solid.contains(box.id) { XCTFail("\(name): part \(box.id) is not solid") }
            if box.minX < 0 || box.minY < 0 || box.maxX > canvas.x || box.maxY > canvas.y {
                XCTFail("\(name): part \(box.id) leaves the canvas")
            }
            for j in placed.indices where j > i && AnchoredLabelLayout.overlaps(box, placed[j]) { overlaps += 1 }
        }
        XCTAssertEqual(overlaps, 0, "\(name): no two labels overlap")
        XCTAssertEqual(Set(placed.map(\.id)).count, placed.count, "\(name): one label per part")
        guard let selected = core.selectedIndex else { return false }
        let candidates = AnatomyLabels.candidates(scene: core.scene, solid: solid, selected: selected)
        guard let own = candidates.first(where: { $0.id == selected }) else { return false }
        if fits(own, camera: camera, aspect: aspect, canvas: canvas) {
            XCTAssertEqual(placed.first?.id, selected, "\(name): the selection is placed first")
            return true
        }
        XCTAssertFalse(placed.contains { $0.id == selected }, "\(name): a selection whose box does not fit")
        return false
    }

    func testOverAGridOfCamerasNoLabelsOverlapAndTheSelectionIsPlaced() async throws {
        let base = try await AnatomyCore.prepare(seed: 1)
        let ids = base.partIDs
        var cameras = 0, selectionsPlaced = 0, labelsPlaced = 0
        for canvas in canvases {
            for turn in stride(from: 0, through: 23, by: 4) {
                for tilt in stride(from: -6, through: 6, by: 3) {
                    for (z, zoom) in [-4, 0, 6].enumerated() {
                        var core = base
                        let part = (turn / 4 * 5 + (tilt + 6) / 3 + z) % ids.count
                        core.view.camera = AnatomyCameraState(turn: turn, tilt: tilt, zoom: zoom)
                        core.view.selection = ids[part]
                        core.view.framed = z == 1 ? ids[part] : nil
                        let name = "\(Int(canvas.x))×\(Int(canvas.y)) turn \(turn) tilt \(tilt) zoom \(zoom)"
                        if assertLayoutRules(core, canvas: canvas, name) { selectionsPlaced += 1 }
                        let aspect = canvas.x / canvas.y
                        labelsPlaced += AnatomyPresenter.labelPlacements(core, camera: core.camera(aspect: aspect),
                                                                         aspect: aspect, canvas: canvas).count
                        cameras += 1
                    }
                }
            }
        }
        XCTAssertEqual(cameras, 180, "90 cameras on two canvases")
        XCTAssertGreaterThan(selectionsPlaced, 0, "the selection is labelled on some cameras")
        XCTAssertGreaterThan(labelsPlaced, 0, "labels are placed")
    }

    func testGhostedAndHiddenPartsGetNoLabel() async throws {
        let base = try await AnatomyCore.prepare(seed: 1)
        let (selected, _) = anatomyApplied(base, "structure.select", [0])
        let (ghosted, ghostResult) = anatomyApplied(selected, "isolate.layer", [0])
        XCTAssertTrue(ghostResult.isAccepted)
        let (hidden, hideResult) = anatomyApplied(ghosted, "isolate.mode", [0])
        XCTAssertTrue(hideResult.isAccepted)
        let (layerHidden, layerResult) = anatomyApplied(base, "layer.show", [2, 0])
        XCTAssertTrue(layerResult.isAccepted)
        let cases: [(String, AnatomyCore)] = [("bones isolated, ghosts", ghosted), ("bones isolated, hidden", hidden),
                                              ("ligaments hidden", layerHidden)]
        for (name, core) in cases {
            XCTAssertLessThan(core.solidIndices.count, 14, "\(name): some parts are not solid")
            for canvas in canvases {
                let aspect = canvas.x / canvas.y
                let placed = AnatomyPresenter.labelPlacements(core, camera: core.camera(aspect: aspect),
                                                              aspect: aspect, canvas: canvas)
                let ids = Set(placed.map(\.id))
                XCTAssertTrue(ids.isSubset(of: core.solidIndices), "\(name): only solid parts")
                XCTAssertTrue(ids.isDisjoint(with: core.ghostIndices), "\(name): no ghost is labelled")
                assertLayoutRules(core, canvas: canvas, name)
            }
        }
    }

    func testACanvasSmallerThanOneBoxPlacesNoLabel() async throws {
        let core = try await AnatomyCore.prepare(seed: 1)
        let canvas = Vec2(20, 20)
        let placed = AnatomyPresenter.labelPlacements(core, camera: core.camera(aspect: 1), aspect: 1, canvas: canvas)
        XCTAssertTrue(placed.isEmpty, "\(placed)")
    }

    func testADrawnFrameLaysTheLabelsOutAndTheMirrorNamesThem() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        AnatomyTest.accept(shell, "structure.select", [3])
        try AnatomyTest.frames(session, 1)
        let presenter = shell.presenter
        let core = try AnatomyTest.core(shell)
        let camera = try XCTUnwrap(presenter.lastCamera)
        let canvas = try XCTUnwrap(presenter.lastLabelCanvas)
        XCTAssertEqual(canvas.x / canvas.y, presenter.lastAspect, accuracy: 0.02, "the canvas has the frame's aspect")
        let expected = AnatomyPresenter.labelPlacements(core, camera: camera, aspect: presenter.lastAspect,
                                                        canvas: canvas)
        XCTAssertEqual(presenter.lastLabels, expected)
        XCTAssertLessThanOrEqual(presenter.lastLabels.count, 16)
        let names = core.scene.parts.map(\.englishName)
        XCTAssertEqual(presenter.mirror.labels.map(\.text), presenter.lastLabels.map { names[$0.id] })
        XCTAssertEqual(presenter.mirror.canvasSize, canvas)
        XCTAssertNotNil(presenter.makeCanvasOverlay(shell.port), "the host draws the labels over the canvas")
    }
}
