// SampleRingBuffer — feature 047 (A06-P01) T-A06-102; gap G-RINGBUFFER (and G-AUDIODSP, minimal).
// Research D1; contract specs/047-ml-p01-audio-source/contracts/api.md.
import Synchronization

/// A preallocated single-producer, single-consumer ring buffer of mono `Float` samples.
///
/// The audio side (one producer thread) calls ``write(_:)``; the render side (one consumer thread) calls
/// ``latest(_:into:)``. The writer never blocks, never allocates and overwrites the oldest samples when the buffer is
/// full. The only shared index is ``totalWritten``, an `Atomic<Int>` stored with release ordering after the samples
/// are copied and loaded with acquire ordering before they are read, so a reader always sees the samples that the
/// counter it read covers.
///
/// Using more than one producer or more than one consumer at the same time is not supported. A reader that lags the
/// writer by almost a whole capacity may see a few samples that were overwritten while it copied them; for
/// visualisation this is acceptable and it never touches memory outside the buffer.
///
/// `@unchecked Sendable` is justified because the storage is allocated once in `init`, never reallocated, released
/// only in `deinit`, and every cross-thread hand-over goes through the acquire/release atomic counter under the
/// single-producer, single-consumer discipline documented above.
public final class SampleRingBuffer: @unchecked Sendable {
    /// Smallest capacity in samples.
    public static let minimumCapacity = 1_024
    /// Largest capacity in samples.
    public static let maximumCapacity = 262_144

    /// Number of samples the buffer holds: a power of two between ``minimumCapacity`` and ``maximumCapacity``.
    public let capacity: Int
    private let mask: Int
    private let storage: UnsafeMutablePointer<Float>
    private let written = Atomic<Int>(0)

    /// Creates a buffer holding at least `capacity` samples.
    ///
    /// - Parameter capacity: requested size; clamped to 1,024…262,144 and rounded up to the next power of two.
    public init(capacity: Int) {
        let clamped = min(max(capacity, Self.minimumCapacity), Self.maximumCapacity)
        var size = Self.minimumCapacity
        while size < clamped { size <<= 1 }
        self.capacity = size
        self.mask = size - 1
        self.storage = UnsafeMutablePointer<Float>.allocate(capacity: size)
        self.storage.initialize(repeating: 0, count: size)
    }

    deinit {
        storage.deinitialize(count: capacity)
        storage.deallocate()
    }

    /// Total number of samples ever written (acquire load); grows without wrapping for the life of the buffer.
    public var totalWritten: Int { written.load(ordering: .acquiring) }

    /// Appends `samples`, overwriting the oldest samples when the buffer is full. Producer thread only.
    ///
    /// Never blocks and never allocates: when more than ``capacity`` samples are passed, only the newest
    /// ``capacity`` are copied.
    /// - Parameter samples: the samples to append, oldest first.
    public func write(_ samples: UnsafeBufferPointer<Float>) {
        guard let base = samples.baseAddress, samples.count > 0 else { return }
        let count = samples.count
        let total = written.load(ordering: .relaxed)   // only this (single) producer stores the counter
        let skip = max(0, count - capacity)
        let n = count - skip
        let start = (total + skip) & mask
        let first = min(n, capacity - start)
        (storage + start).update(from: base + skip, count: first)
        if n > first {
            storage.update(from: base + skip + first, count: n - first)
        }
        written.store(total + count, ordering: .releasing)
    }

    /// Copies up to `count` of the newest samples into `out`, oldest first. Consumer thread only.
    ///
    /// The number copied is `min(count, capacity, totalWritten)`; the samples occupy `out[0..<copied]`. `out` is
    /// grown only when it is shorter than that number, so a caller that preallocates `out` with at least `count`
    /// elements keeps the read path free of allocation. Elements past the copied range are left unchanged.
    /// - Parameters:
    ///   - count: the number of samples wanted.
    ///   - out: the destination array.
    /// - Returns: the number of samples copied.
    @discardableResult
    public func latest(_ count: Int, into out: inout [Float]) -> Int {
        let total = written.load(ordering: .acquiring)
        let n = min(max(count, 0), capacity, total)
        guard n > 0 else { return 0 }
        if out.count < n { out.append(contentsOf: repeatElement(0, count: n - out.count)) }
        let start = (total - n) & mask
        let first = min(n, capacity - start)
        out.withUnsafeMutableBufferPointer { dst in
            guard let d = dst.baseAddress else { return }
            d.update(from: storage + start, count: first)
            if n > first { (d + first).update(from: storage, count: n - first) }
        }
        return n
    }
}
