// LabControls — feature 167 (A23-P02) T-A23-206 (FR-A23-202, FR-A23-203, FR-A23-205; clarification Q4; User Story 4;
// contracts/experience.md "Accessibility identifiers"). The native controls of Visual Programming Lab: every canvas
// edit is also possible here without dragging (the accessible list form). Every control reads the presenter's
// mirror, sends through the presenter (so a refusal sets the feedback line), has a spoken label from
// `EditMessages.label(…)` and an identifier `experience.a23.visual-programming-lab.<name>`:
//
//   - `add-node`: a menu of the seven kinds ("Add node" → `node.add [kind, x, y]` at the view's middle);
//   - `remove-node`: "Remove" (`node.remove [selection]`), shown while a node is selected; with it `move-left`,
//     `move-right`, `move-up` and `move-down` (`node.move` by 32 canvas points, the grid's minor spacing);
//   - `status`: the checker's status line ("Ready", "No output", "Output not connected", "Mix 3: input b is empty");
//   - `feedback`: the sentence of the last refusal, shown when there is one;
//   - `node-list`: one row per node in identity order: a select button (`node-row-<id>`, `node.select`, "Noise 2"),
//     and per input a picker `input-<id>-<index>` of "None" and every output of every other node ("Noise 1 image");
//     choosing an output sends `edge.connect` (with the canvas's refusals), choosing None `edge.disconnect`;
//   - the connections, one line each (`connection-<target>-<index>`, "Noise 1 image → Output 2 image");
//   - `preview-toggle` (feature 168, A23-P03, T-A23-304; clarification Q5): a native switch "Preview" that shows or
//     hides the preview inset; view state only, so it sends no action and changes neither the graph nor its digest.
//   - Feature 169 (A23-P04) T-A23-404, T-A23-406 (FR-A23-401, FR-A23-404; clarifications Q1, Q2, Q4;
//     contracts/library.md "Identifiers"): `library` ("Library", shown when the experience has storage) opens the
//     graph library (``LabLibraryView``) in a sheet; `examples` is the "Examples" menu, one item `example-<id>` per
//     example ("Open the example Clouds"), opened through the presenter's `request(_:)`; when the open graph differs
//     from the last saved or opened one, `library-replace-confirm` asks first (``ReplaceConfirmation``, here while the
//     sheet is down and in the sheet while it is up) and declining changes nothing.
import SwiftUI
import VisualCoreExperienceHost
import VisualProgrammingLabCore

/// One output a list-form picker offers.
struct SourceOption: Equatable, Hashable {
    /// The source node.
    var node: NodeID
    /// The output's index among the node's outputs.
    var index: Int
    /// The spoken title, for example "Noise 1 image".
    var title: String

    /// The picker tag: "<id>-<index>".
    var tag: String { "\(node.rawValue)-\(index)" }
}

/// One line of the list form with its identifier name.
struct ControlLine: Equatable, Hashable {
    /// The identifier name, for example `connection-2-0`.
    var name: String
    /// The text, for example "Noise 1 image → Output 2 image".
    var text: String
}

/// One move button of the selected node.
struct MoveButton: Hashable {
    /// The identifier name, for example `move-left`.
    var name: String
    /// The title, for example "Move left".
    var title: String
    /// The move along x, canvas points.
    var dx: Double
    /// The move along y, canvas points.
    var dy: Double
}

/// The native controls of Visual Programming Lab (see the file header).
struct LabControls: View {
    /// The tag of the picker's "None" choice.
    static let noneTag = "none"
    /// How far the move buttons move the selected node, canvas points.
    static let moveStep = 32.0

    /// The port of the experience (for the identifiers).
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: LabMirror
    /// Sends an action through the presenter.
    var send: @MainActor (String, [Double]) -> Void = { _, _ in }
    /// Where a node added from the menu goes.
    var addPosition: @MainActor () -> CanvasPoint = { CanvasPoint(x: 0, y: 0) }
    /// Shows or hides the preview (view state).
    var setPreview: @MainActor (Bool) -> Void = { _ in }
    /// The library, the examples and the replace confirmation (feature 169); nil in previews of the controls alone.
    var library: LabLibraryActions?

    /// Whether the library sheet is up.
    @State private var showingLibrary = false

    /// Every output a picker for an input of `target` offers: each output of every other node, in identity order.
    static func sourceOptions(for target: NodeID, in graph: VisualGraph) -> [SourceOption] {
        var options: [SourceOption] = []
        for node in graph.nodes.sorted(by: { $0.id < $1.id }) where node.id != target {
            for (index, output) in node.kind.outputs.enumerated() {
                options.append(SourceOption(node: node.id, index: index,
                                            title: EditMessages.label(node: node) + " " + output.name))
            }
        }
        return options
    }

