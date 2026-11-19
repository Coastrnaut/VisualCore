// LabPresenter — feature 167 (A23-P02) T-A23-206 (FR-A23-201–206; clarifications Q3, Q4; contracts/experience.md
// "Presenter"; data-model.md "LabPresenter"); the preview since feature 168 (A23-P03) T-A23-304 (FR-A23-301,
// FR-A23-303, FR-A23-305, FR-A23-306, FR-A23-307; clarifications Q3–Q5; contracts/preview.md "Presenter"; research
// D7). Draws Visual Programming Lab through the host only and owns its presentation state:
//
//   - Drawing: the canvas grid (``GridScene``, a VisualCore `FieldPass` over the whole drawable) is built in `setup`,
//     gets the view's parameters at each `draw` and is torn down in `teardown`; a context rebuild sets it up again
//     from the same view state. `maxFramesPerSecond` 30; one quality tier, `level-0`.
//   - Preview (``pipeline``, a ``PreviewPipeline``): each `draw` draws the grid first (full size, so the viewport the
//     inset pass left in the previous frame never carries over), then, while ``previewVisible``, compiles the graph
//     when its `GraphDocument` fingerprint changed since the last compile (at most once per frame, at a draw only:
//     never from a control, and a view change never compiles), then the schedule's passes and the bottom-left inset.
//     `setup` restores the pipeline's programs and slots from the same schedule; `teardown` releases them. Hidden,
//     the preview compiles and draws nothing and the graph and its digest are unchanged (view state).
//   - View: ``view`` (`CanvasView`: zoom 0.5…2, the centre within ±4,096) is view state, not part of the snapshot, and
//     never sends an action. Its size in points follows the canvas: the size a touch reports and the size the overlay
//     reports (rotation, split view); the drawable covers the canvas, so the grid needs no point size from `resize`.
//   - Touches (`pointer(_:viewSize:port:)`, clarification Q3), every edit sent through the port:
//       one finger on a port draws a rubber wire; ending on a port of the other direction sends `edge.connect` (the
//       output end is the source); ending on a port of the same direction sends nothing and sets the feedback
//       "Connect an output to an input."; ending on the port it began on or anywhere else does nothing;
//       one finger on a node body moves it: once the touch is 10 points or more from where it began, every move
//       sends `node.move` (the position clamped to ±4,096); a touch that ends before that sends `node.select`;
//       one finger on empty canvas pans the view; a touch that ends within 10 points clears the selection
//       (`node.select [0]`, only while a node is selected);
//       a second finger turns the gesture into a pinch (zoom about the two fingers' midpoint, panning with it); a
//       rubber wire is dropped; a node move keeps the moves already sent; once a finger of the pinch lifts, the rest
//       of the touch is ignored. More than two fingers are ignored.
//     A cancelled touch and `cancelPointers()` (the shell calls it on suspension) drop the gesture: nothing more is
//     sent for it, the graph stays as of its last move and no rubber wire remains.
//   - Feedback: ``send(_:_:port:)`` sends an action; a refusal by rule is explained with the sentence of the refusal
//     (`EditMessages.sentence(for:in:)`, computed by `LabCore.applying(_:_:)` on the state before the action), any
//     other refusal of an edit with ``rangeFeedback``; an accepted action clears the feedback.
//   - Mirror: ``LabMirror`` is what the overlay and the controls show (graph, selection, status, feedback, rubber
//     wire, view); it is updated at each draw and after each action the presenter sends.
//   - Test seams: ``view`` (settable), ``feedback``, ``drawnFrames``, ``pipeline``, ``previewVisible`` (settable)
//     and ``graphOverride`` (a graph the preview compiles instead of the core's, for graphs with parameter values
//     no action sets yet). The current state is read through
//     ``currentCore`` (the factory sets it to the shell's engine state), else the last drawn core, else the opening
//     state.
//
// No GL call: everything is drawn through VisualCore's `FieldPass`.
import Foundation
import Observation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualProgrammingLabCore

/// The wire drawn while a finger drags from a port, in canvas points.
struct RubberWire: Equatable {
    /// The node of the port the drag began on.
    var node: NodeID
    /// The port's index among the node's inputs or outputs.
    var index: Int
    /// Whether the port is an input.
    var isInput: Bool
    /// The port's point.
    var start: CanvasPoint
    /// The finger's point.
    var end: CanvasPoint
}

