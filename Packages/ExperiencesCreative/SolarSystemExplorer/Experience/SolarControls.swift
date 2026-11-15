// SolarControls — feature 103 (A14-P01) T-A14-103 (FR-A14-121; clarifications Q4, Q5), with the orbit view's date and
// camera controls by feature 104 (A14-P02) T-A14-208 (FR-A14-211, FR-A14-221; clarifications Q3–Q5;
// contracts/orbit-view.md). The native controls of Solar System Explorer in one section:
//   the date (`date`: "Date: 2000-01-01") and the date buttons −365, −30, −1, +1, +30, +365 days (`date-minus-365`,
//     `date-minus-30`, `date-minus-1`, `date-plus-1`, `date-plus-30`, `date-plus-365` → `date.step [days]`; each
//     disabled when the step would leave 1950-01-01 … 2051-01-01; the date as accessible value);
//   Previous body and Next body (`previous-body`, `next-body` → `body.previous` / `body.next`; disabled at the Sun
//     and at Neptune);
//   the Body menu (`body` → `body.select [index]`) listing the nine bodies by name in catalog order;
//   the camera buttons Orbit left and Orbit right (`orbit-left`, `orbit-right` → `camera.orbit [−1 / +1]`: the camera
//     moves 15° around the focused body to the left or right), Tilt up and Tilt down (`tilt-up`, `tilt-down` →
//     `camera.tilt [+1 / −1]`: the camera rises or sinks 10°, disabled at 85° and 5°), Zoom in and Zoom out
//     (`zoom-in`, `zoom-out` → `camera.zoom [+1 / −1]`, disabled at zoom steps 12 and −1) and Reset view
//     (`reset-view` → `view.reset`), each with the camera value it changes as accessible value;
//   the fact card of the selected body (`fact-1`, `fact-2`, … in display order, each "Mean radius: 6,371 km —
//     Planetary Fact Sheet — Metric": label, value, unit, note and source) and, for a planet, the line
//     "Distance from the Sun on 2000-01-01: 0.983 AU (147,099,000 km)" (`distance`);
//   the legend "Distances and sizes not to scale" (`legend`), the status line (`status`: "Earth selected, body 4 of
//     9") and the answer to a refused action (`message`, shown only when there is one).
// Every control has an accessible label and value (and a hint) and the identifier
// `experience.a14.solar-system-explorer.<name>` from the port; hit areas are at least 44 points high and text wraps.
import SolarSystemExplorerCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// The controls of Solar System Explorer.
struct SolarControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: SolarMirror

    /// The names of the bodies in catalog order (the Body menu's entries).
    static var bodyNames: [String] { SolarCore.catalog.bodies.map(\.name) }

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// The selected body in words: "Earth, body 4 of 9".
    static func bodyWords(index: Int, count: Int) -> String {
        "\(SolarCore.name(index: index)), body \(index + 1) of \(count)"
    }

    /// The identifier name of fact line `index` (0-based): `fact-1` for the first line.
    static func factName(_ index: Int) -> String { "fact-\(index + 1)" }

    /// The date steps of the date buttons in display order (days).
    static let dateSteps: [Int] = [-365, -30, -1, 1, 30, 365]

    /// The identifier name of the date button of `days`: `date-minus-365`, …, `date-plus-365`.
    static func dateName(_ days: Int) -> String { days < 0 ? "date-minus-\(-days)" : "date-plus-\(days)" }

    /// The title of the date button of `days`: "−365 days", "−1 day", "+1 day", "+30 days".
    static func dateTitle(_ days: Int) -> String {
        let sign = days < 0 ? "\u{2212}" : "+"
        return "\(sign)\(abs(days)) \(abs(days) == 1 ? "day" : "days")"
    }

    /// Whether the date `dayOffset` can step by `days` without leaving the model's range.
    static func canStep(dayOffset: Double, by days: Int) -> Bool {
        guard let date = SimulatedDate(dayOffset: dayOffset) else { return false }
        if case .success = date.stepped(by: days) { return true }
        return false
    }

    /// The distance line of the fact card: "Distance from the Sun on 2000-01-01: 0.983 AU (147,099,000 km)"; empty
    /// when there is no distance (the Sun).
    static func distanceLine(date: String, distance: String) -> String {
        distance.isEmpty ? "" : "Distance from the Sun on \(date): \(distance)"
    }

    /// The yaw in words: "Yaw 15°".
    static func yawWords(_ degrees: Double) -> String { "Yaw \(Int(degrees.rounded()))°" }

    /// The pitch in words: "Pitch 35°".
    static func pitchWords(_ degrees: Int) -> String { "Pitch \(degrees)°" }

    /// The zoom in words: "Distance 60.0 scene units, zoom step 0 (−1 to 12)".
    static func zoomWords(distance: Double, steps: Int) -> String {
        String(format: "Distance %.1f scene units", distance) + ", zoom step \(steps) (\u{2212}1 to 12)"
    }

    /// The whole camera in words: "Yaw 0°, pitch 35°, distance 60.0 scene units".
    static func cameraWords(yaw: Double, pitch: Int, distance: Double) -> String {
        "Yaw \(Int(yaw.rounded()))°, pitch \(pitch)°, " + String(format: "distance %.1f scene units", distance)
    }

    /// The controls, or a progress indicator before the first state.
    var body: some View {
        Group {
            if mirror.ready {
                content
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
    }

    @ViewBuilder private var content: some View {
        let words = Self.bodyWords(index: mirror.selection, count: mirror.bodyCount)
        let atFirst = mirror.selection <= 0
        let atLast = mirror.selection >= mirror.bodyCount - 1
        let dateWords = "Date: \(mirror.dateLabel)"
        let yaw = Self.yawWords(mirror.yawDegrees)
        let pitch = Self.pitchWords(mirror.pitchDegrees)
        let zoom = Self.zoomWords(distance: mirror.cameraDistance, steps: mirror.zoomSteps)
        let camera = Self.cameraWords(yaw: mirror.yawDegrees, pitch: mirror.pitchDegrees,
                                      distance: mirror.cameraDistance)
        let distanceLine = Self.distanceLine(date: mirror.dateLabel, distance: mirror.distance)
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Solar System Explorer").font(.headline).accessibilityAddTraits(.isHeader)
            Text(verbatim: dateWords)
                .font(.subheadline)
                .accessibilityLabel(Text(verbatim: "Date"))
                .accessibilityValue(Text(verbatim: mirror.dateLabel))
                .accessibilityIdentifier(port.identifier("date"))
            HStack(spacing: 8) {
                ForEach(Self.dateSteps.prefix(3), id: \.self) { days in dateButton(days) }
            }
            HStack(spacing: 8) {
                ForEach(Self.dateSteps.suffix(3), id: \.self) { days in dateButton(days) }
            }
            HStack(spacing: 8) {
                button("Previous body", name: "previous-body", value: words,
                       hint: atFirst ? "The Sun is the first body" : "Focuses the body nearer the Sun",
                       enabled: !atFirst) { send("body.previous") }
                button("Next body", name: "next-body", value: words,
                       hint: atLast ? "Neptune is the last body" : "Focuses the body farther from the Sun",
                       enabled: !atLast) { send("body.next") }
            }
            Menu {
                ForEach(Self.bodyNames.indices, id: \.self) { index in
                    Button {
                        send("body.select", [Double(index)])
                    } label: {
                        Text(verbatim: Self.bodyNames[index])
                    }
                }
            } label: {
                Text(verbatim: "Body")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(verbatim: "Body"))
            .accessibilityValue(Text(verbatim: words))
            .accessibilityHint(Text(verbatim: "Focuses any of the nine bodies"))
            .accessibilityIdentifier(port.identifier("body"))
            HStack(spacing: 8) {
                button("Orbit left", name: "orbit-left", value: yaw,
                       hint: "Moves the camera 15 degrees to the left around the focused body",
                       enabled: true) { send("camera.orbit", [-1]) }
                button("Orbit right", name: "orbit-right", value: yaw,
                       hint: "Moves the camera 15 degrees to the right around the focused body",
                       enabled: true) { send("camera.orbit", [1]) }
            }
            HStack(spacing: 8) {
                let atTop = mirror.pitchDegrees + SolarState.pitchStep > SolarState.pitchRange.upperBound
                let atBottom = mirror.pitchDegrees - SolarState.pitchStep < SolarState.pitchRange.lowerBound
                button("Tilt up", name: "tilt-up", value: pitch,
                       hint: atTop ? "The camera is at its highest" : "Raises the camera 10 degrees",
                       enabled: !atTop) { send("camera.tilt", [1]) }
                button("Tilt down", name: "tilt-down", value: pitch,
                       hint: atBottom ? "The camera is at its lowest" : "Lowers the camera 10 degrees",
                       enabled: !atBottom) { send("camera.tilt", [-1]) }
            }
            HStack(spacing: 8) {
                let closest = mirror.zoomSteps >= SolarState.zoomRange.upperBound
                let farthest = mirror.zoomSteps <= SolarState.zoomRange.lowerBound
                button("Zoom in", name: "zoom-in", value: zoom,
                       hint: closest ? "The camera is at its closest" : "Moves the camera closer",
                       enabled: !closest) { send("camera.zoom", [1]) }
                button("Zoom out", name: "zoom-out", value: zoom,
                       hint: farthest ? "The camera is at its farthest" : "Moves the camera farther away",
                       enabled: !farthest) { send("camera.zoom", [-1]) }
            }
            button("Reset view", name: "reset-view", value: camera,
                   hint: "Returns to the overview camera; the body and the date stay",
                   enabled: true) { send("view.reset") }
            Text(verbatim: mirror.bodyName).font(.subheadline).accessibilityAddTraits(.isHeader)
            ForEach(mirror.facts.indices, id: \.self) { index in
                Text(verbatim: mirror.facts[index])
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Fact \(index + 1)"))
                    .accessibilityValue(Text(verbatim: mirror.facts[index]))
                    .accessibilityIdentifier(port.identifier(Self.factName(index)))
            }
            if !distanceLine.isEmpty {
                Text(verbatim: distanceLine)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Distance from the Sun"))
                    .accessibilityValue(Text(verbatim: distanceLine))
                    .accessibilityIdentifier(port.identifier("distance"))
            }
            Text(verbatim: SolarCore.notToScale)
                .font(.footnote.italic())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Legend"))
                .accessibilityValue(Text(verbatim: SolarCore.notToScale))
                .accessibilityIdentifier(port.identifier("legend"))
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Status"))
                .accessibilityValue(Text(verbatim: Self.sentence(mirror.status)))
                .accessibilityIdentifier(port.identifier("status"))
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

    /// The date button of `days` (sends `date.step [days]`; disabled when the step would leave the range).
    private func dateButton(_ days: Int) -> some View {
        let enabled = Self.canStep(dayOffset: mirror.dayOffset, by: days)
        let later = days > 0 ? "later" : "earlier"
        return button(Self.dateTitle(days), name: Self.dateName(days), value: mirror.dateLabel,
                      hint: enabled ? "Moves the date \(abs(days)) \(abs(days) == 1 ? "day" : "days") \(later)"
                                    : "The date stays within 1950-01-01 to 2051-01-01",
                      enabled: enabled) { send("date.step", [Double(days)]) }
    }

    /// Sends `control` with `values` through the port and shows the answer when it is refused.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = SolarPresenter.answerWords(control: control, result: result)
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
