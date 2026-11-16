// LabelLayoutTests — feature 112 (A15-P03) T-A15-303 (FR-A15-320; clarification Q4; SC-A15-303). The element-symbol
// labels, host-free and short: no two placed boxes overlap for any library molecule in either mode at the default
// view on canvases of 240 × 160 and 390 × 300 points, and each label sits 6 pt right of and 6 pt above its atom's
// projected centre; atoms projected off the canvas get no label; the selected atom is placed first even when it is the
// farthest; the others follow by distance from the eye; the layout is deterministic.
import Foundation
import Testing
import VisualCoreMath
@testable import MolecularExplorerCore

@Suite struct LabelLayoutTests {
    /// The canvases of the tests (points).
    private let canvases: [Vec2] = [Vec2(240, 160), Vec2(390, 300)]

    /// The default camera of `scene` on `canvas`.
    private func camera(_ scene: MoleculeScene, _ canvas: Vec2) -> OrbitCamera {
        CameraSettings.default.camera(centre: scene.centre, boundingRadius: scene.boundingRadius,
                                      aspect: canvas.x / canvas.y)
    }

    @Test func placedLabelsNeverOverlap() {
        #expect(LabelLayout.boxWidth == 24 && LabelLayout.boxHeight == 18 && LabelLayout.offset == 6)
        for molecule in MoleculeLibrary.molecules {
            for mode in DisplayMode.allCases {
                let scene = MoleculeScene(molecule: molecule, mode: mode)
                for canvas in canvases {
                    let camera = camera(scene, canvas)
                    let labels = LabelLayout.labels(scene: scene, camera: camera, canvas: canvas, selected: nil)
                    let name = "\(molecule.id) \(mode.name) \(canvas.x)"
                    #expect(!labels.isEmpty, "\(name)")
                    #expect(Set(labels.map(\.index)).count == labels.count, "\(name): one label per atom")
                    for (i, label) in labels.enumerated() {
                        let centre = LabelLayout.canvasPoint(of: scene.atoms[label.index].position, camera: camera,
                                                             canvas: canvas)
                        #expect(centre.map { Vec2($0.x + 6, $0.y - 6) } == label.point, "\(name)")
                        #expect(label.symbol == scene.atoms[label.index].symbol)
                        for other in labels[(i + 1)...] {
                            #expect(!LabelLayout.overlaps(label.box, other.box), "\(name): \(label) \(other)")
                        }
                    }
                }
            }
        }
    }

    @Test func atomsOffTheCanvasGetNoLabel() throws {
        let caffeine = try #require(MoleculeLibrary.molecules.last)
        let scene = MoleculeScene(molecule: caffeine, mode: .ballAndStick)
        let canvas = Vec2(240, 160)
        let close = OrbitCamera(target: scene.atoms[0].position, distance: 1.5, yaw: 0, pitch: 0, fovY: .pi / 3,
                                near: 0.01, far: 100)
        let visible = scene.atoms.indices.filter {
            LabelLayout.canvasPoint(of: scene.atoms[$0].position, camera: close, canvas: canvas) != nil
        }
        #expect(visible.count < scene.atoms.count, "some atoms project off the canvas")
        let labels = LabelLayout.labels(scene: scene, camera: close, canvas: canvas, selected: nil)
        #expect(!labels.isEmpty)
        for label in labels {
            #expect(visible.contains(label.index), "atom \(label.index) is off the canvas")
        }
        #expect(LabelLayout.canvasPoint(of: Vec3(0, 0, 0), camera: close, canvas: Vec2(0, 160)) == nil)
    }

    @Test func theSelectedAtomComesFirstThenNearerAtoms() throws {
        let caffeine = try #require(MoleculeLibrary.molecules.last)
        let scene = MoleculeScene(molecule: caffeine, mode: .ballAndStick)
        let canvas = Vec2(390, 300)
        let camera = camera(scene, canvas)
        let eye = camera.eye
        let distance: (Int) -> Double = { (scene.atoms[$0].position - eye).length }
        let farthest = try #require(scene.atoms.indices.max { distance($0) < distance($1) })
        let selected = LabelLayout.labels(scene: scene, camera: camera, canvas: canvas, selected: farthest)
        #expect(selected.first?.index == farthest)
        let unselected = LabelLayout.labels(scene: scene, camera: camera, canvas: canvas, selected: nil)
        for pair in zip(unselected, unselected.dropFirst()) {
            #expect(distance(pair.0.index) <= distance(pair.1.index), "placed by distance from the eye")
        }
        #expect(LabelLayout.labels(scene: scene, camera: camera, canvas: canvas, selected: 999) == unselected)
        #expect(LabelLayout.labels(scene: scene, camera: camera, canvas: canvas, selected: farthest) == selected)
        #expect(LabelLayout.labels(scene: scene, camera: camera, canvas: canvas, selected: nil) == unselected)
    }
}