/// What the overlay and the controls show, updated only when a field changes.
@MainActor
@Observable
final class LabMirror {
    /// The graph as last seen.
    var graph = LabCore.starterGraph
    /// The selected node.
    var selection: NodeID?
    /// The checker's status line ("Ready", "No output", …).
    var status = EditMessages.status(for: GraphChecker.check(LabCore.starterGraph), in: LabCore.starterGraph)
    /// The sentence of the last refusal; nil when there is none.
    var feedback: String?
    /// The wire a finger is drawing; nil when none.
    var rubber: RubberWire?
    /// The canvas view.
    var view = CanvasView(size: LabPresenter.defaultSize)
    /// What the preview shows.
    var preview = PreviewState.ready
    /// Whether the preview is shown (view state).
    var previewVisible = true
}

/// Draws Visual Programming Lab and owns its presentation state (see the file header).
@MainActor
final class LabPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = LabCore

    /// The view size used until the canvas reports one, points.
    nonisolated static let defaultSize = Vec2(1_024, 768)
    /// How far a touch moves before it is a drag rather than a tap, points.
    nonisolated static let tapSlop = 10.0
    /// The feedback for an edit refused by its range or count (the controls never send one).
    static let rangeFeedback = "That edit is outside the canvas."

    /// What the overlay and the controls show.
    let mirror = LabMirror()
    /// The port of the shell; set by the factory.
    var port: ExperienceActionPort?
    /// The current state of the shell's engine; set by the factory.
    var currentCore: (@MainActor () -> LabCore?)?
    /// The canvas grid.
    let grid = GridScene()
    /// The preview of the graph.
    let pipeline = PreviewPipeline()
    /// The graph of the last compile, and its fingerprint (nil when it could not be computed).
    private var compiled: (graph: VisualGraph, fingerprint: String?)?

    /// Whether the preview is shown (view state, a test seam: settable); never an action, never in the digest.
    var previewVisible = true {
        didSet { if mirror.previewVisible != previewVisible { mirror.previewVisible = previewVisible } }
    }

    /// A graph the preview compiles instead of the core's (a test seam); nil by default.
    var graphOverride: VisualGraph?

    /// What the preview shows: ``PreviewState/hidden`` while switched off, else the pipeline's state.
    var previewState: PreviewState { previewVisible ? pipeline.state : .hidden }
    /// The core of the last draw.
    private(set) var lastCore: LabCore?
    /// How many frames were drawn (a test seam).
    private(set) var drawnFrames = 0
    /// The frame cap: 30 frames per second.
    var maxFramesPerSecond: Int { 30 }

    /// The canvas view (a test seam: settable); view state, never an action.
    var view = CanvasView(size: LabPresenter.defaultSize) {
        didSet { if mirror.view != view { mirror.view = view } }
    }

    /// The sentence of the last refusal (a test seam); nil when there is none.
    var feedback: String? { mirror.feedback }

    /// The state the touches and the feedback are computed on.
    var state: LabCore { currentCore?() ?? lastCore ?? LabCore() }

    // MARK: Touch state

    /// One gesture in progress.
    private enum Gesture {
        /// Nothing in progress.
        case none
        /// A rubber wire from a port, drawn by `pointer`.
        case wire(pointer: Int)
        /// A node moved by `pointer`: the node's offset from the finger's canvas point and where the touch began.
        case move(pointer: Int, node: NodeID, offset: Vec2, start: Vec2, dragging: Bool)
        /// The view panned by `pointer` from `start`, last at `last`.
        case pan(pointer: Int, start: Vec2, last: Vec2, far: Bool)
        /// The view pinched by two fingers, last at `midpoint` and `distance` apart.
        case pinch(first: Int, second: Int, midpoint: Vec2, distance: Double)
        /// The rest of a touch whose gesture ended or was dropped: ignored until every finger is up.
        case ignored
    }

    /// The fingers down, by pointer id, in view points.
    private var touches: [Int: Vec2] = [:]
    /// The gesture in progress.
    private var gesture = Gesture.none

    // MARK: Render scene

    /// Builds the grid and restores the preview's programs and slots (again after a context loss).
    func setup(_ context: RenderContext) throws {
        try grid.setup(context)
        pipeline.restore(context)
    }

    /// Passes the new drawable size to the grid (the slots stay 256 × 256; the inset follows each frame's size).
    func resize(_ context: RenderContext) {
        grid.resize(context)
    }

    /// Draws the grid with the view's parameters, then the preview (see the file header), and brings the mirror up
    /// to `core`.
    func draw(_ core: LabCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        drawnFrames += 1
        lastCore = core
        grid.configure(GridScene.parameters(zoom: view.zoom, centreX: view.centre.x, centreY: view.centre.y,
                                            width: view.size.x, height: view.size.y))
        try grid.render(context, frame: frame)
        if previewVisible {
            let graph = graphOverride ?? core.graph
            if needsCompile(graph) {
                pipeline.compile(graph, context: context)
            }
            pipeline.draw(context, time: frame.time)
        }
        follow(core)
    }

    /// Whether `graph` differs from the graph of the last compile by its fingerprint; remembers it when it does.
    /// An equal graph is never fingerprinted again; one equal by fingerprint (the same content in another order) is
    /// remembered without a compile.
    private func needsCompile(_ graph: VisualGraph) -> Bool {
        if let compiled, compiled.graph == graph { return false }
        let fingerprint = try? GraphDocument.fingerprint(of: graph).hex
        if let compiled, let fingerprint, compiled.fingerprint == fingerprint {
            self.compiled = (graph, fingerprint)
            return false
        }
        compiled = (graph, fingerprint)
        return true
    }

    /// Tears the grid and the preview's programs and slots down.
    func teardown(_ context: RenderContext) {
        grid.teardown(context)
        pipeline.release(context)
    }

    // MARK: Actions

    /// Sends `control` with `values` through `port` and sets the feedback from the answer (see the file header).
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let before = state
        let result = port.send(control, values)
        switch result {
        case .accepted:
            setFeedback(nil)
        case .rejected(.rule):
            if case .failure(let refusal) = before.applying(control, values) {
                setFeedback(EditMessages.sentence(for: refusal, in: before.graph))
            } else {
                setFeedback(Self.rangeFeedback)
            }
        case .rejected(.notActive):
            break
        case .rejected:
            setFeedback(Self.rangeFeedback)
        }
        follow(state)
        return result
    }

    /// Sends through the factory's port; nil without one.
    @discardableResult
    func send(_ control: String, _ values: [Double]) -> ActionResult? {
        guard let port else { return nil }
        return send(control, values, port: port)
    }

    /// Where a node added from the controls goes: the box centred on the view's middle, clamped to ±4,096.
    var addPosition: CanvasPoint {
        let centre = view.centre
        return CanvasPoint(x: Self.clamp(centre.x - CanvasLayout.boxWidth / 2),
                           y: Self.clamp(centre.y - CanvasLayout.titleHeight))
    }

    /// Sets the feedback (only when it changed).
    private func setFeedback(_ text: String?) {
        if mirror.feedback != text { mirror.feedback = text }
    }

    /// `value` clamped to ±4,096 (0 when not finite).
    nonisolated static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -CanvasPoint.bound), CanvasPoint.bound)
    }

    /// The canvas view resized to `size` points when it is a valid, different size (the overlay's report).
    func noteCanvasSize(_ size: Vec2) {
        guard size.isFinite, size.x > 0, size.y > 0, size != view.size else { return }
        view = view.resized(to: size)
    }

    // MARK: Touches

    /// Maps a canvas touch to edits and view changes (see the file header).
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        noteCanvasSize(viewSize)
        let location = event.location
        guard location.isFinite else { return }
        switch event.phase {
        case .began:
            began(event.id, at: location)
        case .moved:
            guard touches[event.id] != nil else { return }
            touches[event.id] = location
            moved(event.id, to: location, port: port)
        case .ended:
            guard touches[event.id] != nil else { return }
            touches[event.id] = location
            ended(event.id, at: location, port: port)
            touches[event.id] = nil
            if touches.isEmpty { gesture = .none }
        case .cancelled:
            guard touches[event.id] != nil else { return }
            touches[event.id] = nil
            dropGesture()
        }
    }

    /// Forgets every touch in progress: nothing more is sent for them and no rubber wire remains.
    func cancelPointers() {
        touches = [:]
        gesture = .none
        setRubber(nil)
    }

    /// A finger came down at `location`.
    private func began(_ id: Int, at location: Vec2) {
        guard touches[id] == nil else { return }
        touches[id] = location
        switch touches.count {
        case 1:
            gesture = singleGesture(id, at: location)
        case 2:
            switch gesture {
            case .ignored:
                return
            default:
                setRubber(nil)
                let ids = touches.keys.sorted()
                let a = touches[ids[0]] ?? location
                let b = touches[ids[1]] ?? location
                gesture = .pinch(first: ids[0], second: ids[1], midpoint: (a + b) / 2, distance: (b - a).length)
            }
        default:
            return
        }
    }

    /// The one-finger gesture that begins at `location`: a wire, a move or a pan.
    private func singleGesture(_ id: Int, at location: Vec2) -> Gesture {
        let graph = state.graph
        let point = view.canvas(fromScreen: location)
        switch CanvasLayout.hit(point, in: graph, zoom: view.zoom) {
        case .input(let node, let index):
            guard let found = graph.node(node) else { return .ignored }
            setRubber(RubberWire(node: node, index: index, isInput: true,
                                 start: CanvasLayout.inputPoint(of: found, index: index), end: point))
            return .wire(pointer: id)
        case .output(let node, let index):
            guard let found = graph.node(node) else { return .ignored }
            setRubber(RubberWire(node: node, index: index, isInput: false,
                                 start: CanvasLayout.outputPoint(of: found, index: index), end: point))
            return .wire(pointer: id)
        case .node(let node):
            guard let found = graph.node(node) else { return .ignored }
            let offset = Vec2(found.position.x - point.x, found.position.y - point.y)
            return .move(pointer: id, node: node, offset: offset, start: location, dragging: false)
        case .empty:
            return .pan(pointer: id, start: location, last: location, far: false)
        }
    }

    /// A finger moved to `location`.
    private func moved(_ id: Int, to location: Vec2, port: ExperienceActionPort) {
        switch gesture {
        case .wire(let pointer) where pointer == id:
            if var rubber = mirror.rubber {
                rubber.end = view.canvas(fromScreen: location)
                setRubber(rubber)
            }
        case .move(let pointer, let node, let offset, let start, var dragging) where pointer == id:
            if !dragging, (location - start).length >= Self.tapSlop { dragging = true }
            gesture = .move(pointer: pointer, node: node, offset: offset, start: start, dragging: dragging)
            guard dragging else { return }
            let point = view.canvas(fromScreen: location)
            send("node.move", [Double(node.rawValue), Self.clamp(point.x + offset.x), Self.clamp(point.y + offset.y)],
                 port: port)
        case .pan(let pointer, let start, let last, var far) where pointer == id:
            if (location - start).length >= Self.tapSlop { far = true }
            view = view.panned(by: location - last)
            gesture = .pan(pointer: pointer, start: start, last: location, far: far)
        case .pinch(let first, let second, let midpoint, let distance) where id == first || id == second:
            guard let a = touches[first], let b = touches[second] else { return }
            let newMidpoint = (a + b) / 2
            let newDistance = (b - a).length
            var next = view.panned(by: newMidpoint - midpoint)
            if distance > 0, newDistance > 0 { next = next.pinched(by: newDistance / distance, anchor: newMidpoint) }
            view = next
            gesture = .pinch(first: first, second: second, midpoint: newMidpoint, distance: newDistance)
        default:
            return
        }
    }

    /// A finger lifted at `location`.
    private func ended(_ id: Int, at location: Vec2, port: ExperienceActionPort) {
        switch gesture {
        case .wire(let pointer) where pointer == id:
            let rubber = mirror.rubber
            setRubber(nil)
            gesture = .ignored
            guard let rubber else { return }
            finishWire(rubber, at: view.canvas(fromScreen: location), port: port)
        case .move(let pointer, let node, _, _, let dragging) where pointer == id:
            gesture = .ignored
            if !dragging { send("node.select", [Double(node.rawValue)], port: port) }
        case .pan(let pointer, _, _, let far) where pointer == id:
            gesture = .ignored
            if !far, state.selection != nil { send("node.select", [0], port: port) }
        case .pinch(let first, let second, _, _) where id == first || id == second:
            gesture = .ignored
        default:
            return
        }
    }

    /// Ends a rubber wire on `point`: connects ports of the two directions, or explains a wrong direction.
    private func finishWire(_ rubber: RubberWire, at point: CanvasPoint, port: ExperienceActionPort) {
        let hit = CanvasLayout.hit(point, in: state.graph, zoom: view.zoom)
        let origin: CanvasHit = rubber.isInput ? .input(rubber.node, rubber.index) : .output(rubber.node, rubber.index)
        guard hit != origin else { return }
        switch hit {
        case .input(let node, let index):
            guard !rubber.isInput else {
                setFeedback(EditMessages.wrongDirection)
                return
            }
            send("edge.connect", [Double(rubber.node.rawValue), Double(rubber.index), Double(node.rawValue),
                                  Double(index)], port: port)
        case .output(let node, let index):
            guard rubber.isInput else {
                setFeedback(EditMessages.wrongDirection)
                return
            }
            send("edge.connect", [Double(node.rawValue), Double(index), Double(rubber.node.rawValue),
                                  Double(rubber.index)], port: port)
        case .node, .empty:
            return
        }
    }

    /// Drops the gesture in progress (a cancelled touch): nothing more is sent for it and no rubber wire remains.
    private func dropGesture() {
        setRubber(nil)
        gesture = touches.isEmpty ? .none : .ignored
    }

    /// Sets the rubber wire (only when it changed).
    private func setRubber(_ rubber: RubberWire?) {
        if mirror.rubber != rubber { mirror.rubber = rubber }
    }

    // MARK: Mirror and words

    /// Brings the mirror's graph, selection, status and view up to `core` and the presenter.
    func follow(_ core: LabCore) {
        if mirror.graph != core.graph {
            mirror.graph = core.graph
        }
        let status = EditMessages.status(for: core.check, in: core.graph)
        if mirror.status != status { mirror.status = status }
        if mirror.selection != core.selection { mirror.selection = core.selection }
        if mirror.view != view { mirror.view = view }
        let preview = previewState
        if mirror.preview != preview { mirror.preview = preview }
    }

    /// Shows or hides the preview (view state: no action is sent and the graph is unchanged).
    func setPreviewVisible(_ visible: Bool) {
        previewVisible = visible
        let preview = previewState
        if mirror.preview != preview { mirror.preview = preview }
    }

    /// The canvas label, for example "Visual Programming Lab, 2 nodes, 1 connection, Ready".
    func describe(_ core: LabCore) -> String {
        let nodes = core.graph.nodes.count
        let edges = core.graph.edges.count
        return "Visual Programming Lab, \(nodes) " + (nodes == 1 ? "node" : "nodes") + ", \(edges) "
            + (edges == 1 ? "connection" : "connections") + ", "
            + EditMessages.status(for: core.check, in: core.graph)
    }

    /// The frame probe of the verification runner: the canvas is dark everywhere outside the preview's inset (every
    /// grid colour keeps a luma below 40 of 255; the inset covers the bottom-left third only), so its middle is of
    /// the class `dark` at any view.
    func probes(_ core: LabCore) -> [FrameProbe] {
        [FrameProbe(name: "canvas-dark", x: 0.5, y: 0.5, expected: FrameColorClass.dark.rawValue)].compactMap { $0 }
    }

    /// The actions a canvas gesture can send: move, select and connect.
    var gestureActions: Set<String> { ["node.move", "node.select", "edge.connect"] }

    /// The actions of the native controls: all six.
    var nativeActions: Set<String> { Set(LabCore.actionIDs) }

    /// The native controls (``LabControls``), sending through the presenter.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(LabControls(port: port, mirror: mirror, send: { [weak self] control, values in
            _ = self?.send(control, values, port: port)
        }, addPosition: { [weak self] in
            self?.addPosition ?? CanvasPoint(x: 0, y: 0)
        }, setPreview: { [weak self] visible in
            self?.setPreviewVisible(visible)
        }))
    }

    /// The canvas overlay (``CanvasOverlay``): nodes, ports, wires, the selection, the rubber wire and the preview's
    /// frame and message.
    func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView? {
        AnyView(CanvasOverlay(port: port, mirror: mirror, report: { [weak self] size in
            self?.noteCanvasSize(size)
        }))
    }
}
