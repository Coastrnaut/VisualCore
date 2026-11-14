// DemoAudioSource — feature 047 T-A06-103 (FR-A06-102; gap G-AUDIOSOURCE): the seeded demo signal played at
// real-time pace, no file and no permission. Gaps G-MICPERMISSION and G-FILESOURCE are closed by the sibling files.
import Foundation
import VisualCoreAudioDSP

/// A deterministic source that renders a `DemoSignal` in blocks of 1,024 frames at real-time pace (FR-A06-102).
///
/// A main-run-loop timer computes how many frames are due since start and renders whole blocks to catch up, so the
/// output is the same sample sequence for the same seed whatever the timer jitter. The first block is written
/// synchronously by `start(into:)`.
@MainActor
public final class DemoAudioSource: AudioSource {
    /// Frames rendered per block.
    public static let blockFrames = 1_024

    /// Sample rate of the demo signal (the signal's own rate, 48 kHz by default).
    public let sampleRate: Double
    /// Current lifecycle state.
    public private(set) var state: AudioSourceState = .idle

    private let initialSignal: DemoSignal
    private var signal: DemoSignal
    private var scratch: [Float]
    private var buffer: SampleRingBuffer?
    private var timer: Timer?
    private var startTime: TimeInterval = 0
    private var framesWritten = 0

    /// Creates a demo source for `signal`; every start replays the signal from its initial state.
    public init(signal: DemoSignal) {
        self.initialSignal = signal
        self.signal = signal
        self.sampleRate = signal.sampleRate
        self.scratch = [Float](repeating: 0, count: Self.blockFrames)
    }

    isolated deinit { timer?.invalidate() }

    /// Starts rendering into `buffer`, writing the first block immediately.
    public func start(into buffer: SampleRingBuffer) throws {
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
        guard let buffer else { return }
        scratch.withUnsafeMutableBufferPointer { out in
            signal.render(into: out)
            buffer.write(UnsafeBufferPointer(out))
        }
        framesWritten += Self.blockFrames
    }
}
