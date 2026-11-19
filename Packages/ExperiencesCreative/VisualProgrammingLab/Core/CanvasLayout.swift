// CanvasLayout — feature 167 (A23-P02) T-A23-204 (FR-A23-205; SC-A23-204; clarification Q2; data-model.md
// "CanvasLayout"). Where every node box, port, port touch target and connection curve lies on the canvas, and what a
// canvas point touches:
//   box      168 points wide, a 32-point title row and one 36-point row per port row (rows = max(inputs, outputs, 1))
//   ports    inputs on the left edge, outputs on the right edge, each at the middle of its row
//   targets  a 44 × 44 square in canvas points centred on each port (44 screen points at the default zoom 1)
//   wires    a cubic curve from the output port to the input port, handles max(40, |dx| / 2) along the x axis
//   hit      port first (nearest centre; ties go to the larger node id), then the topmost box (largest id), else empty
// Choices recorded here: targets of neighbouring ports of one side overlap by 8 points (rows 36 apart, targets 44),
// so the nearest port centre wins; the target is fixed in canvas points, so the `zoom` given to ``CanvasLayout/hit``
// does not resize it (it scales with the view, as the spec's "scaled by the zoom" says). Canvas points, origin top-left,
// y down. Pure Foundation; no UI, GPU or clock.
import Foundation

/// An axis-aligned rectangle in canvas points: `x`, `y` is the top-left corner (y grows down).
public struct CanvasRect: Equatable, Sendable {
    /// The left edge.
    public var x: Double
    /// The top edge.
    public var y: Double
    /// The width (not negative for a rectangle of the layout).
    public var width: Double
    /// The height (not negative for a rectangle of the layout).
    public var height: Double

    /// A rectangle with top-left corner `x`, `y` and the given size.
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The point at the middle of the rectangle.
    public var centre: CanvasPoint { CanvasPoint(x: x + width / 2, y: y + height / 2) }

    /// Whether `p` lies inside the rectangle or on its edge; a non-finite point is never inside.
    public func contains(_ p: CanvasPoint) -> Bool {
        p.isFinite && p.x >= x && p.x <= x + width && p.y >= y && p.y <= y + height
    }
}

/// What a canvas point touches: an input or output port (node and port index), a node box, or nothing.
public enum CanvasHit: Equatable, Sendable {
    /// The input port at `index` (declaration order) of the node.
    case input(NodeID, Int)
    /// The output port at `index` (declaration order) of the node.
    case output(NodeID, Int)
    /// The box of the node, away from its ports.
    case node(NodeID)
    /// Empty canvas.
    case empty
}

/// A connection drawn as a cubic Bézier curve in canvas points: from `start` (an output port) to `end` (an input
/// port) with the handles `control1` and `control2`.
public struct WireCurve: Equatable, Sendable {
    /// The output port the curve leaves.
    public var start: CanvasPoint
    /// The handle after `start`.
    public var control1: CanvasPoint
    /// The handle before `end`.
    public var control2: CanvasPoint
    /// The input port the curve reaches.
    public var end: CanvasPoint

    /// A curve with the given points.
    public init(start: CanvasPoint, control1: CanvasPoint, control2: CanvasPoint, end: CanvasPoint) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
    }
}

/// The geometry of the node canvas: boxes, ports, port targets, connection curves and hit testing.
public enum CanvasLayout {
    /// The width of every node box.
    public static let boxWidth = 168.0
    /// The height of the title row of a box.
    public static let titleHeight = 32.0
    /// The height of one port row.
    public static let rowHeight = 36.0
    /// The side of the square touch target centred on each port, in canvas points.
    public static let portTarget = 44.0
    /// The shortest handle of a connection curve.
    public static let minHandle = 40.0

    /// The number of port rows of a box of `kind`: the larger of its input and output counts, at least 1.
    public static func rows(of kind: NodeKind) -> Int {
        max(kind.inputs.count, kind.outputs.count, 1)
    }

