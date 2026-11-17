// ColourEditTests — feature 140 (A19-P03) T-A19-304 (FR-A19-301; SC-A19-301; clarification Q1; contracts/editor.md
// "Colours"). The edited colours drawn inside the one app's session host on the simulator, short runs only (64 × 96
// offscreen stills at one frame time, no sleep, no wall-clock assertion):
//   - in every scene each slot edit changes the picture, and `preset.reset` returns the preset's pixels exactly;
//   - an out-of-range component and a wrong value count are refused and change neither the state, its digest nor
//     the picture;
//   - another preset or another scene clears the edit (the picture is that preset's own), and choosing the shown one
//     keeps it.
import Foundation
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct ColourEditTests {
    /// The frame time of every still.
    static let time = 2.0

    /// A colour far from `components` of slot `slot`: each component moved by a half turn.
    static func farColour(_ components: [Double], slot: Int) -> [Double] {
        (0..<3).map { offset in
            let value = components[slot * 3 + offset]
            return value < 0.5 ? 1 : 0
        }
    }

    @Test func everySlotEditChangesThePictureAndResetReturnsThePresetExactly() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session)
        for scene in 0..<SceneCatalog.scenes.count {
            #expect(shell.handle(control: "scene.select", values: [Double(scene)]) == .accepted)
            let preset = try WallpaperTest.still(session, time: Self.time)
            let core = try WallpaperTest.core(shell)
            #expect(core.custom == 0)
            for slot in 0..<WallpaperCore.colorSlots {
                let colour = Self.farColour(core.colors, slot: slot)
                let result = shell.handle(control: "preset.color", values: [Double(slot)] + colour)
                #expect(result == .accepted, "scene \(scene) slot \(slot)")
                #expect(try WallpaperTest.core(shell).custom == 1)
                let edited = try WallpaperTest.still(session, time: Self.time)
                let differing = WallpaperTest.differingPixels(preset.rgba, edited.rgba)
                #expect(differing > 0, "scene \(scene) slot \(slot) changes the picture")
                #expect(shell.handle(control: "preset.reset", values: []) == .accepted)
                let reset = try WallpaperTest.still(session, time: Self.time)
                #expect(reset == preset, "scene \(scene) slot \(slot): reset gives the preset's pixels exactly")
                #expect(try WallpaperTest.core(shell) == core)
            }
        }
        session.close()
    }

    @Test func outOfRangeAndWrongCountEditsAreRefusedAndChangeNothing() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session)
        #expect(shell.handle(control: "preset.color", values: [2, 0.9, 0.1, 0.4]) == .accepted)
        let before = try WallpaperTest.core(shell)
        let digest = try shell.engine.digest()
        let picture = try WallpaperTest.still(session, time: Self.time)
        let refused: [[Double]] = [[0, 1.5, 0, 0], [0, 0, -0.5, 0], [0, 0, 0, 2], [4, 0.5, 0.5, 0.5],
                                   [1.5, 0.5, 0.5, 0.5], [0, 0.5, 0.5], [0, 0.5, 0.5, 0.5, 0.5], []]
        for values in refused {
            let result = shell.handle(control: "preset.color", values: values)
            #expect(!result.isAccepted, "\(values)")
            #expect(try WallpaperTest.core(shell) == before, "\(values)")
            #expect(try shell.engine.digest() == digest, "\(values)")
        }
        #expect(!shell.handle(control: "preset.reset", values: [0]).isAccepted)
        #expect(try WallpaperTest.core(shell) == before)
        let after = try WallpaperTest.still(session, time: Self.time)
        #expect(after == picture)
        session.close()
    }

    @Test func anotherPresetOrSceneClearsTheEdit() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session)
        #expect(shell.handle(control: "scene.preset", values: [1]) == .accepted)
        let presetOne = try WallpaperTest.still(session, time: Self.time)
        #expect(shell.handle(control: "scene.preset", values: [0]) == .accepted)
        let edit: [Double] = [1, 0.9, 0.1, 0.4]
        #expect(shell.handle(control: "preset.color", values: edit) == .accepted)
        #expect(shell.handle(control: "scene.preset", values: [0]) == .accepted)
        #expect(try WallpaperTest.core(shell).custom == 1, "choosing the shown preset keeps the edit")
        #expect(shell.handle(control: "scene.preset", values: [1]) == .accepted)
        let cleared = try WallpaperTest.core(shell)
        #expect(cleared.custom == 0 && cleared.colors == WallpaperCore.presetComponents(scene: 0, preset: 1))
        #expect(try WallpaperTest.still(session, time: Self.time) == presetOne)

        #expect(shell.handle(control: "preset.color", values: edit) == .accepted)
        #expect(shell.handle(control: "scene.select", values: [0]) == .accepted)
        #expect(try WallpaperTest.core(shell).custom == 1, "choosing the shown scene keeps the edit")
        #expect(shell.handle(control: "scene.select", values: [2]) == .accepted)
        let other = try WallpaperTest.core(shell)
        #expect(other.custom == 0 && other.preset == 0)
        #expect(other.colors == WallpaperCore.presetComponents(scene: 2, preset: 0))
        #expect(other.project.customColors == nil)
        session.close()
    }
}
