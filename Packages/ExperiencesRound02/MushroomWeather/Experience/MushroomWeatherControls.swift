// MushroomWeatherControls — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-005; clarification Q5). The minimal
// control panel: a labelled slot picker (pod 1 … slots, slot − and +), the site (site − and +, over the level's sites,
// or every free floor cell on a level without sites) of the pod to place; place (`pod.place [slot, row, column]`: one
// action of the budget), remove (`pod.remove [slot]`: one action); a toggle per vent (`vent.set [index, open]`, open 1,
// shut 0: one action); the moonlight (moonlight − and + choose a level 0 … 3, Set moonlight sends `moon.set [level]`: one action); the shown
// cycle (cycle − and +, `clock.show [cycle]` clamped to 0 … cycles run); running the weather (`weather.run`), undo,
// redo and next level (kernel actions through the action port), each with an accessibility label, value and identifier.
// The shown cycle is presentation state of the adapter (a level opens at cycle 0). A change the kernel refuses (a site
// another pod occupies, an unchanged pod, vent or moonlight, no action left) is still sent: the kernel refuses it and
// the panel says why. The header shows the actions left of the budget, the status (stage, or the failure in words), the
// progress description, the level in words, the tutorial on levels that have one, the failure in words and a refused
// action in words. Dragging pods, scrubbing the run and full accessibility come in later features of R02-G20. Modelled
// on `MicroscopicAuroraControls` (feature 483).
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

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                slotRow
                siteRow
                placeRow
                ventRow
                moonRow
                cycleRow
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

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(MushroomWeatherMirror.refusalText(code: result.code))."
    }
}
#endif
