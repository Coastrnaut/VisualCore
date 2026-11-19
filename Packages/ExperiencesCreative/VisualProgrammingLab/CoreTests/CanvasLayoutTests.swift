// CanvasLayoutTests — feature 167 (A23-P02) T-A23-204 (FR-A23-205; SC-A23-204; clarification Q2). The canvas
// geometry: the box size of every kind, the port points, every port target of the starter graph (Noise id 1 at 40, 80
// into Output id 2 at 320, 80) at least 44 × 44 screen points at the default zoom, neighbouring targets of one node
// resolved by the nearest centre, the hit order port > topmost node > empty, and the connection curve handles.
// Synthetic data only.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualProgrammingLabCore

@Suite struct CanvasLayoutTests {
    private static let noise = GraphNode(id: NodeID(1), kind: .noise, position: CanvasPoint(x: 40, y: 80))
    private static let output = GraphNode(id: NodeID(2), kind: .output, position: CanvasPoint(x: 320, y: 80))
    private static let starter = VisualGraph(nodes: [noise, output],
                                             edges: [GraphEdge(from: NodeID(1), "image", to: NodeID(2), "image")])

    @Test func constants() {
        #expect(CanvasLayout.boxWidth == 168)
        #expect(CanvasLayout.titleHeight == 32)
        #expect(CanvasLayout.rowHeight == 36)
        #expect(CanvasLayout.portTarget == 44)
        #expect(CanvasLayout.minHandle == 40)
    }

    @Test func boxSizeOfEveryKind() {
        let rows: [NodeKind: Int] = [.time: 1, .constant: 2, .noise: 2, .gradient: 2, .mix: 3, .blur: 2, .output: 1]
        for kind in NodeKind.allCases {
            let expected = rows[kind] ?? -1
            #expect(CanvasLayout.rows(of: kind) == expected, "\(kind)")
            let node = GraphNode(id: NodeID(7), kind: kind, position: CanvasPoint(x: -12, y: 30))
            let box = CanvasLayout.box(of: node)
            #expect(box == CanvasRect(x: -12, y: 30, width: 168, height: 32 + 36 * Double(expected)), "\(kind)")
        }
    }

    @Test func portPoints() {
        let mix = GraphNode(id: NodeID(3), kind: .mix, position: CanvasPoint(x: 100, y: 200))
        #expect(CanvasLayout.inputPoint(of: mix, index: 0) == CanvasPoint(x: 100, y: 250))
        #expect(CanvasLayout.inputPoint(of: mix, index: 1) == CanvasPoint(x: 100, y: 286))
        #expect(CanvasLayout.inputPoint(of: mix, index: 2) == CanvasPoint(x: 100, y: 322))
        #expect(CanvasLayout.outputPoint(of: mix, index: 0) == CanvasPoint(x: 268, y: 250))
        let target = CanvasLayout.portTargetRect(of: mix, input: true, index: 1)
        #expect(target == CanvasRect(x: 78, y: 264, width: 44, height: 44))
        #expect(target.centre == CanvasPoint(x: 100, y: 286))
    }

    @Test func starterTargetsAtLeast44ScreenPoints() {
        let view = CanvasView(size: Vec2(800, 600))
        #expect(view.zoom == 1)
        var count = 0
        for node in Self.starter.nodes {
            let ports = [(true, node.kind.inputs.count), (false, node.kind.outputs.count)]
            for (input, n) in ports {
                for index in 0..<n {
                    let rect = CanvasLayout.portTargetRect(of: node, input: input, index: index)
                    let a = view.screen(fromCanvas: CanvasPoint(x: rect.x, y: rect.y))
                    let b = view.screen(fromCanvas: CanvasPoint(x: rect.x + rect.width, y: rect.y + rect.height))
                    #expect(abs(b.x - a.x) >= 44 - 1e-9, "\(node.id) \(input) \(index)")
                    #expect(abs(b.y - a.y) >= 44 - 1e-9, "\(node.id) \(input) \(index)")
                    count += 1
                }
            }
        }
        #expect(count == 4)
    }

    @Test func distinctPortsOfOneNodeResolveByNearestCentre() {
        let mix = GraphNode(id: NodeID(5), kind: .mix, position: CanvasPoint(x: 0, y: 0))
        let graph = VisualGraph(nodes: [mix])
        for index in 0..<3 {
            let point = CanvasLayout.inputPoint(of: mix, index: index)
            #expect(CanvasLayout.hit(point, in: graph, zoom: 1) == .input(NodeID(5), index))
        }
        #expect(CanvasLayout.hit(CanvasLayout.outputPoint(of: mix, index: 0), in: graph, zoom: 1) == .output(NodeID(5), 0))
        // In the 8-point overlap of rows 0 and 1 (row centres at y 50 and 86), the nearer centre wins.
        #expect(CanvasLayout.hit(CanvasPoint(x: 0, y: 66), in: graph, zoom: 1) == .input(NodeID(5), 0))
        #expect(CanvasLayout.hit(CanvasPoint(x: 0, y: 70), in: graph, zoom: 1) == .input(NodeID(5), 1))
        // Inputs and outputs of one box never share a target.
        let left = CanvasLayout.portTargetRect(of: mix, input: true, index: 0)
        let right = CanvasLayout.portTargetRect(of: mix, input: false, index: 0)
        #expect(left.x + left.width < right.x)
    }

