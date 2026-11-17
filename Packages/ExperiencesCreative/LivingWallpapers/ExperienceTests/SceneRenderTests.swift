// SceneRenderTests — feature 139 (A19-P02) T-A19-208 (FR-A19-203, FR-A19-207; SC-A19-204; spec edge cases "Reduce
// Motion" and "Context loss during preview"; contracts/experience.md "Scenes"). The four scenes drawn inside the one
// app's session host on the simulator, short runs only (small canvases, no sleep, no wall-clock assertion): every
// scene at both levels is not blank, its corner probe is dark and equal state and time give identical pixels; the
// scenes and presets give different pictures; with motion off, and with Reduce Motion on, two frame times give the
// same picture (the animation time's); with motion on two times differ; a preset or parameter change sets uniforms
// only while a scene change rebuilds; a repeated setup after a context recreation draws the same frame; closing
// leaves no GPU object.
import Foundation
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct SceneRenderTests {
    @Test func everySceneAtBothLevelsIsNotBlankAndRepeatsExactly() async throws {
        for level in 0..<2 {
            let session = ExperienceSession()
            session.qualityPin = level
            let shell = try await WallpaperTest.open(session)
            for scene in 0..<SceneCatalog.scenes.count {
                #expect(shell.handle(control: "scene.select", values: [Double(scene)]) == .accepted)
                let frame = try WallpaperTest.picture(session)
                let name = "scene \(scene) level-\(level)"
                #expect(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name)")
                for probe in shell.frameProbes {
                    let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
                    #expect(found?.rawValue == probe.expected, "\(name) \(probe.name)")
                }
                #expect(shell.presenter.lastTier == level && shell.presenter.lastDrawCount == 1, "\(name)")
                let first = try WallpaperTest.still(session, time: 5)
                let second = try WallpaperTest.still(session, time: 5)
                #expect(FrameChecks.isNonBlank(first.rgba, width: first.width, height: first.height), "\(name)")
                #expect(first == second, "\(name): equal state and time give identical pixels")
            }
            session.close()
            let counts = try #require(session.diagnostics.lastCloseCounts)
            #expect(counts.objects == 0 && counts.leaked == 0, "level-\(level)")
        }
    }

    @Test func scenesAndPresetsGiveDifferentPictures() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session)
        var pictures: [StillImage] = []
        for scene in 0..<SceneCatalog.scenes.count {
            #expect(shell.handle(control: "scene.select", values: [Double(scene)]) == .accepted)
            for preset in 0..<3 {
                #expect(shell.handle(control: "scene.preset", values: [Double(preset)]) == .accepted)
                let still = try WallpaperTest.still(session, time: 2)
                for (index, earlier) in pictures.enumerated() {
                    let differing = WallpaperTest.differingPixels(earlier.rgba, still.rgba)
                    #expect(differing > still.width * still.height / 4, "scene \(scene) preset \(preset) vs \(index)")
                }
                pictures.append(still)
            }
        }
        session.close()
    }

    @Test func withMotionOffTwoFrameTimesGiveTheSamePicture() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session)
        #expect(shell.handle(control: "scene.time", values: [30]) == .accepted)
        #expect(shell.handle(control: "motion.enabled", values: [0]) == .accepted)
        let early = try WallpaperTest.still(session, time: 1)
        #expect(shell.presenter.lastUniformTime == 30)
        let late = try WallpaperTest.still(session, time: 9)
        #expect(shell.presenter.lastUniformTime == 30)
        #expect(early == late)
        #expect(shell.handle(control: "motion.enabled", values: [1]) == .accepted)
        let moving = try WallpaperTest.still(session, time: 30)
        #expect(shell.presenter.lastUniformTime == 30)
        #expect(moving == late, "the still at the animation time is the moving scene at that time")
        session.close()
    }

    @Test func withReduceMotionTwoFrameTimesGiveTheSamePicture() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session, reduceMotion: true)
        #expect(try WallpaperTest.core(shell).motion)
        let early = try WallpaperTest.still(session, time: 1)
        let late = try WallpaperTest.still(session, time: 9)
        #expect(shell.presenter.lastUniformTime == 0)
        #expect(early == late)
        session.close()
    }

    @Test func withMotionOnTwoFrameTimesDiffer() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session)
        for scene in 0..<SceneCatalog.scenes.count {
            #expect(shell.handle(control: "scene.select", values: [Double(scene)]) == .accepted)
            let early = try WallpaperTest.still(session, time: 1)
            #expect(shell.presenter.lastUniformTime == 1)
            let late = try WallpaperTest.still(session, time: 40)
            #expect(shell.presenter.lastUniformTime == 40)
            #expect(WallpaperTest.differingPixels(early.rgba, late.rgba) > 0, "scene \(scene)")
        }
        session.close()
    }

    @Test func aPresetOrParameterChangeSetsUniformsAndASceneChangeRebuilds() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session)
        let builds = shell.presenter.sceneBuildCount
        let before = try WallpaperTest.still(session, time: 3)
        #expect(shell.handle(control: "scene.preset", values: [1]) == .accepted)
        #expect(shell.handle(control: "scene.parameter", values: [0, 7]) == .accepted)
        let after = try WallpaperTest.still(session, time: 3)
        #expect(shell.presenter.sceneBuildCount == builds)
        #expect(before != after)
        #expect(shell.handle(control: "scene.select", values: [1]) == .accepted)
        _ = try WallpaperTest.picture(session)
        #expect(shell.presenter.sceneBuildCount == builds + 1)
        #expect(shell.presenter.shownScene == 1)
        session.close()
    }

    @Test func aRepeatedSetupAfterAContextRecreationDrawsTheSameFrame() async throws {
        let session = ExperienceSession()
        let shell = try await WallpaperTest.open(session)
        #expect(shell.handle(control: "scene.select", values: [2]) == .accepted)
        #expect(shell.handle(control: "scene.preset", values: [1]) == .accepted)
        let before = try WallpaperTest.still(session, time: 4)
        let builds = shell.presenter.sceneBuildCount
        session.recreateContext()
        #expect(session.state == .running)
        #expect(shell.presenter.sceneBuildCount == builds + 1, "setup rebuilt the scene")
        #expect(shell.presenter.shownScene == 2, "rebuilt from the core's scene")
        let after = try WallpaperTest.still(session, time: 4)
        #expect(after == before)
        let frame = try WallpaperTest.picture(session)
        #expect(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height))
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }
}
