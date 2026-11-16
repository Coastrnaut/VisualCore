// SimulationControls — feature 117 (A16-P01) T-A16-105 (FR-A16-120, FR-A16-130). The native controls of Simulation Lab
// in one section:
//   the Family picker (`family` → `sim.family [index]`: Cellular automaton, Reaction-diffusion, Wave field; sent only
//     when the choice changes);
//   the Preset picker (`preset` → `sim.preset [index]`: the family's presets, the automaton's with their rule; sent
//     only when the choice changes);
//   Run / Pause (`run-pause` → `sim.run` while paused, `sim.pause` while running);
//   Step (`step` → `sim.step`, disabled while running with a hint saying so);
//   Reset (`reset` → `sim.reset`: the seeded start at step 0);
//   the Speed picker (`speed` → `sim.speed [index]`: ×0.25, ×0.5, ×1, ×2, ×4);
//   the Time step stepper (`time-step` → `sim.timestep [Δt ± 0.05]`, feature 119: reaction-diffusion and the wave
//     only; a step beyond the stability limit is refused and its sentence appears in the message line);
//   without floating-point render targets the Family picker disables reaction-diffusion and the wave field;
//   feature 120 (A16-P04) T-A16-404/405/408/409: the Seed row (`seed-column`, `seed-row`, `seed` → `sim.paint [x, y,
//     0]`), the Inspector (`inspector`: every parameter with value, unit and range, the time step with its limit), the
//     approximation label (`approximation`), the Presets section (bundled presets → `sim.family` and `sim.preset`;
//     saved ones → `sim.spec`; `preset-name` and `preset-save`; delete), and Capture (`capture`, with a ShareLink to
//     the PNG; a running simulation is paused for it and resumed); the Speed picker disables speeds above the cap;
//   the status line (`status`: "Running at ×1, step 120") and the answer to a refused action (`message`, shown only
//     when there is one).
// Every control and line has an accessible label and value (controls a hint too) and the identifier
// `experience.a16.simulation-lab.<name>` from the port; hit areas are at least 44 points high and text wraps. A new
// message is also announced to VoiceOver.
//
// The view holds references only — the port, the mirror and the presenter — and no closure, so the rebuilt view
// compares equal from one host update to the next (feature 108 T-A14-609). Actions go through the presenter.
import SimulationLabCore
import SwiftUI
import VisualCoreParameters
import VisualCoreRendering
import VisualCoreExperience
import VisualCoreExperienceHost