    @Test func hitOrderPortThenTopmostNodeThenEmpty() {
        let graph = Self.starter
        #expect(CanvasLayout.hit(CanvasPoint(x: 40, y: 130), in: graph, zoom: 1) == .input(NodeID(1), 0))
        #expect(CanvasLayout.hit(CanvasPoint(x: 40, y: 166), in: graph, zoom: 1) == .input(NodeID(1), 1))
        #expect(CanvasLayout.hit(CanvasPoint(x: 208, y: 130), in: graph, zoom: 1) == .output(NodeID(1), 0))
        #expect(CanvasLayout.hit(CanvasPoint(x: 320, y: 130), in: graph, zoom: 1) == .input(NodeID(2), 0))
        // A port target reaches 22 points beyond the box edge and still wins.
        #expect(CanvasLayout.hit(CanvasPoint(x: 20, y: 130), in: graph, zoom: 1) == .input(NodeID(1), 0))
        #expect(CanvasLayout.hit(CanvasPoint(x: 120, y: 90), in: graph, zoom: 1) == .node(NodeID(1)))
        #expect(CanvasLayout.hit(CanvasPoint(x: 400, y: 100), in: graph, zoom: 1) == .node(NodeID(2)))
        #expect(CanvasLayout.hit(CanvasPoint(x: 260, y: 300), in: graph, zoom: 1) == .empty)
        #expect(CanvasLayout.hit(CanvasPoint(x: .nan, y: 130), in: graph, zoom: 1) == .empty)
        #expect(CanvasLayout.hit(CanvasPoint(x: 0, y: 0), in: VisualGraph(), zoom: 1) == .empty)
        // Overlapping boxes: the larger identity is on top; a port of the lower box still wins over the upper box.
        let under = GraphNode(id: NodeID(3), kind: .time, position: CanvasPoint(x: 0, y: 0))
        let over = GraphNode(id: NodeID(9), kind: .time, position: CanvasPoint(x: 60, y: 10))
        let stack = VisualGraph(nodes: [over, under])
        #expect(CanvasLayout.hit(CanvasPoint(x: 100, y: 20), in: stack, zoom: 1) == .node(NodeID(9)))
        #expect(CanvasLayout.hit(CanvasPoint(x: 168, y: 50), in: stack, zoom: 1) == .output(NodeID(3), 0))
    }

    @Test func equalDistanceGoesToLargerNodeID() {
        let a = GraphNode(id: NodeID(4), kind: .time, position: CanvasPoint(x: 0, y: 0))
        let b = GraphNode(id: NodeID(8), kind: .output, position: CanvasPoint(x: 168, y: 0))
        let graph = VisualGraph(nodes: [b, a])
        // Output 0 of node 4 and input 0 of node 8 are both at (168, 50).
        #expect(CanvasLayout.hit(CanvasPoint(x: 168, y: 50), in: graph, zoom: 1) == .input(NodeID(8), 0))
    }

    @Test func targetsAreFixedInCanvasPoints() {
        let graph = Self.starter
        let point = CanvasPoint(x: 20, y: 130)
        for zoom in [0.5, 1, 2] {
            #expect(CanvasLayout.hit(point, in: graph, zoom: zoom) == .input(NodeID(1), 0), "\(zoom)")
        }
    }

    @Test func wireCurveHandles() {
        let curve = CanvasLayout.wire(GraphEdge(from: NodeID(1), "image", to: NodeID(2), "image"), in: Self.starter)
        // Start (208, 130), end (320, 130): dx 112, handle max(40, 56) = 56.
        #expect(curve == WireCurve(start: CanvasPoint(x: 208, y: 130), control1: CanvasPoint(x: 264, y: 130),
                                   control2: CanvasPoint(x: 264, y: 130), end: CanvasPoint(x: 320, y: 130)))
        let near = GraphNode(id: NodeID(3), kind: .output, position: CanvasPoint(x: 230, y: 300))
        let graph = VisualGraph(nodes: [Self.noise, near])
        let short = CanvasLayout.wire(GraphEdge(from: NodeID(1), "image", to: NodeID(3), "image"), in: graph)
        // dx 22: the handle is the minimum 40.
        #expect(short == WireCurve(start: CanvasPoint(x: 208, y: 130), control1: CanvasPoint(x: 248, y: 130),
                                   control2: CanvasPoint(x: 190, y: 350), end: CanvasPoint(x: 230, y: 350)))
        let back = GraphNode(id: NodeID(4), kind: .blur, position: CanvasPoint(x: -300, y: 80))
        let backGraph = VisualGraph(nodes: [Self.noise, back])
        let backward = CanvasLayout.wire(GraphEdge(from: NodeID(1), "image", to: NodeID(4), "image"), in: backGraph)
        // dx -508: the handle is 254 and still points out of each port.
        #expect(backward?.control1 == CanvasPoint(x: 462, y: 130))
        #expect(backward?.control2 == CanvasPoint(x: -554, y: 130))
    }

    @Test func wireOfMissingNodeOrPortIsNil() {
        let graph = Self.starter
        #expect(CanvasLayout.wire(GraphEdge(from: NodeID(9), "image", to: NodeID(2), "image"), in: graph) == nil)
        #expect(CanvasLayout.wire(GraphEdge(from: NodeID(1), "image", to: NodeID(9), "image"), in: graph) == nil)
        #expect(CanvasLayout.wire(GraphEdge(from: NodeID(1), "colour", to: NodeID(2), "image"), in: graph) == nil)
        #expect(CanvasLayout.wire(GraphEdge(from: NodeID(1), "image", to: NodeID(2), "time"), in: graph) == nil)
    }

    @Test func rectContains() {
        let rect = CanvasRect(x: 0, y: 0, width: 10, height: 5)
        #expect(rect.contains(CanvasPoint(x: 0, y: 0)))
        #expect(rect.contains(CanvasPoint(x: 10, y: 5)))
        #expect(rect.contains(CanvasPoint(x: 10.01, y: 5)) == false)
        #expect(rect.contains(CanvasPoint(x: .infinity, y: 1)) == false)
    }
}
