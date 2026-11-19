// GraphModelTests — feature 166 (A23-P01) T-A23-105 (FR-A23-101; SC-A23-101; clarification Q2). The graph model:
// the identity range 1…9,999 and its ordering and single-integer coding, the canvas bound ±4,096 and finiteness, the
// connection order (target node, target port, source node, source port), the limits 32 and 64, a parameter's stored
// value or default, and the output node found by kind. Synthetic data only.
import Foundation
import Testing
@testable import VisualProgrammingLabCore

@Suite struct GraphModelTests {
    @Test func nodeIDRange() {
        #expect(NodeID.validRange == 1...9_999)
        #expect(NodeID(1).isValid)
        #expect(NodeID(9_999).isValid)
        #expect(NodeID(0).isValid == false)
        #expect(NodeID(10_000).isValid == false)
        #expect(NodeID(-1).isValid == false)
        #expect(NodeID(42).rawValue == 42)
        #expect(NodeID(42).description == "42")
    }

    @Test func nodeIDOrderAndCoding() throws {
        #expect(NodeID(2) < NodeID(10))
        #expect([NodeID(7), NodeID(3), NodeID(5)].sorted() == [NodeID(3), NodeID(5), NodeID(7)])
        let data = try JSONEncoder().encode([NodeID(5), NodeID(9_999)])
        #expect(String(data: data, encoding: .utf8) == "[5,9999]")
        #expect(try JSONDecoder().decode([NodeID].self, from: Data("[1,0]".utf8)) == [NodeID(1), NodeID(0)])
        #expect(throws: (any Error).self) { try JSONDecoder().decode([NodeID].self, from: Data("[1.5]".utf8)) }
    }

    @Test func canvasPointBounds() {
        #expect(CanvasPoint.bound == 4_096)
        let inside: [CanvasPoint] = [CanvasPoint(x: 0, y: 0), CanvasPoint(x: 4_096, y: -4_096),
                                     CanvasPoint(x: -4_096, y: 4_096), CanvasPoint(x: 12.25, y: -3_000.5)]
        for point in inside {
            #expect(point.isFinite)
            #expect(point.isInBounds, "\(point)")
        }
        let outside: [CanvasPoint] = [CanvasPoint(x: 4_096.5, y: 0), CanvasPoint(x: 0, y: -4_096.5),
                                      CanvasPoint(x: 10_000, y: 10_000)]
        for point in outside {
            #expect(point.isFinite)
            #expect(point.isInBounds == false, "\(point)")
        }
        let notFinite: [CanvasPoint] = [CanvasPoint(x: .nan, y: 0), CanvasPoint(x: 0, y: .infinity),
                                        CanvasPoint(x: -.infinity, y: 0)]
        for point in notFinite {
            #expect(point.isFinite == false)
            #expect(point.isInBounds == false)
        }
    }

    @Test func edgeOrder() {
        let a = GraphEdge(from: NodeID(9), "image", to: NodeID(2), "a")
        let b = GraphEdge(from: NodeID(1), "image", to: NodeID(2), "b")
        let c = GraphEdge(from: NodeID(3), "value", to: NodeID(5), "amount")
        let d = GraphEdge(from: NodeID(4), "image", to: NodeID(5), "amount")
        let e = GraphEdge(from: NodeID(4), "value", to: NodeID(5), "amount")
        let f = GraphEdge(from: NodeID(1), "image", to: NodeID(10), "a")
        #expect([f, e, d, c, b, a].sorted() == [a, b, c, d, e, f])
        #expect(a < b)
        #expect((b < a) == false)
        #expect(d < e)
        #expect(Set([a, a, b]).count == 2)
        #expect(a.sourceNode == NodeID(9))
        #expect(a.sourcePort == "image")
        #expect(a.targetNode == NodeID(2))
        #expect(a.targetPort == "a")
    }

    @Test func limits() {
        #expect(GraphLimits.maxNodes == 32)
        #expect(GraphLimits.maxEdges == 64)
    }

    @Test func nodeDefaultsAndValues() {
        let node = GraphNode(id: NodeID(1), kind: .noise, parameters: ["scale": 8, "extra": 2])
        #expect(node.position == CanvasPoint(x: 0, y: 0))
        #expect(node.value(of: "scale") == 8)
        #expect(node.value(of: "octaves") == 4)
        #expect(node.value(of: "speed") == 0.5)
        #expect(node.value(of: "extra") == 2)
        #expect(node.value(of: "nothing") == nil)
        let bare = GraphNode(id: NodeID(2), kind: .output)
        #expect(bare.parameters.isEmpty)
        #expect(bare.value(of: "image") == nil)
        #expect(GraphNode(id: NodeID(3), kind: .gradient).value(of: "angle") == 90)
    }

    @Test func outputNodes() {
        let none = VisualGraph(nodes: [GraphNode(id: NodeID(1), kind: .time)])
        #expect(none.outputNodes.isEmpty)
        #expect(none.output == nil)
        let one = VisualGraph(nodes: [GraphNode(id: NodeID(4), kind: .blur), GraphNode(id: NodeID(2), kind: .output)])
        #expect(one.outputNodes == [NodeID(2)])
        #expect(one.output == NodeID(2))
        let two = VisualGraph(nodes: [GraphNode(id: NodeID(9), kind: .output), GraphNode(id: NodeID(1), kind: .mix),
                                      GraphNode(id: NodeID(3), kind: .output)])
        #expect(two.outputNodes == [NodeID(3), NodeID(9)])
        #expect(two.output == nil)
        #expect(VisualGraph().nodes.isEmpty)
        #expect(VisualGraph().edges.isEmpty)
    }

    @Test func nodeLookup() {
        let graph = VisualGraph(nodes: [GraphNode(id: NodeID(4), kind: .blur), GraphNode(id: NodeID(2), kind: .output)])
        #expect(graph.node(NodeID(4))?.kind == .blur)
        #expect(graph.node(NodeID(2))?.kind == .output)
        #expect(graph.node(NodeID(3)) == nil)
    }
}
