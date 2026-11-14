// TunnelStream — feature 055 (A07-P02) T-A07-205 (FR-A07-201, FR-A07-230; SC-A07-201; clarification 1). The streaming
// tunnel's bookkeeping: VisualCore's `SegmentWindow` (2 behind, 8 ahead, capacity 12) decides which piece indices live
// and which to build (at most 2 per step, nearest first) or retire; a `SlotPool` of 12 slots holds one element per live
// piece (in the presenter a `MeshRenderer`) and never grows. A retired piece hands its element to `retire` (the
// presenter releases the renderer's GPU resources) and frees its slot; a new piece takes a free slot and fills it with
// a freshly built element (a `MeshRenderer`'s mesh is fixed, so a reused slot gets a new renderer for the new mesh).
// Generic over the element so the bounds are testable without a GPU.
import VisualCoreScenes

/// The streamed tunnel pieces: a `SegmentWindow` of piece indices and a fixed `SlotPool` of their elements.
struct TunnelStream<Element: Sendable> {
    /// Pieces kept behind the camera's piece.
    static var behind: Int { 2 }
    /// Pieces kept ahead of the camera's piece.
    static var ahead: Int { 8 }
    /// The slots of the pool: the most elements ever alive.
    static var capacity: Int { 12 }

    /// The window of live piece indices.
    private(set) var window: SegmentWindow
    private var pool: SlotPool<Element?>
    /// The slot of each live piece index.
    private(set) var slots: [Int: Int] = [:]

    /// An empty stream (nothing live, every slot free).
    init() {
        window = Self.makeWindow()
        pool = SlotPool(capacity: Self.capacity) { _ in nil }
    }

    private static func makeWindow() -> SegmentWindow {
        guard let window = SegmentWindow(behind: behind, ahead: ahead, capacity: capacity) else {
            preconditionFailure("the tunnel window's constants are valid")
        }
        return window
    }

    /// The live piece indices, ascending.
    var live: [Int] { window.live }
    /// The number of live elements (always `slots.count`, at most `capacity`).
    var liveCount: Int { slots.count }
    /// The number of free slots.
    var available: Int { pool.available }

    /// The element of the live piece `index`, nil when it is not live.
    func element(for index: Int) -> Element? {
        guard let slot = slots[index] else { return nil }
        return pool[slot]
    }

    /// Moves the window to `distance`: retires the pieces that left it (their elements go to `retire`, their slots back
    /// to the pool), then builds at most `SegmentWindow.maxBuildsPerStep` new pieces into free slots with `build`.
    /// Returns the window's step. A failing `build` resets the whole stream (every element to `retire`) and rethrows,
    /// so the window and the pool never disagree.
    @discardableResult
    mutating func advance(to distance: Double, pieceLength: Double, build: (Int) throws -> Element,
                          retire: (Element) -> Void) rethrows -> SegmentWindowStep {
        let step = window.advance(to: distance, pieceLength: pieceLength)
        for index in step.toRetire { free(index, retire: retire) }
        for index in step.toBuild {
            guard let slot = pool.acquire() else {
                // Not reachable: the capacity covers the whole window. Start over rather than disagree.
                reset(retire: retire)
                return step
            }
            do {
                pool[slot] = try build(index)
                slots[index] = slot
            } catch {
                pool.release(slot)
                reset(retire: retire)
                throw error
            }
        }
        return step
    }

    /// Retires every live piece (elements to `retire`, slots back to the pool) and empties the window.
    mutating func reset(retire: (Element) -> Void) {
        for index in Array(slots.keys) { free(index, retire: retire) }
        slots = [:]
        window = Self.makeWindow()
    }

    private mutating func free(_ index: Int, retire: (Element) -> Void) {
        guard let slot = slots.removeValue(forKey: index) else { return }
        if let element = pool[slot] { retire(element) }
        pool[slot] = nil
        pool.release(slot)
    }
}
