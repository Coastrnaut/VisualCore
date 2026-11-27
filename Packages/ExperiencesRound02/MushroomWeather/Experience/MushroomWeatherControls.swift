// MushroomWeatherControls — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-005; clarification Q5). The minimal
// control panel: a labelled slot picker (pod 1 … slots, slot − and +), the site (site − and +, over the level's sites,
// or every free floor cell on a level without sites) of the pod to place; place (`pod.place [slot, row, column]`: one
// action of the budget), remove (`pod.remove [slot]`: one action); a toggle per vent (`vent.set [index, open]`, open 1,
// shut 0: one action); the moonlight (moonlight − and + choose a level 0 … 3, Set moonlight sends `moon.set [level]`:
// one action); the shown cycle (cycle − and +, `clock.show [cycle]` clamped to 0 … cycles run); running the weather
// (`weather.run`), undo, redo and next level (kernel actions through the action port), each with an accessibility
// label, value and identifier. The shown cycle is presentation state of the adapter (a level opens at cycle 0). A
// change the kernel refuses (a site another pod occupies, an unchanged pod, vent or moonlight, no action left) is still
// sent: the kernel refuses it and the panel says why. The header shows the actions left of the budget, the status
// (stage, or the failure in words), the progress description, the level in words, the tutorial on levels that have one,
// the failure in words and a refused action in words. Feature 494 (R02-G20-04) T-R02G2004-005 (FR-R02G2004-010, 011):
// every kernel button sends through the presenter (so refusals are shown and logged with their code), and the panel
// gains "Reset view" (the authored camera, presentation only); a pod tapped on the canvas selects its slot here, and a
// moon drag's level becomes the chosen moonlight. Full accessibility comes in a later feature of R02-G20. Modelled on
// `MicroscopicAuroraControls` (features 483 and 484).
//
// Feature 495 (R02-G20-05) T-R02G2005-005 (FR-R02G2005-001 … 005; clarifications Q1 … Q4): a teaching block under the
// header — the tutorial instruction with "Dismiss tutorial" (`tutorial.dismiss`), "Hint" (each press shows the next of
// three levels through the presenter's `showHint()`; hints send nothing) with the hint text, the failure explanation
// (in place of the short failure words), and the level's band, goal and best stars — and a progress block after the
// view row: "Campaign" (`mode.campaign`), "Daily" (`mode.daily [year, month, day]` with today's local date from the
// presenter) and "Practice" (`mode.practice`), and a picker of the open levels (1 … the frontier, with their bands and
// stars) with "Play level" (`level.select [n]`). All wrapping text in the panel, never over the floor; refusals read in
// words. The existing rows, identifiers and the feature 494 gesture wiring are unchanged. Modelled on
// `MicroscopicAuroraControls` (feature 485).
//
// Feature 496 (R02-G20-06) T-R02G2006-005 (FR-R02G2006-001, 005, 006; clarification Q5): the summary element ("Forest",
// identifier `summary`, the words of `MushroomWeatherFeedbackPlan.summaryText(core:slot:site:)`), the adjustable slot,
// site and moonlight (`accessibilityAdjustableAction`: increment and decrement move the slot and the site like the −
// and + buttons, through the presenter, which plays the selected site's audition when the sound is on, and choose the
// moonlight to set like Moonlight − and +; their values are "pod n", "site at row r, column c" and "moonlight l of 3"),
// each vent toggle with its value ("open" or "closed"), a value in words on every control (Place the selected site,
// Remove the slot's pod, Cycle − and + the shown cycle, Run the progress, Undo and Redo the actions made, Next level
// the next open level, Reset view "authored" or "orbited", Dismiss the instruction, Play level the picked level,
// Campaign / Daily / Practice "selected" or "not selected", Hint the level shown, Sound "on" or "off"), refusals in the
// feedback plan's words, the Sound toggle (off by default, identifier `sound`; presentation only, saving it is
// R02-G20-07), rows that become columns at accessibility text sizes, wrapping text and a 520-point readable width
// (iPad). The existing identifiers and actions are unchanged. Modelled on `MicroscopicAuroraControls` (feature 486).
#if os(iOS)
import MushroomWeatherCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Mushroom Weather.
struct MushroomWeatherControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows (and the panel's selection).
    @Bindable var mirror: MushroomWeatherMirror
    /// The presenter (feature 495): hints, the tutorial, the modes and the daily date; nil sends through `sendAction`.
    var presenter: MushroomWeatherPresenter? = nil
    /// Sends a control with its values through the presenter (feature 494).
    let sendAction: (String, [Double]) -> Void
    /// Returns the camera to the authored view (feature 494).
    let resetView: () -> Void
    /// The text size: rows become columns at accessibility sizes (feature 496).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 496).
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 496).
    static let readableWidth: CGFloat = 520

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                slotRow
                siteRow
                placeRow
                ventRow
                moonRow
                cycleRow
                playRow
                viewRow
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 496).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 496; off by default; presentation only).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter?.setSound(on: $0) }))
            .disabled(presenter == nil)
            .accessibilityLabel("Sound of the forest")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// The actions made of the budget, in words (feature 496): the value of Undo and Redo.
    private var actionsMade: String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return made == 1 ? "1 action made" : "\(made) actions made"
    }

    /// Changes the panel's selection through the presenter (which plays the audition when the sound is on), or
    /// directly without one (feature 496).
    private func select(_ change: @escaping (MushroomWeatherMirror) -> Void) {
        if let presenter { presenter.changeSelection(change) } else { change(mirror) }
    }

    /// An adjustable value's action (feature 496): increment and decrement move the slot or the site like the + and −
    /// buttons, or choose the moonlight to set like Moonlight + and − (presentation only; Place and Set moonlight spend
    /// the action).
    private func adjust(_ adjustment: AccessibilityAdjustmentDirection, slot: Bool = false, site: Bool = false,
                        moon: Bool = false) {
        let step: Int
        switch adjustment {
        case .increment: step = 1
        case .decrement: step = -1
        @unknown default: return
        }
        if slot { moveSlot(step) }
        if site { moveSite(step) }
        if moon { mirror.chosenMoonlight = mirror.clampedMoonlight(mirror.chosenMoonlight + step) }
    }

    /// The level, actions, status, failure (while no explanation replaces it) and refusal lines.
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
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("progress"))
        Text(mirror.summary).font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Forest")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// Choose the pod slot the panel edits.
    @ViewBuilder private var slotRow: some View {
        row {
            Button("Slot −") { moveSlot(-1) }
                .accessibilityLabel("Edit the previous pod")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("slot-minus"))
            Text("pod \(mirror.selectedSlot + 1) of \(mirror.slotCount)")
                .accessibilityLabel("Pod slot")
                .accessibilityValue("pod \(mirror.selectedSlot + 1)")
                .accessibilityAdjustableAction { direction in adjust(direction, slot: true) }
                .accessibilityIdentifier(port.identifier("slot"))
            Button("Slot +") { moveSlot(1) }
                .accessibilityLabel("Edit the next pod")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("slot-plus"))
        }
        Text(mirror.podsLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("pods-detail"))
    }

    /// Choose the site the pod would stand on.
    @ViewBuilder private var siteRow: some View {
        row {
            Button("Site −") { moveSite(-1) }
                .accessibilityLabel("Choose the previous site")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("site-minus"))
            Text(mirror.selectedSite.map { MushroomWeatherLevel.cellWords($0) } ?? "no site")
                .accessibilityLabel("Site")
                .accessibilityValue(mirror.selectedSite.map { "site at " + MushroomWeatherLevel.cellWords($0) }
                                    ?? "no site")
                .accessibilityAdjustableAction { direction in adjust(direction, site: true) }
                .accessibilityIdentifier(port.identifier("site"))
            Button("Site +") { moveSite(1) }
                .accessibilityLabel("Choose the next site")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("site-plus"))
        }
    }

    /// Place the selected pod, or remove the slot's pod.
    @ViewBuilder private var placeRow: some View {
        row {
            Button("Place") { place() }
                .accessibilityLabel("Place the pod")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("place"))
            Button("Remove") { send("pod.remove", [Double(mirror.selectedSlot)]) }
                .accessibilityLabel("Remove the pod from this slot")
                .accessibilityValue(mirror.selectedPodLabel)
                .accessibilityIdentifier(port.identifier("remove"))
        }
        Text(mirror.selectionLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("selection"))
    }

    /// One toggle per canopy vent.
    @ViewBuilder private var ventRow: some View {
        ForEach(Array(mirror.ventsOpen.enumerated()), id: \.offset) { index, open in
            Button(open ? "Vent \(index + 1): open" : "Vent \(index + 1): closed") {
                send("vent.set", [Double(index), open ? 0 : 1])
            }
            .accessibilityLabel(ventName(index))
            .accessibilityValue(open ? "open" : "closed")
            .accessibilityHint(open ? "Closes the vent" : "Opens the vent")
            .accessibilityIdentifier(port.identifier("vent-\(index)"))
        }
    }

    /// Choose a moonlight level (presentation only) and set it with one action, as Microscopic Aurora's panel chooses a
    /// well's strength before Place: every certified moonlight change is one panel action.
    @ViewBuilder private var moonRow: some View {
        row {
            Button("Moonlight −") { mirror.chosenMoonlight = mirror.clampedMoonlight(mirror.chosenMoonlight - 1) }
                .accessibilityLabel("Choose a dimmer moonlight")
                .accessibilityValue(mirror.chosenMoonLabel)
                .accessibilityIdentifier(port.identifier("moon-minus"))
            Text(mirror.moonLabel)
                .accessibilityLabel("Moonlight to set, now " + mirror.moonLabel)
                .accessibilityValue(mirror.chosenMoonValue)
                .accessibilityAdjustableAction { direction in adjust(direction, moon: true) }
                .accessibilityIdentifier(port.identifier("moon"))
            Button("Moonlight +") { mirror.chosenMoonlight = mirror.clampedMoonlight(mirror.chosenMoonlight + 1) }
                .accessibilityLabel("Choose a brighter moonlight")
                .accessibilityValue(mirror.chosenMoonLabel)
                .accessibilityIdentifier(port.identifier("moon-plus"))
            Button("Set moonlight") { send("moon.set", [Double(mirror.clampedMoonlight(mirror.chosenMoonlight))]) }
                .accessibilityLabel("Set the moonlight")
                .accessibilityValue(mirror.chosenMoonLabel)
                .accessibilityIdentifier(port.identifier("moon-set"))
        }
    }

    /// Show an earlier or later cycle of the run, and run the weather.
    @ViewBuilder private var cycleRow: some View {
        row {
            Button("Cycle −") { show(cycle: mirror.shownCycle - 1) }
                .accessibilityLabel("Show the run one cycle earlier")
                .accessibilityValue(mirror.cycleLabel)
                .accessibilityIdentifier(port.identifier("cycle-minus"))
            Text("cycle \(mirror.shownCycle)")
                .accessibilityIdentifier(port.identifier("cycle"))
            Button("Cycle +") { show(cycle: mirror.shownCycle + 1) }
                .accessibilityLabel("Show the run one cycle later")
                .accessibilityValue(mirror.cycleLabel)
                .accessibilityIdentifier(port.identifier("cycle-plus"))
            Button("Run") { send("weather.run") }
                .accessibilityLabel("Run the weather and end the level")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("run"))
        }
        Text(mirror.cycleLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("cycle-detail"))
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last pod, vent, moonlight or run")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the pod, vent, moonlight or run")
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
    /// goal and best stars (feature 495).
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

    /// The mode buttons and the picker of open levels with their bands and stars (feature 495).
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
        MushroomWeatherMirror.modeName(mirror.mode) == name ? "selected" : "not selected"
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
            send("mode.daily", MushroomWeatherPresenter.dateValues(MushroomWeatherPresenter.today()))
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

    /// Reset the view (feature 494; presentation only).
    @ViewBuilder private var viewRow: some View {
        row {
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue((presenter?.gestures.orbit ?? .authored) == .authored ? "authored" : "orbited")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// Vent `index` named by its number and cell (feature 496; the vent toggle's label): "Vent n at row r, column c",
    /// or "Vent n" while no play is followed.
    private func ventName(_ index: Int) -> String {
        guard let level = mirror.play?.level, index < level.vents.count else { return "Vent \(index + 1)" }
        return "Vent \(index + 1) at " + MushroomWeatherLevel.cellWords(level.vents[index].cell)
    }

    /// Moves the slot selection by `step`, wrapping over the level's slots (through the presenter since feature 496).
    private func moveSlot(_ step: Int) {
        select { mirror in
            let count: Int = mirror.slotCount
            mirror.slot = ((mirror.selectedSlot + step) % count + count) % count
        }
    }

    /// Moves the site selection by `step`, wrapping over the level's sites (through the presenter since feature 496).
    private func moveSite(_ step: Int) {
        select { mirror in
            let count: Int = max(1, mirror.sites.count)
            mirror.siteIndex = ((mirror.siteIndex + step) % count + count) % count
        }
    }

    /// Sends the selected pod's placement.
    private func place() {
        guard let site = mirror.selectedSite else {
            mirror.message = MushroomWeatherFeedbackPlan.refusalText(code: "r02-g20.action")
            return
        }
        send("pod.place", [Double(mirror.selectedSlot), Double(site.row), Double(site.column)])
    }

    /// Shows cycle `cycle` (clamped to 0 … cycles run).
    private func show(cycle: Int) {
        send("clock.show", [Double(mirror.clampedCycle(cycle))])
    }

    /// Sends `control` through the presenter, which shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        sendAction(control, values)
    }
}
#endif
