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
//
// Feature 475 (R02-G18-05) T-R02G1805-005 (FR-R02G1805-001 … 005; clarifications Q1 … Q4): a teaching block under the
// header — the tutorial instruction with "Dismiss tutorial" (`tutorial.dismiss`), "Hint" (each press shows the next of
// three levels through the presenter's `showHint()`; hints send nothing) with the hint text, the failure explanation
// (in place of the short failure words), and the level's band, goal and best stars — and a progress block after the
// play row: "Campaign" (`mode.campaign`), "Daily" (`mode.daily [year, month, day]` with today's local date from the
// presenter) and "Practice" (`mode.practice`), and a picker of the open levels (1 … the frontier, with their bands and
// stars) with "Play level" (`level.select [n]`). All wrapping text in the panel, never over the sky; refusals read in
// words. The existing rows (pending orbit, Set periapsis, Set size, Reset view, tick, Play, undo, redo, next level)
// are unchanged.
//
// Feature 476 (R02-G18-06) T-R02G1806-005 (FR-R02G1806-001, 005, 006; clarification Q5): the summary element
// ("Sky", identifier `summary`), the adjustable pending eccentricity, direction and size
// (`accessibilityAdjustableAction`: increment and decrement move the pending orbit like the − and + buttons, through
// the presenter, which plays the audition when the sound is on; their values are "pending eccentricity 0.ee",
// "pending periapsis at d°" and "pending size a"), a value in words on every control (Set periapsis and Set size the
// pending change, Play the progress, Undo and Redo the actions made, Next level the next open level, Play level the
// picked level, Reset view "authored" or "orbited", Dismiss the instruction, Campaign / Daily / Practice "selected" or
// "not selected", Hint the level shown, Sound "on" or "off"), refusals in the feedback plan's words, the Sound toggle
// (off by default, identifier `sound`), rows that become columns at accessibility text sizes, wrapping text and a
// 520-point readable width (iPad).
//
// Feature 477 (R02-G18-07) T-R02G1807-006 (clarifications Q2, Q4, Q5): "Replay best solution" (identifier `replay`,
// value the level) for a level with a verified stored solution, and during replay its position ("Replay: action k of
// n", identifier `replay-position`) with Step (identifier `replay-step`, value "Action k of n") and Stop (identifier
// `replay-stop`, value the trace's actions), each with a label; the Sound toggle saves the choice through
// `settings.sound`.
// Feature 479 (R02-G18-09) T-R02G1809-003 (clarification Q1): the failure explanation has its own identifier
// `explanation` (it shared `failure` with the short failure line), and the identifiers the panel gives through
// `port.identifier` (`experience.r02-g18.apsides-workshop.<name>`) are listed in ``identifierNames``, each once.
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
    /// The presenter (feature 475): hints, the tutorial, the modes and the daily date; nil sends through ``send``.
    var presenter: ApsidesWorkshopPresenter? = nil
    /// Returns the camera to the authored view (feature 474; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 474); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil
    /// Redraws the last snapshot with the mirror's preview after the pending orbit moved (feature 474).
    var redraw: () -> Void = {}
    /// Every identifier name the panel gives (clarification Q1 of feature 479), each once; the identifier is
    /// `experience.r02-g18.apsides-workshop.<name>` (`port.identifier`).
    static let identifierNames: [String] = [
        "eccentricity", "eccentricity-minus", "eccentricity-plus", "direction", "direction-minus", "direction-plus",
        "size", "size-minus", "size-plus", "orbit-detail", "set-periapsis", "set-size", "reset-view", "pending-reason",
        "tick", "tick-minus", "tick-plus", "tick-detail", "play", "undo", "redo", "next-level", "dismiss-tutorial",
        "hint", "campaign", "daily", "practice", "level-picker", "play-level", "replay", "replay-step", "replay-stop",
        "sound", "actions", "status", "failure", "explanation", "progress", "summary", "message", "tutorial",
        "hint-text", "band", "stars", "goal", "replay-position",
    ]
    /// The text size: rows become columns at accessibility sizes (feature 476).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 476).
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 476).
    static let readableWidth: CGFloat = 520

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                eccentricityRow
                directionRow
                sizeRow
                setRow
                tickRow
                playRow
                progressRows
                replaySection
                soundToggle
            }
            .padding()
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
        }
        .onAppear { presenter?.controlsAppeared() }
        .onDisappear { presenter?.controlsDisappeared() }
        .onChange(of: scenePhase) { _, phase in presenter?.sceneActive(phase == .active) }
    }

    /// A row of controls that becomes a column at accessibility text sizes (feature 476).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 476; off by default; since feature 477 saved through `settings.sound`).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { saveSound(on: $0) }))
            .disabled(presenter == nil)
            .accessibilityLabel("Sound of the sky")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// Saves the sound choice through the presenter (`settings.sound`, feature 477), or sends it directly without one.
    private func saveSound(on: Bool) {
        if let presenter { presenter.saveSound(on: on, port: port) } else { send("settings.sound", [on ? 1 : 0]) }
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 477).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("replay-position"))
            row {
                Button("Step") { replay("replay.step") }
                    .accessibilityLabel("Apply the next action of the replay")
                    .accessibilityValue(Self.replayStepValue(mirror))
                    .accessibilityIdentifier(port.identifier("replay-step"))
                Button("Stop") { replay("replay.stop") }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue(Self.replayStopValue(mirror))
                    .accessibilityIdentifier(port.identifier("replay-stop"))
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { replay("replay.start", [Double(mirror.levelNumber)]) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
                .accessibilityIdentifier(port.identifier("replay"))
        }
    }

    /// Sends a replay control through the presenter (refusals in words) or directly without one (feature 477).
    private func replay(_ control: String, _ values: [Double] = []) {
        guard let presenter else {
            send(control, values)
            return
        }
        switch control {
        case "replay.start": presenter.startReplay(port: port)
        case "replay.step": presenter.stepReplay(port: port)
        default: presenter.stopReplay(port: port)
        }
    }

    /// The replay position line: "Replay: action k of n" (feature 477).
    static func replayPositionText(_ mirror: ApsidesWorkshopMirror) -> String {
        "Replay: action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Step's value: "Action k of n", the trace actions played (feature 477).
    static func replayStepValue(_ mirror: ApsidesWorkshopMirror) -> String {
        "Action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Stop's value: the trace's actions (feature 477).
    static func replayStopValue(_ mirror: ApsidesWorkshopMirror) -> String {
        mirror.replayLength == 1 ? "1 action" : "\(mirror.replayLength) actions"
    }

    /// The actions made of the budget, in words (feature 476): the value of Undo and Redo.
    private var actionsMade: String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return made == 1 ? "1 action made" : "\(made) actions made"
    }

    /// The level, actions, status, short failure (only without an explanation), progress and refusal lines.
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
    /// goal and best stars (feature 475).
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
                .accessibilityIdentifier(port.identifier("explanation"))
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

    /// The mode buttons and the picker of open levels with their bands and stars (feature 475).
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
        ApsidesWorkshopMirror.modeName(mirror.mode) == name ? "selected" : "not selected"
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
        if let presenter {
            presenter.playDaily(port: port)
        } else {
            send("mode.daily", ApsidesWorkshopPresenter.dateValues(ApsidesWorkshopPresenter.today()))
        }
    }

    /// Replays the level with the practice budget (`mode.practice`).
    private func practice() {
        if let presenter { presenter.playPractice(port: port) } else { send("mode.practice") }
    }

    /// Plays open level `level` (`level.select [level]`).
    private func selectLevel(_ level: Int) {
        if let presenter { presenter.selectLevel(level, port: port) } else { send("level.select", [Double(level)]) }
    }

    /// Lower or raise the eccentricity by one step (one action).

    @ViewBuilder private var eccentricityRow: some View {
        row {
            Button("Eccentricity −") { movePending(eccentricity: -1, direction: 0, size: 0) }
                .accessibilityLabel("Lower the pending eccentricity by one step")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("eccentricity-minus"))
            Text(mirror.pendingLine("eccentricity", mirror.orbit.eccentricity, mirror.pending.eccentricity))
                .accessibilityLabel("Pending eccentricity")
                .accessibilityValue(Self.eccentricityValue(mirror.pending.eccentricity))
                .accessibilityAdjustableAction { direction in adjust(direction, eccentricity: 1) }
                .accessibilityIdentifier(port.identifier("eccentricity"))
            Button("Eccentricity +") { movePending(eccentricity: 1, direction: 0, size: 0) }
                .accessibilityLabel("Raise the pending eccentricity by one step")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("eccentricity-plus"))
        }
        Text(mirror.orbitLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("orbit-detail"))
    }

    /// Turn the periapsis direction back or forward by 15° (one action).
    @ViewBuilder private var directionRow: some View {
        row {
            Button("Direction −") { movePending(eccentricity: 0, direction: -1, size: 0) }
                .accessibilityLabel("Turn the pending periapsis 15 degrees clockwise")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("direction-minus"))
            Text(mirror.pendingLine("direction", mirror.orbit.direction * 15, mirror.pending.direction * 15, unit: "°"))
                .accessibilityLabel("Pending periapsis direction")
                .accessibilityValue("pending periapsis at \(mirror.pending.direction * 15)°")
                .accessibilityAdjustableAction { direction in adjust(direction, direction: 1) }
                .accessibilityIdentifier(port.identifier("direction"))
            Button("Direction +") { movePending(eccentricity: 0, direction: 1, size: 0) }
                .accessibilityLabel("Turn the pending periapsis 15 degrees counterclockwise")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("direction-plus"))
        }
    }

    /// Shrink or grow the orbit by one lattice unit (one action).
    @ViewBuilder private var sizeRow: some View {
        row {
            Button("Size −") { movePending(eccentricity: 0, direction: 0, size: -1) }
                .accessibilityLabel("Shrink the pending orbit by one unit")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("size-minus"))
            Text(mirror.pendingLine("size", mirror.orbit.size, mirror.pending.size))
                .accessibilityLabel("Pending size")
                .accessibilityValue("pending size \(mirror.pending.size)")
                .accessibilityAdjustableAction { direction in adjust(direction, size: 1) }
                .accessibilityIdentifier(port.identifier("size"))
            Button("Size +") { movePending(eccentricity: 0, direction: 0, size: 1) }
                .accessibilityLabel("Grow the pending orbit by one unit")
                .accessibilityValue(mirror.orbitLabel)
                .accessibilityIdentifier(port.identifier("size-plus"))
        }
    }

    /// Set the pending periapsis or size (one action each) and return the camera.
    @ViewBuilder private var setRow: some View {
        row {
            Button("Set periapsis") { setPeriapsis() }
                .disabled(!mirror.periapsisSettable)
                .accessibilityLabel("Set the periapsis to the pending eccentricity and direction")
                .accessibilityValue(periapsisChange)
                .accessibilityIdentifier(port.identifier("set-periapsis"))
            Button("Set size") { setSize() }
                .disabled(!mirror.sizeSettable)
                .accessibilityLabel("Set the size to the pending size")
                .accessibilityValue(sizeChange)
                .accessibilityIdentifier(port.identifier("set-size"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue((presenter?.gestures.orbit ?? .authored) == .authored ? "authored" : "orbited")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
        if let reason = mirror.pendingReason {
            Text(reason).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("pending-reason"))
        }
    }

    /// Show an earlier or later tick of the revolution, and play it.
    @ViewBuilder private var tickRow: some View {
        row {
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
        Text(mirror.tickLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("tick-detail"))
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last tuning or play")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the tuning or play")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue(mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
                                    : "no further level open")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
    }

    /// Moves the pending orbit by the given steps (presentation only) and redraws the preview; through the presenter
    /// (feature 476), which also plays the audition when the sound is on.
    private func movePending(eccentricity: Int, direction: Int, size: Int) {
        if let presenter {
            presenter.movePending(eccentricity: eccentricity, direction: direction, size: size)
            return
        }
        mirror.movePending(eccentricity: eccentricity, direction: direction, size: size)
        redraw()
    }

    /// "pending eccentricity 0.ee" for step `k` (k × 0.05, two decimals; feature 476).
    static func eccentricityValue(_ k: Int) -> String {
        let e: Int = k * 5
        return "pending eccentricity 0." + (e < 10 ? "0" : "") + "\(e)"
    }

    /// The value of Set periapsis (feature 476): the pending change in words, or "no change pending".
    private var periapsisChange: String {
        guard mirror.periapsisSettable else { return "no change pending" }
        let k: Int = mirror.pending.eccentricity * 5
        return "eccentricity 0." + (k < 10 ? "0" : "") + "\(k), periapsis at \(mirror.pending.direction * 15)°"
    }

    /// The value of Set size (feature 476): the pending size in words, or "no change pending".
    private var sizeChange: String {
        mirror.sizeSettable ? "size \(mirror.pending.size)" : "no change pending"
    }

    /// An adjustable pending value's action (feature 476): increment and decrement move the pending orbit by the given
    /// step like the + and − buttons (presentation only; Set periapsis and Set size spend the action).
    private func adjust(_ adjustment: AccessibilityAdjustmentDirection, eccentricity: Int = 0, direction: Int = 0,
                        size: Int = 0) {
        switch adjustment {
        case .increment: movePending(eccentricity: eccentricity, direction: direction, size: size)
        case .decrement: movePending(eccentricity: -eccentricity, direction: -direction, size: -size)
        @unknown default: break
        }
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
