// ChromeTests — feature 153 (A21-P02) T-A21-206 (FR-A21-201, FR-A21-205; SC-A21-203; contracts/experience.md
// "Chrome"). The controls step aside and come back: "Hide controls" hides them and leaves only the line with the
// accessibility action "Show controls"; a tap on the sky (a touch that lifts where it landed) or that action brings them
// back, in every trial; a drag, a cancelled touch or `cancelPointers` does not; the flag is not in the state (the
// snapshot and the digest are unchanged and no action is sent). Every control has a spoken label and value and an
// identifier under `experience.a21.aurora.`, and every action has a native control (no gesture action). The controls
// render with `ImageRenderer` shown and hidden. Short runs only.
import Foundation
import SwiftUI
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct ChromeTests {
    @Test func everyControlHasASpokenLabelAndANativeAction() async throws {
        let shell = try await AuroraTest.shell()
        let mirror = shell.presenter.mirror
        var byName = Dictionary(uniqueKeysWithValues: AuroraControls.labels(mirror).map { ($0.name, $0.text) })
        #expect(byName["preset"] == "Sky, Polar night" && byName["hue"] == "Colour shift, 0°")
        #expect(byName["speed"] == "Speed, 1.0 times" && byName["turbulence"] == "Turbulence, 45 %")
        #expect(byName["ribbons"] == "Ribbons, 3" && byName["stars"] == "Stars, 320")
        #expect(byName["clouds"] == "Clouds, 10 %" && byName["limit"] == "Brightness limit, 60 %")
        #expect(byName["hide-controls"] == "Hide controls, Controls shown")
        AuroraTest.accept(shell, "preset.select", [1])
        AuroraTest.accept(shell, "colour.hue", [-0.25])
        AuroraTest.accept(shell, "light.limit", [0.3])
        let labels = AuroraControls.labels(mirror)
        #expect(Set(labels.map(\.name)).count == labels.count, "unique names")
        for label in labels {
            #expect(!label.title.isEmpty && !label.value.isEmpty, "\(label.name)")
        }
        byName = Dictionary(uniqueKeysWithValues: labels.map { ($0.name, $0.text) })
        #expect(byName["preset"] == "Sky, Violet veil" && byName["hue"] == "Colour shift, −90°")
        #expect(byName["limit"] == "Brightness limit, 30 %")
        #expect(Set(AuroraControls.actionOfControl.values) == Set(SkyCore.actionIDs), "a control for every action")
        #expect(Set(AuroraControls.actionOfControl.keys).isSubset(of: Set(labels.map(\.name))))
        #expect(shell.port.identifier("limit") == "experience.a21.aurora.limit")
        let presenter = shell.presenter
        #expect(presenter.gestureActions.isEmpty)
        #expect(presenter.nativeActions == Set(SkyCore.actionIDs))
        #expect(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions).isEmpty)
        let summary = shell.accessibilitySummary
        #expect(summary == "Aurora, Violet veil, colour shift −90°, speed 0.8 times, 2 ribbons, 200 stars, clouds 30 %, "
                + "brightness limit 30 %", "\(summary)")
    }

    @Test func hiddenControlsReturnByATapAndByTheAction() async throws {
        let shell = try await AuroraTest.shell()
        let presenter = shell.presenter
        let snapshot = try shell.snapshot()
        let digest = try shell.engine.digest()
        let revision = shell.port.revision
        for trial in 0..<5 {
            presenter.hideControls()
            #expect(presenter.mirror.controlsHidden, "trial \(trial)")
            let hidden = AuroraControls.labels(presenter.mirror)
            #expect(hidden.map(\.name) == ["show-controls"])
            #expect(hidden.first?.value == AuroraControls.showControlsAction)
            #expect(AuroraControls.showControlsAction == "Show controls")
            if trial.isMultiple(of: 2) {
                AuroraTest.touch(shell, .began, at: Vec2(100, 80))
                AuroraTest.touch(shell, .moved, at: Vec2(104, 83))
                AuroraTest.touch(shell, .ended, at: Vec2(105, 84))
            } else {
                presenter.showControls()   // the accessibility action's handler
            }
            #expect(!presenter.mirror.controlsHidden, "trial \(trial)")
            #expect(AuroraControls.labels(presenter.mirror).count == 13)
        }
        #expect(shell.port.revision == revision, "no action was sent")
        #expect(try shell.snapshot().payload == snapshot.payload, "the flag is not in the snapshot")
        #expect(try shell.engine.digest() == digest, "nor in the digest")
    }

    @Test func aDragACancelledTouchOrASuspensionDoNotShowTheControls() async throws {
        let shell = try await AuroraTest.shell()
        let presenter = shell.presenter
        presenter.hideControls()
        AuroraTest.touch(shell, .began, at: Vec2(40, 40))
        AuroraTest.touch(shell, .moved, at: Vec2(120, 60))
        AuroraTest.touch(shell, .ended, at: Vec2(120, 60))
        #expect(presenter.mirror.controlsHidden, "a drag is not a tap")
        AuroraTest.touch(shell, .began, at: Vec2(40, 40), id: 2)
        AuroraTest.touch(shell, .cancelled, at: Vec2(40, 40), id: 2)
        AuroraTest.touch(shell, .ended, at: Vec2(40, 40), id: 2)
        #expect(presenter.mirror.controlsHidden, "a cancelled touch is not a tap")
        AuroraTest.touch(shell, .began, at: Vec2(40, 40), id: 3)
        presenter.cancelPointers()
        AuroraTest.touch(shell, .ended, at: Vec2(40, 40), id: 3)
        #expect(presenter.mirror.controlsHidden, "a forgotten touch is not a tap")
        AuroraTest.touch(shell, .began, at: Vec2(40, 40), id: 4)
        AuroraTest.touch(shell, .ended, at: Vec2(40, 40), id: 4)
        #expect(!presenter.mirror.controlsHidden)
    }

    @Test func theControlsRenderShownAndHidden() async throws {
        let shell = try await AuroraTest.shell()
        let presenter = shell.presenter
        let shown = ImageRenderer(content: presenter.makeControls(shell.port).frame(width: 390))
        let shownSize = try #require(shown.uiImage).size
        presenter.hideControls()
        let hidden = ImageRenderer(content: presenter.makeControls(shell.port).frame(width: 390))
        let hiddenSize = try #require(hidden.uiImage).size
        #expect(shownSize.width <= 390 && hiddenSize.width <= 390)
        #expect(hiddenSize.height < shownSize.height, "hidden controls step aside: \(hiddenSize) \(shownSize)")
    }
}
