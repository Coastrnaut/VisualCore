// StereoFileAudioSource — feature 061 (A08-P01) T-A08-103 (FR-A08-102; gap G-STEREO): a person-picked file decoded
// to deinterleaved Float that keeps its first two channels (a mono file is written to both) and is looped at
// real-time pace into a `StereoSampleBuffer`. Decoding and pacing mirror `FileAudioSource`; blocks are 1,024 frames
// with at most eight blocks of catch-up per tick, like `TestSignalAudioSource`.
// Contract specs/061-os-p01-acquisition/contracts/api.md.
import AVFAudio
import Foundation
import VisualCoreAudioDSP

/// A two-channel source that plays any file `AVAudioFile` can decode (WAV, AIFF, CAF, M4A/AAC, MP3), looped
/// (FR-A08-102).
///
/// The file is opened in `init` to validate it, so an undecodable file throws there. A file with two or more channels
/// keeps its first two (``channelCount`` 2, further channels are ignored); a mono file reports ``channelCount`` 1 and
/// writes the same samples to both buffer channels. `start(into:)` writes the first block synchronously; a
/// main-run-loop timer then writes further blocks whenever the elapsed time is due, keeping real-time pace. At the end
/// of the file the read position returns to frame 0. The file is read in place, never copied, and nothing is written
/// to disk. Security-scoped access (files from the system importer) is held from `init` until the source is released.
@MainActor
public final class StereoFileAudioSource: StereoAudioSource {
    /// Frames decoded and written per block.
    public static let blockFrames: AVAudioFrameCount = 1_024

    /// The file's sample rate, in hertz.
    public let sampleRate: Double
    /// Number of frames in the file.
    public let frameCount: Int64
    /// Number of channels written: 2 for a file with two or more channels, 1 for a mono file.
    public let channelCount: Int
    /// The file being played.
    public let url: URL
    /// Current lifecycle state.
    public private(set) var state: AudioSourceState = .idle

    private let file: AVAudioFile
    private let pcm: AVAudioPCMBuffer
    private var left: [Float]
    private var right: [Float]
    private let scopedAccess: Bool
    private var buffer: StereoSampleBuffer?
    private var timer: Timer?
    private var startTime: TimeInterval = 0
    private var framesWritten = 0

    /// Opens `url` for decoding.
    /// - Throws: `AudioSourceError.undecodable` when the file cannot be opened, is empty, or has no channels.
    public init(url: URL) throws {
        self.url = url
        let scoped = url.startAccessingSecurityScopedResource()
        do {
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            let format = file.processingFormat
            guard file.length > 0, format.channelCount > 0, format.sampleRate > 0,
                  let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: Self.blockFrames) else {
                throw AudioSourceError.undecodable(url.lastPathComponent)
            }
            self.file = file
            self.pcm = pcm
            self.sampleRate = format.sampleRate
            self.frameCount = file.length
            self.channelCount = min(Int(format.channelCount), 2)
        } catch let error as AudioSourceError {
            if scoped { url.stopAccessingSecurityScopedResource() }
            throw error
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            throw AudioSourceError.undecodable(url.lastPathComponent)
        }
        self.scopedAccess = scoped
        self.left = [Float](repeating: 0, count: Int(Self.blockFrames))
        self.right = [Float](repeating: 0, count: Int(Self.blockFrames))
    }

    isolated deinit {
        timer?.invalidate()
        if scopedAccess { url.stopAccessingSecurityScopedResource() }
    }

    /// Starts playing from the beginning of the file into `buffer`, writing the first block immediately.
    public func start(into buffer: StereoSampleBuffer) throws {
        stop()
        self.buffer = buffer
        file.framePosition = 0
        framesWritten = 0
        startTime = ProcessInfo.processInfo.systemUptime
        try writeBlock()
        state = .running
        let timer = Timer(timeInterval: Double(Self.blockFrames) / sampleRate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stops playing. Safe to call when idle.
    public func stop() {
        timer?.invalidate()
        timer = nil
        buffer = nil
        if case .failed = state { return }
        state = .idle
    }

    private func tick() {
        let due = Int((ProcessInfo.processInfo.systemUptime - startTime) * sampleRate)
        // Catch up at most eight blocks per tick so a long stall does not burst.
        var blocks = 0
        while framesWritten <= due, blocks < 8 {
            do { try writeBlock() } catch {
                stop()
                state = .failed("\(error)")
                return
            }
            blocks += 1
        }
    }

    /// Decodes one full block (wrapping to frame 0 at the end), copies the first two channels and writes them.
    private func writeBlock() throws {
        // vc:hot-path begin
        guard let buffer else { return }
        var filled = 0
        let target = Int(Self.blockFrames)
        var emptyReads = 0
        while filled < target {
            let want = AVAudioFrameCount(target - filled)
            do { try file.read(into: pcm, frameCount: want) } catch {
                throw AudioSourceError.undecodable(url.lastPathComponent) // vc:cold
            }
            let got = Int(pcm.frameLength)
            if got == 0 {
                emptyReads += 1
                if emptyReads > 1 { throw AudioSourceError.undecodable(url.lastPathComponent) } // vc:cold
                file.framePosition = 0
                continue
            }
            emptyReads = 0
            copyChannels(frames: got, at: filled)
            filled += got
            if file.framePosition >= file.length { file.framePosition = 0 }
        }
        if channelCount == 2 {
            left.withUnsafeBufferPointer { l in
                right.withUnsafeBufferPointer { r in
                    buffer.write(left: UnsafeBufferPointer(rebasing: l[0..<filled]),
                                 right: UnsafeBufferPointer(rebasing: r[0..<filled]))
                }
            }
        } else {
            left.withUnsafeBufferPointer { l in
                let mono = UnsafeBufferPointer(rebasing: l[0..<filled])
                buffer.write(left: mono, right: mono)
            }
        }
        framesWritten += filled
        // vc:hot-path end
    }

    private func copyChannels(frames: Int, at offset: Int) {
        // vc:hot-path begin
        guard let channels = pcm.floatChannelData else { return }
        let source0 = channels[0]
        left.withUnsafeMutableBufferPointer { out in
            for frame in 0..<frames { out[offset + frame] = source0[frame] }
        }
        guard channelCount == 2 else { return }
        let source1 = channels[1]
        right.withUnsafeMutableBufferPointer { out in
            for frame in 0..<frames { out[offset + frame] = source1[frame] }
        }
        // vc:hot-path end
    }
}
