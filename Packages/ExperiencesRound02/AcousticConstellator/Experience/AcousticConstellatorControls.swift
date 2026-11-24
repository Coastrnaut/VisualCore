// AcousticConstellatorControls — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-005; clarification Q5). The
// minimal control panel: labelled buttons for the chosen star (star − and +) and the chosen partner (partner − and +)
// (presentation state only; a level opens with star 0 and partner 1 chosen, both clamped to the level's stars), link
// and unlink (the chosen star and partner), nudge − and + (the chosen star's starting phase by one step) and listen
// (kernel actions through the action port), undo, redo and next level, each with an accessibility label, value and
// identifier; the header shows the actions left of the budget, the status (stage, or the failure in words), the progress
// description, the failure in words and a refused action in words. Feature 424 (R02-G13-04) adds "Reset view" (the
// authored camera) and sends through the presenter, which shows and logs refusals; full accessibility comes in
// R02-G13-06. Feature 425 (R02-G13-05) T-R02G1305-005: the tutorial instruction with Dismiss, Hint (each press
// reveals the next level), the failure explanation with Undo and Retry, the goal with the level's band and best stars,
// Campaign / Daily / Practice and a picker of the open levels with Play level; all as wrapping text in the panel, never
// over the stars. "Next level" stays; before a win it is refused in words.
// Feature 426 (R02-G13-06) T-R02G1306-005 (FR-R02G1306-001, 005, 006; clarification Q5): the summary element
// ("Constellation", identifier `summary`), the adjustable star and partner (steppers with
// `accessibilityAdjustableAction`; the star's value is the star as the level words it with its rate and phase, the
// partner's likewise with whether the pair is linked), a value in words on every control (``Values``: Link and Unlink
// the chosen pair, Nudge the chosen star, Listen the missing pairs, Undo and Redo the actions made, Next level the next
// open level, Retry the level and mode, Play level the picked level; Reset view "authored" or "orbited", Dismiss the
// instruction, Campaign / Daily / Practice "selected" or "not selected", Hint the level shown, Sound "on" or "off"),
// refusals in words, the Sound toggle (off by default, identifier `sound`), rows that become columns at accessibility
// text sizes, wrapping text and a 520-point readable width (iPad).
// Feature 427 (R02-G13-07) T-R02G1307-005 (clarifications Q2, Q4, Q5): "Replay best solution" (identifier `replay`,
// value the level) for a level with a verified stored solution, and during replay its position ("Replay: action k of
// n", identifier `replay-position`) with Step (identifier `replay-step`, value "Action k of n") and Stop (identifier
// `replay-stop`, value the trace's actions), each with a label; the Sound toggle saves the choice through
// `settings.sound`; the mode's name includes "replay".
// Feature 429 (R02-G13-09) T-R02G1309-003 (FR-R02G1309-001; clarification Q1): the identifiers the panel gives through
// `port.identifier` (`experience.r02-g13.acoustic-constellator.<name>`) are listed in ``identifierNames``, each once.
#if os(iOS)
import AcousticConstellatorCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Acoustic Constellator.
struct AcousticConstellatorControls: View {
    /// The action port (its identifiers name the controls).
    let port: ExperienceActionPort
    /// What the panel shows and chooses.
    let mirror: AcousticConstellatorMirror
    /// The presenter (feature 425): hints, tutorial, retry, undo and the daily level; sound and summary (feature 426).
    let presenter: AcousticConstellatorPresenter
    /// Returns the camera to the authored view (feature 424).
    let resetView: () -> Void
    /// Sends a control with its values through the presenter (which shows and logs a refusal).
    let sender: (String, [Double]) -> Void
    /// Every identifier name the panel gives (clarification Q1 of feature 429), each once; the identifier is
    /// `experience.r02-g13.acoustic-constellator.<name>` (`port.identifier`).
    static let identifierNames: [String] = [
        "star", "partner", "link", "unlink", "nudge-minus", "nudge-plus", "listen", "undo", "redo", "next-level",
        "reset-view", "dismiss-tutorial", "hint", "failure-undo", "retry", "campaign", "daily", "practice", "level-picker",
        "play-level", "replay", "replay-step", "replay-stop", "sound", "summary", "choice", "status", "actions", "progress",
        "message", "failure", "instruction", "hint-text", "goal", "replay-position",
    ]

