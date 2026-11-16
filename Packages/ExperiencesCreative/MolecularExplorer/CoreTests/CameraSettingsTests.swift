// CameraSettingsTests — feature 111 (A15-P02) T-A15-203 (FR-A15-220; clarification Q3; SC-A15-203). The stored camera,
// host-free and short: the default is turn 2, tilt 2, zoom 0 (30°, 20°); turning wraps 23 → 0 and 0 → 23; tilt and zoom
// refuse a step beyond their limits and change nothing; the camera looks at the scene's centre at every step; at zoom +4
// the camera stays outside the bounding sphere for every library molecule, both modes and aspects 0.5 and 2.0.
// Feature 112 (A15-P03) T-A15-304 (FR-A15-302; clarification Q2): the pan refuses values other than −1, 0, 1, (0, 0) and
// steps beyond −10…10; reset zeroes it; each step moves the target by 0.1 × the bounding radius along the view's right
// or up direction (the molecule appears to move the other way) and leaves the distance and view direction unchanged;
// camera JSON without the pan decodes with pan 0 and a pan outside −10…10 does not decode.
import Foundation
import Testing
import VisualCoreMath
@testable import MolecularExplorerCore

@Suite struct CameraSettingsTests {
    @Test func theDefaultIsTurnedAndTilted() {
        let camera = CameraSettings.default
        #expect(camera.turnSteps == 2 && camera.tiltSteps == 2 && camera.zoomSteps == 0 && camera.isValid)
        #expect(camera.turnDegrees == 30 && camera.tiltDegrees == 20)
        let clamped = CameraSettings(turnSteps: 25, tiltSteps: 20, zoomSteps: -9)
        #expect(clamped == CameraSettings(turnSteps: 1, tiltSteps: 8, zoomSteps: -4))
        #expect(CameraSettings(turnSteps: -1, tiltSteps: 0, zoomSteps: 0).turnSteps == 23)
    }

    @Test func turningWrapsBothWays() {
        var camera = CameraSettings(turnSteps: 23, tiltSteps: 0, zoomSteps: 0)
        camera.turn(1)
        #expect(camera.turnSteps == 0)
        camera.turn(-1)
        #expect(camera.turnSteps == 23 && camera.turnDegrees == 345)
        camera.turn(48)
        #expect(camera.turnSteps == 23)
        camera.turn(Int.min)
        #expect(camera.isValid)
    }

    @Test func tiltAndZoomRefuseBeyondTheirLimits() {
        var camera = CameraSettings(turnSteps: 0, tiltSteps: 8, zoomSteps: 4)
        let before = camera
        var accepted = camera.tilt(1)
        #expect(!accepted)
        accepted = camera.zoom(1)
        #expect(!accepted && camera == before)
        accepted = camera.tilt(Int.max)
        #expect(!accepted && camera == before)
        camera = CameraSettings(turnSteps: 0, tiltSteps: -8, zoomSteps: -4)
        let low = camera
        accepted = camera.tilt(-1)
        #expect(!accepted)
        accepted = camera.zoom(-1)
        #expect(!accepted && camera == low && camera.tiltDegrees == -80)
        accepted = camera.tilt(16)
        #expect(accepted && camera.tiltSteps == 8)
        accepted = camera.zoom(8)
        #expect(accepted && camera.zoomSteps == 4)
    }

    @Test func theCameraLooksAtTheCentreAtEveryStep() {
        let centre = Vec3(1.5, -0.5, 2)
        for turn in 0..<24 {
            for tilt in -8...8 {
                let settings = CameraSettings(turnSteps: turn, tiltSteps: tilt, zoomSteps: 0)
                let camera = settings.camera(centre: centre, boundingRadius: 3, aspect: 1)
                #expect(camera.target == centre)
                #expect(abs(camera.yaw - Double(turn * 15) * .pi / 180) <= 1e-12)
                #expect(abs(camera.pitch - Double(tilt * 10) * .pi / 180) <= 1e-12, "tilt \(tilt) is not clamped")
                #expect(abs((camera.eye - centre).length - camera.distance) <= 1e-9)
            }
        }
        let framed = CameraSettings.default.camera(centre: centre, boundingRadius: 3, aspect: 1)
        #expect(abs(framed.fovY - .pi / 3) <= 1e-12)
        #expect(abs(framed.distance - 3 * 1.25 / sin(Double.pi / 6)) <= 1e-9)
    }

    @Test func theNearestZoomStaysOutsideTheMolecule() {
        let aspects: [Double] = [0.5, 2.0]
        let nearest = CameraSettings(turnSteps: 0, tiltSteps: 0, zoomSteps: 4)
        for molecule in MoleculeLibrary.molecules {
            for mode in DisplayMode.allCases {
                let scene = MoleculeScene(molecule: molecule, mode: mode)
                for aspect in aspects {
                    let camera = nearest.camera(centre: scene.centre, boundingRadius: scene.boundingRadius,
                                                aspect: aspect)
                    #expect(camera.distance > 1.3 * scene.boundingRadius, "\(molecule.id) \(mode.name) \(aspect)")
                    #expect(camera.near < camera.distance - scene.boundingRadius)
                    #expect(camera.far > camera.distance + scene.boundingRadius)
                }
            }
        }
        let wide = CameraSettings.framedDistance(boundingRadius: 1, aspect: 2.0)
        let tall = CameraSettings.framedDistance(boundingRadius: 1, aspect: 0.5)
        #expect(abs(wide - 2.5) <= 1e-9 && tall > wide)
    }

