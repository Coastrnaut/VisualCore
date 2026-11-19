// GraphFixtures — feature 166 (A23-P01) T-A23-107, T-A23-108 (SC-A23-102, SC-A23-103, SC-A23-104, SC-A23-105;
// FR-A23-104–107). The named fixture graphs the checker tests and the host-count test share: the journey graphs, the
// whole library, the limits, every connection refusal, the cycle fixtures (loops of 1, 2, 3 and 8 nodes, two separate
// loops, a loop through an otherwise valid graph) and the output fixtures. Synthetic data only; built with small
// helpers, no force unwraps.
import VisualProgrammingLabCore

/// Named fixture graphs for the checker tests and the host-count test.
enum GraphFixtures {
    // MARK: Helpers

    /// A node of `kind` with identity `id` and the given stored parameters.
    static func node(_ id: Int, _ kind: NodeKind, _ parameters: [String: Double] = [:]) -> GraphNode {
        GraphNode(id: NodeID(id), kind: kind, parameters: parameters,
                  position: CanvasPoint(x: Double(id) * 40, y: Double(id % 4) * 30))
    }

    /// A connection from `source`.`sourcePort` to `target`.`targetPort`.
    static func edge(_ source: Int, _ sourcePort: String, _ target: Int, _ targetPort: String) -> GraphEdge {
        GraphEdge(from: NodeID(source), sourcePort, to: NodeID(target), targetPort)
    }

    /// Identities as `NodeID`s.
    static func ids(_ raw: [Int]) -> [NodeID] { raw.map { NodeID($0) } }

    /// The ring of blur nodes `ring` (image → image, each into the next, the last into the first), in ring order.
    static func blurRing(_ ring: [Int]) -> [GraphEdge] {
        var edges: [GraphEdge] = []
        for (index, id) in ring.enumerated() {
            edges.append(edge(id, "image", ring[(index + 1) % ring.count], "image"))
        }
        return edges
    }

    // MARK: Accepted graphs

