// AmbientRenderTests — feature 132 (A18-P02) T-A18-204, T-A18-206 (FR-A18-202, FR-A18-207, FR-A18-208; SC-A18-203,
// SC-A18-204; research D3, D4; contracts/experience.md "Theme"). The drawn "Noise gradient" background inside the one
// app's session host on the simulator, short runs only (no wall-clock assertion): the frames at level-0 and level-1
// are not blank, the centre probe is dark and each level makes one draw with its octaves; with motion off, and with
// Reduce Motion on, two stills at frame times 1 and 7 are identical; with motion on they differ; a speed outside
// 0.25–2 is refused and changes nothing; closing leaves no GPU object.
import Foundation
import Testing
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct AmbientRenderTests {
    @Test func theFramesAtBothLevelsAreNotBlankAndTheCentreIsDark() async throws {
        for level in 0..<2 {
            let session = ExperienceSession()
            session.qualityPin = level
            let shell = try await AmbientTest.open(session)
            let frame = try AmbientTest.picture(session)
            #expect(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "level-\(level)")
            for probe in shell.frameProbes {
                let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
                #expect(found?.rawValue == probe.expected, "level-\(level) \(probe.name)")
            }
            #expect(shell.engine.qualityTier == level)
            #expect(shell.presenter.lastDrawCount == 1, "level-\(level): one full-screen draw")
            #expect(shell.presenter.lastOctaves == AmbientCore.octaves(forTier: level))
            #expect(shell.presenter.lastOctaves == (level == 0 ? 5 : 3))
            let still = try AmbientTest.still(session, time: 3)
            #expect(FrameChecks.isNonBlank(still.rgba, width: still.width, height: still.height),
                    "level-\(level) still")
            session.close()
            let counts = try #require(session.diagnostics.lastCloseCounts)
            #expect(counts.objects == 0 && counts.leaked == 0, "level-\(level)")
            #expect(session.hostsAlive == 0)
        }
    }

    @Test func withMotionOffTwoFramesAtDifferentTimesAreIdentical() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let off = shell.handle(control: "theme.motion", values: [0])
        #expect(off == .accepted)
        let early = try AmbientTest.still(session, time: 1)
        #expect(shell.presenter.lastUniformTime == 0)
        let late = try AmbientTest.still(session, time: 7)
        #expect(shell.presenter.lastUniformTime == 0)
        #expect(AmbientTest.differingPixels(early.rgba, late.rgba) == 0)
        #expect(early == late)
        #expect(FrameChecks.isNonBlank(late.rgba, width: late.width, height: late.height))
        session.close()
    }

    @Test func withReduceMotionTwoFramesAtDifferentTimesAreIdentical() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session, reduceMotion: true)
        let core = try AmbientTest.core(shell)
        #expect(core.motion, "Reduce Motion stills the background without turning motion off")
        let early = try AmbientTest.still(session, time: 1)
        let late = try AmbientTest.still(session, time: 7)
        #expect(shell.presenter.lastUniformTime == 0)
        #expect(AmbientTest.differingPixels(early.rgba, late.rgba) == 0)
        #expect(early == late)
        session.close()
    }

    @Test func withMotionOnTwoFramesAtDifferentTimesDiffer() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let early = try AmbientTest.still(session, time: 1)
        #expect(shell.presenter.lastUniformTime == 1)
        let late = try AmbientTest.still(session, time: 7)
        #expect(shell.presenter.lastUniformTime == 7)
        #expect(AmbientTest.differingPixels(early.rgba, late.rgba) > 0)
        // The speed scales the uniform time.
        let faster = shell.handle(control: "theme.speed", values: [2])
        #expect(faster == .accepted)
        _ = try AmbientTest.still(session, time: 7)
        #expect(shell.presenter.lastUniformTime == 14)
        session.close()
    }

    @Test func aSpeedOutsideItsRangeIsRefused() async throws {
        let session = ExperienceSession()
        let shell = try await AmbientTest.open(session)
        let digest = try shell.engine.digest()
        for speed in [0.2, 2.5, 0, -1, 0.249] {
            let result = shell.handle(control: "theme.speed", values: [speed])
            #expect(!result.isAccepted, "speed \(speed)")
            let core = try AmbientTest.core(shell)
            #expect(core.speed == 1, "speed \(speed)")
        }
        #expect(try shell.engine.digest() == digest)
        for speed in [0.25, 2] {
            let result = shell.handle(control: "theme.speed", values: [speed])
            #expect(result == .accepted, "speed \(speed)")
        }
        session.close()
    }
}
