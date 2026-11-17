// AmbientControls — feature 132 T-A18-203 (FR-A18-202, FR-A18-207; G-OVERLAY; clarification Q2). The native controls
// of Ambient Clock, modelled on Interactive Anatomy's: the hour-cycle menu (`hour-cycle`: System, 12-hour, 24-hour),
// the seconds toggle (`seconds`) and the date toggle (`date`), which send `clock.format [cycle, seconds, date]`; the
// motion toggle (`motion` → `theme.motion [0 / 1]`) and the speed slider (`speed` → `theme.speed [0.25…2]`). Each
// sends only when its value changes, reads the presenter's mirror, has an accessible label, value and hint, and the
// identifier `experience.a18.ambient-clock.<name>` (`ExperienceActionPort.identifier`).
import SwiftUI
import VisualCoreExperienceHost

/// The native controls of Ambient Clock (see the file header).
struct AmbientControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: AmbientMirror
    /// The presenter the format goes through.
    let presenter: AmbientPresenter

    /// The titles of the hour cycles, by index: "System", "12-hour", "24-hour".
    static let hourCycleTitles = ["System", "12-hour", "24-hour"]

    /// The speed in words: "Speed 1.25 times".
    static func speedWords(_ speed: Double) -> String {
        "Speed " + String(format: "%.2f", speed) + " times"
    }

    /// The controls.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Ambient Clock").font(.headline).accessibilityAddTraits(.isHeader)
            hourCyclePicker
            toggle("Seconds", name: "seconds", isOn: mirror.showSeconds, hint: "Shows the seconds") { on in
                sendFormat(showSeconds: on)
            }
            toggle("Date", name: "date", isOn: mirror.showDate, hint: "Shows the date below the time") { on in
                sendFormat(showDate: on)
            }
            toggle("Motion", name: "motion", isOn: mirror.motion, hint: "Moves the background slowly") { on in
                port.send("theme.motion", [on ? 1 : 0])
            }
            speedSlider
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The hour-cycle menu (sends `clock.format` when the choice changes).
    private var hourCyclePicker: some View {
        let current = min(max(mirror.hourCycle, 0), Self.hourCycleTitles.count - 1)
        return Picker(selection: Binding(get: { current },
                                         set: { cycle in
                                             guard cycle != mirror.hourCycle else { return }
                                             sendFormat(hourCycle: cycle)
                                         })) {
            ForEach(Array(Self.hourCycleTitles.enumerated()), id: \.offset) { index, title in
                Text(verbatim: title).tag(index)
            }
        } label: {
            Text(verbatim: "Hour cycle")
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Hour cycle"))
        .accessibilityValue(Text(verbatim: Self.hourCycleTitles[current]))
        .accessibilityHint(Text(verbatim: "Chooses the system, 12-hour or 24-hour clock"))
        .accessibilityIdentifier(port.identifier("hour-cycle"))
    }

    /// The speed slider, 0.25…2 (sends `theme.speed` when the value changes).
    private var speedSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: Self.speedWords(mirror.speed)).font(.body)
            Slider(value: Binding(get: { mirror.speed },
                                  set: { value in
                                      guard value != mirror.speed else { return }
                                      port.send("theme.speed", [value])
                                  }),
                   in: AmbientCore.speedRange)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Speed"))
                .accessibilityValue(Text(verbatim: Self.speedWords(mirror.speed)))
                .accessibilityHint(Text(verbatim: "Sets how fast the background moves"))
                .accessibilityIdentifier(port.identifier("speed"))
        }
    }

    /// A toggle titled `title` with the identifier name `name`, calling `send` only when the choice changes.
    private func toggle(_ title: String, name: String, isOn: Bool, hint: String,
                        send: @escaping @MainActor (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn },
                             set: { on in
                                 guard on != isOn else { return }
                                 send(on)
                             })) {
            Text(verbatim: title).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: isOn ? "On" : "Off"))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// Sends `clock.format` with the mirror's format, changed by the given values.
    private func sendFormat(hourCycle: Int? = nil, showSeconds: Bool? = nil, showDate: Bool? = nil) {
        presenter.setFormat(hourCycle: hourCycle ?? mirror.hourCycle, showSeconds: showSeconds ?? mirror.showSeconds,
                            showDate: showDate ?? mirror.showDate, port: port)
    }
}
