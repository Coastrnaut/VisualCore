// TunnelStream — feature 055 (A07-P02) T-A07-205 (FR-A07-201, FR-A07-230; SC-A07-201; clarification 1). The streaming
// tunnel's bookkeeping: VisualCore's `SegmentWindow` (2 behind, 8 ahead, capacity 12) decides which piece indices live
// and which to build (at most 2 per step, nearest first) or retire; a `SlotPool` of 12 slots holds one element per live
// piece (in the presenter a `MeshRenderer`) and never grows. A retired piece hands its element to `retire` (the
// presenter releases the renderer's GPU resources) and frees its slot; a new piece takes a free slot and fills it with
// a freshly built element (a `MeshRenderer`'s mesh is fixed, so a reused slot gets a new renderer for the new mesh).
// Generic over the element so the bounds are testable without a GPU.
// Feature 058 (A07-P05) T-A07-504 (FR-A07-502; plan "Lifecycle"): the window follows the quality level.
// `resize(behind:ahead:)` replaces the `SegmentWindow` with one of the level's behind/ahead (capacity unchanged at 12,
// the level-0 need); the elements stay in their slots. The window gives the desired range around the current piece;
// the slots are the truth of what lives: every `advance` retires at once each live piece outside that range (so a
// shrink takes effect in the frame it is applied) and builds the missing pieces of the range, at most
// `SegmentWindow.maxBuildsPerStep` per step in the window's nearest-first order, so a still-live piece is never
// rebuilt and a growing window fills two new pieces per frame.
import VisualCoreScenes

/// The streamed tunnel pieces: a `SegmentWindow` of piece indices and a fixed `SlotPool` of their elements.
struct TunnelStream<Element: Sendable> {
    /// Pieces kept behind the camera's piece at quality level 0 (the default window).
    static var behind: Int { 2 }
    /// Pieces kept ahead of the camera's piece at quality level 0 (the default window).
    static var ahead: Int { 8 }
    /// The slots of the pool: the most elements ever alive.
    static var capacity: Int { 12 }

    /// The window: its desired range is what should live (after a resize its own `live` list may trail the slots,
    /// which are what lives).
    private(set) var window: SegmentWindow
    private var pool: SlotPool<Element?>
    /// The slot of each live piece index.
    private(set) var slots: [Int: Int] = [:]
    /// The number of elements built by the last `advance` (pieces still live are not rebuilt; at most
    /// `SegmentWindow.maxBuildsPerStep`).
    private(set) var builtLastStep = 0

    /// An empty stream (nothing live, every slot free) with the level-0 window (2 behind, 8 ahead).
    init() {
        window = Self.makeWindow(behind: Self.behind, ahead: Self.ahead)
        pool = SlotPool(capacity: Self.capacity) { _ in nil }
    }

    private static func makeWindow(behind: Int, ahead: Int) -> SegmentWindow {
        guard let window = SegmentWindow(behind: behind, ahead: ahead, capacity: capacity) else {
            preconditionFailure("the tunnel window's sizes fit the capacity")
        }
        return window
    }

    /// Replaces the window by an empty one of `behind` and `ahead` (feature 058: a quality level change); nothing
    /// happens when the sizes are unchanged. The live elements stay; the next `advance` retires those outside the new
    /// window at once and builds the missing ones at most two per step. Sizes that would not fit the capacity (or are
    /// negative) are clamped to it: `behind` to 0…11 and `ahead` to 0…(11 − behind).
    mutating func resize(behind: Int, ahead: Int) {
        let b = min(max(0, behind), Self.capacity - 1)
        let a = min(max(0, ahead), Self.capacity - 1 - b)
        guard b != window.behind || a != window.ahead else { return }
        window = Self.makeWindow(behind: b, ahead: a)
    }

    /// The pieces kept behind the camera's piece by the current window.
    var windowBehind: Int { window.behind }
    /// The pieces kept ahead of the camera's piece by the current window.
    var windowAhead: Int { window.ahead }

    /// Whether every piece the window wants is live (the slots, which survive a resize, are what counts).
    var isComplete: Bool {
        guard let desired = window.desired else { return false }
        return slots.count == desired.count && desired.allSatisfy { slots[$0] != nil }
    }

    /// The live piece indices, ascending.
    var live: [Int] { slots.keys.sorted() }
    /// The number of live elements (always `slots.count`, at most `capacity`).
    var liveCount: Int { slots.count }
    /// The number of free slots.
    var available: Int { pool.available }

    /// The element of the live piece `index`, nil when it is not live.
    func element(for index: Int) -> Element? {
        guard let slot = slots[index] else { return nil }
        return pool[slot]
    }

    /// Moves the window to `distance`: retires every live piece outside the window's desired range (their elements go
    /// to `retire`, their slots back to the pool), then builds at most `SegmentWindow.maxBuildsPerStep` missing pieces
    /// of the range into free slots with `build`, nearest to the current piece first (on a tie the one ahead), as the
    /// window orders them. The slots decide what is missing, so after a resize a piece that is still live is kept and
    /// costs no build. Returns the pieces actually built and retired; a non-finite distance or a piece length that is
    /// not a finite positive number changes nothing. A failing `build` resets the whole stream (every element to
    /// `retire`) and rethrows, so the window and the pool never disagree.
    @discardableResult
    mutating func advance(to distance: Double, pieceLength: Double, build: (Int) throws -> Element,
                          retire: (Element) -> Void) rethrows -> SegmentWindowStep {
        builtLastStep = 0
        guard distance.isFinite, pieceLength.isFinite, pieceLength > 0 else {
            return SegmentWindowStep(toBuild: [], toRetire: [])
        }
        _ = window.advance(to: distance, pieceLength: pieceLength)
        guard let desired = window.desired, let current = window.current else {
            return SegmentWindowStep(toBuild: [], toRetire: [])
        }
        var retired: [Int] = []
        for index in slots.keys.sorted() where !desired.contains(index) {
            free(index, retire: retire)
            retired.append(index)
        }
        var missing: [Int] = []
        var offset = 0
        let reach = max(window.ahead, window.behind)
        while missing.count < SegmentWindow.maxBuildsPerStep, offset <= reach {
            for candidate in offset == 0 ? [current] : [current + offset, current - offset]
            where missing.count < SegmentWindow.maxBuildsPerStep && desired.contains(candidate)
                && slots[candidate] == nil {
                missing.append(candidate)
            }
            offset += 1
        }
        var built: [Int] = []
        for index in missing {
            guard let slot = pool.acquire() else {
                // Not reachable: the capacity covers the whole window. Start over rather than disagree.
                reset(retire: retire)
                return SegmentWindowStep(toBuild: built, toRetire: retired)
            }
            do {
                pool[slot] = try build(index)
                slots[index] = slot
                builtLastStep += 1
                built.append(index)
            } catch {
                pool.release(slot)
                reset(retire: retire)
                throw error
            }
        }
        return SegmentWindowStep(toBuild: built, toRetire: retired)
    }

    /// Retires every live piece (elements to `retire`, slots back to the pool) and empties the window.
    mutating func reset(retire: (Element) -> Void) {
        for index in Array(slots.keys) { free(index, retire: retire) }
        slots = [:]
        window = Self.makeWindow(behind: window.behind, ahead: window.ahead)
    }

    private mutating func free(_ index: Int, retire: (Element) -> Void) {
        guard let slot = slots.removeValue(forKey: index) else { return }
        if let element = pool[slot] { retire(element) }
        pool[slot] = nil
        pool.release(slot)
    }
}
