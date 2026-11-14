// TestSignalAudioSource — feature 061 (A08-P01) T-A08-103 (FR-A08-102; gap G-STEREO): the deterministic `TestSignal`
// played at real-time pace into a `StereoSampleBuffer`, no file and no permission. Pacing mirrors `DemoAudioSource`.
// Contract specs/061-os-p01-acquisition/contracts/api.md.
import Foundation
import VisualCoreAudioDSP

/// A deterministic two-channel source that renders a `TestSignal` in blocks of 1,024 frames at real-time pace
/// (FR-A08-102).
///
/// A main-run-loop timer computes how many frames are due since start and renders whole blocks to catch up (at most
/// eight per tick), so the output is the same sample sequence for the same signal whatever the timer jitter. The
/// first block is written synchronously by `start(into:)`, and every start replays the signal from its initial state.
/// A mono signal writes the same samples to both channels of the buffer.
@MainActor
public final class TestSignalAudioSource: StereoAudioSource {
    /// Frames rendered per block.
    public static let blockFrames = 1_024

    /// Sample rate of the test signal (the signal's own rate).
    public let sampleRate: Double
    /// Number of channels of the signal: 1 or 2.
    public let channelCount: Int
    /// Current lifecycle state.
    public private(set) var state: AudioSourceState = .idle

    private let initialSignal: TestSignal
    private var signal: TestSignal
    private var left: [Float]
    private var right: [Float]
    private var buffer: StereoSampleBuffer?
    private var timer: Timer?
    private var startTime: TimeInterval = 0
    private var framesWritten = 0

    /// Creates a source for `signal`; every start replays the signal from its initial state.
    public init(signal: TestSignal) {
        self.initialSignal = signal
        self.signal = signal
        self.sampleRate = signal.sampleRate
        self.channelCount = signal.channelCount
        self.left = [Float](repeating: 0, count: Self.blockFrames)
        self.right = [Float](repeating: 0, count: Self.blockFrames)
    }

    isolated deinit { timer?.invalidate() }

    /// Starts rendering into `buffer` from the signal's first frame, writing the first block immediately.
    public func start(into buffer: StereoSampleBuffer) throws {
        stop()
        self.buffer = buffer
        signal = initialSignal
        framesWritten = 0
        startTime = ProcessInfo.processInfo.systemUptime
        renderBlock()
        state = .running
        let interval = Double(Self.blockFrames) / sampleRate
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stops rendering. Safe to call when idle.
    public func stop() {
        timer?.invalidate()
        timer = nil
        buffer = nil
        state = .idle
    }

    private func tick() {
        let due = Int((ProcessInfo.processInfo.systemUptime - startTime) * sampleRate)
        // Catch up at most eight blocks per tick so a long stall does not burst.
        var blocks = 0
        while framesWritten <= due, blocks < 8 {
            renderBlock()
            blocks += 1
        }
    }

    private func renderBlock() {
        // vc:hot-path begin
        guard let buffer else { return }
        // The scratch arrays already hold `blockFrames` elements, so `render` does not reallocate them.
        signal.render(frames: Self.blockFrames, left: &left, right: &right)
        if channelCount == 2 {
            left.withUnsafeBufferPointer { l in
                right.withUnsafeBufferPointer { r in buffer.write(left: l, right: r) }
            }
        } else {
            left.withUnsafeBufferPointer { l in buffer.write(left: l, right: l) }
        }
        framesWritten += Self.blockFrames
        // vc:hot-path end
    }
}
