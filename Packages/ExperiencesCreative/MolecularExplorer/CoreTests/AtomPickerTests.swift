// AtomPickerTests — feature 112 (A15-P03) T-A15-302 (FR-A15-310; clarification Q3; SC-A15-301). Ray-to-sphere picking,
// host-free and short: a ray through a lone atom's centre picks it in both modes and a ray beside it misses; of two
// overlapping atoms the nearer along the ray wins; a ray pointing away or with no direction picks nothing; and the
// manual's regression fixture — for all five library molecules, both modes and eight camera positions (turns 0, 6, 12,
// 18 × tilts −3, +3) at aspect 1.5, the ray through every atom's projected centre picks the atom a brute-force search
// (written independently here) finds nearest along that ray, which is the atom itself whenever no other sphere is met
// nearer; the empty corners of the canvas pick nothing.
import Foundation
import Testing
import VisualCoreMath
@testable import MolecularExplorerCore

@Suite struct AtomPickerTests {
    /// A molecule of carbon atoms at `positions`.
    private func carbons(_ positions: [Vec3]) throws -> Molecule {
        let atoms = positions.map { Atom(symbol: "C", x: $0.x, y: $0.y, z: $0.z) }
        return try Molecule.make(id: "carbons", title: "Carbons", atoms: atoms, bonds: [],
                                 source: MoleculeLibrary.source(id: "carbons", cid: 1)).get()
    }

    /// The distance along the unit `direction` from `origin` at which the sphere is first met (0 from inside), or nil.
    private func entry(origin: Vec3, direction: Vec3, centre: Vec3, radius: Double) -> Double? {
        let oc = origin - centre
        let b = oc.dot(direction)
        let c = oc.dot(oc) - radius * radius
        let disc = b * b - c
        guard disc >= 0 else { return nil }
        let far = -b + disc.squareRoot()
        guard far >= 0 else { return nil }
        return max(-b - disc.squareRoot(), 0)
    }

    @Test func aRayThroughALoneAtomPicksIt() throws {
        let centre = Vec3(1, -2, 3)
        let molecule = try carbons([centre])
        let directions: [Vec3] = [Vec3(1, 0, 0), Vec3(0, -1, 0), Vec3(0.3, 0.4, -0.5), Vec3(-2, 1, 1)]
        for mode in DisplayMode.allCases {
            let scene = MoleculeScene(molecule: molecule, mode: mode)
            let radius = scene.atoms[0].radius
            for direction in directions {
                let unit = direction.normalized
                let origin = centre - unit * 10
                #expect(AtomPicker.pick(origin: origin, direction: direction, scene: scene) == 0, "\(mode.name)")
                #expect(AtomPicker.pick(origin: origin, direction: -direction, scene: scene) == nil, "pointing away")
                let side = unit.cross(Vec3(0.2, 0.9, 0.1)).normalized
                #expect(AtomPicker.pick(origin: origin + side * (radius * 1.01), direction: direction,
                                        scene: scene) == nil, "beside the drawn sphere")
                #expect(AtomPicker.pick(origin: origin + side * (radius * 0.99), direction: direction,
                                        scene: scene) == 0, "just inside the drawn sphere")
            }
            #expect(AtomPicker.pick(origin: centre - Vec3(10, 0, 0), direction: .zero, scene: scene) == nil)
        }
    }

    @Test func overlappingAtomsGiveTheNearer() throws {
        let molecule = try carbons([Vec3(0, 0, 0), Vec3(0, 0, 1)])
        for mode in DisplayMode.allCases {
            let scene = MoleculeScene(molecule: molecule, mode: mode)
            #expect(AtomPicker.pick(origin: Vec3(0, 0, 10), direction: Vec3(0, 0, -1), scene: scene) == 1)
            #expect(AtomPicker.pick(origin: Vec3(0, 0, -10), direction: Vec3(0, 0, 1), scene: scene) == 0)
            #expect(AtomPicker.pick(origin: Vec3(0.1, 0, 10), direction: Vec3(0, 0, -3), scene: scene) == 1)
        }
    }

    @Test func eachProjectedCentrePicksTheNearestAtomAlongItsLineOfSight() {
        let aspect = 1.5
        let turns: [Int] = [0, 6, 12, 18]
        let tilts: [Int] = [-3, 3]
        #expect(MoleculeLibrary.molecules.count == 5)
        var cases = 0, themselves = 0, covered = 0
        for molecule in MoleculeLibrary.molecules {
            for mode in DisplayMode.allCases {
                let scene = MoleculeScene(molecule: molecule, mode: mode)
                for turn in turns {
                    for tilt in tilts {
                        let settings = CameraSettings(turnSteps: turn, tiltSteps: tilt, zoomSteps: 0)
                        let camera = settings.camera(centre: scene.centre, boundingRadius: scene.boundingRadius,
                                                     aspect: aspect)
                        let viewProjection = camera.viewProjection(aspect: aspect)
                        for (index, atom) in scene.atoms.enumerated() {
                            let clip = viewProjection * Vec4(atom.position, 1)
                            #expect(clip.w > 0, "\(molecule.id) atom \(index) is in front of the camera")
                            let ndc = Vec2(clip.x / clip.w, clip.y / clip.w)
                            let ray = camera.ray(ndc: ndc, aspect: aspect)
                            var best: (index: Int, distance: Double)?
                            var own: Double?
                            for (other, item) in scene.atoms.enumerated() {
                                guard let t = entry(origin: ray.origin, direction: ray.direction,
                                                    centre: item.position, radius: item.radius) else { continue }
                                if other == index { own = t }
                                if best == nil || t < best!.distance { best = (other, t) }
                            }
                            let label = "\(molecule.id) \(mode.name) turn \(turn) tilt \(tilt) atom \(index)"
                            #expect(own != nil, "\(label): the line of sight meets its own atom")
                            let picked = AtomPicker.pick(ndc: ndc, camera: camera, aspect: aspect, scene: scene)
                            #expect(picked == best?.index, "\(label)")
                            if let own, let best, best.distance >= own {
                                #expect(picked == index, "\(label): nothing nearer, so the atom itself")
                            }
                            cases += 1
                            if picked == index { themselves += 1 } else { covered += 1 }
                        }
                    }
                }
            }
        }
        #expect(cases == 2 * 8 * (3 + 5 + 9 + 12 + 24))
        #expect(themselves > 0 && covered > 0, "both visible and covered atoms are exercised")
    }

    @Test func theEmptyCornersPickNothing() {
        let corners: [Vec2] = [Vec2(-0.98, -0.98), Vec2(0.98, -0.98), Vec2(-0.98, 0.98), Vec2(0.98, 0.98)]
        for molecule in MoleculeLibrary.molecules {
            for mode in DisplayMode.allCases {
                let scene = MoleculeScene(molecule: molecule, mode: mode)
                let camera = CameraSettings.default.camera(centre: scene.centre, boundingRadius: scene.boundingRadius,
                                                           aspect: 1.5)
                for corner in corners {
                    #expect(AtomPicker.pick(ndc: corner, camera: camera, aspect: 1.5, scene: scene) == nil,
                            "\(molecule.id) \(mode.name) \(corner)")
                }
            }
        }
    }
}
