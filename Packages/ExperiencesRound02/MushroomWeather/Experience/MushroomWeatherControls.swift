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
            }
            .padding()
        }
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
            .accessibilityIdentifier(port.identifier("progress"))
        Text(mirror.targetLabel).font(.footnote)
        if let message = mirror.message {
            Text(message).font(.footnote)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// Choose the pod slot the panel edits.
    @ViewBuilder private var slotRow: some View {
        HStack(spacing: 16) {
            Button("Slot −") { moveSlot(-1) }
                .accessibilityLabel("Edit the previous pod")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("slot-minus"))
            Text("pod \(mirror.selectedSlot + 1) of \(mirror.slotCount)")
                .accessibilityLabel("Pod slot")
                .accessibilityValue("pod \(mirror.selectedSlot + 1) of \(mirror.slotCount)")
                .accessibilityIdentifier(port.identifier("slot"))
            Button("Slot +") { moveSlot(1) }
                .accessibilityLabel("Edit the next pod")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("slot-plus"))
        }
        Text(mirror.podsLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("pods-detail"))
    }

    /// Choose the site the pod would stand on.
    @ViewBuilder private var siteRow: some View {
        HStack(spacing: 16) {
            Button("Site −") { moveSite(-1) }
                .accessibilityLabel("Choose the previous site")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("site-minus"))
            Text(mirror.selectedSite.map { MushroomWeatherLevel.cellWords($0) } ?? "no site")
                .accessibilityIdentifier(port.identifier("site"))
            Button("Site +") { moveSite(1) }
                .accessibilityLabel("Choose the next site")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("site-plus"))
        }
    }

    /// Place the selected pod, or remove the slot's pod.
    @ViewBuilder private var placeRow: some View {
        HStack(spacing: 16) {
            Button("Place") { place() }
                .accessibilityLabel("Place the pod")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("place"))
            Button("Remove") { send("pod.remove", [Double(mirror.selectedSlot)]) }
                .accessibilityLabel("Remove the pod from this slot")
                .accessibilityValue(mirror.podsLabel)
                .accessibilityIdentifier(port.identifier("remove"))
        }
        Text(mirror.selectionLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("selection"))
    }

    /// One toggle per canopy vent.
    @ViewBuilder private var ventRow: some View {
        ForEach(Array(mirror.ventsOpen.enumerated()), id: \.offset) { index, open in
            Button(open ? "Vent \(index + 1): open" : "Vent \(index + 1): shut") {
                send("vent.set", [Double(index), open ? 0 : 1])
            }
            .accessibilityLabel(open ? "Shut vent \(index + 1)" : "Open vent \(index + 1)")
            .accessibilityValue(mirror.ventLabel(index))
            .accessibilityIdentifier(port.identifier("vent-\(index)"))
        }
    }

    /// Choose a moonlight level (presentation only) and set it with one action, as Microscopic Aurora's panel chooses a
    /// well's strength before Place: every certified moonlight change is one panel action.
    @ViewBuilder private var moonRow: some View {
        HStack(spacing: 16) {
            Button("Moonlight −") { mirror.chosenMoonlight = mirror.clampedMoonlight(mirror.chosenMoonlight - 1) }
                .accessibilityLabel("Choose a dimmer moonlight")
                .accessibilityValue(mirror.chosenMoonLabel)
                .accessibilityIdentifier(port.identifier("moon-minus"))
            Text(mirror.moonLabel)
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
        HStack(spacing: 16) {
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
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last pod, vent, moonlight or run")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the pod, vent, moonlight or run")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
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

    /// The mode buttons and the picker of open levels with their bands and stars (feature 495).
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
        HStack(spacing: 16) {
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// Moves the slot selection by `step`, wrapping over the level's slots.
    private func moveSlot(_ step: Int) {
        let count: Int = mirror.slotCount
        mirror.slot = ((mirror.selectedSlot + step) % count + count) % count
    }

    /// Moves the site selection by `step`, wrapping over the level's sites.
    private func moveSite(_ step: Int) {
        let count: Int = max(1, mirror.sites.count)
        mirror.siteIndex = ((mirror.siteIndex + step) % count + count) % count
    }

    /// Sends the selected pod's placement.
    private func place() {
        guard let site = mirror.selectedSite else {
            mirror.message = "That change was refused: this level has no sites."
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
