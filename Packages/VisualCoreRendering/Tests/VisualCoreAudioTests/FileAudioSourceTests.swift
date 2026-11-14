// FileAudioSourceTests — feature 047 T-A06-103 (FR-A06-103, FR-A06-105; gap G-FILESOURCE): original WAV, CAF and
// M4A (AAC) tones generated at run time decode at their rate, carry a 440 Hz tone, loop past their end, and an
// undecodable file throws. Each test runs well under 3 s.
import AVFAudio
import Foundation
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

@MainActor
final class FileAudioSourceTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vc-audio-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private enum Kind { case wav, caf, m4a }

    /// Writes `seconds` of a 440 Hz sine at 44.1 kHz, mono, amplitude 0.5.
    private func writeTone(_ kind: Kind, seconds: Double = 1) throws -> URL {
        let rate = 44_100.0
        let name: String
        var settings: [String: Any] = [AVSampleRateKey: rate, AVNumberOfChannelsKey: 1]
        switch kind {
        case .wav:
            name = "tone.wav"
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = false
        case .caf:
            name = "tone.caf"
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = 32
            settings[AVLinearPCMIsFloatKey] = true
            settings[AVLinearPCMIsBigEndianKey] = false
        case .m4a:
            name = "tone.m4a"
            settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        }
        let url = directory.appendingPathComponent(name)
        let frames = AVAudioFrameCount(seconds * rate)
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32,
                                       interleaved: false)
            let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
            pcm.frameLength = frames
            let samples = try XCTUnwrap(pcm.floatChannelData)[0]
            for i in 0..<Int(frames) { samples[i] = 0.5 * Float(sin(2 * Double.pi * 440 * Double(i) / rate)) }
            try file.write(from: pcm)
        } // The file is closed (and the AAC encoder flushed) when it is released here.
        return url
    }

    /// Estimates the frequency from positive-going zero crossings of the latest 4,096 samples.
    private func dominantFrequency(_ buffer: SampleRingBuffer, sampleRate: Double) -> Double {
        var samples = [Float](repeating: 0, count: 4_096)
        let n = buffer.latest(4_096, into: &samples)
        var crossings = 0
        for i in 1..<n where samples[i - 1] < 0 && samples[i] >= 0 { crossings += 1 }
        return Double(crossings) / (Double(n) / sampleRate)
    }

    private func checkDecodes(_ kind: Kind) throws {
        let url = try writeTone(kind)
        let source = try FileAudioSource(url: url)
        XCTAssertEqual(source.sampleRate, 44_100)
        XCTAssertEqual(source.channelCount, 1)
        // PCM is exact; AAC may differ by encoder priming/remainder frames.
        XCTAssertEqual(Double(source.frameCount), 44_100, accuracy: kind == .m4a ? 2_048 : 0)
        let buffer = SampleRingBuffer(capacity: 65_536)
        try source.start(into: buffer)
        XCTAssertEqual(source.state, .running)
        XCTAssertEqual(buffer.totalWritten, Int(FileAudioSource.chunkFrames), "first chunk is written synchronously")
        pump(0.2)
        source.stop()
        XCTAssertEqual(source.state, .idle)
        XCTAssertGreaterThan(buffer.totalWritten, Int(FileAudioSource.chunkFrames))
        XCTAssertEqual(dominantFrequency(buffer, sampleRate: source.sampleRate), 440, accuracy: 30)
    }

    func testWAVDecodes() throws { try checkDecodes(.wav) }
    func testCAFDecodes() throws { try checkDecodes(.caf) }
    func testM4ADecodes() throws { try checkDecodes(.m4a) }

    func testShortFileLoopsPastItsEnd() throws {
        let url = try writeTone(.wav, seconds: 0.1)
        let source = try FileAudioSource(url: url)
        XCTAssertEqual(source.frameCount, 4_410)
        let buffer = SampleRingBuffer(capacity: 65_536)
        try source.start(into: buffer)
        pump(0.3)
        source.stop()
        XCTAssertGreaterThan(buffer.totalWritten, 2 * 4_410, "writing continues after the file length")
        XCTAssertEqual(dominantFrequency(buffer, sampleRate: source.sampleRate), 440, accuracy: 30)
        let written = buffer.totalWritten
        pump(0.1)
        XCTAssertEqual(buffer.totalWritten, written, "stop halts writing")
    }

    func testGarbageFileThrows() throws {
        var generator = SplitMix(state: 0x5EED)
        let bytes = (0..<8_192).map { _ in UInt8(truncatingIfNeeded: generator.next()) }
        for name in ["garbage.wav", "garbage.m4a", "garbage.caf"] {
            let url = directory.appendingPathComponent(name)
            try Data(bytes).write(to: url)
            XCTAssertThrowsError(try FileAudioSource(url: url), name) { error in
                guard case AudioSourceError.undecodable = error else {
                    return XCTFail("expected undecodable, got \(error)")
                }
            }
        }
    }

    func testMissingFileThrows() {
        XCTAssertThrowsError(try FileAudioSource(url: directory.appendingPathComponent("absent.wav")))
    }
}

/// Deterministic byte source for the garbage fixture.
private struct SplitMix {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
