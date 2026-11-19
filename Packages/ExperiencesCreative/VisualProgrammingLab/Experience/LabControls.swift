// LabControls — feature 167 (A23-P02) T-A23-206 (FR-A23-202, FR-A23-203, FR-A23-205; clarification Q4; User Story 4;
// contracts/experience.md "Accessibility identifiers"). The native controls of Visual Programming Lab: every canvas
// edit is also possible here without dragging (the accessible list form). Every control reads the presenter's
// mirror, sends through the presenter (so a refusal sets the feedback line), has a spoken label from
// `EditMessages.label(…)` and an identifier `experience.a23.visual-programming-lab.<name>`:
//
//   - `add-node`: "Add node", a button that shows or hides an inline list of the seven kinds, one button
//     `add-node-<kind>` each ("Mix", `add-node-mix`; `node.add [kind, x, y]` at the view's middle, then the list
//     closes);
//   - `remove-node`: "Remove" (`node.remove [selection]`), shown while a node is selected; with it `move-left`,
//     `move-right`, `move-up` and `move-down` (`node.move` by 32 canvas points, the grid's minor spacing);
//   - `status`: the checker's status line ("Ready", "No output", "Output not connected", "Mix 3: input b is empty");
//   - `feedback`: the sentence of the last refusal, shown when there is one;
//   - `node-list`: one row per node in identity order: a select button (`node-row-<id>`, `node.select`, "Noise 2"),
//     and per input a button `input-<id>-<index>` (label the input's name, value the current source's title, "None" or
//     "Noise 1 image") that shows or hides an inline list of option buttons `input-<id>-<index>-option-<tag>`: "None"
//     (tag ``LabControls/noneTag``) and every output of every other node (tag "<id>-<output>", "Noise 1 image");
//     choosing an output sends `edge.connect` (with the canvas's refusals), choosing None `edge.disconnect`;
//   - the connections, one line each (`connection-<target>-<index>`, "Noise 1 image → Output 2 image");
//   - `preview-toggle` (feature 168, A23-P03, T-A23-304; clarification Q5): a native switch "Preview" that shows or
//     hides the preview inset; view state only, so it sends no action and changes neither the graph nor its digest.
//   - Feature 169 (A23-P04) T-A23-404, T-A23-406 (FR-A23-401, FR-A23-404; clarifications Q1, Q2, Q4;
//     contracts/library.md "Identifiers"): `library` ("Library", shown when the experience has storage) opens the
//     graph library (``LabLibraryView``) in a sheet; `examples` is the "Examples" button that shows or hides an inline
//     list, one button `example-<id>` per example ("Open the example Clouds"), opened through the presenter's
//     `request(_:)`; when the open graph differs from the last saved or opened one, `library-replace-confirm` asks
//     first (``ReplaceConfirmation``, here while the sheet is down and in the sheet while it is up) and declining
//     changes nothing.
//
// Inline lists, not menus (feature 170, A23-P05, T-A23-505): the kinds, the sources and the examples are inline,
// expanding lists of buttons, never a `Menu`, a menu-style `Picker`, a popover or a sheet. While a menu is up over the
// canvas, which presents a new frame 30 times a second, the system never reports the app idle, so the interface tests
// wait 60 s per tap and taps on menu entries are unreliable; plain buttons in the controls' own scroll view have no
// such overlay. At most one list is open at a time (``LabControls/openList``); every choice closes it. Every button is
// at least 44 points high and keeps its spoken label and hint.
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
    /// The key of the one inline list that is open (``addListKey``, ``examplesListKey`` or an input's identifier
    /// name `input-<id>-<index>`); nil when every list is closed.
    @State private var openList: String?

    /// The key of the inline list of kinds.
    static let addListKey = "add-node"
    /// The key of the inline list of examples.
    static let examplesListKey = "examples"

    /// The identifier name of the add button of `kind`: `add-node-<kind>`, for example `add-node-mix`.
    static func addName(_ kind: NodeKind) -> String { "add-node-" + kind.rawValue }

    /// The identifier name of the button of input `index` of `node`: `input-<id>-<index>`.
    static func inputName(_ node: NodeID, input index: Int) -> String { "input-\(node.rawValue)-\(index)" }

    /// The identifier name of the option `tag` of input `index` of `node`: `input-<id>-<index>-option-<tag>`, for
    /// example `input-3-0-option-1-0` or `input-3-0-option-none`.
    static func optionName(_ node: NodeID, input index: Int, tag: String) -> String {
        inputName(node, input: index) + "-option-" + tag
    }

    /// The title of the source with `tag` among `options`: "None" for ``noneTag`` or a tag that names no option.
    static func title(ofTag tag: String, in options: [SourceOption]) -> String {
        options.first { $0.tag == tag }?.title ?? "None"
    }

    /// Opens the inline list `key`, or closes it when it is the open one (closing any other).
    private func toggle(_ key: String) { openList = openList == key ? nil : key }

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
                Button {
                    toggle(Self.addListKey)
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
            if openList == Self.addListKey { addList() }
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
            Button {
                toggle(Self.examplesListKey)
            } label: {
                Text(verbatim: "Examples").frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "Examples"))
            .accessibilityHint(Text(verbatim: "Opens an example graph in place of the open graph"))
            .accessibilityIdentifier(port.identifier("examples"))
        }
        if openList == Self.examplesListKey {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(LabExamples.all) { example in
                    Button {
                        openList = nil
                        _ = actions.request(.example(example.id))
                    } label: {
                        Text(verbatim: example.title).frame(minHeight: 44)
                    }
                    .accessibilityLabel(Text(verbatim: LabExamples.spokenLabel(example)))
                    .accessibilityIdentifier(port.identifier(LabExamples.identifierName(example)))
                }
            }
            .padding(.leading, 16)
        }
        if !showingLibrary, let message = mirror.libraryMessage {
            Text(verbatim: message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: message))
                .accessibilityIdentifier(port.identifier("library-message"))
        }
    }

    /// The inline list of the seven kinds: one button `add-node-<kind>` each, which adds the kind at the view's middle
    /// and closes the list.
    private func addList() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(NodeKind.allCases.enumerated()), id: \.offset) { index, kind in
                Button {
                    openList = nil
                    let at = addPosition()
                    send("node.add", [Double(index), at.x, at.y])
                } label: {
                    Text(verbatim: EditMessages.title(of: kind)).frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: EditMessages.title(of: kind)))
                .accessibilityHint(Text(verbatim: "Adds a node of this kind in the middle of the canvas"))
                .accessibilityIdentifier(port.identifier(Self.addName(kind)))
            }
        }
        .padding(.leading, 16)
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

    /// One node of the list form: its select button and, per input, its button with an inline list of sources.
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
                inputRow(node, input: index, declaration: declaration, options: options, in: graph)
            }
        }
    }
}