    /// The picker tag of the output feeding input `index` of `node`, or ``noneTag``.
    static func currentTag(of node: GraphNode, input index: Int, in graph: VisualGraph) -> String {
        guard node.kind.inputs.indices.contains(index) else { return noneTag }
        let name = node.kind.inputs[index].name
        guard let edge = graph.edges.first(where: { $0.targetNode == node.id && $0.targetPort == name }),
              let source = graph.node(edge.sourceNode),
              let output = source.kind.outputs.firstIndex(where: { $0.name == edge.sourcePort }) else {
            return noneTag
        }
        return "\(source.id.rawValue)-\(output)"
    }

    /// The action a picker choice sends: `edge.disconnect [id, index]` for None, else `edge.connect [source,
    /// output, id, index]`; nil for a tag that names no option.
    static func action(choosing tag: String, for node: NodeID, input index: Int) -> (String, [Double])? {
        if tag == noneTag { return ("edge.disconnect", [Double(node.rawValue), Double(index)]) }
        let parts = tag.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return ("edge.connect", [Double(parts[0]), Double(parts[1]), Double(node.rawValue), Double(index)])
    }

    /// The connection lines, in connection order, with their identifier names.
    static func connectionLines(_ graph: VisualGraph) -> [ControlLine] {
        graph.edges.sorted().map { edge in
            let index = graph.node(edge.targetNode)?.kind.inputs.firstIndex { $0.name == edge.targetPort } ?? 0
            return ControlLine(name: "connection-\(edge.targetNode.rawValue)-\(index)",
                               text: EditMessages.label(edge: edge, in: graph))
        }
    }

    /// The four move buttons, by ``moveStep``.
    static let moves = [MoveButton(name: "move-left", title: "Move left", dx: -moveStep, dy: 0),
                        MoveButton(name: "move-right", title: "Move right", dx: moveStep, dy: 0),
                        MoveButton(name: "move-up", title: "Move up", dx: 0, dy: -moveStep),
                        MoveButton(name: "move-down", title: "Move down", dx: 0, dy: moveStep)]

