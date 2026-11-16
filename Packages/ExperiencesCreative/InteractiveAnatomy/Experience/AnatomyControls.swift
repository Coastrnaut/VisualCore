// AnatomyControls — feature 125 (A17-P02) T-A17-204 (FR-A17-203, FR-A17-205, FR-A17-206, FR-A17-207; clarification
// Q4; contracts/scene.md). The native controls of Interactive Anatomy:
//   three layer toggles (`layer-bones`, `layer-cartilage`, `layer-ligaments` → `layer.show [layer, 0 / 1]`): "Bones",
//     "Cartilage and menisci", "Ligaments and tendons", valued "Shown" or "Hidden";
//   the structure list, the 14 parts grouped by layer under a heading per layer (`structure-<i>` →
//     `structure.select [i]`): each row names the part, its value says "Selected" when selected and its hint names
//     the layer in words; a row whose layer is hidden says "Hidden" and is disabled;
//   Turn left and Turn right (`turn-left`, `turn-right` → `camera.turn [−1 / +1]`), Tilt up and Tilt down (`tilt-up`,
//     `tilt-down` → `camera.tilt [+1 / −1]`, disabled at the limits), Zoom in and Zoom out (`zoom-in`, `zoom-out` →
//     `camera.zoom [+1 / −1]`, disabled at the limits) and Reset view (`reset-view` → `view.reset`), each valued with
//     the camera in words ("Turned 30°, tilted 10°, zoom step 0");
//   the answer to a refused action (`message`, shown only when there is one).
// Every control has an accessible label and value (and a hint) and the identifier
// `experience.a17.interactive-anatomy.<name>` from the port; hit areas are at least 44 points high and text wraps.
// The view holds references only (the port, the mirror and the presenter), as Molecular Explorer's controls do, so the
// rebuilt view compares equal; actions go through the presenter.
import InteractiveAnatomyCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// The controls of Interactive Anatomy.
struct AnatomyControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: AnatomyMirror
    /// The presenter every action goes through (it shows the answer to a refused action in the mirror).
    let presenter: AnatomyPresenter

    /// The toggle label of `layer`: "Bones", "Cartilage and menisci", "Ligaments and tendons".
    static func layerTitle(_ layer: AnatomyLayer) -> String {
        let words = AnatomyCore.layerWords(layer)
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// The identifier name of the toggle of `layer`: `layer-bones`, `layer-cartilage`, `layer-ligaments`.
    static func layerName(_ layer: AnatomyLayer) -> String {
        "layer-" + layer.rawValue
    }

    /// The camera in words: "Turned 30°, tilted 10°, zoom step 0".
    static func cameraWords(_ camera: AnatomyCameraState) -> String {
        let turn = Int(Double(camera.turn) * AnatomyCameraState.turnStepDegrees)
        let tilt = Int(Double(camera.tilt) * AnatomyCameraState.tiltStepDegrees)
        return "Turned \(turn)°, tilted \(tilt)°, zoom step \(camera.zoom)"
    }

    /// The controls, or a progress indicator before the first state.
    var body: some View {
        if mirror.ready {
            content
        } else {
            ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
        }
    }

    /// The toggles, the list, the camera buttons and the message.
    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Interactive Anatomy").font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(Array(AnatomyLayer.allCases.enumerated()), id: \.offset) { index, layer in
                layerToggle(index: index, layer: layer)
            }
            ForEach(Array(AnatomyLayer.allCases.enumerated()), id: \.offset) { index, layer in
                structureSection(layerIndex: index, layer: layer)
            }
            cameraButtons
            if !mirror.message.isEmpty {
                Text(verbatim: mirror.message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Message"))
                    .accessibilityValue(Text(verbatim: mirror.message))
                    .accessibilityIdentifier(port.identifier("message"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Whether the layer at `index` is shown.
    private func shown(_ index: Int) -> Bool {
        mirror.visibleLayers.indices.contains(index) && mirror.visibleLayers[index]
    }

    /// The toggle of `layer` (sends `layer.show [index, 0 / 1]` only when the choice changes).
    private func layerToggle(index: Int, layer: AnatomyLayer) -> some View {
        let title = Self.layerTitle(layer)
        return Toggle(isOn: Binding(get: { shown(index) },
                                    set: { on in
                                        guard on != shown(index) else { return }
                                        send("layer.show", [Double(index), on ? 1 : 0])
                                    })) {
            Text(verbatim: title).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: shown(index) ? "Shown" : "Hidden"))
        .accessibilityHint(Text(verbatim: "Shows or hides the \(AnatomyCore.layerWords(layer))"))
        .accessibilityIdentifier(port.identifier(Self.layerName(layer)))
    }

    /// The heading of `layer` and one row per part on it.
    @ViewBuilder private func structureSection(layerIndex: Int, layer: AnatomyLayer) -> some View {
        Text(verbatim: Self.layerTitle(layer))
            .font(.subheadline)
            .accessibilityAddTraits(.isHeader)
        ForEach(mirror.parts.indices.filter { mirror.parts[$0].layer == layer }, id: \.self) { index in
            structureRow(index: index, layerShown: shown(layerIndex))
        }
    }

    /// The row of part `index` (sends `structure.select [index]`; disabled and marked "Hidden" on a hidden layer).
    private func structureRow(index: Int, layerShown: Bool) -> some View {
        let part = mirror.parts[index]
        let selected = mirror.selected == index
        let value = !layerShown ? "Hidden" : selected ? "Selected" : "Not selected"
        let layerWords = AnatomyCore.layerWords(part.layer)
        return Button {
            send("structure.select", [Double(index)])
        } label: {
            HStack {
                Text(verbatim: part.name).font(.body).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if !layerShown || selected {
                    Text(verbatim: value).font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .disabled(!layerShown)
        .accessibilityLabel(Text(verbatim: part.name))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityHint(Text(verbatim: layerShown ? "Selects this structure, on the \(layerWords) layer"
                                    : "Hidden with the \(layerWords) layer"))
        .accessibilityIdentifier(port.identifier("structure-\(index)"))
    }

    /// Turn, tilt and zoom steps and Reset view.
    @ViewBuilder private var cameraButtons: some View {
        let camera = mirror.camera
        let words = Self.cameraWords(camera)
        let tilt = AnatomyCameraState.tiltRange, zoom = AnatomyCameraState.zoomRange
        let atTop = camera.tilt >= tilt.upperBound, atBottom = camera.tilt <= tilt.lowerBound
        let atNear = camera.zoom >= zoom.upperBound, atFar = camera.zoom <= zoom.lowerBound
        HStack(spacing: 8) {
            button("Turn left", name: "turn-left", value: words, hint: "Turns the view 15 degrees left",
                   enabled: true) { send("camera.turn", [-1]) }
            button("Turn right", name: "turn-right", value: words, hint: "Turns the view 15 degrees right",
                   enabled: true) { send("camera.turn", [1]) }
        }
        HStack(spacing: 8) {
            button("Tilt up", name: "tilt-up", value: words,
                   hint: atTop ? "The view is tilted as far up as it goes" : "Tilts the view 10 degrees up",
                   enabled: !atTop) { send("camera.tilt", [1]) }
            button("Tilt down", name: "tilt-down", value: words,
                   hint: atBottom ? "The view is tilted as far down as it goes" : "Tilts the view 10 degrees down",
                   enabled: !atBottom) { send("camera.tilt", [-1]) }
        }
        HStack(spacing: 8) {
            button("Zoom in", name: "zoom-in", value: words,
                   hint: atNear ? "The view is zoomed in as far as it goes" : "Moves the view closer",
                   enabled: !atNear) { send("camera.zoom", [1]) }
            button("Zoom out", name: "zoom-out", value: words,
                   hint: atFar ? "The view is zoomed out as far as it goes" : "Moves the view farther away",
                   enabled: !atFar) { send("camera.zoom", [-1]) }
        }
        button("Reset view", name: "reset-view", value: words,
               hint: "Returns to the opening view; the selection and the layers stay", enabled: true) {
            send("view.reset")
        }
    }

    /// Sends `control` with `values` through the presenter, which shows the answer when it is refused.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, through: port)
    }

    /// A bordered button `title` with the identifier `name`, the accessible value `value` and the hint `hint`.
    private func button(_ title: String, name: String, value: String, hint: String, enabled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }
}
