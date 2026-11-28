// MyceliumArchitectControls — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-005, 010; clarification Q5). The
// minimal control panel: a cell cursor (column − and +, row − and +, clamped to the board; the cell is named in words
// by the kernel's cell description); nutrient (`cell.nutrient [column, row]`), blocker (`cell.blocker [column, row]`)
// and clear (`cell.clear [column, row]`) on the cursor's cell, one action each; a direction picker (direction − and +,
// cyclic over north … north-west, as buttons, since UI tests cannot tap a segmented picker) with seed
// (`root.seed [direction]`) and unseed (`root.unseed [direction]`), one action each; the shown pulse (pulse − and +,
// `growth.show [pulse]`, clamped to 0 … the pulses run: presentation only); running the growth (`growth.run`), undo,
// redo and next level (kernel actions through the action port), each with an accessibility label, value and
// identifier. A change the kernel refuses (a cell off the sites or not empty, a limit reached, a starting seed, no
// action left) is still sent: the kernel refuses it and the panel says why. The header shows the actions left of the
// budget, the status (stage, or the failure in words), the progress description, the level in words, the tutorial on
// levels that have one, the failure in words and a refused action in words; every terminal is named in words, so no
// information is carried by colour alone. Touching the board, scrubbing the growth and full accessibility come in later
// features of R02-G22. Modelled on `BinaryGardensControls` (feature 503).
// Feature 514 (R02-G22-04) T-R02G2204-006 (FR-R02G2204-011, 013; clarification Q2): every kernel control sends through
// the presenter (so refusals are shown and logged with their reason code) and every row is kept. The panel gains the
// placement tool as two buttons, "Nutrient tool" and "Blocker tool" (never a segmented picker, which interface tests
// cannot tap; the chosen one carries the selected trait and the value "selected"), which choose what a tap on an empty
// site places; "Place at cursor" (one `cell.nutrient` or `cell.blocker [column, row]` by the tool on the cursor's cell);
// "Inspect cursor" and "Inspect: none" (presentation only) with the inspected cell's words; "Reset view" (the authored
// camera, presentation only; its value "authored" or "orbited"); and the preview in words (the predicted verdict or
// the refusal), so no preview or inspection is carried by colour alone. Modelled on `BinaryGardensControls`
// (feature 504).
#if os(iOS)
import MyceliumArchitectCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Mycelium Architect.
struct MyceliumArchitectControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows (and the panel's selection).
    @Bindable var mirror: MyceliumArchitectMirror
    /// Sends a kernel control with its values through the presenter (feature 514: refusals shown and logged).
    let sendAction: (String, [Double]) -> Void
    /// Chooses the placement tool through the presenter (feature 514; presentation only).
    let chooseTool: (MyceliumArchitectTool) -> Void
    /// Sends the tool's placement on the cursor's cell through the presenter (feature 514).
    let placeAtCursor: () -> Void
    /// Inspects a cell, or clears the inspection with nil, through the presenter (feature 514; presentation only).
    let inspect: (MyceliumArchitectCell?) -> Void
    /// Returns the camera to the authored view through the presenter (feature 514; presentation only).
    let resetView: () -> Void

    /// The accessibility identifier names of the panel's elements (each prefixed by the experience's prefix), as
    /// built: the interface tests find the controls by these names.
    static let identifierNames: [String] = [
        "actions", "status", "tutorial", "failure", "progress", "message", "column-minus", "column-plus", "row-minus",
        "row-plus", "cell", "nutrient", "blocker", "clear", "direction-minus", "direction", "direction-plus", "seed",
        "unseed", "pulse-minus", "pulse", "pulse-plus", "run", "terminals", "undo", "redo", "next-level",
        "tool-nutrient", "tool-blocker", "place", "preview", "inspect-cursor", "inspect-none", "inspect-detail",
        "reset-view",
    ]

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                toolRow
                cursorRow
                cellRow
                inspectRow
                directionRow
                pulseRow
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
        if let preview = mirror.previewLabel {
            Text(preview).font(.footnote)
                .accessibilityIdentifier(port.identifier("preview"))
        }
    }

    /// The placement tool as two buttons (feature 514; never a segmented picker) and "Place at cursor".
    @ViewBuilder private var toolRow: some View {
        HStack(spacing: 12) {
            toolButton(.nutrient, title: "Nutrient tool", name: "tool-nutrient")
            toolButton(.blocker, title: "Blocker tool", name: "tool-blocker")
            Button("Place at cursor") { placeAtCursor() }
                .accessibilityLabel("Place the chosen tool's item on the cursor's cell")
                .accessibilityValue(mirror.toolLabel + " at " + mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("place"))
        }
    }

    /// One tool button: chooses `tool` (presentation only); the chosen one is marked selected in words and by trait.
    private func toolButton(_ tool: MyceliumArchitectTool, title: String, name: String) -> some View {
        let chosen: Bool = mirror.tool == tool
        let traits: AccessibilityTraits = chosen ? .isSelected : []
        let shown: String = chosen ? title + " ✓" : title
        return Button(shown) { chooseTool(tool) }
            .accessibilityLabel(title)
            .accessibilityValue(chosen ? "selected" : "not selected")
            .accessibilityAddTraits(traits)
            .accessibilityIdentifier(port.identifier(name))
    }

    /// Inspect the cursor's cell or nothing (feature 514; presentation only), with the inspected cell in words.
    @ViewBuilder private var inspectRow: some View {
        HStack(spacing: 16) {
            Button("Inspect cursor") { inspect(mirror.cursor) }
                .accessibilityLabel("Inspect the cursor's cell")
                .accessibilityValue(mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("inspect-cursor"))
            Button("Inspect: none") { inspect(nil) }
                .accessibilityLabel("Clear the inspection")
                .accessibilityValue(mirror.inspectedLabel ?? "none")
                .accessibilityIdentifier(port.identifier("inspect-none"))
        }
        if let words = mirror.inspectedLabel {
            Text("Inspected " + words).font(.footnote)
                .accessibilityLabel("Inspected cell")
                .accessibilityValue(words)
                .accessibilityIdentifier(port.identifier("inspect-detail"))
        }
    }

    /// Return the camera to the authored view (feature 514; presentation only).
    @ViewBuilder private var viewRow: some View {
        Button("Reset view") { resetView() }
            .accessibilityLabel("Return the camera to the authored view")
            .accessibilityValue(mirror.orbited ? "orbited" : "authored")
            .accessibilityIdentifier(port.identifier("reset-view"))
    }

    /// Move the cell cursor by a column or a row.
    @ViewBuilder private var cursorRow: some View {
        HStack(spacing: 12) {
            Button("Column −") { mirror.moveColumn(-1) }
                .accessibilityLabel("Move the cursor one column left")
                .accessibilityValue(mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("column-minus"))
            Button("Column +") { mirror.moveColumn(1) }
                .accessibilityLabel("Move the cursor one column right")
                .accessibilityValue(mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("column-plus"))
            Button("Row −") { mirror.moveRow(-1) }
                .accessibilityLabel("Move the cursor one row up")
                .accessibilityValue(mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("row-minus"))
            Button("Row +") { mirror.moveRow(1) }
                .accessibilityLabel("Move the cursor one row down")
                .accessibilityValue(mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("row-plus"))
        }
        Text("Cell " + mirror.cellLabel).font(.footnote)
            .accessibilityLabel("Cursor cell")
            .accessibilityValue(mirror.cellLabel)
            .accessibilityIdentifier(port.identifier("cell"))
    }

    /// Place a nutrient or a blocker on the cursor's cell, or clear it.
    @ViewBuilder private var cellRow: some View {
        HStack(spacing: 16) {
            Button("Nutrient") { send("cell.nutrient", cellValues) }
                .accessibilityLabel("Place a nutrient on the cursor's cell")
                .accessibilityValue(mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("nutrient"))
            Button("Blocker") { send("cell.blocker", cellValues) }
                .accessibilityLabel("Place a blocker on the cursor's cell")
                .accessibilityValue(mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("blocker"))
            Button("Clear") { send("cell.clear", cellValues) }
                .accessibilityLabel("Clear the nutrient or blocker on the cursor's cell")
                .accessibilityValue(mirror.cellLabel)
                .accessibilityIdentifier(port.identifier("clear"))
        }
    }

    /// Choose a direction and seed or unseed it at the root.
    @ViewBuilder private var directionRow: some View {
        HStack(spacing: 12) {
            Button("Direction −") { mirror.direction = (mirror.selectedDirection.rawValue + 7) % 8 }
                .accessibilityLabel("Choose the previous direction")
                .accessibilityValue(mirror.directionLabel)
                .accessibilityIdentifier(port.identifier("direction-minus"))
            Text(mirror.directionLabel)
                .accessibilityLabel("Direction")
                .accessibilityValue(mirror.directionLabel)
                .accessibilityIdentifier(port.identifier("direction"))
            Button("Direction +") { mirror.direction = (mirror.selectedDirection.rawValue + 1) % 8 }
                .accessibilityLabel("Choose the next direction")
                .accessibilityValue(mirror.directionLabel)
                .accessibilityIdentifier(port.identifier("direction-plus"))
        }
        HStack(spacing: 16) {
            Button("Seed") { send("root.seed", [Double(mirror.selectedDirection.rawValue)]) }
                .accessibilityLabel("Seed a filament from the root in the chosen direction")
                .accessibilityValue(mirror.directionLabel)
                .accessibilityIdentifier(port.identifier("seed"))
            Button("Unseed") { send("root.unseed", [Double(mirror.selectedDirection.rawValue)]) }
                .accessibilityLabel("Remove the seed in the chosen direction")
                .accessibilityValue(mirror.directionLabel)
                .accessibilityIdentifier(port.identifier("unseed"))
        }
    }

    /// Show an earlier or later pulse of the growth, and run it.
    @ViewBuilder private var pulseRow: some View {
        HStack(spacing: 16) {
            Button("Pulse −") { send("growth.show", [Double(mirror.pulse(moved: -1))]) }
                .accessibilityLabel("Show the growth one pulse earlier")
                .accessibilityValue(mirror.pulseLabel)
                .accessibilityIdentifier(port.identifier("pulse-minus"))
            Text(mirror.pulseLabel)
                .accessibilityIdentifier(port.identifier("pulse"))
            Button("Pulse +") { send("growth.show", [Double(mirror.pulse(moved: 1))]) }
                .accessibilityLabel("Show the growth one pulse later")
                .accessibilityValue(mirror.pulseLabel)
                .accessibilityIdentifier(port.identifier("pulse-plus"))
            Button("Run") { send("growth.run") }
                .accessibilityLabel("Run the growth and end the level")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("run"))
        }
        Text(mirror.terminalsLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("terminals"))
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last placement, clear, seed or run")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the placement, clear, seed or run")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
    }

    /// The cursor's column and row as action values.
    private var cellValues: [Double] { [Double(mirror.cursorColumn), Double(mirror.cursorRow)] }

    /// Sends `control` through the presenter, which shows a refusal in words and logs its code (feature 514).
    private func send(_ control: String, _ values: [Double] = []) {
        sendAction(control, values)
    }
}
#endif
