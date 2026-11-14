// TestSignalAudioSourceTests — feature 061 (A08-P01) T-A08-103 (FR-A08-102; gap G-STEREO): the test-signal source
// writes its first block on start, writes exactly `TestSignal.value(atFrame:channel:)` on both channels, stops
// writing when stopped, and replays from frame 0 on restart. Each test runs well under 2 s.
import Foundation
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

@MainActor
final class TestSignalAudioSourceTests: XCTestCase {
    private let frames = TestSignalAudioSource.blockFrames

    private func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func stereoSignal() -> TestSignal {
        TestSignal(waveform: .sine, frequency: 440, channelCount: 2, rightRatio: 2)
    }

    /// Reads frames `[start, start + count)` of `buffer`, failing the test when they are not available.
    private func read(_ buffer: StereoSampleBuffer, from start: Int, count: Int) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: count)
        var right = [Float](repeating: 0, count: count)
        XCTAssertEqual(buffer.frames(from: start, count: count, left: &left, right: &right), count)
        return (left, right)
    }

    func testStartWritesFirstBlockAndRunsAtRealTimePace() throws {
        let source = TestSignalAudioSource(signal: stereoSignal())
        let protocolView: any StereoAudioSource = source
        XCTAssertEqual(protocolView.channelCount, 2)
        XCTAssertEqual(protocolView.sampleRate, 48_000)
        XCTAssertEqual(source.state, .idle)
        let buffer = StereoSampleBuffer(capacityFrames: 65_536)
        try source.start(into: buffer)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(buffer.totalFrames, frames, "first block is written synchronously")
        pump(0.25)
        source.stop()
        // 0.25 s at 48 kHz is 12,000 frames; accept generous timer jitter but require the timer to have run.
        XCTAssertGreaterThan(buffer.totalFrames, 2 * frames)
        XCTAssertLessThanOrEqual(buffer.totalFrames, 48_000)
    }

    func testStereoSamplesEqualTheSignalOnBothChannels() throws {
        let signal = stereoSignal()
        let source = TestSignalAudioSource(signal: signal)
        let buffer = StereoSampleBuffer(capacityFrames: 65_536)
        try source.start(into: buffer)
        pump(0.05)
        source.stop()
        let total = buffer.totalFrames
        XCTAssertGreaterThanOrEqual(total, frames)
        let block = read(buffer, from: 0, count: total)
        XCTAssertEqual(block.left, (0..<total).map { signal.value(atFrame: $0, channel: 0) })
        XCTAssertEqual(block.right, (0..<total).map { signal.value(atFrame: $0, channel: 1) })
        XCTAssertNotEqual(block.left, block.right, "ratio 2 gives two different channels")
    }

    func testMonoSignalWritesTheSameSamplesToBothChannels() throws {
        let signal = TestSignal(waveform: .square, frequency: 1_000)
        let source = TestSignalAudioSource(signal: signal)
        XCTAssertEqual(source.channelCount, 1)
        let buffer = StereoSampleBuffer(capacityFrames: 4_096)
        try source.start(into: buffer)
        source.stop()
        let block = read(buffer, from: 0, count: frames)
        XCTAssertEqual(block.left, block.right)
        XCTAssertEqual(block.left, (0..<frames).map { signal.value(atFrame: $0, channel: 0) })
    }

    func testStopMakesIdleAndHaltsWriting() throws {
        let source = TestSignalAudioSource(signal: stereoSignal())
        let buffer = StereoSampleBuffer(capacityFrames: 65_536)
        try source.start(into: buffer)
        pump(0.05)
        source.stop()
        XCTAssertEqual(source.state, .idle)
        let written = buffer.totalFrames
        pump(0.1)
        XCTAssertEqual(buffer.totalFrames, written)
        source.stop()
        XCTAssertEqual(source.state, .idle, "stop is safe when idle")
    }

    func testRestartReplaysFromFrameZero() throws {
        let signal = stereoSignal()
        let source = TestSignalAudioSource(signal: signal)
        let first = StereoSampleBuffer(capacityFrames: 65_536)
        let second = StereoSampleBuffer(capacityFrames: 4_096)
        try source.start(into: first)
        pump(0.05)
        try source.start(into: second)
        source.stop()
        XCTAssertEqual(second.totalFrames, frames)
        let a = read(first, from: 0, count: frames)
        let b = read(second, from: 0, count: frames)
        XCTAssertEqual(a.left, b.left)
        XCTAssertEqual(a.right, b.right)
        XCTAssertEqual(b.right, (0..<frames).map { signal.value(atFrame: $0, channel: 1) })
    }
}
