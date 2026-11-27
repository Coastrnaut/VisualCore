// MicroscopicAuroraControls — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-005; clarification Q5). The minimal
// control panel: a slot picker (well 1 … 3), the site (site − and +, over the level's sites), the strength (− and +,
// 1 … 4) and the sense (a toggle) of the well to place; place (`well.place [slot, row, column, strength, sense]`: one
// action of the budget), remove (`well.remove [slot]`: one action); the shown tick (tick − and +, `clock.show [tick]`
// clamped to 0 … ticks swum); playing the swim (`swim.play`), undo, redo and next level (kernel actions through the
// action port), each with an accessibility label, value and identifier. The shown tick is presentation state of the
// adapter (a level opens at tick 0). A placement the kernel refuses (an occupied site, an unchanged well, no action
// left) is still sent: the kernel refuses it and the panel says why. The header shows the actions left of the budget,
// the status (stage, or the failure in words), the progress description, the tutorial on levels that have one, the
// failure in words and a refused action in words. Feature 484 (R02-G19-04) T-R02G1904-005 (FR-R02G1904-009): every
// kernel button sends through the presenter (so refusals are logged), and the panel gains "Freeze" (the presenter's
// freeze, presentation only) and "Reset view" (the authored camera); a well tapped on the canvas selects its slot here.
// Full accessibility comes in a later feature of R02-G19.
//
// Feature 485 (R02-G19-05) T-R02G1905-005 (FR-R02G1905-001 … 005; clarifications Q1 … Q4): a teaching block under the
// header — the tutorial instruction with "Dismiss tutorial" (`tutorial.dismiss`), "Hint" (each press shows the next of
// three levels through the presenter's `showHint()`; hints send nothing) with the hint text, the failure explanation
// (in place of the short failure words), and the level's band, goal and best stars — and a progress block after the
// view row: "Campaign" (`mode.campaign`), "Daily" (`mode.daily [year, month, day]` with today's local date from the
// presenter) and "Practice" (`mode.practice`), and a picker of the open levels (1 … the frontier, with their bands and
// stars) with "Play level" (`level.select [n]`). All wrapping text in the panel, never over the dish; refusals read in
// words. The existing rows are unchanged.
//
// Feature 486 (R02-G19-06) T-R02G1906-005 (FR-R02G1906-001, 005, 006; clarification Q5): the summary element ("Dish",
// identifier `summary`), the adjustable slot, site and strength (`accessibilityAdjustableAction`: increment and
// decrement move the selection like the − and + buttons, through the presenter, which plays the selected well's
// audition when the sound is on; their values are "well n", "site at row r, column c" and "strength s") and the sense
// toggle ("clockwise" or "counterclockwise"), a value in words on every control (Place the selected well, Remove the
// slot's well, Play the progress, Undo and Redo the actions made, Next level the next open level, Play level the picked
// level, Freeze "frozen" or "not frozen", Reset view "authored" or "orbited", Dismiss the instruction, Campaign / Daily
// / Practice "selected" or "not selected", Hint the level shown, Sound "on" or "off"), refusals in the feedback plan's
// words, the Sound toggle (off by default, identifier `sound`), rows that become columns at accessibility text sizes,
// wrapping text and a 520-point readable width (iPad).
//
// Feature 487 (R02-G19-07) T-R02G1907-006 (clarifications Q2, Q4, Q5): "Replay best solution" (identifier `replay`,
// value the level) for a level with a verified stored solution, and during replay its position ("Replay: action k of
// n", identifier `replay-position`) with Step (identifier `replay-step`, value "Action k of n") and Stop (identifier
// `replay-stop`, value the trace's actions), each with a label; the Sound toggle saves the choice through
// `settings.sound`.
//
// Feature 489 (R02-G19-09) T-R02G1909-003 (clarification Q1): the failure explanation has its own identifier
// `explanation` (it shared `failure` with the short failure line); every identifier the panel gives through
// `port.identifier` (`experience.r02-g19.microscopic-aurora.<name>`) is listed in ``identifierNames``, each once.
#if os(iOS)
import MicroscopicAuroraCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Microscopic Aurora.
struct MicroscopicAuroraControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows (and the panel's selection).
    @Bindable var mirror: MicroscopicAuroraMirror
    /// The presenter (feature 485): hints, the tutorial, the modes and the daily date; nil sends through `sendAction`.
    var presenter: MicroscopicAuroraPresenter? = nil
    /// Sends a control with its values through the presenter (feature 484).
    let sendAction: (String, [Double]) -> Void
    /// Toggles the presenter's freeze (feature 484).
    let freeze: () -> Void
    /// Returns the camera to the authored view (feature 484).
    let resetView: () -> Void
    /// The text size: rows become columns at accessibility sizes (feature 486).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 486).
    @Environment(\.scenePhase) private var scenePhase

    /// Every identifier name the panel gives through `port.identifier`, each exactly once (feature 489, clarification
    /// Q1): the interface tests find the controls by these names.
    static let identifierNames: [String] = [
        "slot", "slot-minus", "slot-plus", "selection", "wells-detail", "site", "site-minus", "site-plus", "strength",
        "strength-minus", "strength-plus", "sense", "place", "remove", "freeze", "reset-view", "tick", "tick-minus",
        "tick-plus", "tick-detail", "play", "undo", "redo", "next-level", "dismiss-tutorial", "hint", "campaign", "daily",
        "practice", "level-picker", "play-level", "replay", "replay-step", "replay-stop", "sound", "actions", "status",
        "failure", "explanation", "progress", "summary", "message", "tutorial", "hint-text", "band", "stars", "goal",
        "replay-position",
    ]

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 486).
    static let readableWidth: CGFloat = 520

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                slotRow
                siteRow
                strengthRow
                placeRow
                tickRow
                playRow
                viewRow
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 486).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 486; off by default; since feature 487 saved through `settings.sound`).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { saveSound(on: $0) }))
            .disabled(presenter == nil)
            .accessibilityLabel("Sound of the dish")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// Saves the sound choice through the presenter (`settings.sound`, feature 487), or sends it directly without one.
    private func saveSound(on: Bool) {
        if let presenter { presenter.saveSound(on: on, port: port) } else { send("settings.sound", [on ? 1 : 0]) }
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 487).
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

    /// Sends a replay control through the presenter (refusals in words) or directly without one (feature 487).
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

    /// The replay position line: "Replay: action k of n" (feature 487).
    static func replayPositionText(_ mirror: MicroscopicAuroraMirror) -> String {
        "Replay: action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Step's value: "Action k of n", the trace actions played (feature 487).
    static func replayStepValue(_ mirror: MicroscopicAuroraMirror) -> String {
        "Action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Stop's value: the trace's actions (feature 487).
    static func replayStopValue(_ mirror: MicroscopicAuroraMirror) -> String {
        mirror.replayLength == 1 ? "1 action" : "\(mirror.replayLength) actions"
    }

    /// The actions made of the budget, in words (feature 486): the value of Undo and Redo.
    private var actionsMade: String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return made == 1 ? "1 action made" : "\(made) actions made"
    }

    /// Changes the panel's selection through the presenter (which plays the audition when the sound is on), or
    /// directly without one (feature 486).
    private func select(_ change: @escaping (MicroscopicAuroraMirror) -> Void) {
        if let presenter { presenter.changeSelection(change) } else { change(mirror) }
    }

    /// An adjustable selection value's action (feature 486): increment and decrement move the slot, the site or the
    /// strength like the + and − buttons (presentation only; Place spends the action).
    private func adjust(_ adjustment: AccessibilityAdjustmentDirection, slot: Bool = false, site: Bool = false,
                        strength: Bool = false) {
        let step: Int
        switch adjustment {
        case .increment: step = 1
        case .decrement: step = -1
        @unknown default: return
        }
        if slot { select { mirror in mirror.slot = ((mirror.slot + step) % 3 + 3) % 3 } }
        if site { moveSite(step) }
        if strength { select { mirror in mirror.strength = min(4, max(1, mirror.strength + step)) } }
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
        Text(mirror.summary).font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Dish")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// Choose the well slot the panel edits.
    @ViewBuilder private var slotRow: some View {
        row {
            Button("Well −") { select { mirror in mirror.slot = (mirror.slot + 2) % 3 } }
                .accessibilityLabel("Edit the previous well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("slot-minus"))
            Text("well \(mirror.slot + 1)")
                .accessibilityLabel("Well slot")
                .accessibilityValue("well \(mirror.slot + 1)")
                .accessibilityAdjustableAction { direction in adjust(direction, slot: true) }
                .accessibilityIdentifier(port.identifier("slot"))
            Button("Well +") { select { mirror in mirror.slot = (mirror.slot + 1) % 3 } }
                .accessibilityLabel("Edit the next well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("slot-plus"))
        }
        Text(mirror.wellsLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("wells-detail"))
    }

    /// Choose the site the well would stand on.
    @ViewBuilder private var siteRow: some View {
        row {
            Button("Site −") { moveSite(-1) }
                .accessibilityLabel("Choose the previous site")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("site-minus"))
            Text(mirror.selectedSite.map { MicroscopicAuroraLevel.cellWords($0) } ?? "no site")
                .accessibilityLabel("Site")
                .accessibilityValue(mirror.selectedSite.map { "site at " + MicroscopicAuroraLevel.cellWords($0) }
                                    ?? "no site")
                .accessibilityAdjustableAction { direction in adjust(direction, site: true) }
                .accessibilityIdentifier(port.identifier("site"))
            Button("Site +") { moveSite(1) }
                .accessibilityLabel("Choose the next site")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("site-plus"))
        }
    }

    /// Choose the strength and the turning sense.
    @ViewBuilder private var strengthRow: some View {
        row {
            Button("Strength −") { select { mirror in mirror.strength = max(1, mirror.strength - 1) } }
                .accessibilityLabel("Weaken the well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("strength-minus"))
            Text("strength \(mirror.strength)")
                .accessibilityLabel("Strength")
                .accessibilityValue("strength \(mirror.strength)")
                .accessibilityAdjustableAction { direction in adjust(direction, strength: true) }
                .accessibilityIdentifier(port.identifier("strength"))
            Button("Strength +") { select { mirror in mirror.strength = min(4, mirror.strength + 1) } }
                .accessibilityLabel("Strengthen the well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("strength-plus"))
            Button(mirror.counterclockwise ? "Counterclockwise" : "Clockwise") {
                select { mirror in mirror.counterclockwise.toggle() }
            }
            .accessibilityLabel("Switch the turning sense")
            .accessibilityValue(mirror.counterclockwise ? "counterclockwise" : "clockwise")
            .accessibilityIdentifier(port.identifier("sense"))
        }
    }

    /// Place the selected well, or remove the slot's well.
    @ViewBuilder private var placeRow: some View {
        row {
            Button("Place") { place() }
                .accessibilityLabel("Place the well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("place"))
            Button("Remove") { send("well.remove", [Double(mirror.slot)]) }
                .accessibilityLabel("Remove the well from this slot")
                .accessibilityValue(mirror.wellsLabel)
                .accessibilityIdentifier(port.identifier("remove"))
        }
        Text(mirror.selectionLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("selection"))
    }

    /// Show an earlier or later tick of the swim, and play it.
    @ViewBuilder private var tickRow: some View {
        row {
            Button("Tick −") { show(tick: mirror.shownTick - 1) }
                .accessibilityLabel("Show the swim one tick earlier")
                .accessibilityValue(mirror.tickLabel)
                .accessibilityIdentifier(port.identifier("tick-minus"))
            Text("tick \(mirror.shownTick)")
                .accessibilityIdentifier(port.identifier("tick"))
            Button("Tick +") { show(tick: mirror.shownTick + 1) }
                .accessibilityLabel("Show the swim one tick later")
                .accessibilityValue(mirror.tickLabel)
                .accessibilityIdentifier(port.identifier("tick-plus"))
            Button("Play") { send("swim.play") }
                .accessibilityLabel("Play the swim and end the level")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("play"))
        }
        Text(mirror.tickLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("tick-detail"))
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last placement, removal or play")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the placement, removal or play")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue(mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
                                    : "no further level open")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
    }

    /// The tutorial instruction with Dismiss tutorial, Hint with the hint text, the failure explanation, and the band,
    /// goal and best stars (feature 485).
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

    /// The mode buttons and the picker of open levels with their bands and stars (feature 485).
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
        MicroscopicAuroraMirror.modeName(mirror.mode) == name ? "selected" : "not selected"
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
            send("mode.daily", MicroscopicAuroraPresenter.dateValues(MicroscopicAuroraPresenter.today()))
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

    /// Freeze the field and reset the view (feature 484; presentation only).
    @ViewBuilder private var viewRow: some View {
        row {
            Button(mirror.frozen ? "Unfreeze" : "Freeze") { freeze() }
                .accessibilityLabel(mirror.frozen ? "Unfreeze the swim" : "Freeze the swim")
                .accessibilityValue(mirror.frozen ? "frozen" : "not frozen")
                .accessibilityIdentifier(port.identifier("freeze"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue((presenter?.gestures.orbit ?? .authored) == .authored ? "authored" : "orbited")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// Moves the site selection by `step`, wrapping over the level's sites.
    private func moveSite(_ step: Int) {
        select { mirror in
            let count: Int = max(1, mirror.sites.count)
            mirror.siteIndex = ((mirror.siteIndex + step) % count + count) % count
        }
    }

    /// Sends the selected well's placement.
    private func place() {
        guard let site = mirror.selectedSite else {
            mirror.message = MicroscopicAuroraFeedbackPlan.refusalText(code: "r02-g19.action")
            return
        }
        send("well.place", [Double(mirror.slot), Double(site.row), Double(site.column), Double(mirror.strength),
                            mirror.counterclockwise ? 1 : 0])
    }

    /// Shows tick `tick` (clamped to 0 … ticks swum).
    private func show(tick: Int) {
        send("clock.show", [Double(mirror.clampedTick(tick))])
    }

    /// Sends `control` through the presenter, which shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        sendAction(control, values)
    }
}
#endif