/// The controls of Simulation Lab.
struct SimulationControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: SimulationMirror
    /// The presenter every action goes through (it shows the answer to a refused action in the mirror).
    let presenter: SimulationPresenter

    /// The host's still renderer (nil outside the host).
    @Environment(\.experienceStillRenderer) private var still
    /// The Seed row's column.
    @State private var seedColumn = SimulationCore.gridSize / 2
    /// The Seed row's row.
    @State private var seedRow = SimulationCore.gridSize / 2
    /// The name typed for a saved experiment.
    @State private var presetName = ""
    /// The answer to the last save.
    @State private var presetMessage: String?

    /// The time-step increment of one stepper tap.
    static let timeStepIncrement = 0.05

    /// The time step one tap from `value` (`up` adds, otherwise subtracts ``timeStepIncrement``), rounded to two
    /// decimals so repeated taps stay on the 0.05 grid.
    static func nextTimeStep(_ value: Double, up: Bool) -> Double {
        ((value + (up ? timeStepIncrement : -timeStepIncrement)) * 100).rounded() / 100
    }

    /// The Run / Pause button's title: "Pause" while running, "Run" while paused.
    static func runPauseTitle(running: Bool) -> String { running ? "Pause" : "Run" }

    /// The Step button's hint: why it is disabled while running.
    static func stepHint(running: Bool) -> String {
        running ? "Pause first to step one iteration at a time" : "Runs exactly one iteration"
    }

    /// The preset in words for the Preset picker's value ("Life (B3/S23)"; "Custom parameters" without a preset).
    static func presetTitle(_ titles: [String], preset: Int?) -> String {
        guard let preset, titles.indices.contains(preset) else { return "Custom parameters" }
        return titles[preset]
    }

    /// The controls, or a progress indicator before the first state.
    var body: some View {
        if mirror.ready {
            content
        } else {
            ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
        }
    }

    /// The pickers, the buttons and the lines.
    @ViewBuilder private var content: some View {
        let running = mirror.running
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Simulation Lab").font(.headline).accessibilityAddTraits(.isHeader)
            familyPicker
            presetPicker
            HStack(spacing: 8) {
                button(Self.runPauseTitle(running: running), name: "run-pause", value: mirror.status,
                       hint: running ? "Pauses the simulation" : "Starts the simulation", enabled: true) {
                    send(running ? "sim.pause" : "sim.run")
                }
                button("Step", name: "step", value: mirror.status, hint: Self.stepHint(running: running),
                       enabled: !running) { send("sim.step") }
                button("Reset", name: "reset", value: mirror.status,
                       hint: "Returns to the seeded start at step 0", enabled: true) { send("sim.reset") }
            }
            speedPicker
            if mirror.family != 0 { timeStepStepper }
            seedRowView
            line(mirror.approximation, label: "Approximation", name: "approximation")
            inspector
            presetsSection
            captureRow
            line(mirror.status, label: "Status", name: "status")
            if !mirror.message.isEmpty {
                line(mirror.message, label: "Message", name: "message")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: mirror.message) { _, message in
            if !message.isEmpty { AccessibilityNotification.Announcement(message).post() }
        }
    }

    /// The Family picker (sends `sim.family [index]` only when the choice changes).
    private var familyPicker: some View {
        Picker(selection: Binding(get: { mirror.family },
                                  set: { index in
                                      guard index != mirror.family else { return }
                                      send("sim.family", [Double(index)])
                                  })) {
            ForEach(SimulationCore.familyTitles.indices, id: \.self) { index in
                Text(verbatim: SimulationCore.familyTitles[index]).tag(index)
                    .disabled(index != 0 && !mirror.floatFamiliesAvailable)
            }
        } label: {
            Text(verbatim: "Family")
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Family"))
        .accessibilityValue(Text(verbatim: mirror.familyTitle))
        .accessibilityHint(Text(verbatim: "Chooses the cellular automaton, reaction-diffusion or the wave field"))
        .accessibilityIdentifier(port.identifier("family"))
    }

    /// The Preset picker (sends `sim.preset [index]` only when the choice changes).
    private var presetPicker: some View {
        let titles = mirror.presetTitles
        return Picker(selection: Binding(get: { mirror.preset ?? -1 },
                                         set: { index in
                                             guard index >= 0, index != mirror.preset else { return }
                                             send("sim.preset", [Double(index)])
                                         })) {
            ForEach(titles.indices, id: \.self) { index in
                Text(verbatim: titles[index]).tag(index)
            }
        } label: {
            Text(verbatim: "Preset")
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Preset"))
        .accessibilityValue(Text(verbatim: Self.presetTitle(titles, preset: mirror.preset)))
        .accessibilityHint(Text(verbatim: titles.count == 1 ? "This family has one preset"
                                    : "Chooses a preset of this family and starts it again"))
        .accessibilityIdentifier(port.identifier("preset"))
    }

    /// The Speed picker (sends `sim.speed [index]` only when the choice changes).
    private var speedPicker: some View {
        Picker(selection: Binding(get: { mirror.speedIndex },
                                  set: { index in
                                      guard index != mirror.speedIndex else { return }
                                      send("sim.speed", [Double(index)])
                                  })) {
            ForEach(SimulationCore.speedTitles.indices, id: \.self) { index in
                Text(verbatim: SimulationCore.speedTitles[index]).tag(index)
                    .disabled(index > mirror.speedCap)
            }
        } label: {
            Text(verbatim: "Speed")
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Speed"))
        .accessibilityValue(Text(verbatim: SimulationCore.speedTitle(index: mirror.speedIndex)))
        .accessibilityHint(Text(verbatim: "Sets how many iterations run per second, relative to the family's rate"))
        .accessibilityIdentifier(port.identifier("speed"))
    }

    /// The Time step stepper (sends `sim.timestep [Δt ± 0.05]`; the core refuses a step beyond the limit).
    private var timeStepStepper: some View {
        let words = SimulationCore.decimal(mirror.timeStep)
        return Stepper {
            Text(verbatim: "Time step \(words)")
        } onIncrement: {
            send("sim.timestep", [Self.nextTimeStep(mirror.timeStep, up: true)])
        } onDecrement: {
            send("sim.timestep", [Self.nextTimeStep(mirror.timeStep, up: false)])
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Time step"))
        .accessibilityValue(Text(verbatim: words))
        .accessibilityHint(Text(verbatim: "Changes the time step by 0.05; a step beyond the stability limit is refused"))
        .accessibilityIdentifier(port.identifier("time-step"))
    }

    /// The Seed row: column and row steppers and a Seed button sending `sim.paint [x, y, 0]`, the touch alternative.
    private var seedRowView: some View {
        let last = SimulationCore.gridSize - 1
        return VStack(alignment: .leading, spacing: 4) {
            Stepper(value: $seedColumn, in: 0...last) { Text(verbatim: "Column \(seedColumn)") }
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Seed column"))
                .accessibilityValue(Text(verbatim: "\(seedColumn)"))
                .accessibilityIdentifier(port.identifier("seed-column"))
            Stepper(value: $seedRow, in: 0...last) { Text(verbatim: "Row \(seedRow)") }
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Seed row"))
                .accessibilityValue(Text(verbatim: "\(seedRow)"))
                .accessibilityIdentifier(port.identifier("seed-row"))
            button("Seed", name: "seed", value: "column \(seedColumn), row \(seedRow)",
                   hint: "Seeds the cell as a tap on the field does", enabled: true) {
                send("sim.paint", [Double(seedColumn), Double(seedRow), 0])
            }
        }
    }

    /// The inspector: every parameter of the family with value, unit and range, and the time step with its limit.
    @ViewBuilder private var inspector: some View {
        if let spec = mirror.spec {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Inspector").font(.subheadline).accessibilityAddTraits(.isHeader)
                ForEach(Self.inspectorRows(spec), id: \.self) { row in
                    Text(verbatim: row).font(.footnote).fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(port.identifier("inspector"))
        }
    }

    /// The inspector's rows for `spec`: "Feed: 0.035 (range 0 to 0.1)", "Wave speed: 1 cells per time unit (range 0.1
    /// to 2)", and the time step with its limit ("Time step: 1 time units (limit 1.5625)"; the wave's names the Courant
    /// limit 0.707; the automaton's is one generation).
    static func inspectorRows(_ spec: SimulationSpec) -> [String] {
        var rows: [String] = []
        for definition in ParameterCatalog.definitions(for: spec.kind) {
            let unit = definition.unit.isEmpty ? "" : " " + definition.unit
            rows.append("\(definition.title): \(SimulationCore.decimal(spec.value(definition.name)))\(unit) (range "
                        + "\(SimulationCore.decimal(definition.minimum)) to \(SimulationCore.decimal(definition.maximum)))")
        }
        switch spec.kind {
        case .automaton: rows.append("Time step: one generation per step")
        case .reactionDiffusion:
            rows.append("Time step: \(SimulationCore.decimal(spec.timeStep)) time units (limit 1.5625)")
        case .wave:
            rows.append("Time step: \(SimulationCore.decimal(spec.timeStep)) time units (Courant number "
                        + "\(SimulationCore.decimal((spec.courantNumber * 1000).rounded() / 1000)), limit 0.707)")
        }
        return rows
    }

    /// The Presets section: the bundled presets, the saved experiments, saving under a name, deleting.
    @ViewBuilder private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Presets").font(.subheadline).accessibilityAddTraits(.isHeader)
            ForEach(ExperimentPreset.bundled.indices, id: \.self) { index in
                let preset = ExperimentPreset.bundled[index]
                button(preset.name, name: "bundled-\(index)", value: preset.source + ", " + preset.license,
                       hint: preset.annotation, enabled: true) { open(bundled: preset) }
            }
            if let store = presenter.presets {
                ForEach(store.entries, id: \.id) { entry in
                    HStack(spacing: 8) {
                        button(entry.preset.name, name: "saved-\(entry.id.uuidString.lowercased())",
                               value: SimulationCore.presetWords(entry.preset.spec),
                               hint: "Opens the saved experiment", enabled: true) {
                            send("sim.spec", SimulationCore.specValues(entry.preset.spec))
                        }
                        button("Delete", name: "delete-\(entry.id.uuidString.lowercased())", value: entry.preset.name,
                               hint: "Deletes the saved experiment", enabled: true) { store.delete(entry.id) }
                    }
                }
                TextField(text: $presetName) { Text(verbatim: "Name") }
                    .frame(minHeight: 44)
                    .accessibilityLabel(Text(verbatim: "Experiment name"))
                    .accessibilityIdentifier(port.identifier("preset-name"))
                button("Save experiment", name: "preset-save", value: presetName,
                       hint: "Saves the current experiment under this name", enabled: true) { save(store) }
                if let presetMessage { line(presetMessage, label: "Preset message", name: "preset-message") }
            }
        }
    }

    /// The Capture button and, after a capture, the share link to its PNG; a failure shows its message.
    @ViewBuilder private var captureRow: some View {
        button("Capture picture", name: "capture", value: "1024 × 1024 PNG",
               hint: "Captures the field as a picture to share", enabled: still != nil) { captureNow() }
        if let url = presenter.capture.url {
            ShareLink(item: SimulationCaptureFile(url: url),
                      preview: SharePreview(Text(verbatim: "Simulation Lab picture"))) {
                Text(verbatim: "Share picture").frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier(port.identifier("share"))
        }
        if let message = presenter.capture.message { line(message, label: "Capture message", name: "capture-message") }
    }

    /// Chooses a bundled preset by its family and preset index.
    private func open(bundled preset: ExperimentPreset) {
        let family = Double(SimulationCore.families.firstIndex(of: preset.spec.kind) ?? 0)
        let index = SimulationCore.preset(of: preset.spec) ?? 0
        if mirror.family != Int(family) { send("sim.family", [family]) }
        send("sim.preset", [Double(index)])
    }

    /// Saves the current experiment under the typed name.
    private func save(_ store: SimulationPresetStore) {
        guard let spec = mirror.spec else { return }
        let preset = ExperimentPreset(name: presetName.trimmingCharacters(in: .whitespacesAndNewlines), spec: spec,
                                      palette: "standard", annotation: "Saved in Simulation Lab.",
                                      source: "Saved by you", license: "original")
        presetMessage = store.save(preset)
        if presetMessage == nil { presetName = "" }
    }

    /// Captures the field through the host's still renderer, pausing a running simulation around it.
    private func captureNow() {
        guard let still else { return }
        presenter.captureStill(through: port) { width, height in try still(width: width, height: height) }
    }

    /// Sends `control` with `values` through the presenter, which shows the answer when it is refused.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, through: port)
    }

    /// A wrapping text line `text` with the accessible label `label`, the value `text` and the identifier `name`.
    private func line(_ text: String, label: String, name: String) -> some View {
        Text(verbatim: text)
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityValue(Text(verbatim: text))
            .accessibilityIdentifier(port.identifier(name))
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
