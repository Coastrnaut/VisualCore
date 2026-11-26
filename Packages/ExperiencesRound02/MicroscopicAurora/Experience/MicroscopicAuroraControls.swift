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

    /// Choose the well slot the panel edits.
    @ViewBuilder private var slotRow: some View {
        HStack(spacing: 16) {
            Button("Well −") { mirror.slot = (mirror.slot + 2) % 3 }
                .accessibilityLabel("Edit the previous well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("slot-minus"))
            Text("well \(mirror.slot + 1)")
                .accessibilityIdentifier(port.identifier("slot"))
            Button("Well +") { mirror.slot = (mirror.slot + 1) % 3 }
                .accessibilityLabel("Edit the next well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("slot-plus"))
        }
        Text(mirror.wellsLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("wells-detail"))
    }

    /// Choose the site the well would stand on.
    @ViewBuilder private var siteRow: some View {
        HStack(spacing: 16) {
            Button("Site −") { moveSite(-1) }
                .accessibilityLabel("Choose the previous site")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("site-minus"))
            Text(mirror.selectedSite.map { MicroscopicAuroraLevel.cellWords($0) } ?? "no site")
                .accessibilityIdentifier(port.identifier("site"))
            Button("Site +") { moveSite(1) }
                .accessibilityLabel("Choose the next site")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("site-plus"))
        }
    }

    /// Choose the strength and the turning sense.
    @ViewBuilder private var strengthRow: some View {
        HStack(spacing: 16) {
            Button("Strength −") { mirror.strength = max(1, mirror.strength - 1) }
                .accessibilityLabel("Weaken the well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("strength-minus"))
            Text("strength \(mirror.strength)")
                .accessibilityIdentifier(port.identifier("strength"))
            Button("Strength +") { mirror.strength = min(4, mirror.strength + 1) }
                .accessibilityLabel("Strengthen the well")
                .accessibilityValue(mirror.selectionLabel)
                .accessibilityIdentifier(port.identifier("strength-plus"))
            Button(mirror.counterclockwise ? "Counterclockwise" : "Clockwise") {
                mirror.counterclockwise.toggle()
            }
            .accessibilityLabel("Switch the turning sense")
            .accessibilityValue(mirror.selectionLabel)
            .accessibilityIdentifier(port.identifier("sense"))
        }
    }

    /// Place the selected well, or remove the slot's well.
    @ViewBuilder private var placeRow: some View {
        HStack(spacing: 16) {
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
        HStack(spacing: 16) {
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
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last placement, removal or play")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the placement, removal or play")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
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

    /// The mode buttons and the picker of open levels with their bands and stars (feature 485).
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
        HStack(spacing: 16) {
            Button(mirror.frozen ? "Unfreeze" : "Freeze") { freeze() }
                .accessibilityLabel(mirror.frozen ? "Unfreeze the swim" : "Freeze the swim")
                .accessibilityValue(mirror.frozen ? "frozen" : "not frozen")
                .accessibilityIdentifier(port.identifier("freeze"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// Moves the site selection by `step`, wrapping over the level's sites.
    private func moveSite(_ step: Int) {
        let count: Int = max(1, mirror.sites.count)
        mirror.siteIndex = ((mirror.siteIndex + step) % count + count) % count
    }

    /// Sends the selected well's placement.
    private func place() {
        guard let site = mirror.selectedSite else {
            mirror.message = "That change was refused: this level has no sites."
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
