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
                slotRow
                siteRow
                strengthRow
                placeRow
                tickRow
                playRow
                viewRow
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