    /// The controls.
    var body: some View {
        let graph = mirror.graph
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Visual Programming Lab").font(.headline).accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                Menu {
                    ForEach(Array(NodeKind.allCases.enumerated()), id: \.offset) { index, kind in
                        Button {
                            let at = addPosition()
                            send("node.add", [Double(index), at.x, at.y])
                        } label: {
                            Text(verbatim: EditMessages.title(of: kind))
                        }
                    }
                } label: {
                    Text(verbatim: "Add node").frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Add node"))
                .accessibilityHint(Text(verbatim: "Adds a node of the chosen kind in the middle of the canvas"))
                .accessibilityIdentifier(port.identifier("add-node"))
                if let selection = mirror.selection, let node = graph.node(selection) {
                    Button {
                        send("node.remove", [Double(selection.rawValue)])
                    } label: {
                        Text(verbatim: "Remove").frame(minHeight: 44)
                    }
                    .accessibilityLabel(Text(verbatim: "Remove " + EditMessages.label(node: node)))
                    .accessibilityIdentifier(port.identifier("remove-node"))
                    moveButtons(node)
                }
            }
            if let library { libraryRow(library) }
            Toggle(isOn: Binding(get: { mirror.previewVisible }, set: { visible in setPreview(visible) })) {
                Text(verbatim: "Preview")
            }
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "Preview"))
            .accessibilityHint(Text(verbatim: "Shows or hides the picture the graph makes"))
            .accessibilityIdentifier(port.identifier("preview-toggle"))
            Text(verbatim: mirror.status)
                .font(.footnote)
                .accessibilityLabel(Text(verbatim: "Status, " + mirror.status))
                .accessibilityIdentifier(port.identifier("status"))
            if let feedback = mirror.feedback {
                Text(verbatim: feedback)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: feedback))
                    .accessibilityIdentifier(port.identifier("feedback"))
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(graph.nodes.sorted { $0.id < $1.id }, id: \.id) { node in
                    nodeRow(node, in: graph)
                }
                ForEach(Self.connectionLines(graph), id: \.name) { line in
                    Text(verbatim: line.text)
                        .font(.footnote)
                        .accessibilityLabel(Text(verbatim: line.text))
                        .accessibilityIdentifier(port.identifier(line.name))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(verbatim: "Nodes"))
            .accessibilityIdentifier(port.identifier("node-list"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(OptionalReplaceConfirmation(port: port, mirror: mirror, actions: library,
                                              active: !showingLibrary))
        .sheet(isPresented: $showingLibrary) {
            if let library {
                LabLibraryView(port: port, mirror: mirror, actions: library, close: { showingLibrary = false })
            }
        }
    }

    /// The "Library" button (with storage only) and the "Examples" menu (feature 169).
    @ViewBuilder
    private func libraryRow(_ actions: LabLibraryActions) -> some View {
        HStack(spacing: 12) {
            if actions.library != nil {
                Button {
                    showingLibrary = true
                } label: {
                    Text(verbatim: "Library").frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Library"))
                .accessibilityHint(Text(verbatim: "Saves the open graph, or opens, renames or removes a saved graph"))
                .accessibilityIdentifier(port.identifier("library"))
            }
            Menu {
                ForEach(LabExamples.all) { example in
                    Button {
                        _ = actions.request(.example(example.id))
                    } label: {
                        Text(verbatim: example.title)
                    }
                    .accessibilityLabel(Text(verbatim: LabExamples.spokenLabel(example)))
                    .accessibilityIdentifier(port.identifier(LabExamples.identifierName(example)))
                }
            } label: {
                Text(verbatim: "Examples").frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "Examples"))
            .accessibilityHint(Text(verbatim: "Opens an example graph in place of the open graph"))
            .accessibilityIdentifier(port.identifier("examples"))
        }
        if !showingLibrary, let message = mirror.libraryMessage {
            Text(verbatim: message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: message))
                .accessibilityIdentifier(port.identifier("library-message"))
        }
    }

    /// The four buttons that move the selected node by ``moveStep``.
    @ViewBuilder
    private func moveButtons(_ node: GraphNode) -> some View {
        ForEach(Self.moves, id: \.name) { move in
            Button {
                send("node.move", [Double(node.id.rawValue), LabPresenter.clamp(node.position.x + move.dx),
                                   LabPresenter.clamp(node.position.y + move.dy)])
            } label: {
                Text(verbatim: move.title).frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: move.title + ", " + EditMessages.label(node: node)))
            .accessibilityIdentifier(port.identifier(move.name))
        }
    }

    /// One node of the list form: its select button and a picker per input.
    private func nodeRow(_ node: GraphNode, in graph: VisualGraph) -> some View {
        let selected = mirror.selection == node.id
        let options = Self.sourceOptions(for: node.id, in: graph)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                send("node.select", [Double(node.id.rawValue)])
            } label: {
                Text(verbatim: EditMessages.label(node: node)).frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: EditMessages.label(node: node)))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityHint(Text(verbatim: "Selects the node"))
            .accessibilityIdentifier(port.identifier("node-row-\(node.id.rawValue)"))
            // Feature 169 (T-A23-408): the checker's sentences for this node, under its name.
            if let problems = mirror.diagnostics[node.id], !problems.isEmpty {
                ForEach(Array(problems.enumerated()), id: \.offset) { _, sentence in
                    Label { Text(verbatim: sentence) } icon: { Text(verbatim: "!") }
                        .font(.footnote)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(port.identifier("node-diagnostic-row-\(node.id.rawValue)"))
            }
            ForEach(Array(node.kind.inputs.enumerated()), id: \.offset) { index, declaration in
                Picker(selection: Binding(get: { Self.currentTag(of: node, input: index, in: graph) },
                                          set: { tag in
                                              guard tag != Self.currentTag(of: node, input: index, in: graph),
                                                    let action = Self.action(choosing: tag, for: node.id,
                                                                             input: index) else { return }
                                              send(action.0, action.1)
                                          })) {
                    Text(verbatim: "None").tag(Self.noneTag)
                    ForEach(options, id: \.tag) { option in
                        Text(verbatim: option.title).tag(option.tag)
                    }
                } label: {
                    Text(verbatim: EditMessages.label(port: declaration, of: node))
                }
                .accessibilityLabel(Text(verbatim: EditMessages.label(port: declaration, of: node)))
                .accessibilityIdentifier(port.identifier("input-\(node.id.rawValue)-\(index)"))
            }
        }
    }
}

/// ``ReplaceConfirmation`` when the controls have the library's actions; nothing otherwise (feature 169).
struct OptionalReplaceConfirmation: ViewModifier {
    /// The port that names the elements.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: LabMirror
    /// The presenter's actions; nil without them.
    let actions: LabLibraryActions?
    /// Whether the controls present the dialog (not while the library sheet is up).
    var active: Bool

    /// The view, with the dialog when there are actions.
    @ViewBuilder
    func body(content: Content) -> some View {
        if let actions {
            content.modifier(ReplaceConfirmation(port: port, mirror: mirror, actions: actions, active: active))
        } else {
            content
        }
    }
}