    /// The first journey graph: Noise → Output. Order [1, 2].
    static var noiseToOutput: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output)], edges: [edge(1, "image", 2, "image")])
    }

    /// The second journey graph: Noise and Gradient → Mix → Blur → Output. Order [1, 2, 3, 4, 5].
    static var journeyMix: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .gradient), node(3, .mix), node(4, .blur), node(5, .output)],
                    edges: [edge(1, "image", 3, "a"), edge(2, "image", 3, "b"), edge(3, "image", 4, "image"),
                            edge(4, "image", 5, "image")])
    }

    /// Every kind, every input fed: Time(1), Constant(3) → Noise(2), Gradient(4) → Mix(5) → Blur(6) → Output(7).
    /// Kahn's smallest-ready-first order is [1, 3, 2, 4, 5, 6, 7].
    static var fullLibrary: VisualGraph {
        VisualGraph(nodes: [node(1, .time), node(2, .noise), node(3, .constant), node(4, .gradient), node(5, .mix),
                            node(6, .blur), node(7, .output)],
                    edges: [edge(1, "time", 2, "time"), edge(3, "value", 2, "scale"), edge(3, "colour", 4, "start"),
                            edge(3, "colour", 4, "end"), edge(2, "image", 5, "a"), edge(4, "image", 5, "b"),
                            edge(3, "value", 5, "amount"), edge(5, "image", 6, "image"), edge(3, "value", 6, "radius"),
                            edge(6, "image", 7, "image")])
    }

    /// Identities against the flow: Noise(9) → Blur(5) → Output(1). Order [9, 5, 1].
    static var descendingIDs: VisualGraph {
        VisualGraph(nodes: [node(1, .output), node(5, .blur), node(9, .noise)],
                    edges: [edge(9, "image", 5, "image"), edge(5, "image", 1, "image")])
    }

    /// Gradient with both optional colour inputs empty → Output: accepted.
    static var optionalInputsEmpty: VisualGraph {
        VisualGraph(nodes: [node(1, .gradient), node(2, .output)], edges: [edge(1, "image", 2, "image")])
    }

    /// Noise(1) → Output(2), plus Gradient(3) → Blur(4) that does not reach the output. Order [1, 2, 3, 4];
    /// reaching {1, 2}.
    static var unreachedBranch: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output), node(3, .gradient), node(4, .blur)],
                    edges: [edge(1, "image", 2, "image"), edge(3, "image", 4, "image")])
    }

    /// Exactly 32 nodes and 64 connections: Constant(1), Time(2), Noise(3…26) each fed time and scale, Mix(27…31)
    /// chained over Noise(3…8) with the constant as amount, Output(32) fed by Mix(31). Accepted.
    static var atLimits: VisualGraph {
        var nodes = [node(1, .constant), node(2, .time)]
        var edges: [GraphEdge] = []
        for id in 3...26 {
            nodes.append(node(id, .noise))
            edges.append(edge(2, "time", id, "time"))
            edges.append(edge(1, "value", id, "scale"))
        }
        for id in 27...31 {
            nodes.append(node(id, .mix))
            edges.append(edge(id == 27 ? 3 : id - 1, "image", id, "a"))
            edges.append(edge(id - 23, "image", id, "b"))   // Noise 4…8
            edges.append(edge(1, "value", id, "amount"))
        }
        nodes.append(node(32, .output))
        edges.append(edge(31, "image", 32, "image"))
        return VisualGraph(nodes: nodes, edges: edges)
    }

    // MARK: Limits and node refusals

    /// 33 nodes (``atLimits`` plus a lone Constant 33): refused as too many nodes.
    static var oneNodePastLimit: VisualGraph {
        var graph = atLimits
        graph.nodes.append(node(33, .constant))
        return graph
    }

    /// 65 connections (``atLimits`` plus one more into a noise scale): refused as too many connections.
    static var oneEdgePastLimit: VisualGraph {
        var graph = atLimits
        graph.edges.append(edge(1, "value", 3, "scale"))
        return graph
    }

    /// Two nodes share identity 1.
    static var duplicateNode: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(1, .gradient), node(2, .output)], edges: [edge(1, "image", 2, "image")])
    }

    /// Noise(1) stores `colour`, a parameter noise does not declare.
    static var undeclaredParameter: VisualGraph {
        VisualGraph(nodes: [node(1, .noise, ["colour": 0.5]), node(2, .output)], edges: [edge(1, "image", 2, "image")])
    }

    /// Noise(1) stores `scale` 64, outside 0.5…32.
    static var parameterOutOfRange: VisualGraph {
        VisualGraph(nodes: [node(1, .noise, ["scale": 64]), node(2, .output)], edges: [edge(1, "image", 2, "image")])
    }

    /// Noise(1) stores `speed` NaN.
    static var parameterNotFinite: VisualGraph {
        VisualGraph(nodes: [node(1, .noise, ["speed": .nan]), node(2, .output)], edges: [edge(1, "image", 2, "image")])
    }

    /// Noise(1) stores only `octaves`; `scale` and `speed` take their defaults. Accepted.
    static var missingParameters: VisualGraph {
        VisualGraph(nodes: [node(1, .noise, ["octaves": 2]), node(2, .output)], edges: [edge(1, "image", 2, "image")])
    }

    /// An undeclared parameter and a connection to a missing node: only the node stage's issue is reported.
    static var nodeAndEdgeIssues: VisualGraph {
        VisualGraph(nodes: [node(1, .noise, ["hue": 1]), node(2, .output)], edges: [edge(1, "image", 9, "image")])
    }

    // MARK: Connection refusals

    /// The graph for the pair (`from`, `to`) and its tested connection: a source node of the kind whose output has
    /// type `from` (Time.time, Constant.value, Constant.colour, Noise.image) as node 1, a target whose input has type
    /// `to` (Noise.time, Noise.scale, Gradient.start, Blur.image) as node 2, and Output(3) fed by the target.
    static func typePair(from: ValueType, to: ValueType) -> (graph: VisualGraph, edge: GraphEdge) {
        let source: (kind: NodeKind, port: String) = switch from {
        case .time: (.time, "time")
        case .scalar: (.constant, "value")
        case .colour: (.constant, "colour")
        case .texture: (.noise, "image")
        }
        let target: (kind: NodeKind, port: String) = switch to {
        case .time: (.noise, "time")
        case .scalar: (.noise, "scale")
        case .colour: (.gradient, "start")
        case .texture: (.blur, "image")
        }
        let tested = edge(1, source.port, 2, target.port)
        let graph = VisualGraph(nodes: [node(1, source.kind), node(2, target.kind), node(3, .output)],
                                edges: [tested, edge(2, "image", 3, "image")])
        return (graph, tested)
    }

    /// Noise(1) → node 9, which does not exist.
    static var unknownTargetNode: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output)],
                    edges: [edge(1, "image", 2, "image"), edge(1, "image", 9, "image")])
    }

    /// Node 9, which does not exist, → Blur(3).
    static var unknownSourceNode: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output), node(3, .blur)],
                    edges: [edge(1, "image", 2, "image"), edge(9, "image", 3, "image")])
    }

    /// Noise(1).colour (no such port) → Output(2).
    static var unknownSourcePort: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output)], edges: [edge(1, "colour", 2, "image")])
    }

    /// Noise(1) → Output(2).picture (no such port).
    static var unknownTargetPort: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output)], edges: [edge(1, "image", 2, "picture")])
    }

    /// From an input: Noise(1).time → Output(2).image.
    static var fromAnInput: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output)], edges: [edge(1, "time", 2, "image")])
    }

    /// Into an output: Noise(1).image → Noise(2).image (an output of noise), plus Noise(2) → Output(3).
    static var intoAnOutput: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .noise), node(3, .output)],
                    edges: [edge(1, "image", 2, "image"), edge(2, "image", 3, "image")])
    }

    /// Noise(1) and Noise(2) both feed Output(3).image.
    static var inputFedTwice: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .noise), node(3, .output)],
                    edges: [edge(1, "image", 3, "image"), edge(2, "image", 3, "image")])
    }

    /// Noise(1) → Output(2) stored twice.
    static var duplicateEdge: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output)],
                    edges: [edge(1, "image", 2, "image"), edge(1, "image", 2, "image")])
    }

    // MARK: Cycles

    /// A blur fed by itself (loop of 1), Blur(1) → Output(2).
    static var loopOfOne: VisualGraph {
        VisualGraph(nodes: [node(1, .blur), node(2, .output)],
                    edges: [edge(1, "image", 1, "image"), edge(1, "image", 2, "image")])
    }

    /// Blur(1) ⇄ Blur(2), Blur(2) → Output(3).
    static var loopOfTwo: VisualGraph {
        VisualGraph(nodes: [node(1, .blur), node(2, .blur), node(3, .output)],
                    edges: blurRing([1, 2]) + [edge(2, "image", 3, "image")])
    }

    /// Blur 1 → 2 → 3 → 1, Blur(3) → Output(4).
    static var loopOfThree: VisualGraph {
        VisualGraph(nodes: [node(1, .blur), node(2, .blur), node(3, .blur), node(4, .output)],
                    edges: blurRing([1, 2, 3]) + [edge(3, "image", 4, "image")])
    }

    /// The ring of the eight-node loop, in loop order (identities deliberately out of order).
    static let ringOfEight = [4, 7, 2, 9, 5, 1, 8, 3]

    /// Eight blurs in the ring 4 → 7 → 2 → 9 → 5 → 1 → 8 → 3 → 4, Blur(4) → Output(20).
    static var loopOfEight: VisualGraph {
        VisualGraph(nodes: ringOfEight.map { node($0, .blur) } + [node(20, .output)],
                    edges: blurRing(ringOfEight) + [edge(4, "image", 20, "image")])
    }

    /// Two separate loops: Blur 2 ⇄ 4 and Blur 1 → 5 → 3 → 1; Blur(3) → Output(6). The loop reached first holds
    /// identity 1.
    static var twoLoops: VisualGraph {
        VisualGraph(nodes: [1, 2, 3, 4, 5].map { node($0, .blur) } + [node(6, .output)],
                    edges: blurRing([2, 4]) + blurRing([1, 5, 3]) + [edge(3, "image", 6, "image")])
    }

    /// Two connections forming a loop through an otherwise valid graph: Noise(1) → Mix(2).a, Mix(2) → Blur(3) →
    /// Mix(2).b, Mix(2) → Output(4).
    static var loopThroughValidGraph: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .mix), node(3, .blur), node(4, .output)],
                    edges: [edge(1, "image", 2, "a"), edge(3, "image", 2, "b"), edge(2, "image", 3, "image"),
                            edge(2, "image", 4, "image")])
    }

    /// The smallest remaining identity lies below the loop: Blur 5 ⇄ 6, Blur(5) → Output(1).
    static var loopAboveOutput: VisualGraph {
        VisualGraph(nodes: [node(1, .output), node(5, .blur), node(6, .blur)],
                    edges: blurRing([5, 6]) + [edge(5, "image", 1, "image")])
    }

    // MARK: Output refusals

    /// No nodes at all.
    static var empty: VisualGraph { VisualGraph() }

    /// A noise and no output node.
    static var noOutputNode: VisualGraph { VisualGraph(nodes: [node(1, .noise)]) }

    /// Noise(1) → Output(2), and a second Output(3).
    static var twoOutputs: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output), node(3, .output)], edges: [edge(1, "image", 2, "image")])
    }

    /// Noise(1) and an Output(2) with nothing connected.
    static var disconnectedOutput: VisualGraph { VisualGraph(nodes: [node(1, .noise), node(2, .output)]) }

    /// Noise(1) → Mix(2).a, Mix(2).b empty, Mix(2) → Output(3).
    static var mixMissingB: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .mix), node(3, .output)],
                    edges: [edge(1, "image", 2, "a"), edge(2, "image", 3, "image")])
    }

    /// Noise(1) → Mix(2).b, Mix(2).a empty, Mix(2) → Output(3).
    static var mixMissingA: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .mix), node(3, .output)],
                    edges: [edge(1, "image", 2, "b"), edge(2, "image", 3, "image")])
    }

    /// Noise(1) → Output(2) and a Blur(3) with its image empty that reaches nothing.
    static var unreachedEmptyInput: VisualGraph {
        VisualGraph(nodes: [node(1, .noise), node(2, .output), node(3, .blur)], edges: [edge(1, "image", 2, "image")])
    }

    // MARK: Sets

    /// The fixtures the checker accepts.
    static var acyclic: [(name: String, graph: VisualGraph)] {
        [("noise-to-output", noiseToOutput), ("journey-mix", journeyMix), ("full-library", fullLibrary),
         ("descending-ids", descendingIDs), ("optional-inputs-empty", optionalInputsEmpty),
         ("unreached-branch", unreachedBranch), ("at-limits", atLimits), ("missing-parameters", missingParameters)]
    }

    /// The cycle fixtures.
    static var cycles: [(name: String, graph: VisualGraph)] {
        [("loop-of-one", loopOfOne), ("loop-of-two", loopOfTwo), ("loop-of-three", loopOfThree),
         ("loop-of-eight", loopOfEight), ("two-loops", twoLoops), ("loop-through-valid-graph", loopThroughValidGraph),
         ("loop-above-output", loopAboveOutput)]
    }

    /// The 16 type-pair graphs, named `type-<from>-<to>`.
    static var typePairs: [(name: String, graph: VisualGraph)] {
        var pairs: [(name: String, graph: VisualGraph)] = []
        for from in ValueType.allCases {
            for to in ValueType.allCases {
                pairs.append(("type-\(from.rawValue)-\(to.rawValue)", typePair(from: from, to: to).graph))
            }
        }
        return pairs
    }

    /// Every fixture graph, accepted and refused, by name.
    static var all: [(name: String, graph: VisualGraph)] {
        let refusals: [(name: String, graph: VisualGraph)] = [
            ("one-node-past-limit", oneNodePastLimit), ("one-edge-past-limit", oneEdgePastLimit),
            ("duplicate-node", duplicateNode), ("undeclared-parameter", undeclaredParameter),
            ("parameter-out-of-range", parameterOutOfRange), ("parameter-not-finite", parameterNotFinite),
            ("node-and-edge-issues", nodeAndEdgeIssues), ("unknown-target-node", unknownTargetNode),
            ("unknown-source-node", unknownSourceNode), ("unknown-source-port", unknownSourcePort),
            ("unknown-target-port", unknownTargetPort), ("from-an-input", fromAnInput),
            ("into-an-output", intoAnOutput), ("input-fed-twice", inputFedTwice), ("duplicate-edge", duplicateEdge),
            ("empty", empty), ("no-output-node", noOutputNode), ("two-outputs", twoOutputs),
            ("disconnected-output", disconnectedOutput), ("mix-missing-b", mixMissingB),
            ("mix-missing-a", mixMissingA), ("unreached-empty-input", unreachedEmptyInput)]
        return acyclic + cycles + typePairs + refusals
    }
}