    @Test func outOfRangeStepsDoNotDecode() {
        let valid = try? JSONDecoder().decode(CameraSettings.self, from: Data(#"{"tilt":-8,"turn":23,"zoom":4}"#.utf8))
        #expect(valid == CameraSettings(turnSteps: 23, tiltSteps: -8, zoomSteps: 4))
        let payloads: [String] = [#"{"tilt":9,"turn":0,"zoom":0}"#, #"{"tilt":0,"turn":24,"zoom":0}"#,
                                  #"{"tilt":0,"turn":0,"zoom":-5}"#]
        for payload in payloads {
            #expect((try? JSONDecoder().decode(CameraSettings.self, from: Data(payload.utf8))) == nil, "\(payload)")
        }
    }

    @Test func panRefusesBadValuesAndLimits() {
        var camera = CameraSettings.default
        #expect(camera.panX == 0 && camera.panY == 0 && CameraSettings.panRange == -10...10)
        let refused: [(Int, Int)] = [(0, 0), (2, 0), (0, -2), (Int.min, 1), (1, Int.max)]
        for (dx, dy) in refused {
            let accepted = camera.pan(dx: dx, dy: dy)
            #expect(!accepted && camera == .default, "pan \(dx), \(dy)")
        }
        for _ in 0..<10 {
            let accepted = camera.pan(dx: -1, dy: 1)
            #expect(accepted)
        }
        let edge = camera
        var accepted = camera.pan(dx: -1, dy: 0)
        #expect(!accepted && camera == edge && camera.panX == -10 && camera.panY == 10)
        accepted = camera.pan(dx: 1, dy: 1)
        #expect(!accepted && camera == edge, "refused when either axis leaves the range")
        accepted = camera.pan(dx: 1, dy: 0)
        #expect(accepted && camera.panX == -9 && camera.isValid)
        camera.turn(3)
        camera.reset()
        #expect(camera == .default)
        #expect(CameraSettings(turnSteps: 0, tiltSteps: 0, zoomSteps: 0, panX: 40, panY: -40).panX == 10)
    }

    @Test func eachPanStepMovesTheTargetAlongTheViewAxes() {
        let centre = Vec3(1, 2, -3)
        let radius = 2.5
        let aspect = 1.5
        for turn in stride(from: 0, to: 24, by: 5) {
            for tilt in [-8, -3, 0, 4, 8] {
                let still = CameraSettings(turnSteps: turn, tiltSteps: tilt, zoomSteps: 1)
                let base = still.camera(centre: centre, boundingRadius: radius, aspect: aspect)
                let axes = still.viewAxes
                let forward = (base.target - base.eye).normalized
                #expect(abs(axes.right.length - 1) <= 1e-12 && abs(axes.up.length - 1) <= 1e-12)
                #expect(abs(axes.right.dot(forward)) <= 1e-12 && abs(axes.up.dot(forward)) <= 1e-12)
                #expect(abs(axes.right.dot(axes.up)) <= 1e-12 && axes.right.cross(axes.up).dot(forward) < 0)
                for (px, py) in [(1, 0), (0, 1), (-3, 2), (10, -10)] {
                    let panned = CameraSettings(turnSteps: turn, tiltSteps: tilt, zoomSteps: 1, panX: px, panY: py)
                    let camera = panned.camera(centre: centre, boundingRadius: radius, aspect: aspect)
                    let expected = centre + (axes.right * Double(px) + axes.up * Double(py)) * (0.1 * radius)
                    #expect((camera.target - expected).length <= 1e-12, "turn \(turn) tilt \(tilt)")
                    #expect(camera.distance == base.distance && camera.near == base.near && camera.far == base.far)
                    #expect(((camera.target - camera.eye).normalized - forward).length <= 1e-12)
                    let seen = camera.project(centre, aspect: aspect)
                    #expect(px == 0 || (seen.x < 0) == (px > 0), "the molecule appears to move the other way")
                    #expect(py == 0 || (seen.y < 0) == (py > 0))
                }
            }
        }
    }

    @Test func panCodingDefaultsAndLimits() throws {
        let old = try JSONDecoder().decode(CameraSettings.self, from: Data(#"{"tilt":1,"turn":3,"zoom":-2}"#.utf8))
        #expect(old == CameraSettings(turnSteps: 3, tiltSteps: 1, zoomSteps: -2) && old.panX == 0 && old.panY == 0)
        let panned = CameraSettings(turnSteps: 3, tiltSteps: 1, zoomSteps: -2, panX: -10, panY: 7)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(panned)
        #expect(String(decoding: data, as: UTF8.self) == #"{"panX":-10,"panY":7,"tilt":1,"turn":3,"zoom":-2}"#)
        #expect((try? JSONDecoder().decode(CameraSettings.self, from: data)) == panned)
        let payloads: [String] = [#"{"panX":11,"tilt":0,"turn":0,"zoom":0}"#,
                                  #"{"panY":-11,"tilt":0,"turn":0,"zoom":0}"#,
                                  #"{"panX":"1","tilt":0,"turn":0,"zoom":0}"#]
        for payload in payloads {
            #expect((try? JSONDecoder().decode(CameraSettings.self, from: Data(payload.utf8))) == nil, "\(payload)")
        }
    }
}
