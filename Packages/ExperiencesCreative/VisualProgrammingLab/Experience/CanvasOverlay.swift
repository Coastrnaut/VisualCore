// CanvasOverlay — feature 167 (A23-P02) T-A23-206 (FR-A23-201, FR-A23-205; clarification Q4; contracts/experience.md
// "Accessibility identifiers"). The native view drawn over the canvas grid through the host's overlay slot
// (`ExperiencePresenter.makeCanvasOverlay(_:)`): every wire (a cubic curve from `CanvasLayout.wire`), every node box
// with its title and port rows, the port dots coloured by value type and marked by shape (circle scalar, diamond
// colour, square texture, triangle time, so the type never depends on colour alone), the selection outline and the
// rubber wire. Everything is placed in screen points through the mirror's `CanvasView`, so it follows pan and zoom.
// It reads the presenter's mirror only and sends nothing (the host draws it with hit testing off; touches reach the
// presenter's `pointer`). Every node, port and wire carries its spoken label (`EditMessages.label(…)`) and its
// identifier (`node-<id>`, `port-<id>-in-<index>`, `port-<id>-out-<index>`, `wire-<target>-<index>`) under the
// experience's prefix; the list form in the controls is the accessible way to make the same edits. The overlay
// reports its size to the presenter (the canvas view's size in points).
//
// The preview (feature 168, A23-P03, T-A23-304; clarifications Q4, Q5; contracts/preview.md "Identifiers"): while
// shown, a frame `preview` around the bottom-left square of a third of the canvas's shorter side (in points, where the
// presenter draws the inset in pixels), labelled "Preview" (spoken "Preview, ready" or "Preview, <message>"), and,
// when the preview cannot draw, its message `preview-message` inside the square.
import SwiftUI
import VisualCoreExperienceHost
import VisualCoreMath
import VisualProgrammingLabCore

/// The shape that marks a port's value type.
enum PortMark: Equatable {
    /// A scalar.
    case circle
    /// A colour.
    case diamond
    /// A texture.
    case square
    /// Time.
    case triangle

    /// The mark of `type`.
    static func of(_ type: ValueType) -> PortMark {
        switch type {
        case .scalar: return .circle
        case .colour: return .diamond
        case .texture: return .square
        case .time: return .triangle
        }
    }
}

/// The shape of a port mark in a square frame.
struct PortMarkShape: Shape {
    /// Which mark.
    let mark: PortMark

    /// The mark's path in `rect`.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch mark {
        case .circle:
            path.addEllipse(in: rect)
        case .square:
            path.addRect(rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08))
        case .diamond:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        case .triangle:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// The nodes, ports and wires drawn over the canvas (see the file header).
struct CanvasOverlay: View {
    /// The port of the experience (for the identifiers).
    let port: ExperienceActionPort
    /// What the overlay shows.
    let mirror: LabMirror
    /// Tells the presenter the overlay's size in points.
    var report: @MainActor (Vec2) -> Void = { _ in }

    /// The side of a port dot at zoom 1, points.
    static let dotSize = 14.0

    /// The colour of a value type.
    static func colour(_ type: ValueType) -> Color {
        switch type {
        case .scalar: return Color(red: 0.55, green: 0.80, blue: 1.0)
        case .colour: return Color(red: 1.0, green: 0.62, blue: 0.40)
        case .texture: return Color(red: 0.62, green: 0.90, blue: 0.55)
        case .time: return Color(red: 0.92, green: 0.82, blue: 0.40)
        }
    }

    /// `p` on screen as a `CGPoint`.
    static func screen(_ p: CanvasPoint, _ view: CanvasView) -> CGPoint {
        let s = view.screen(fromCanvas: p)
        return CGPoint(x: s.x, y: s.y)
    }

    /// The screen path of `curve`.
    static func path(_ curve: WireCurve, _ view: CanvasView) -> Path {
        var path = Path()
        path.move(to: screen(curve.start, view))
        path.addCurve(to: screen(curve.end, view), control1: screen(curve.control1, view),
                      control2: screen(curve.control2, view))
        return path
    }

    /// The curve of a rubber wire, oriented from its output end.
    static func curve(_ rubber: RubberWire) -> WireCurve {
        let start = rubber.isInput ? rubber.end : rubber.start
        let end = rubber.isInput ? rubber.start : rubber.end
        let handle = max(CanvasLayout.minHandle, abs(end.x - start.x) / 2)
        return WireCurve(start: start, control1: CanvasPoint(x: start.x + handle, y: start.y),
                         control2: CanvasPoint(x: end.x - handle, y: end.y), end: end)
    }

    /// The index of the input `port` among the kind's inputs, or 0.
    static func inputIndex(_ edge: GraphEdge, in graph: VisualGraph) -> Int {
        graph.node(edge.targetNode)?.kind.inputs.firstIndex { $0.name == edge.targetPort } ?? 0
    }

