// GPUFrameTimer.swift — GPU time of one frame's draw calls from GL_EXT_disjoint_timer_query (feature 175 T-A24-304;
// FR-A24-305, clarification Q2, U-GPUTIMER). Contract: specs/175-gbl-p03-runner-probe/contracts/visualcore.md.
import CVisualCoreGL

/// One finished GPU timer result: the frame it bracketed and the GPU time of its commands in milliseconds
/// (nanoseconds / 1,000,000).
public struct GPUFrameTime: Sendable, Equatable {
    /// The frame number passed to `GPUFrameTimer.begin(frame:)`.
    public let frame: Int
    /// GPU time of the bracketed commands in milliseconds.
    public let milliseconds: Double

    /// Creates a result for `frame` taking `milliseconds`.
    public init(frame: Int, milliseconds: Double) {
        self.frame = frame
        self.milliseconds = milliseconds
    }
}

/// Times one frame's GL work at a time with a ring of four `GL_TIME_ELAPSED_EXT` queries.
///
/// Create it in a scene callback (usually `setup`) and call every method only inside scene callbacks, on the main
/// thread, with the host's context current — never from other code. Results arrive a few frames late through
/// `poll()`, only when the result is available and the GPU did not report a disjoint event; a disjoint read discards
/// every pending query. A timer belongs to the context generation it was created on: after `recreateContext()` it
/// reads nothing, `poll()` returns no results and `release()` only forgets its query names (the context that owned
/// them is gone). Create a new timer in the new generation's `setup`.
@MainActor
public final class GPUFrameTimer {
    /// The extension the timer needs in `RenderCapabilities.extensions`.
    public static let extensionName = "GL_EXT_disjoint_timer_query"
    /// Number of queries in the ring: at most this many frames are in flight; a frame begun while all are pending is
    /// not timed.
    public static let ringSize = 4

    /// How many disjoint reads have discarded pending queries since creation.
    public private(set) var disjointCount = 0

    private weak var resources: ResourceRegistry?
    private let generation: Int
    private var free: [GLuint]
    private var pending: [(frame: Int, query: GLuint)] = []
    private var open: (frame: Int, query: GLuint)?
    private var released = false

    /// Creates the timer and its four queries on the current context; nil unless `extensionName` is listed in
    /// `context.resources.renderCapabilities.extensions` and the loader resolved its entry points.
    public init?(context: RenderContext) {
        guard context.resources.renderCapabilities.extensions.contains(Self.extensionName),
              vcglHasDisjointTimerQuery() == 1 else { return nil }
        var names = [GLuint](repeating: 0, count: Self.ringSize)
        vcglGenQueries(GLsizei(Self.ringSize), &names)
        guard !names.contains(0) else {
            let created = names.filter { $0 != 0 }
            if !created.isEmpty { vcglDeleteQueries(GLsizei(created.count), created) }
            return nil
        }
        resources = context.resources
        generation = context.generation
        free = names
        var disjoint: GLint = 0
        vcglGetIntegerv(GLenum(GL_GPU_DISJOINT_EXT), &disjoint)   // reading clears an earlier flag
    }

    /// True when the timer still belongs to the registry's current context generation and was not released.
    private var isCurrent: Bool {
        guard !released, let resources else { return false }
        return resources.generation == generation
    }

    /// Starts timing `frame`'s GL work. Does nothing when a query is already open, every query is pending (the
    /// frame is not timed) or the timer belongs to an older context generation.
    public func begin(frame: Int) {
        guard isCurrent, open == nil, !free.isEmpty else { return }
        let query = free.removeFirst()
        vcglBeginQuery(GLenum(GL_TIME_ELAPSED_EXT), query)
        open = (frame, query)
    }

    /// Ends the open query, if any; its result becomes available to `poll()` a few frames later.
    public func end() {
        guard isCurrent, let current = open else { return }
        vcglEndQuery(GLenum(GL_TIME_ELAPSED_EXT))
        pending.append(current)
        open = nil
    }

    /// Returns the finished, available, non-disjoint results in frame order and frees their queries. A disjoint
    /// read discards every pending query and increments `disjointCount`; a timer of an older generation returns
    /// no results and forgets its queries without reading them.
    public func poll() -> [GPUFrameTime] {
        guard isCurrent else {
            forget()
            return []
        }
        var disjoint: GLint = 0
        vcglGetIntegerv(GLenum(GL_GPU_DISJOINT_EXT), &disjoint)
        if disjoint != 0 {
            free.append(contentsOf: pending.map(\.query))
            pending.removeAll()
            disjointCount += 1
            return []
        }
        var results: [GPUFrameTime] = []
        while let first = pending.first {
            var available: GLuint = 0
            vcglGetQueryObjectuiv(first.query, GLenum(GL_QUERY_RESULT_AVAILABLE), &available)
            guard available != 0 else { break }
            var nanoseconds: GLuint64 = 0
            vcglGetQueryObjectui64vEXT(first.query, GLenum(GL_QUERY_RESULT), &nanoseconds)
            results.append(GPUFrameTime(frame: first.frame, milliseconds: Double(nanoseconds) / 1_000_000))
            pending.removeFirst()
            free.append(first.query)
        }
        return results
    }

    /// Deletes the queries on the current generation's context (ending an open one first); for a timer of an older
    /// generation it only forgets them. Safe to call more than once; afterwards every method does nothing.
    public func release() {
        guard !released else { return }
        if isCurrent {
            if open != nil { end() }
            let names = free + pending.map(\.query)
            if !names.isEmpty { vcglDeleteQueries(GLsizei(names.count), names) }
        }
        forget()
    }

    private func forget() {
        free.removeAll()
        pending.removeAll()
        open = nil
        released = true
    }
}
