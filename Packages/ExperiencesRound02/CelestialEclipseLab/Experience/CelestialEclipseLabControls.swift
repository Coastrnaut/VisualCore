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
//
// Feature 464 (R02-G17-04) T-R02G1704-005 (FR-R02G1704-008; clarification Q5): phase − and + no longer send a phase
// change each (every change costs an action, so stepping to a far orbit position could exceed the budget); they move
// the chosen planet's pending phase (`mirror.pendingOffset`, presentation only, wrapping 0 … period − 1), drawn as the
// same preview as a drag, and the phase line reads "phase P → Q" while one is pending. "Set phase" sends exactly one
// `orbit.phase [body, pending]` when the pending phase differs from the current one (disabled otherwise), and "Reset
// view" returns the camera to the authored orbit. Every button sends through the presenter's `send` (refusals shown
// in words and logged with their codes); everything else is unchanged.
//
// Feature 465 (R02-G17-05) T-R02G1705-005 (FR-R02G1705-001 … 005; clarifications Q1 … Q4): a teaching block under the
// header — the tutorial instruction with "Dismiss tutorial" (`tutorial.dismiss`), "Hint" (each press shows the next of
// three levels through the presenter's `showHint()`; hints send nothing) with the hint text, the failure explanation,
// and the level's band, goal and best stars — and a progress block: "Campaign" (`mode.campaign`), "Daily"
// (`mode.daily [year, month, day]` with today's local date from the presenter) and "Practice" (`mode.practice`), and a
// picker of the open levels (1 … the frontier, with their bands and stars) with "Play level" (`level.select [n]`). All
// wrapping text in the panel, never over the sky; refusals read in words.
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
    /// The presenter (feature 465): hints, the tutorial, the modes and the daily date; nil sends through ``send``.
    var presenter: CelestialEclipseLabPresenter? = nil
    /// Returns the camera to the authored view (feature 464; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 464); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil
    /// Redraws the last snapshot with the mirror's preview after the pending phase moved (feature 464).
    var redraw: () -> Void = {}

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                planetRow
                phaseRow
                tickRow
                playRow
                progressRows
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
        if let failure = mirror.failureText, mirror.explanation == nil {
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

    /// The tutorial instruction with Dismiss tutorial, Hint with the hint text, the failure explanation, and the band,
    /// goal and best stars (feature 465).
    @ViewBuilder private var teaching: some View {
        if let tutorial = mirror.tutorialText {
            Text(tutorial).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("tutorial"))
            Button("Dismiss tutorial") { dismissTutorial() }
                .accessibilityLabel("Dismiss the tutorial")
                .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
        }
        Button("Hint") { presenter?.showHint() }
            .disabled(presenter == nil)
            .accessibilityLabel("Show a hint")
            .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            .accessibilityIdentifier(port.identifier("hint"))
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("hint-text"))
        }
        if let explanation = mirror.explanation {
            Text(explanation).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("failure"))
        }
        HStack(spacing: 12) {
            Text(mirror.bandLabel).font(.footnote)
                .accessibilityIdentifier(port.identifier("band"))
            Text(mirror.starsLabel).font(.footnote)
                .accessibilityIdentifier(port.identifier("stars"))
        }
        Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("goal"))
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 465).
    @ViewBuilder private var progressRows: some View {
        HStack(spacing: 12) {
            Button("Campaign") { campaign() }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(modeValue("campaign"))
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { daily() }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(modeValue("daily"))
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { practice() }
                .accessibilityLabel("Practise this level with more actions")
                .accessibilityValue(modeValue("practice"))
                .accessibilityIdentifier(port.identifier("practice"))
        }
        HStack(spacing: 12) {
            Stepper(mirror.levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityLabel("Level to play")
                .accessibilityValue(mirror.levelLabel(mirror.pickedLevel))
                .accessibilityIdentifier(port.identifier("level-picker"))
            Button("Play level") { selectLevel(mirror.pickedLevel) }
                .accessibilityLabel("Play the picked level")
                .accessibilityValue(mirror.levelLabel(mirror.pickedLevel))
                .accessibilityIdentifier(port.identifier("play-level"))
        }
    }

    /// "selected" when `name` is the current mode's name, else "not selected".
    private func modeValue(_ name: String) -> String {
        CelestialEclipseLabMirror.modeName(mirror.mode) == name ? "selected" : "not selected"
    }

    /// Ends the tutorial of the level (`tutorial.dismiss`).
    private func dismissTutorial() {
        if let presenter { presenter.dismissTutorial(port: port) } else { send("tutorial.dismiss") }
    }

    /// Returns to the campaign (`mode.campaign`).
    private func campaign() {
        if let presenter { presenter.playCampaign(port: port) } else { send("mode.campaign") }
    }

    /// Plays today's daily level (`mode.daily` with the presenter's local calendar date).
    private func daily() {
        let values: [Double] = CelestialEclipseLabPresenter.dateValues(CelestialEclipseLabPresenter.today())
        if let presenter { presenter.playDaily(port: port) } else { send("mode.daily", values) }
    }

    /// Replays the level with the practice budget (`mode.practice`).
    private func practice() {
        if let presenter { presenter.playPractice(port: port) } else { send("mode.practice") }
    }

    /// Plays open level `level` (`level.select [level]`).
    private func selectLevel(_ level: Int) {
        if let presenter { presenter.selectLevel(level, port: port) } else { send("level.select", [Double(level)]) }
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

    /// Move the chosen planet's pending phase back or forward by one (presentation only) and set it (one action).
    @ViewBuilder private var phaseRow: some View {
        HStack(spacing: 16) {
            Button("Phase −") { movePending(step: -1) }
                .accessibilityLabel("Move the pending phase back by one")
                .accessibilityValue(phaseLabel)
                .accessibilityIdentifier(port.identifier("phase-minus"))
            Text(phaseLabel)
                .accessibilityIdentifier(port.identifier("phase"))
            Button("Phase +") { movePending(step: 1) }
                .accessibilityLabel("Move the pending phase forward by one")
                .accessibilityValue(phaseLabel)
                .accessibilityIdentifier(port.identifier("phase-plus"))
        }
        HStack(spacing: 16) {
            Button("Set phase") { setPhase() }
                .disabled(!mirror.pendingDiffers)
                .accessibilityLabel("Set the chosen planet's phase to the pending one")
                .accessibilityValue(phaseLabel)
                .accessibilityIdentifier(port.identifier("set-phase"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue("presentation only")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// The phase line: "phase P", or "phase P → Q" while a phase Q is pending.
    private var phaseLabel: String {
        guard let pending = mirror.pendingOffset else { return "phase \(mirror.chosenPhase)" }
        return "phase \(mirror.chosenPhase) → \(pending)"
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

    /// Moves the chosen planet's pending phase by `step` (±1) modulo its period and redraws the preview; a fixed
    /// planet says why nothing moves.
    private func movePending(step: Int) {
        if mirror.chosenFixed {
            mirror.message = CelestialEclipseLabGestureController.fixedReason
            return
        }
        mirror.pendingOffset = mirror.steppedPending(step)
        redraw()
    }

    /// Sets the chosen planet's phase to the pending one (one action) when it differs from the current phase.
    private func setPhase() {
        guard let pending = mirror.pendingOffset, mirror.pendingDiffers else { return }
        send("orbit.phase", [Double(mirror.chosenBody), Double(pending)])
    }

    /// Shows tick `tick` (clamped to 0 … horizon − 1).
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
