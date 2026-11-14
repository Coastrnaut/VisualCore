// SlotPool — feature 055 (A07-P02) T-A07-202 (FR-A07-201; gap G-SEGMENTSTREAM).

/// A fixed set of reusable elements addressed by slot index that never grows.
///
/// Every element is made once in ``init(capacity:make:)``; ``acquire()`` hands out the lowest free slot and
/// ``release(_:)`` takes it back so the element can be refilled and reused (for example one mesh renderer per
/// streamed tunnel piece).
public struct SlotPool<Element: Sendable>: Sendable {
    private var elements: [Element]
    private var inUse: [Bool]
    private var freeCount: Int

    /// Creates a pool of `capacity` elements, calling `make` once per slot index `0..<capacity` up front.
    /// A negative capacity is treated as 0.
    public init(capacity: Int, make: (Int) -> Element) {
        let count = max(0, capacity)
        elements = (0..<count).map(make)
        inUse = Array(repeating: false, count: count)
        freeCount = count
    }

    /// The fixed number of slots.
    public var capacity: Int { elements.count }

    /// The number of slots that are free to acquire.
    public var available: Int { freeCount }

    /// Takes the lowest free slot, or returns `nil` when every slot is in use.
    public mutating func acquire() -> Int? {
        guard freeCount > 0, let slot = inUse.firstIndex(of: false) else { return nil }
        inUse[slot] = true
        freeCount -= 1
        return slot
    }

    /// Returns `slot` to the pool. Out-of-range slots and slots that are already free are ignored.
    public mutating func release(_ slot: Int) {
        guard inUse.indices.contains(slot), inUse[slot] else { return }
        inUse[slot] = false
        freeCount += 1
    }

    /// Reads or replaces the element of `slot`; `slot` must be in `0..<capacity`.
    public subscript(slot: Int) -> Element {
        get { elements[slot] }
        set { elements[slot] = newValue }
    }
}