// MARK: - Inputs

/// One entry of an input's inline list: the option tag ("none" or "<id>-<output>") and its title.
private struct InputChoice: Hashable {
    /// The option tag.
    var tag: String
    /// The spoken title, for example "None" or "Noise 1 image".
    var title: String
}

extension LabControls {
    /// The button of one input (label the input's name, value the current source's title) and, while it is open, its
    /// inline list of options: "None" and every output of every other node. A choice sends what
    /// ``action(choosing:for:input:)`` gives (nothing when it is the current source) and closes the list.
    @ViewBuilder
    fileprivate func inputRow(_ node: GraphNode, input index: Int, declaration: PortDeclaration,
                              options: [SourceOption], in graph: VisualGraph) -> some View {
        let key = Self.inputName(node.id, input: index)
        let current = Self.currentTag(of: node, input: index, in: graph)
        let currentTitle = Self.title(ofTag: current, in: options)
        let name = EditMessages.label(port: declaration, of: node)
        Button {
            toggle(key)
        } label: {
            Text(verbatim: name + ": " + currentTitle).frame(minHeight: 44)
        }
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(verbatim: currentTitle))
        .accessibilityHint(Text(verbatim: "Shows the outputs that can feed this input"))
        .accessibilityIdentifier(port.identifier(key))
        if openList == key {
            let choices = [InputChoice(tag: Self.noneTag, title: "None")]
                + options.map { InputChoice(tag: $0.tag, title: $0.title) }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(choices, id: \.tag) { choice in
                    let tag = choice.tag, title = choice.title
                    Button {
                        openList = nil
                        guard tag != Self.currentTag(of: node, input: index, in: graph),
                              let action = Self.action(choosing: tag, for: node.id, input: index) else { return }
                        send(action.0, action.1)
                    } label: {
                        Text(verbatim: title).frame(minHeight: 44)
                    }
                    .accessibilityLabel(Text(verbatim: title))
                    .accessibilityAddTraits(tag == current ? .isSelected : [])
                    .accessibilityIdentifier(port.identifier(Self.optionName(node.id, input: index, tag: tag)))
                }
            }
            .padding(.leading, 16)
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
