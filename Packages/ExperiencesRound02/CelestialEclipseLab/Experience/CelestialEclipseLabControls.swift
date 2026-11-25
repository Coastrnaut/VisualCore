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
//
// Feature 466 (R02-G17-06) T-R02G1706-005 (FR-R02G1706-001, 005, 006; clarification Q5): the summary element ("Sky",
// identifier `summary`), the adjustable chosen planet and pending phase (`accessibilityAdjustableAction`: the planet's
// increment and decrement choose the next and previous movable body like Planet + and −, the phase's move the pending
// phase like Phase + and −; their values are "body j, phase p of q" and "pending phase p"), a value in words on every
// control (Set phase the pending change, Run the progress, Undo and Redo the actions made, Next level the next open
// level, Play level the picked level, Reset view "authored" or "orbited", Dismiss the instruction, Campaign / Daily /
// Practice "selected" or "not selected", Hint the level shown, Sound "on" or "off"), refusals in the feedback plan's
// words, the Sound toggle (off by default, identifier `sound`), rows that become columns at accessibility text sizes,
// wrapping text and a 520-point readable width (iPad).
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
    /// The text size: rows become columns at accessibility sizes (feature 466).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 466).
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 466).
    static let readableWidth: CGFloat = 520

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
                soundToggle
            }
            .padding()
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
        }
        .onAppear { presenter?.controlsAppeared() }
        .onDisappear { presenter?.controlsDisappeared() }
        .onChange(of: scenePhase) { _, phase in presenter?.sceneActive(phase == .active) }
    }

    /// A row of controls that becomes a column at accessibility text sizes (feature 466).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 466; off by default; presentation only).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter?.setSound(on: $0) }))
            .disabled(presenter == nil)
            .accessibilityLabel("Sound of the sky")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// The actions made of the budget, in words (feature 466): the value of Undo and Redo.
    private var actionsMade: String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return made == 1 ? "1 action made" : "\(made) actions made"
    }

    /// The level, actions, status, tutorial, failure and refusal lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · \(mirror.actionsLeft) of \(mirror.budget) actions left")
            .font(.headline)
            .accessibilityIdentifier(port.identifier("actions"))
        Text(mirror.status).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("status"))
        if let failure = mirror.failureText, mirror.explanation == nil {
            Text(failure).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("failure"))
        }
        Text(mirror.measureLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("progress"))
        Text(mirror.summary).font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sky")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
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
                .accessibilityValue(tutorial)
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
        row {
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
        row {
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
        row {
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
        row {
            Button("Planet −") { send("orbit.choose", [Double(mirror.nextBody(-1))]) }
                .accessibilityLabel("Choose the previous planet")
                .accessibilityValue(mirror.bodyLabel)
                .accessibilityIdentifier(port.identifier("planet-minus"))
            Text("body \(mirror.chosenBody)")
                .accessibilityLabel("Chosen planet")
                .accessibilityValue(chosenValue)
                .accessibilityAdjustableAction { direction in adjustPlanet(direction) }
                .accessibilityIdentifier(port.identifier("planet"))
            Button("Planet +") { send("orbit.choose", [Double(mirror.nextBody(1))]) }
                .accessibilityLabel("Choose the next planet")
                .accessibilityValue(mirror.bodyLabel)
                .accessibilityIdentifier(port.identifier("planet-plus"))
        }
        Text(mirror.bodyLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("planet-detail"))
    }

    /// Move the chosen planet's pending phase back or forward by one (presentation only) and set it (one action).
    @ViewBuilder private var phaseRow: some View {
        row {
            Button("Phase −") { movePending(step: -1) }
                .accessibilityLabel("Move the pending phase back by one")
                .accessibilityValue(phaseLabel)
                .accessibilityIdentifier(port.identifier("phase-minus"))
            Text(phaseLabel)
                .accessibilityLabel("Pending phase")
                .accessibilityValue(pendingValue)
                .accessibilityAdjustableAction { direction in adjustPhase(direction) }
                .accessibilityIdentifier(port.identifier("phase"))
            Button("Phase +") { movePending(step: 1) }
                .accessibilityLabel("Move the pending phase forward by one")
                .accessibilityValue(phaseLabel)
                .accessibilityIdentifier(port.identifier("phase-plus"))
        }
        row {
            Button("Set phase") { setPhase() }
                .disabled(!mirror.pendingDiffers)
                .accessibilityLabel("Set the chosen planet's phase to the pending one")
                .accessibilityValue(phaseLabel)
                .accessibilityIdentifier(port.identifier("set-phase"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue((presenter?.gestures.orbit ?? .authored) == .authored ? "authored" : "orbited")
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
        row {
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
        Text(mirror.tickLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("tick-detail"))
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last phase change or run")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the phase change or run")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue(mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
                                    : "no further level open")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
    }

    /// The chosen planet's value in words (feature 466): "body j, phase p of q" (q its period), or "body j, fixed".
    private var chosenValue: String {
        if mirror.chosenFixed { return "body \(mirror.chosenBody), fixed" }
        return "body \(mirror.chosenBody), phase \(mirror.chosenPhase) of \(mirror.chosenPeriod)"
    }

    /// The pending phase's value in words (feature 466): "pending phase p" (the current phase when none is pending).
    private var pendingValue: String { "pending phase \(mirror.pendingOffset ?? mirror.chosenPhase)" }

    /// The planet's adjustable action (feature 466): increment and decrement choose the next and previous movable body
    /// like Planet + and − (`orbit.choose`).
    private func adjustPlanet(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: send("orbit.choose", [Double(mirror.nextBody(1))])
        case .decrement: send("orbit.choose", [Double(mirror.nextBody(-1))])
        @unknown default: break
        }
    }

    /// The pending phase's adjustable action (feature 466): increment and decrement move the pending phase forward
    /// and back by one like Phase + and − (presentation only; Set phase spends the action).
    private func adjustPhase(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: movePending(step: 1)
        case .decrement: movePending(step: -1)
        @unknown default: break
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
