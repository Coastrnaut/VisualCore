// CelestialEclipseLabControls — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-005; clarification Q5). The
// minimal control panel: labelled buttons for the chosen planet (planet − and +, the previous or next movable body,
// `orbit.choose [body]`), its phase (phase − and +, `orbit.phase [body, offset]` with the chosen body's phase moved by
// one modulo its period: one action of the budget) and the shown tick (tick − and +, `clock.show [tick]` clamped to
// 0 … horizon − 1), running the clock (`clock.run`), undo, redo and next level (kernel actions through the action
// port), each with an accessibility label, value and identifier. The chosen body and the shown tick are presentation
// state of the adapter (a level opens with the lowest-numbered movable body and tick 0). The header shows the actions
// left of the budget, the status (stage, or the failure in words), the progress description, the tutorial on levels
// that have one, the failure in words and a refused action in words. Tapping planets on the canvas, dragging the
// timeline and full accessibility come in later features of R02-G17.
#if os(iOS)
import CelestialEclipseLabCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Celestial Eclipse Lab.
struct CelestialEclipseLabControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows.
    let mirror: CelestialEclipseLabMirror

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                planetRow
                phaseRow
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

    /// Choose the previous or next movable planet.
    @ViewBuilder private var planetRow: some View {
        HStack(spacing: 16) {
            Button("Planet −") { send("orbit.choose", [Double(mirror.nextBody(-1))]) }
                .accessibilityLabel("Choose the previous planet")
                .accessibilityValue(mirror.bodyLabel)
                .accessibilityIdentifier(port.identifier("planet-minus"))
            Text("body \(mirror.chosenBody)")
                .accessibilityIdentifier(port.identifier("planet"))
            Button("Planet +") { send("orbit.choose", [Double(mirror.nextBody(1))]) }
                .accessibilityLabel("Choose the next planet")
                .accessibilityValue(mirror.bodyLabel)
                .accessibilityIdentifier(port.identifier("planet-plus"))
        }
        Text(mirror.bodyLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("planet-detail"))
    }

    /// Move the chosen planet's phase back or forward by one (one action).
    @ViewBuilder private var phaseRow: some View {
        HStack(spacing: 16) {
            Button("Phase −") { setPhase(step: -1) }
                .accessibilityLabel("Move the chosen planet's phase back by one")
                .accessibilityValue(mirror.bodyLabel)
                .accessibilityIdentifier(port.identifier("phase-minus"))
            Text("phase \(mirror.chosenPhase)")
                .accessibilityIdentifier(port.identifier("phase"))
            Button("Phase +") { setPhase(step: 1) }
                .accessibilityLabel("Move the chosen planet's phase forward by one")
                .accessibilityValue(mirror.bodyLabel)
                .accessibilityIdentifier(port.identifier("phase-plus"))
        }
    }

    /// Show an earlier or later tick of the predicted sky, and run the clock.
    @ViewBuilder private var tickRow: some View {
        HStack(spacing: 16) {
            Button("Tick −") { show(tick: mirror.shownTick - 1) }
                .accessibilityLabel("Show the sky one tick earlier")
                .accessibilityValue(mirror.tickLabel)
                .accessibilityIdentifier(port.identifier("tick-minus"))
            Text("tick \(mirror.shownTick)")
                .accessibilityIdentifier(port.identifier("tick"))
            Button("Tick +") { show(tick: mirror.shownTick + 1) }
                .accessibilityLabel("Show the sky one tick later")
                .accessibilityValue(mirror.tickLabel)
                .accessibilityIdentifier(port.identifier("tick-plus"))
            Button("Run") { send("clock.run") }
                .accessibilityLabel("Run the clock and end the level")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("run"))
        }
        Text(mirror.tickLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("tick-detail"))
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last phase change or run")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the phase change or run")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
    }

    /// Sets the chosen planet's phase to its current phase moved by `step` (±1) modulo its period.
    private func setPhase(step: Int) {
        send("orbit.phase", [Double(mirror.chosenBody), Double(mirror.steppedPhase(step))])
    }

    /// Shows tick `tick` (clamped to 0 … horizon − 1).
    private func show(tick: Int) {
        send("clock.show", [Double(mirror.clampedTick(tick))])
    }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(CelestialEclipseLabMirror.refusalText(code: result.code))."
    }
}
#endif
