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
//
// Feature 474 (R02-G18-04) T-R02G1804-005 (FR-R02G1804-008; clarification Q5): the eccentricity, direction and size − and
// + no longer send a tuning each (every tuning costs an action, so stepping to a far orbit could exceed the budget);
// they move the pending orbit (`mirror.pendingOrbit`, presentation only; the direction wraps 0 … 23, the eccentricity
// clamps to 0 … 15 and the size to 8 … 48), drawn as the same preview as a drag, and each line reads "value → pending"
// while one is pending. "Set periapsis" sends exactly one `orbit.periapsis [k, d]` with the pending eccentricity and
// direction, and "Set size" one `orbit.size [a]` with the pending size, each only when the pending value differs from
// the current one and the resulting orbit is valid (disabled otherwise); "Reset view" returns the camera to the
// authored view. Every button sends through the presenter's `send` (refusals shown in words and logged with their
// codes).
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
    /// Returns the camera to the authored view (feature 474; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 474); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil
    /// Redraws the last snapshot with the mirror's preview after the pending orbit moved (feature 474).
    var redraw: () -> Void = {}

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                eccentricityRow
                directionRow
                sizeRow
                setRow
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
            Button("Eccentricity −") { movePending(eccentricity: -1, direction: 0, size: 0) }
                .accessibilityLabel("Lower the pending eccentricity by one step")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("eccentricity-minus"))
            Text(mirror.pendingLine("eccentricity", mirror.orbit.eccentricity, mirror.pending.eccentricity))
                .accessibilityIdentifier(port.identifier("eccentricity"))
            Button("Eccentricity +") { movePending(eccentricity: 1, direction: 0, size: 0) }
                .accessibilityLabel("Raise the pending eccentricity by one step")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("eccentricity-plus"))
        }
        Text(mirror.orbitLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("orbit-detail"))
    }

    /// Turn the periapsis direction back or forward by 15° (one action).
    @ViewBuilder private var directionRow: some View {
        HStack(spacing: 16) {
            Button("Direction −") { movePending(eccentricity: 0, direction: -1, size: 0) }
                .accessibilityLabel("Turn the pending periapsis 15 degrees clockwise")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("direction-minus"))
            Text(mirror.pendingLine("direction", mirror.orbit.direction * 15, mirror.pending.direction * 15, unit: "°"))
                .accessibilityIdentifier(port.identifier("direction"))
            Button("Direction +") { movePending(eccentricity: 0, direction: 1, size: 0) }
                .accessibilityLabel("Turn the pending periapsis 15 degrees counterclockwise")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("direction-plus"))
        }
    }

    /// Shrink or grow the orbit by one lattice unit (one action).
    @ViewBuilder private var sizeRow: some View {
        HStack(spacing: 16) {
            Button("Size −") { movePending(eccentricity: 0, direction: 0, size: -1) }
                .accessibilityLabel("Shrink the pending orbit by one unit")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("size-minus"))
            Text(mirror.pendingLine("size", mirror.orbit.size, mirror.pending.size))
                .accessibilityIdentifier(port.identifier("size"))
            Button("Size +") { movePending(eccentricity: 0, direction: 0, size: 1) }
                .accessibilityLabel("Grow the pending orbit by one unit")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("size-plus"))
        }
    }

    /// Set the pending periapsis or size (one action each) and return the camera.
    @ViewBuilder private var setRow: some View {
        HStack(spacing: 16) {
            Button("Set periapsis") { setPeriapsis() }
                .disabled(!mirror.periapsisSettable)
                .accessibilityLabel("Set the periapsis to the pending eccentricity and direction")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("set-periapsis"))
            Button("Set size") { setSize() }
                .disabled(!mirror.sizeSettable)
                .accessibilityLabel("Set the size to the pending size")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("set-size"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue("presentation only")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
        if let reason = mirror.pendingReason {
            Text(reason).font(.footnote)
                .accessibilityIdentifier(port.identifier("pending-reason"))
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

    /// Moves the pending orbit by the given steps (presentation only) and redraws the preview.
    private func movePending(eccentricity: Int, direction: Int, size: Int) {
        mirror.movePending(eccentricity: eccentricity, direction: direction, size: size)
        redraw()
    }

    /// Sets the periapsis to the pending eccentricity and direction (one action) when settable.
    private func setPeriapsis() {
        guard mirror.periapsisSettable else { return }
        let pending: ApsidesWorkshopOrbit = mirror.pending
        send("orbit.periapsis", [Double(pending.eccentricity), Double(pending.direction)])
    }

    /// Sets the size to the pending size (one action) when settable.
    private func setSize() {
        guard mirror.sizeSettable else { return }
        send("orbit.size", [Double(mirror.pending.size)])
    }

    /// Shows tick `tick` (clamped to 0 … period − 1).
    private func show(tick: Int) {
        send("clock.show", [Double(mirror.clampedTick(tick))])
    }

    /// Sends `control` through the presenter (or the port when no sender is set) and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        if let sender {
            sender(control, values)
            return
        }
        let result = port.send(control, values)
        mirror.record(control, values, accepted: result.isAccepted, code: result.code)
    }
}
#endif