    /// The overlay.
    var body: some View {
        let view = mirror.view
        let graph = mirror.graph
        let zoom = view.zoom
        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(graph.edges.sorted(), id: \.self) { edge in
                    if let curve = CanvasLayout.wire(edge, in: graph) {
                        Self.path(curve, view)
                            .stroke(Color.white.opacity(0.75), lineWidth: max(2 * zoom, 1))
                            .accessibilityElement()
                            .accessibilityLabel(Text(verbatim: EditMessages.label(edge: edge, in: graph)))
                            .accessibilityIdentifier(port.identifier(
                                "wire-\(edge.targetNode.rawValue)-\(Self.inputIndex(edge, in: graph))"))
                    }
                }
                ForEach(graph.nodes.sorted { $0.id < $1.id }, id: \.id) { node in
                    nodeView(node, view: view, selected: mirror.selection == node.id)
                }
                if let rubber = mirror.rubber {
                    Self.path(Self.curve(rubber), view)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: max(2 * zoom, 1), dash: [6, 4]))
                }
                if mirror.previewVisible {
                    previewFrame(size: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .onAppear { reportSize(geometry.size) }
            .onChange(of: geometry.size) { _, size in reportSize(size) }
        }
        .allowsHitTesting(false)
    }

    /// The preview inset's frame in an overlay of `size` points: the bottom-left square of a third of the shorter
    /// side.
    static func previewRect(in size: CGSize) -> CGRect {
        let side = max(0, min(size.width, size.height) / 3)
        return CGRect(x: 0, y: size.height - side, width: side, height: side)
    }

    /// The preview's frame, label and message (see the file header).
    private func previewFrame(size: CGSize) -> some View {
        let rect = Self.previewRect(in: size)
        let message = mirror.preview.message
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                .frame(width: rect.width, height: rect.height)
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: "Preview, " + (message ?? "ready")))
                .accessibilityIdentifier(port.identifier("preview"))
            Text(verbatim: "Preview")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 4)
                .background(Color.black.opacity(0.6))
                .accessibilityHidden(true)
            if let message {
                Text(verbatim: message)
                    .font(.caption)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .padding(6)
                    .frame(width: rect.width, height: rect.height)
                    .accessibilityLabel(Text(verbatim: message))
                    .accessibilityIdentifier(port.identifier("preview-message"))
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .position(x: rect.midX, y: rect.midY)
    }

    /// Reports `size` to the presenter.
    private func reportSize(_ size: CGSize) {
        report(Vec2(Double(size.width), Double(size.height)))
    }

    /// One node: its box, title, port rows and selection outline.
    @ViewBuilder
    private func nodeView(_ node: GraphNode, view: CanvasView, selected: Bool) -> some View {
        let box = CanvasLayout.box(of: node)
        let zoom = view.zoom
        let origin = Self.screen(node.position, view)
        let width = box.width * zoom
        let height = box.height * zoom
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8 * zoom)
                .fill(Color(red: 0.16, green: 0.17, blue: 0.21).opacity(0.94))
            RoundedRectangle(cornerRadius: 8 * zoom)
                .stroke(selected ? Color.yellow : Color.white.opacity(0.35), lineWidth: selected ? 3 : 1)
            // Feature 169 (T-A23-408): a node the checker names gets a dashed red outline and a "!" badge, so the mark
            // never depends on colour alone.
            if let problems = mirror.diagnostics[node.id], !problems.isEmpty {
                RoundedRectangle(cornerRadius: 10 * zoom)
                    .stroke(Color(red: 1, green: 0.35, blue: 0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(-4 * zoom)
                Text(verbatim: "!")
                    .font(.system(size: 14 * zoom, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(width: 20 * zoom, height: 20 * zoom)
                    .background(Circle().fill(Color(red: 1, green: 0.35, blue: 0.35)))
                    .position(x: width - 4 * zoom, y: 0)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: problems.joined(separator: " ")))
                    .accessibilityIdentifier(port.identifier("node-diagnostic-\(node.id.rawValue)"))
            }
            Text(verbatim: EditMessages.label(node: node))
                .font(.system(size: 14 * zoom, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .frame(width: width, height: CanvasLayout.titleHeight * zoom)
            ForEach(Array(node.kind.inputs.enumerated()), id: \.offset) { index, declaration in
                Text(verbatim: declaration.name)
                    .font(.system(size: 12 * zoom))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .position(x: width * 0.28, y: rowY(index) * zoom)
            }
            ForEach(Array(node.kind.outputs.enumerated()), id: \.offset) { index, declaration in
                Text(verbatim: declaration.name)
                    .font(.system(size: 12 * zoom))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .position(x: width * 0.72, y: rowY(index) * zoom)
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: ([EditMessages.label(node: node)] + (mirror.diagnostics[node.id] ?? []))
            .joined(separator: ". ")))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(port.identifier("node-\(node.id.rawValue)"))
        .position(x: origin.x + width / 2, y: origin.y + height / 2)
        ForEach(Array(node.kind.inputs.enumerated()), id: \.offset) { index, declaration in
            portDot(declaration, of: node, input: true, index: index, view: view)
        }
        ForEach(Array(node.kind.outputs.enumerated()), id: \.offset) { index, declaration in
            portDot(declaration, of: node, input: false, index: index, view: view)
        }
    }

    /// The middle of port row `index` below the box's top, canvas points.
    private func rowY(_ index: Int) -> Double {
        CanvasLayout.titleHeight + CanvasLayout.rowHeight * Double(index) + CanvasLayout.rowHeight / 2
    }

    /// One port dot, coloured and shaped by its type, with its spoken label and identifier.
    private func portDot(_ declaration: PortDeclaration, of node: GraphNode, input: Bool, index: Int,
                         view: CanvasView) -> some View {
        let point = input ? CanvasLayout.inputPoint(of: node, index: index)
            : CanvasLayout.outputPoint(of: node, index: index)
        let centre = Self.screen(point, view)
        let side = Self.dotSize * view.zoom
        let name = "port-\(node.id.rawValue)-" + (input ? "in" : "out") + "-\(index)"
        return PortMarkShape(mark: PortMark.of(declaration.type))
            .fill(Self.colour(declaration.type))
            .overlay(PortMarkShape(mark: PortMark.of(declaration.type)).stroke(Color.black.opacity(0.6), lineWidth: 1))
            .frame(width: side, height: side)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: EditMessages.label(port: declaration, of: node)))
            .accessibilityIdentifier(port.identifier(name))
            .position(centre)
    }
}
