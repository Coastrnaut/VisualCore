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
