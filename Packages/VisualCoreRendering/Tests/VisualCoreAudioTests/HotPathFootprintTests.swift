// HotPathFootprintTests — feature 049 (A06-P03) T-A06-310 (SC-A06-305; analyze U1): after one warm-up block,
// 1,000 blocks through the demo source's per-block work and 1,000 calls of the microphone tap sink fed one
// preallocated `AVAudioPCMBuffer` change the process footprint (`phys_footprint`) by at most 64 KiB.
//
// The footprint bounds growth, not transient allocations: an allocation freed within the same block would not show
// here. The construct rule (no allocating constructs on the audio hot path) is enforced on the source by the
// repository check `scripts/check_audio_hot_path.py`; this test is the run-time complement. The footprint is read
// with `task_info(TASK_VM_INFO)` exactly as `ProcessMemory.footprint()` does, because this test target does not
// depend on VisualCoreRendering. Each test runs well under 2 s.
import AVFoundation
import Darwin
import Foundation
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

/// The physical footprint of the process in bytes, or nil when the system does not give it (mirrors
/// `ProcessMemory.footprint()` in VisualCoreRendering).
private func physFootprint() -> Int? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
        }
    }
    guard result == KERN_SUCCESS else { return nil }
    let bytes = info.phys_footprint
    guard bytes > 0, bytes <= UInt64(Int.max) else { return nil }
    return Int(bytes)
}

@MainActor
final class HotPathFootprintTests: XCTestCase {
    /// Allowed footprint growth over 1,000 blocks.
    private static let maxGrowth = 64 * 1_024
    /// Blocks measured after the warm-up.
    private static let blocks = 1_000

    /// The demo source's block path (`renderBlock`) is private and timer-driven. The test checks once through the
    /// public API that `start(into:)` writes one block, then repeats the exact per-block work `renderBlock` does —
    /// `DemoSignal.render(into:)` into a preallocated scratch plus `SampleRingBuffer.write` — 1,000 times, which is
    /// deterministic and needs no timer.
    func testDemoBlockPathDoesNotGrowFootprint() throws {
        let frames = DemoAudioSource.blockFrames
        let source = DemoAudioSource(signal: DemoSignal(seed: 1, mode: .tone440))
        let sourceBuffer = SampleRingBuffer(capacity: 16_384)
        try source.start(into: sourceBuffer)
        source.stop()
        XCTAssertEqual(sourceBuffer.totalWritten, frames, "start(into:) writes the first block synchronously")

        var signal = DemoSignal(seed: 1, mode: .tone440)
        let ring = SampleRingBuffer(capacity: 16_384)
        let scratch = UnsafeMutableBufferPointer<Float>.allocate(capacity: frames)
        scratch.initialize(repeating: 0)
        defer { scratch.deallocate() }

        // Warm-up block.
        signal.render(into: scratch)
        ring.write(UnsafeBufferPointer(scratch))
        let writtenBefore = ring.totalWritten
        let before = try XCTUnwrap(physFootprint())

        for _ in 0..<Self.blocks {
            signal.render(into: scratch)
            ring.write(UnsafeBufferPointer(scratch))
        }

        let after = try XCTUnwrap(physFootprint())
        XCTAssertEqual(ring.totalWritten - writtenBefore, Self.blocks * frames)
        XCTAssertLessThanOrEqual(after - before, Self.maxGrowth,
                                 "demo block path grew the footprint by \(after - before) bytes")
    }

    /// `MicrophoneAudioSource.makeTapBlock` is private; the tap block only calls `MicrophoneTapSink.consume(_:)`,
    /// so the sink is driven directly with one preallocated 48 kHz stereo non-interleaved buffer.
    func testMicrophoneTapSinkDoesNotGrowFootprint() throws {
        let frames = 1_024
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        XCTAssertFalse(format.isInterleaved)
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        pcm.frameLength = AVAudioFrameCount(frames)
        let channels = try XCTUnwrap(pcm.floatChannelData)
        for frame in 0..<frames {
            let value = Float(sin(2 * Double.pi * 440 * Double(frame) / 48_000))
            channels[0][frame] = value
            channels[1][frame] = value
        }
        let ring = SampleRingBuffer(capacity: 16_384)
        let sink = MicrophoneTapSink(buffer: ring)

        // Warm-up block.
        sink.consume(pcm)
        let writtenBefore = ring.totalWritten
        let before = try XCTUnwrap(physFootprint())

        for _ in 0..<Self.blocks {
            sink.consume(pcm)
        }

        let after = try XCTUnwrap(physFootprint())
        XCTAssertEqual(ring.totalWritten - writtenBefore, Self.blocks * frames)
        XCTAssertLessThanOrEqual(after - before, Self.maxGrowth,
                                 "microphone tap sink grew the footprint by \(after - before) bytes")
    }
}
