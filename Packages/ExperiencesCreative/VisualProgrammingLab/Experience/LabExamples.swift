// LabExamples — feature 169 (A23-P04) T-A23-406 (FR-A23-404; SC-A23-404; clarification Q4; data-model.md "LabExample";
// contracts/library.md "Identifiers"; User Story 3). The example graphs of Visual Programming Lab, written in code in
// this repository (recorded in `docs/apps/visual-programming-lab/licenses.md`; no data file, no artwork):
//
//   - `clouds` ("Clouds"): Time (rate 1) into Noise's time (scale 6, speed 0.5), Noise into Output;
//   - `soft-gradient` ("Soft gradient"): a Constant colour (0.2, 0.45, 0.9) into Gradient's start (angle 45), Gradient
//     into Blur (radius 6), Blur into Output;
//   - `mixed-clouds` ("Mixed clouds", the journey graph): Time into Noise's time, Noise and Gradient (angle 60) into
//     Mix (amount 0.4), Mix into Blur (radius 3), Blur into Output.
//
// Each passes the checker and compiles within the preview's budget of 6 textures (ExampleTests). Identities run from 1
// in the order listed, positions 240 canvas points apart from left to right, so the canvas shows every node. The
// controls open an example from the "Examples" menu (`examples`, each item `example-<id>`) through the presenter's
// replace confirmation and the same restore path as a saved graph.
import Foundation
import VisualProgrammingLabCore

/// One example graph: its identifier, title, graph and licence line.
struct LabExample: Equatable, Identifiable, Sendable {
    /// The identifier: `clouds`, `soft-gradient` or `mixed-clouds`.
    var id: String
    /// The title shown and spoken, for example "Clouds".
    var title: String
    /// The graph the example opens.
    var graph: VisualGraph
    /// The licence and provenance line (as in licenses.md).
    var licence: String
}

/// The example graphs (see the file header).
enum LabExamples {
    /// The licence line of every example.
    static let licence = "Written for VisualCore in this repository (A23-P04); original, the repository's license."

    /// The horizontal distance between neighbouring nodes, canvas points.
    static let spacing = 240.0

    /// A node of `kind` with identity `id` in column `column` and row `row`, with `parameters`.
    static func node(_ id: Int, _ kind: NodeKind, column: Int, row: Int = 0,
                     _ parameters: [String: Double] = [:]) -> GraphNode {
        GraphNode(id: NodeID(id), kind: kind, parameters: parameters,
                  position: CanvasPoint(x: 40 + Double(column) * spacing, y: 80 + Double(row) * 200))
    }

    /// Time into Noise into Output.
    static let clouds = LabExample(
        id: "clouds", title: "Clouds",
        graph: VisualGraph(
            nodes: [node(1, .time, column: 0, ["rate": 1]),
                    node(2, .noise, column: 1, ["scale": 6, "speed": 0.5]),
                    node(3, .output, column: 2)],
            edges: [GraphEdge(from: NodeID(1), "time", to: NodeID(2), "time"),
                    GraphEdge(from: NodeID(2), "image", to: NodeID(3), "image")]),
        licence: licence)

    /// A Constant colour into Gradient's start, Gradient into Blur into Output.
    static let softGradient = LabExample(
        id: "soft-gradient", title: "Soft gradient",
        graph: VisualGraph(
            nodes: [node(1, .constant, column: 0, ["red": 0.2, "green": 0.45, "blue": 0.9]),
                    node(2, .gradient, column: 1, ["angle": 45]),
                    node(3, .blur, column: 2, ["radius": 6]),
                    node(4, .output, column: 3)],
            edges: [GraphEdge(from: NodeID(1), "colour", to: NodeID(2), "start"),
                    GraphEdge(from: NodeID(2), "image", to: NodeID(3), "image"),
                    GraphEdge(from: NodeID(3), "image", to: NodeID(4), "image")]),
        licence: licence)

    /// Time into Noise, Noise and Gradient into Mix, Mix into Blur, Blur into Output (the journey graph).
    static let mixedClouds = LabExample(
        id: "mixed-clouds", title: "Mixed clouds",
        graph: VisualGraph(
            nodes: [node(1, .time, column: 0, ["rate": 1]),
                    node(2, .noise, column: 1, ["scale": 6, "speed": 0.5]),
                    node(3, .gradient, column: 1, row: 1, ["angle": 60]),
                    node(4, .mix, column: 2, ["amount": 0.4]),
                    node(5, .blur, column: 3, ["radius": 3]),
                    node(6, .output, column: 4)],
            edges: [GraphEdge(from: NodeID(1), "time", to: NodeID(2), "time"),
                    GraphEdge(from: NodeID(2), "image", to: NodeID(4), "a"),
                    GraphEdge(from: NodeID(3), "image", to: NodeID(4), "b"),
                    GraphEdge(from: NodeID(4), "image", to: NodeID(5), "image"),
                    GraphEdge(from: NodeID(5), "image", to: NodeID(6), "image")]),
        licence: licence)

    /// The examples in menu order.
    static let all = [clouds, softGradient, mixedClouds]

    /// The example `id`; nil when there is none.
    static func example(_ id: String) -> LabExample? {
        all.first { $0.id == id }
    }

    /// The identifier name of an example's menu item: `example-<id>`.
    static func identifierName(_ example: LabExample) -> String { "example-" + example.id }

    /// The spoken label of an example's menu item, for example "Open the example Clouds".
    static func spokenLabel(_ example: LabExample) -> String { "Open the example " + example.title }
}
