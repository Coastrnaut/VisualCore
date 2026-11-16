// PickerTests — feature 125 (A17-P02) T-A17-203 (FR-A17-204, FR-A17-205; SC-A17-202). Picking on the bundled knee:
// for each of the 14 parts at least one of the 26 probe rays (from 100 cm outside along the axis and diagonal
// directions, aimed at the part's centre) picks it with every layer shown, and with its layer hidden no probe picks
// it, at both levels; a ray that misses gives nil; with every layer hidden every probe misses; equal distances go to
// the lower part index; the same ray gives the same pick; the NDC overload equals the ray it casts.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import InteractiveAnatomyCore

@Suite struct PickerTests {
    /// The 26 unit directions along the axes and diagonals.
    private static let pickerProbeDirections: [Vec3] = {
        var directions: [Vec3] = []
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 where x != 0 || y != 0 || z != 0 {
                    directions.append(Vec3(Double(x), Double(y), Double(z)).normalized)
                }
            }
        }
        return directions
    }()

    /// Every layer.
    private static let pickerAllLayers = Set(AnatomyLayer.allCases)

    /// The bundled knee's scene at `quality`.
    private static func pickerScene(_ quality: AnatomyQuality) throws -> AnatomyScene {
        try AnatomyScene.build(try AnatomyContent.bundledRightKnee(), quality: quality).get()
    }

    /// The part picked by the probe along `direction` aimed at part `index`'s centre.
    private static func pickerProbe(_ scene: AnatomyScene, _ index: Int, _ direction: Vec3,
                                    _ visible: Set<AnatomyLayer>) -> Int? {
        let center = scene.structureSphere(index).center
        return AnatomyPicker.pick(origin: center - direction * 100, direction: direction, scene: scene,
                                  visible: visible)?.index
    }

    @Test func probeRaysReachEveryPartAndNeverAHiddenOne() throws {
        #expect(Self.pickerProbeDirections.count == 26)
        for quality in AnatomyQuality.levels {
            let scene = try Self.pickerScene(quality)
            for (index, part) in scene.parts.enumerated() {
                guard let layer = part.layer else { continue }
                var shownHits = 0, hiddenHits = 0
                var others = Self.pickerAllLayers
                others.remove(layer)
                for direction in Self.pickerProbeDirections {
                    if Self.pickerProbe(scene, index, direction, Self.pickerAllLayers) == index { shownHits += 1 }
                    let hidden = Self.pickerProbe(scene, index, direction, others)
                    if hidden == index { hiddenHits += 1 }
                    if let hidden { #expect(scene.parts[hidden].layer != layer, "\(part.id) hit \(hidden) on its layer") }
                }
                #expect(shownHits >= 1, "level \(quality.level) \(part.id)")
                #expect(hiddenHits == 0, "level \(quality.level) \(part.id)")
            }
        }
    }

    @Test func aMissGivesNil() throws {
        let scene = try Self.pickerScene(AnatomyQuality.levels[1])
        let all = Self.pickerAllLayers
        #expect(AnatomyPicker.pick(origin: Vec3(50, 0, 0), direction: Vec3(0, 0, 1), scene: scene, visible: all) == nil)
        #expect(AnatomyPicker.pick(origin: Vec3(0, 0, 50), direction: Vec3(0, 0, 1), scene: scene, visible: all) == nil)
        #expect(AnatomyPicker.pick(origin: Vec3(0, 0, 50), direction: .zero, scene: scene, visible: all) == nil)
        let nan = Vec3(.nan, 0, 0)
        #expect(AnatomyPicker.pick(origin: nan, direction: Vec3(0, 0, -1), scene: scene, visible: all) == nil)
    }

    @Test func everyLayerHiddenMissesEverything() throws {
        let scene = try Self.pickerScene(AnatomyQuality.levels[1])
        for index in scene.parts.indices {
            for direction in Self.pickerProbeDirections {
                #expect(Self.pickerProbe(scene, index, direction, []) == nil)
            }
        }
    }

    @Test func equalDistancesGoToTheLowerIndex() throws {
        let region = try AnatomyContent.bundledRightKnee()
        // Every mesh placed as the same unit sphere: every part is hit at the same distance.
        let result = AnatomyScene.build(region, quality: AnatomyQuality.levels[1]) { id in
            MeshPlacement(meshID: id, kind: .sphere, shape: .sphere(radii: Vec3(1, 1, 1)), model: .identity)
        }
        let scene = try result.get()
        let origin = Vec3(0.1, 0.2, 10), direction = Vec3(0, 0, -1)
        let first = AnatomyPicker.pick(origin: origin, direction: direction, scene: scene, visible: Self.pickerAllLayers)
        #expect(first?.index == 0)
        let withoutBones = AnatomyPicker.pick(origin: origin, direction: direction, scene: scene,
                                              visible: [.cartilage, .ligaments])
        #expect(withoutBones?.index == 4)
        let ligamentsOnly = AnatomyPicker.pick(origin: origin, direction: direction, scene: scene, visible: [.ligaments])
        #expect(ligamentsOnly?.index == 8)
        // The rule itself.
        #expect(AnatomyPicker.better((5, 1.0), (3, 1.0 + 1e-12)).index == 3)
        #expect(AnatomyPicker.better((3, 1.0), (5, 1.0)).index == 3)
        #expect(AnatomyPicker.better((5, 2.0), (3, 2.5)).index == 5)
        #expect(AnatomyPicker.better(nil, (7, 4.0)).index == 7)
    }

    @Test func picksAreDeterministicAndTheNDCOverloadCastsTheCameraRay() throws {
        let scene = try Self.pickerScene(AnatomyQuality.levels[0])
        let camera = AnatomyCameraState.opening.camera(center: scene.regionCenter, radius: scene.regionRadius,
                                                       aspect: 1)
        let ndc = Vec2(0.02, 0.05)
        let ray = camera.ray(ndc: ndc, aspect: 1)
        let viaRay = AnatomyPicker.pick(origin: ray.origin, direction: ray.direction, scene: scene,
                                        visible: Self.pickerAllLayers)
        let viaNDC = AnatomyPicker.pick(ndc: ndc, camera: camera, aspect: 1, scene: scene, visible: Self.pickerAllLayers)
        let again = AnatomyPicker.pick(ndc: ndc, camera: camera, aspect: 1, scene: scene, visible: Self.pickerAllLayers)
        #expect(viaNDC != nil)
        #expect(viaNDC?.index == viaRay?.index)
        #expect(viaNDC?.distance == viaRay?.distance)
        #expect(again?.index == viaNDC?.index)
        #expect(again?.distance == viaNDC?.distance)
    }
}
