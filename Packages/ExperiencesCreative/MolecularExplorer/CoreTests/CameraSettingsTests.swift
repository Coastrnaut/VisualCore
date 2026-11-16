// CameraSettingsTests — feature 111 (A15-P02) T-A15-203 (FR-A15-220; clarification Q3; SC-A15-203). The stored camera,
// host-free and short: the default is turn 2, tilt 2, zoom 0 (30°, 20°); turning wraps 23 → 0 and 0 → 23; tilt and zoom
// refuse a step beyond their limits and change nothing; the camera looks at the scene's centre at every step; at zoom +4
// the camera stays outside the bounding sphere for every library molecule, both modes and aspects 0.5 and 2.0.
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
}
