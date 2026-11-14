// StereoFileAudioSourceTests — feature 061 (A08-P01) T-A08-103 (FR-A08-102; gap G-STEREO): stereo and mono WAV files
// generated at run time keep their channels (stereo: left 440 Hz, right 880 Hz; mono: written to both), loop at
// real-time pace, and a damaged file throws `.undecodable`. No audio file is committed. Each test runs well under 2 s.
import AVFAudio
import Foundation
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

@MainActor
final class StereoFileAudioSourceTests: XCTestCase {
    private static let rate = 48_000.0
    private static let seconds = 0.5
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vc-stereo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private static func sine(_ frequency: Double, _ frame: Int) -> Float {
        0.5 * Float(sin(2 * Double.pi * frequency * Double(frame) / rate))
    }

    /// Writes a 0.5 s, 48 kHz, 32-bit float WAV: left 440 Hz, right 880 Hz (stereo) or 440 Hz only (mono).
    private func writeWAV(name: String, channels: Int) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: Self.rate,
                                       AVNumberOfChannelsKey: channels, AVLinearPCMBitDepthKey: 32,
                                       AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false]
        let frames = AVAudioFrameCount(Self.seconds * Self.rate)
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32,
                                       interleaved: false)
            let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
            pcm.frameLength = frames
            let data = try XCTUnwrap(pcm.floatChannelData)
            for i in 0..<Int(frames) {
                data[0][i] = Self.sine(440, i)
                if channels == 2 { data[1][i] = Self.sine(880, i) }
            }
            try file.write(from: pcm)
        } // The file is closed when it is released here.
        return url
    }

    private func firstBlock(_ buffer: StereoSampleBuffer) -> (left: [Float], right: [Float]) {
        let count = Int(StereoFileAudioSource.blockFrames)
        var left = [Float](repeating: 0, count: count)
        var right = [Float](repeating: 0, count: count)
        XCTAssertEqual(buffer.frames(from: 0, count: count, left: &left, right: &right), count)
        return (left, right)
    }

    func testStereoFileKeepsBothChannels() throws {
        let source = try StereoFileAudioSource(url: writeWAV(name: "stereo.wav", channels: 2))
        XCTAssertEqual(source.channelCount, 2)
        XCTAssertEqual(source.sampleRate, Self.rate)
        XCTAssertEqual(source.frameCount, Int64(Self.seconds * Self.rate))
        let buffer = StereoSampleBuffer(capacityFrames: 65_536)
        try source.start(into: buffer)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(buffer.totalFrames, Int(StereoFileAudioSource.blockFrames), "first block is written synchronously")
        source.stop()
        XCTAssertEqual(source.state, .idle)
        let block = firstBlock(buffer)
        for i in 0..<block.left.count {
            XCTAssertEqual(block.left[i], Self.sine(440, i), accuracy: 1e-4, "left frame \(i)")
            XCTAssertEqual(block.right[i], Self.sine(880, i), accuracy: 1e-4, "right frame \(i)")
        }
        let maxDifference = zip(block.left, block.right).map { abs($0 - $1) }.max() ?? 0
        XCTAssertGreaterThan(maxDifference, 0.1, "left and right stay different channels")
    }

    func testMonoFileIsWrittenToBothChannels() throws {
        let source = try StereoFileAudioSource(url: writeWAV(name: "mono.wav", channels: 1))
        XCTAssertEqual(source.channelCount, 1)
        let buffer = StereoSampleBuffer(capacityFrames: 65_536)
        try source.start(into: buffer)
        source.stop()
        let block = firstBlock(buffer)
        XCTAssertEqual(block.left, block.right)
        for i in 0..<block.left.count {
            XCTAssertEqual(block.left[i], Self.sine(440, i), accuracy: 1e-4, "frame \(i)")
        }
    }

    func testFileLoopsAtRealTimePaceAndStopHaltsWriting() throws {
        let source = try StereoFileAudioSource(url: writeWAV(name: "loop.wav", channels: 2))
        let buffer = StereoSampleBuffer(capacityFrames: 131_072)
        try source.start(into: buffer)
        pump(0.7)
        source.stop()
        // 0.7 s at 48 kHz is 33,600 frames, more than the 24,000-frame file: writing continued past its end.
        XCTAssertGreaterThan(buffer.totalFrames, Int(Self.seconds * Self.rate), "writing continues after the file length")
        let written = buffer.totalFrames
        pump(0.1)
        XCTAssertEqual(buffer.totalFrames, written, "stop halts writing")
    }

    func testDamagedFileThrowsUndecodable() throws {
        var generator = StereoFixtureBytes(state: 0x5EED_0061)
        let bytes = (0..<8_192).map { _ in UInt8(truncatingIfNeeded: generator.next()) }
        let url = directory.appendingPathComponent("damaged.wav")
        try Data(bytes).write(to: url)
        XCTAssertThrowsError(try StereoFileAudioSource(url: url)) { error in
            guard case AudioSourceError.undecodable = error else {
                return XCTFail("expected undecodable, got \(error)")
            }
        }
    }
}

/// Deterministic byte source for the damaged-file fixture (SplitMix64).
private struct StereoFixtureBytes {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
