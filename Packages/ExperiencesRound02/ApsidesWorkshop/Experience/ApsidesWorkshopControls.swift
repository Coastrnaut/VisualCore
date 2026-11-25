// ApsidesWorkshopControls — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-005; clarification Q5). The minimal
// control panel: labelled buttons for the periapsis knob (eccentricity − and +, direction − and +, each
// `orbit.periapsis [k, d]` with one step changed: one action of the budget), the size (size − and +, `orbit.size [a]`:
// one action), the shown tick (tick − and +, `clock.show [tick]` clamped to 0 … period − 1), playing the revolution
// (`orbit.play`), undo, redo and next level (kernel actions through the action port), each with an accessibility label,
// value and identifier. The shown tick is presentation state of the adapter (a level opens at tick 0). A step that
// would leave the steps' ranges or make the orbit invalid is still sent: the kernel refuses it and the panel says why.
// The header shows the actions left of the budget, the status (stage, or the failure in words), the progress
// description, the tutorial on levels that have one, the failure in words and a refused action in words. Dragging the
// periapsis knob and the semi-major axis, turning the time crank and full accessibility come in later features of
// R02-G18.
#if os(iOS)
import ApsidesWorkshopCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Apsides Workshop.
struct ApsidesWorkshopControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows.
    let mirror: ApsidesWorkshopMirror

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                eccentricityRow
                directionRow
                sizeRow
                tickRow
                playRow
            }
            .padding()
        }
    }

    /// The level, actions, status, tutorial, failure and refusal lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · \(mirror.actionsLeft) of \(mirror.budget) actions left")
            .font(.headline)
            .accessibilityIdentifier(port.identifier("actions"))
        Text(mirror.status).font(.subheadline)
            .accessibilityIdentifier(port.identifier("status"))
        if let tutorial = mirror.tutorialText {
            Text(tutorial).font(.footnote)
                .accessibilityIdentifier(port.identifier("tutorial"))
        }
        if let failure = mirror.failureText {
            Text(failure).font(.footnote)
                .accessibilityIdentifier(port.identifier("failure"))
        }
        Text(mirror.measureLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("progress"))
        Text(mirror.targetLabel).font(.footnote)
        if let message = mirror.message {
            Text(message).font(.footnote)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// Lower or raise the eccentricity by one step (one action).
    @ViewBuilder private var eccentricityRow: some View {
        HStack(spacing: 16) {
            Button("Eccentricity −") { knob(eccentricityStep: -1, directionStep: 0) }
                .accessibilityLabel("Lower the eccentricity by one step")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("eccentricity-minus"))
            Text("eccentricity \(mirror.orbit.eccentricity)")
                .accessibilityIdentifier(port.identifier("eccentricity"))
            Button("Eccentricity +") { knob(eccentricityStep: 1, directionStep: 0) }
                .accessibilityLabel("Raise the eccentricity by one step")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("eccentricity-plus"))
        }
        Text(mirror.orbitLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("orbit-detail"))
    }

    /// Turn the periapsis direction back or forward by 15° (one action).
    @ViewBuilder private var directionRow: some View {
        HStack(spacing: 16) {
            Button("Direction −") { knob(eccentricityStep: 0, directionStep: -1) }
                .accessibilityLabel("Turn the periapsis 15 degrees clockwise")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("direction-minus"))
            Text("direction \(mirror.orbit.direction * 15)°")
                .accessibilityIdentifier(port.identifier("direction"))
            Button("Direction +") { knob(eccentricityStep: 0, directionStep: 1) }
                .accessibilityLabel("Turn the periapsis 15 degrees counterclockwise")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("direction-plus"))
        }
    }

    /// Shrink or grow the orbit by one lattice unit (one action).
    @ViewBuilder private var sizeRow: some View {
        HStack(spacing: 16) {
            Button("Size −") { send("orbit.size", [Double(mirror.orbit.size - 1)]) }
                .accessibilityLabel("Shrink the orbit by one unit")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("size-minus"))
            Text("size \(mirror.orbit.size)")
                .accessibilityIdentifier(port.identifier("size"))
            Button("Size +") { send("orbit.size", [Double(mirror.orbit.size + 1)]) }
                .accessibilityLabel("Grow the orbit by one unit")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("size-plus"))
        }
    }

    /// Show an earlier or later tick of the revolution, and play it.
    @ViewBuilder private var tickRow: some View {
        HStack(spacing: 16) {
            Button("Tick −") { show(tick: mirror.shownTick - 1) }
                .accessibilityLabel("Show the orbiter one tick earlier")
                .accessibilityValue(mirror.tickLabel)
                .accessibilityIdentifier(port.identifier("tick-minus"))
            Text("tick \(mirror.shownTick)")
                .accessibilityIdentifier(port.identifier("tick"))
            Button("Tick +") { show(tick: mirror.shownTick + 1) }
                .accessibilityLabel("Show the orbiter one tick later")
                .accessibilityValue(mirror.tickLabel)
                .accessibilityIdentifier(port.identifier("tick-plus"))
            Button("Play") { send("orbit.play") }
                .accessibilityLabel("Play the revolution and end the level")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("play"))
        }
        Text(mirror.tickLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("tick-detail"))
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last tuning or play")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the tuning or play")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
    }

    /// Sends the periapsis knob with the eccentricity and direction moved by the given steps (the direction wraps).
    private func knob(eccentricityStep: Int, directionStep: Int) {
        let orbit: ApsidesWorkshopOrbit = mirror.orbit
        let direction: Int = ((orbit.direction + directionStep) % 24 + 24) % 24
        send("orbit.periapsis", [Double(orbit.eccentricity + eccentricityStep), Double(direction)])
    }

    /// Shows tick `tick` (clamped to 0 … period − 1).
    private func show(tick: Int) {
        send("clock.show", [Double(mirror.clampedTick(tick))])
    }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(ApsidesWorkshopMirror.refusalText(code: result.code))."
    }
}
#endif