    /// The box of `node`: its top-left corner is the node's position; the height is the title row plus its port rows.
    public static func box(of node: GraphNode) -> CanvasRect {
        CanvasRect(x: node.position.x, y: node.position.y, width: boxWidth,
                   height: titleHeight + Double(rows(of: node.kind)) * rowHeight)
    }

    /// The point of the input port at `index` of `node`: on the box's left edge, at the middle of row `index`.
    public static func inputPoint(of node: GraphNode, index: Int) -> CanvasPoint {
        CanvasPoint(x: node.position.x, y: rowMiddle(of: node, index: index))
    }

    /// The point of the output port at `index` of `node`: on the box's right edge, at the middle of row `index`.
    public static func outputPoint(of node: GraphNode, index: Int) -> CanvasPoint {
        CanvasPoint(x: node.position.x + boxWidth, y: rowMiddle(of: node, index: index))
    }

    /// The touch target of a port of `node` (an input when `input` is true, else an output): a ``portTarget``-sided
    /// square centred on the port point.
    public static func portTargetRect(of node: GraphNode, input: Bool, index: Int) -> CanvasRect {
        let point = input ? inputPoint(of: node, index: index) : outputPoint(of: node, index: index)
        return CanvasRect(x: point.x - portTarget / 2, y: point.y - portTarget / 2, width: portTarget,
                          height: portTarget)
    }

    /// The curve of `edge` in `graph`, from its output port to its input port with handles of
    /// max(``minHandle``, |dx| / 2) along x; nil when either node or either port does not exist.
    public static func wire(_ edge: GraphEdge, in graph: VisualGraph) -> WireCurve? {
        guard let source = graph.node(edge.sourceNode), let target = graph.node(edge.targetNode),
              let outputIndex = source.kind.outputs.firstIndex(where: { $0.name == edge.sourcePort }),
              let inputIndex = target.kind.inputs.firstIndex(where: { $0.name == edge.targetPort }) else {
            return nil
        }
        let start = outputPoint(of: source, index: outputIndex)
        let end = inputPoint(of: target, index: inputIndex)
        let handle = max(minHandle, abs(end.x - start.x) / 2)
        return WireCurve(start: start, control1: CanvasPoint(x: start.x + handle, y: start.y),
                         control2: CanvasPoint(x: end.x - handle, y: end.y), end: end)
    }

    /// What the canvas point `p` touches in `graph`: the port whose target contains `p` and whose centre is nearest
    /// (ties go to the larger node id), else the topmost box containing `p` (the largest node id), else ``CanvasHit/empty``.
    /// The targets are fixed in canvas points; `zoom` (screen points per canvas point) does not resize them. A
    /// non-finite point touches nothing.
    public static func hit(_ p: CanvasPoint, in graph: VisualGraph, zoom: Double) -> CanvasHit {
        guard p.isFinite else { return .empty }
        var best: (hit: CanvasHit, distance: Double, id: NodeID)?
        for node in graph.nodes {
            let ports = [(true, node.kind.inputs.count), (false, node.kind.outputs.count)]
            for (input, count) in ports {
                for index in 0..<count {
                    let target = portTargetRect(of: node, input: input, index: index)
                    guard target.contains(p) else { continue }
                    let centre = target.centre
                    let distance = (p.x - centre.x) * (p.x - centre.x) + (p.y - centre.y) * (p.y - centre.y)
                    let candidate: CanvasHit = input ? .input(node.id, index) : .output(node.id, index)
                    if let current = best {
                        if distance < current.distance || (distance == current.distance && node.id > current.id) {
                            best = (candidate, distance, node.id)
                        }
                    } else {
                        best = (candidate, distance, node.id)
                    }
                }
            }
        }
        if let best { return best.hit }
        let topmost = graph.nodes.filter { box(of: $0).contains(p) }.map(\.id).max()
        if let topmost { return .node(topmost) }
        return .empty
    }

    private static func rowMiddle(of node: GraphNode, index: Int) -> Double {
        node.position.y + titleHeight + rowHeight * Double(index) + rowHeight / 2
    }
}
