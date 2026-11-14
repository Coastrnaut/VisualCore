// FileAudioSource — feature 047 T-A06-103 (FR-A06-103, FR-A06-105; gap G-FILESOURCE): a person-picked file decoded
// in 4,096-frame chunks to mono Float and looped at real-time pace. Gaps G-AUDIOSOURCE and G-MICPERMISSION are closed
// by the sibling files.
import AVFAudio
import Foundation
import VisualCoreAudioDSP

/// A source that plays any file `AVAudioFile` can decode (WAV, AIFF, CAF, M4A/AAC, MP3), looped (FR-A06-103).
///
/// The file is opened in `init` to validate it, so an undecodable file throws there. `start(into:)` writes the first
/// chunk synchronously; a main-run-loop timer then writes further chunks whenever the elapsed time is due, keeping
/// real-time pace. At the end of the file the read position returns to frame 0. The file is read in place, never
/// copied, and nothing is written to disk (FR-A06-105). Security-scoped access (files from the system importer) is
/// held from `init` until the source is released.
@MainActor
public final class FileAudioSource: AudioSource {
    /// Frames decoded per chunk.
    public static let chunkFrames: AVAudioFrameCount = 4_096

    /// The file's sample rate, in hertz.
    public let sampleRate: Double
    /// Number of frames in the file.
    public let frameCount: Int64
    /// Number of channels in the file (mixed down to mono when written).
    public let channelCount: Int
    /// The file being played.
    public let url: URL
    /// Current lifecycle state.
    public private(set) var state: AudioSourceState = .idle

    private let file: AVAudioFile
    private let pcm: AVAudioPCMBuffer
    private var mono: [Float]
    private let scopedAccess: Bool
    private var buffer: SampleRingBuffer?
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
                  let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: Self.chunkFrames) else {
                throw AudioSourceError.undecodable(url.lastPathComponent)
            }
            self.file = file
            self.pcm = pcm
            self.sampleRate = format.sampleRate
            self.frameCount = file.length
            self.channelCount = Int(format.channelCount)
        } catch let error as AudioSourceError {
            if scoped { url.stopAccessingSecurityScopedResource() }
            throw error
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            throw AudioSourceError.undecodable(url.lastPathComponent)
        }
        self.scopedAccess = scoped
        self.mono = [Float](repeating: 0, count: Int(Self.chunkFrames))
    }

    isolated deinit {
        timer?.invalidate()
        if scopedAccess { url.stopAccessingSecurityScopedResource() }
    }

    /// Starts playing from the beginning of the file into `buffer`, writing the first chunk immediately.
    public func start(into buffer: SampleRingBuffer) throws {
        stop()
        self.buffer = buffer
        file.framePosition = 0
        framesWritten = 0
        startTime = ProcessInfo.processInfo.systemUptime
        try writeChunk()
        state = .running
        let timer = Timer(timeInterval: 1_024 / sampleRate, repeats: true) { [weak self] _ in
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
        var chunks = 0
        while framesWritten <= due, chunks < 4 {
            do { try writeChunk() } catch {
                stop()
                state = .failed("\(error)")
                return
            }
            chunks += 1
        }
    }

    /// Decodes one full chunk (wrapping to frame 0 at the end), mixes it to mono and writes it.
    private func writeChunk() throws {
        // vc:hot-path begin
        guard let buffer else { return }
        var filled = 0
        let target = Int(Self.chunkFrames)
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
            mixDown(frames: got, at: filled)
            filled += got
            if file.framePosition >= file.length { file.framePosition = 0 }
        }
        mono.withUnsafeBufferPointer { buffer.write(UnsafeBufferPointer(rebasing: $0[0..<filled])) }
        framesWritten += filled
        // vc:hot-path end
    }

    private func mixDown(frames: Int, at offset: Int) {
        // vc:hot-path begin
        guard let channels = pcm.floatChannelData else { return }
        let count = channelCount
        let scale = 1 / Float(count)
        mono.withUnsafeMutableBufferPointer { out in
            for frame in 0..<frames {
                var sum: Float = 0
                for channel in 0..<count { sum += channels[channel][frame] }
                out[offset + frame] = sum * scale
            }
        }
        // vc:hot-path end
    }
}
