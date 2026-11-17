// LowPowerCadenceTests — feature 156 (A21-P05) T-A21-505 (FR-A21-505; SC-A21-502, SC-A21-505; contracts/sound.md
// "Cadence"). Fixture 5 of the manual: Low Power Mode caps the frame rate at 30 and the sky shows no jump in time.
// Through the one app's session host, with the presenter's ``AuroraPresenter/fixedDelta`` as each frame's delta:
// 60 frames of 1/30 s and 120 frames of 1/60 s end at the same sky time with the same off-screen pixels at every
// shared instant; a switch from 1/60 s to 1/30 s frames halfway ends at the same time with no step above one frame's
// span; a 0.5 s stall, clamped as the host clamps it, moves the clock by at most 0.1 s times the speed; under Reduce
// Motion and the still view the clock holds at both cadences. Short runs only (no sleep, no wall-clock assertion).
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct LowPowerCadenceTests {
    /// Opens Aurora and draws `frames` frames of `span` seconds; returns the start time, the clock time after each
    /// frame, the speed and the off-screen stills after every `stillEvery`-th frame.
    private func run(_ spans: [Double], stillEvery: Int = 0) async throws
        -> (start: Double, times: [Double], speed: Double, stills: [[UInt8]]) {
        let session = ExperienceSession()
        defer { session.close() }
        let presenter = try await AuroraTest.open(session).presenter
        let start = presenter.clock.time
        var times: [Double] = []
        var stills: [[UInt8]] = []
        for (index, span) in spans.enumerated() {
            presenter.fixedDelta = span
            try AuroraTest.draw(session)
            times.append(presenter.clock.time)
            if stillEvery > 0, (index + 1) % stillEvery == 0 {
                presenter.fixedDelta = nil   // an off-screen still has delta 0
                stills.append(try AuroraTest.still(session))
            }
        }
        return (start, times, presenter.clock.speed, stills)
    }

    @Test func lowPowerModeCapsTheFrameRateAtThirty() async throws {
        #expect(FramePacing(thermal: .nominal, lowPower: true, requestedMaxFPS: 60).maxFPS == 30)
        let shell = try await AuroraTest.shell()
        #expect(shell.presenter.maxFramesPerSecond <= 30)
    }

    @Test func thirtyAndSixtyFramesPerSecondReachTheSameSky() async throws {
        let sixty = try await run(Array(repeating: 1.0 / 60, count: 120), stillEvery: 2)
        let thirty = try await run(Array(repeating: 1.0 / 30, count: 60), stillEvery: 1)
        #expect(sixty.start == thirty.start && sixty.speed == thirty.speed)
        let end = sixty.start + 2 * sixty.speed
        #expect(abs((sixty.times.last ?? 0) - end) <= 1e-6, "60 fps: \(sixty.times.last ?? 0) vs \(end)")
        #expect(abs((thirty.times.last ?? 0) - end) <= 1e-6, "30 fps: \(thirty.times.last ?? 0) vs \(end)")
        #expect(sixty.stills.count == 60 && thirty.stills.count == 60)
        var differing = 0
        for (a, b) in zip(sixty.stills, thirty.stills) where a != b { differing += 1 }
        #expect(differing == 0, "pixels differ at \(differing) of 60 shared instants")
        print("aurora-cadence: end \(sixty.times.last ?? 0) / \(thirty.times.last ?? 0); 60 shared stills identical")
    }

    @Test func turningLowPowerOnMidMotionKeepsTheTime() async throws {
        let spans = Array(repeating: 1.0 / 60, count: 60) + Array(repeating: 1.0 / 30, count: 30)
        let switched = try await run(spans)
        let end = switched.start + 2 * switched.speed
        #expect(abs((switched.times.last ?? 0) - end) <= 1e-6, "\(switched.times.last ?? 0) vs \(end)")
        var previous = switched.start
        var largest = 0.0
        for (time, span) in zip(switched.times, spans) {
            let step = time - previous
            #expect(step >= 0 && step <= span * switched.speed + 1e-9, "a step of \(step) in a frame of \(span)")
            largest = max(largest, step)
            previous = time
        }
        print("aurora-cadence: switched run ends at \(switched.times.last ?? 0); largest step \(largest)")
    }

    @Test func aStallMovesTheClockByAtMostTheClampedDelta() async throws {
        let stall = FramePacing.clampedDelta(0.5)
        #expect(stall == 0.1)
        let stalled = try await run([stall])
        let step = (stalled.times.first ?? 0) - stalled.start
        #expect(step > 0 && step <= 0.1 * stalled.speed + 1e-12, "the stall moved the clock \(step)")
    }

    @Test func reduceMotionAndTheStillViewHoldAtBothCadences() async throws {
        for reduceMotion in [true, false] {
            let session = ExperienceSession()
            defer { session.close() }
            let presenter = try await AuroraTest.open(session, reduceMotion: reduceMotion).presenter
            if !reduceMotion { presenter.setStillView(true) }
            let time = presenter.clock.time
            for span in [1.0 / 60, 1.0 / 30] {
                presenter.fixedDelta = span
                try AuroraTest.draw(session, frames: 10)
                #expect(presenter.clock.time == time, "\(reduceMotion ? "Reduce Motion" : "still view") at \(span)")
            }
        }
    }
}
