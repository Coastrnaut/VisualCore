// StereoSampleBuffer — feature 061 (A08-P01) T-A08-102 (FR-A08-102, FR-A08-104); gap G-STEREO (DSP part).
// Spec Clarifications (new types beside SampleRingBuffer); data-model.md; contract specs/061-os-p01-acquisition/contracts/api.md.
import Synchronization

/// A preallocated single-writer, lock-free ring buffer of two-channel `Float` frames, read by absolute frame position.
///
/// Frames are stored interleaved (left, right). The writer calls ``write(left:right:)`` (a mono writer passes the same
/// samples twice); readers call ``frames(from:count:left:right:)`` or ``latestFrames(_:left:right:)``. The writer never
/// blocks, never allocates and overwrites the oldest frames when the buffer is full.
///
/// Two `Atomic<Int>` counters coordinate the threads in the manner of a sequence lock: before a block is copied the
/// writer publishes the frame count it is about to reach (``reserved``), and after the whole block is copied it
/// publishes ``totalFrames`` with release ordering. A reader loads ``totalFrames`` with acquire ordering before copying
/// and checks the reserved count after copying (behind an acquire fence); if the writer reached the copied range in
/// the meantime the read reports 0 frames instead of torn data.
///
/// Only one writer at a time is supported. `@unchecked Sendable` is justified because the storage is allocated once
/// in `init`, never reallocated, released only in `deinit`, and every cross-thread hand-over goes through the atomic
/// counters under the single-writer discipline documented above.
public final class StereoSampleBuffer: @unchecked Sendable {
    /// Smallest capacity in frames.
    public static let minimumCapacityFrames = 1_024
    /// Largest capacity in frames.
    public static let maximumCapacityFrames = 131_072

    /// Number of frames the buffer holds: a power of two between ``minimumCapacityFrames`` and
    /// ``maximumCapacityFrames``.
    public let capacityFrames: Int
    private let mask: Int
    private let storage: UnsafeMutablePointer<Float>
    private let written = Atomic<Int>(0)
    private let reserved = Atomic<Int>(0)

    /// Creates a buffer holding at least `capacityFrames` frames.
    ///
    /// - Parameter capacityFrames: requested size; clamped to 1,024…131,072 and rounded up to the next power of two.
    public init(capacityFrames: Int) {
        let clamped = min(max(capacityFrames, Self.minimumCapacityFrames), Self.maximumCapacityFrames)
        var size = Self.minimumCapacityFrames
        while size < clamped { size <<= 1 }
        self.capacityFrames = size
        self.mask = size - 1
        self.storage = UnsafeMutablePointer<Float>.allocate(capacity: 2 * size)
        self.storage.initialize(repeating: 0, count: 2 * size)
    }

    deinit {
        storage.deinitialize(count: 2 * capacityFrames)
        storage.deallocate()
    }

    /// Total number of frames ever written (acquire load); grows without wrapping for the life of the buffer.
    public var totalFrames: Int { written.load(ordering: .acquiring) }

    /// Appends one block of frames. Writer thread only.
    ///
    /// `left` and `right` must have equal lengths; otherwise nothing is written. A mono writer may pass the same
    /// buffer twice. When more than ``capacityFrames`` frames are passed only the newest ``capacityFrames`` are
    /// copied, but ``totalFrames`` still advances by the full count. The frame counter is published after the whole
    /// block is copied. Never blocks and never allocates.
    /// - Parameters:
    ///   - left: left-channel samples, oldest first.
    ///   - right: right-channel samples, oldest first.
    public func write(left: UnsafeBufferPointer<Float>, right: UnsafeBufferPointer<Float>) {
        let count = left.count
        guard count > 0, right.count == count, let l = left.baseAddress, let r = right.baseAddress else { return }
        let total = written.load(ordering: .relaxed)   // only this (single) writer stores the counter
        let end = total + count
        reserved.store(end, ordering: .relaxed)
        atomicMemoryFence(ordering: .releasing)         // the reservation is visible before any storage write
        let skip = max(0, count - capacityFrames)
        for i in skip..<count {
            let slot = ((total + i) & mask) << 1
            storage[slot] = l[i]
            storage[slot + 1] = r[i]
        }
        written.store(end, ordering: .releasing)
    }

    /// Convenience for ``write(left:right:)`` with arrays.
    ///
    /// - Parameters:
    ///   - left: left-channel samples, oldest first.
    ///   - right: right-channel samples, oldest first (same count as `left`).
    public func write(left: [Float], right: [Float]) {
        left.withUnsafeBufferPointer { l in
            right.withUnsafeBufferPointer { r in write(left: l, right: r) }
        }
    }

    /// Copies frames `[start, start + count)` into `left` and `right` when they are entirely written and still held.
    ///
    /// The range must satisfy `start ≥ totalFrames − capacityFrames` and `start + count ≤ totalFrames`; otherwise,
    /// or when the writer overwrote part of the range during the copy, nothing valid is returned and the result is 0.
    /// On success the frames occupy `left[0..<count]` and `right[0..<count]`; each array is grown only when it is
    /// shorter than `count`, so preallocated arrays keep the read path free of allocation.
    /// - Parameters:
    ///   - start: absolute index of the first frame.
    ///   - count: number of frames wanted.
    ///   - left: receives the left channel.
    ///   - right: receives the right channel.
    /// - Returns: `count` on success, else 0.
    @discardableResult
    public func frames(from start: Int, count: Int, left: inout [Float], right: inout [Float]) -> Int {
        guard count > 0, start >= 0 else { return 0 }
        let total = written.load(ordering: .acquiring)
        guard start + count <= total, start >= total - capacityFrames else { return 0 }
        if left.count < count { left.append(contentsOf: repeatElement(0, count: count - left.count)) }
        if right.count < count { right.append(contentsOf: repeatElement(0, count: count - right.count)) }
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                for i in 0..<count {
                    let slot = ((start + i) & mask) << 1
                    l[i] = storage[slot]
                    r[i] = storage[slot + 1]
                }
            }
        }
        atomicMemoryFence(ordering: .acquiring)          // the copy completes before the re-check
        let after = reserved.load(ordering: .relaxed)
        guard start >= after - capacityFrames else { return 0 }
        return count
    }

    /// Copies up to `count` of the newest frames, oldest first, into `left[0..<n]` and `right[0..<n]`.
    ///
    /// - Parameters:
    ///   - count: the number of frames wanted; limited to ``capacityFrames`` and ``totalFrames``.
    ///   - left: receives the left channel.
    ///   - right: receives the right channel.
    /// - Returns: the number of frames copied (0 when none are written or the read was overwritten).
    @discardableResult
    public func latestFrames(_ count: Int, left: inout [Float], right: inout [Float]) -> Int {
        let total = written.load(ordering: .acquiring)
        let n = min(max(count, 0), capacityFrames, total)
        guard n > 0 else { return 0 }
        return frames(from: total - n, count: n, left: &left, right: &right)
    }
}