    /// The text size: rows become columns at accessibility sizes (feature 426).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 426).
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 426).
    static let readableWidth: CGFloat = 520

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                choiceRows
                linkRow
                nudgeRow
                playRow
                progressRows
                replaySection
                soundToggle
            }
            .padding()
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
        }
        .onAppear { presenter.controlsAppeared() }
        .onDisappear { presenter.controlsDisappeared() }
        .onChange(of: scenePhase) { _, phase in presenter.sceneActive(phase == .active) }
    }

    /// A row of controls that becomes a column at accessibility text sizes (feature 426).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 426; off by default; saved through `settings.sound` since feature 427).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityLabel("Sound of the stars")
            .accessibilityValue(Self.soundValue(mirror.soundOn))
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// The level, actions, status (the summary element), failure and refusal lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · \(mirror.actionsLeft) of \(mirror.budget) actions left")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("actions"))
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("status"))
        Text(mirror.summary).font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Constellation")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        if let failure = mirror.failureText {
            Text(failure).font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("failure"))
        }
        Text(mirror.measureLabel).font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("progress"))
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// The adjustable star and partner (feature 426: swipe up or down steps them; the summary follows) and the
    /// chosen pair in words.
    @ViewBuilder private var choiceRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.starLabel,
                    onIncrement: { stepStar(1) },
                    onDecrement: { stepStar(-1) })
                .accessibilityLabel("Chosen star")
                .accessibilityValue(mirror.starDetail)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: stepStar(1)
                    case .decrement: stepStar(-1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier(port.identifier("star"))
            Stepper(mirror.partnerLabel,
                    onIncrement: { stepPartner(1) },
                    onDecrement: { stepPartner(-1) })
                .accessibilityLabel("Partner star to link with the chosen star")
                .accessibilityValue(mirror.partnerWords)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: stepPartner(1)
                    case .decrement: stepPartner(-1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier(port.identifier("partner"))
        }
        Text(mirror.choiceLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("choice"))
    }

    /// Link and unlink the chosen pair.
    @ViewBuilder private var linkRow: some View {
        row {
            Button("Link") { send("link.add", pairValues) }
                .accessibilityLabel("Link the chosen star to the partner")
                .accessibilityValue(Self.values(mirror).pair)
                .accessibilityIdentifier(port.identifier("link"))
            Button("Unlink") { send("link.remove", pairValues) }
                .accessibilityLabel("Remove the link between the chosen star and the partner")
                .accessibilityValue(Self.values(mirror).pair)
                .accessibilityIdentifier(port.identifier("unlink"))
        }
    }

    /// Nudge the chosen star's phase and listen.
    @ViewBuilder private var nudgeRow: some View {
        row {
            Button("Nudge −") { send("star.nudge", [Double(mirror.star), -1]) }
                .accessibilityLabel("Nudge the chosen star's phase back one step")
                .accessibilityValue(Self.values(mirror).nudge)
                .accessibilityIdentifier(port.identifier("nudge-minus"))
            Button("Nudge +") { send("star.nudge", [Double(mirror.star), 1]) }
                .accessibilityLabel("Nudge the chosen star's phase forward one step")
                .accessibilityValue(Self.values(mirror).nudge)
                .accessibilityIdentifier(port.identifier("nudge-plus"))
            Button("Listen") { send("constellation.listen") }
                .accessibilityLabel("Listen to the constellation")
                .accessibilityValue(Self.values(mirror).listen)
                .accessibilityIdentifier(port.identifier("listen"))
        }
    }

    /// Undo, redo, next level and reset view.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
                .accessibilityValue(Self.values(mirror).actions)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
                .accessibilityValue(Self.values(mirror).actions)
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue(Self.values(mirror).nextLevel)
                .accessibilityIdentifier(port.identifier("next-level"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue(Self.viewValue(presenter.gestures.orbit == .authored))
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// The tutorial instruction, the hint, the goal and the failure's Undo and Retry (feature 425); the failure
    /// explanation itself is the header's failure line.
    @ViewBuilder private var teaching: some View {
        if let instruction = mirror.instruction {
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("instruction"))
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityValue(instruction)
                    .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
            }
        }
        row {
            Button("Hint") { presenter.showHint() }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(Self.hintValue(mirror.hintLevel))
                .accessibilityIdentifier(port.identifier("hint"))
            Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("goal"))
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("hint-text"))
        }
        if mirror.failureText != nil {
            row {
                Button("Undo") { presenter.undoAction(port: port) }
                    .accessibilityLabel("Undo the last action")
                    .accessibilityValue(Self.values(mirror).actions)
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Start the level again")
                    .accessibilityValue(Self.values(mirror).retry)
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 425).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "campaign"))
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "daily"))
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more actions")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "practice"))
                .accessibilityIdentifier(port.identifier("practice"))
        }
        row {
            Stepper(levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityLabel("Level to play")
                .accessibilityValue(levelLabel(mirror.pickedLevel))
                .accessibilityIdentifier(port.identifier("level-picker"))
            Button("Play level") { send("level.select", [Double(mirror.pickedLevel)]) }
                .accessibilityLabel("Play the picked level")
                .accessibilityValue(Self.values(mirror).playLevel)
                .accessibilityIdentifier(port.identifier("play-level"))
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band: Int = AcousticConstellatorProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 427).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("replay-position"))
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Play the next action of the replay")
                    .accessibilityValue(Self.replayStepValue(mirror))
                    .accessibilityIdentifier(port.identifier("replay-step"))
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue(Self.replayStopValue(mirror))
                    .accessibilityIdentifier(port.identifier("replay-stop"))
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
                .accessibilityIdentifier(port.identifier("replay"))
        }
    }

    /// The replay position line: "Replay: action k of n" (feature 427).
    static func replayPositionText(_ mirror: AcousticConstellatorMirror) -> String {
        "Replay: action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Step's value: "Action k of n" (feature 427).
    static func replayStepValue(_ mirror: AcousticConstellatorMirror) -> String {
        "Action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Stop's value: the trace's actions, "n actions" ("1 action" for one) (feature 427).
    static func replayStopValue(_ mirror: AcousticConstellatorMirror) -> String {
        mirror.replayLength == 1 ? "1 action" : "\(mirror.replayLength) actions"
    }

    /// The mode's name: campaign, daily, practice or replay.
    static func modeName(_ mode: AcousticConstellatorMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// The accessibility values in words of the controls that act on the play (feature 426, after feature 386's
    /// convergence lesson): every native control carries a value.
    struct Values: Equatable {
        /// Link and Unlink: the chosen pair (`AcousticConstellatorMirror.choiceLabel`).
        let pair: String
        /// Nudge − and +: the chosen star with its rate and phase (`AcousticConstellatorMirror.starDetail`).
        let nudge: String
        /// Listen: the missing symbol pairs (`AcousticConstellatorMirror.missingLabel`).
        let listen: String
        /// Undo and redo: the actions made of the budget, "k actions made of B" ("1 action made of B" for one).
        let actions: String
        /// Next level: the next open level, or that none is open.
        let nextLevel: String
        /// Retry: the level and the mode, "level n, <mode>".
        let retry: String
        /// Play level: the picked level, "level n".
        let playLevel: String
    }

    /// The button values of `mirror` (see ``Values``).
    static func values(_ mirror: AcousticConstellatorMirror) -> Values {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        let actions: String = (made == 1 ? "1 action made" : "\(made) actions made") + " of \(mirror.budget)"
        let next: String = mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
            : "no further level open"
        return Values(pair: mirror.choiceLabel, nudge: mirror.starDetail, listen: mirror.missingLabel,
                      actions: actions, nextLevel: next,
                      retry: "level \(mirror.levelNumber), " + modeName(mirror.mode),
                      playLevel: "level \(mirror.pickedLevel)")
    }

    /// The Reset view value: "authored" or "orbited".
    static func viewValue(_ authored: Bool) -> String { authored ? "authored" : "orbited" }

    /// A mode button's value: "selected" or "not selected".
    static func selectedValue(_ selected: Bool) -> String { selected ? "selected" : "not selected" }

    /// The Sound toggle's value: "on" or "off".
    static func soundValue(_ on: Bool) -> String { on ? "on" : "off" }

    /// The Hint button's value: "none shown" or "level h of 3".
    static func hintValue(_ level: Int) -> String { level == 0 ? "none shown" : "level \(level) of 3" }

    /// Steps the chosen star by `delta` and refreshes the summary.
    private func stepStar(_ delta: Int) {
        mirror.stepStar(delta)
        presenter.refreshSummary()
    }

    /// Steps the chosen partner by `delta` and refreshes the summary.
    private func stepPartner(_ delta: Int) {
        mirror.stepPartner(delta)
        presenter.refreshSummary()
    }

    /// The chosen star and partner as the values of `link.add` and `link.remove`.
    private var pairValues: [Double] { [Double(mirror.star), Double(mirror.partner)] }

    /// Sends `control` through the presenter.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
