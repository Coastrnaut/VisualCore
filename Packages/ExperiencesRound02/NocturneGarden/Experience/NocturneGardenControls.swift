// NocturneGardenControls — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-005; clarification Q5). The minimal
// control panel: labelled pickers for the kind, the column, the row, the size and the bloom (presentation state only),
// plant, move, resize and remove (kernel actions through the action port), a sun picker (Sun − and +) with "Set sun"
// (feature 384: one move reaches any allowed elevation), undo, redo, next level and "Reset view", each with an
// accessibility label and value. Feature 385 (R02-G09-05) T-R02G0905-005: the tutorial instruction with Dismiss, Hint
// (each press reveals the next level), the failure explanation with Undo and Retry, the goal and stars, Campaign / Daily /
// Practice and a picker of the open levels; all as wrapping text in the panel, never over the garden. Dragging stems, pinching to scale and sliding the sun come in R02-G09-04;
// full accessibility in R02-G09-06. Feature 386 (R02-G09-06) T-R02G0906-005 (FR-R02G0906-001, 005, 006; clarification
// Q5): the summary element ("Garden"), adjustable kind, column, row, size, bloom and sun pickers (the sun picker is a
// stepper over the allowed elevations), refusals in words, the Sound toggle (off by default), rows that become columns
// at accessibility text sizes, wrapping text and a 520-point readable width. Feature 387 (R02-G09-07)
// T-R02G0907-005 (clarifications Q2, Q4, Q5): "Replay best solution" for a level with a verified stored solution, and
// during replay its position ("Replay: move k of n") with Step and Stop, each with a label and a value; the Sound toggle
// saves the choice through `settings.sound`.
#if os(iOS)
import NocturneGardenCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Nocturne Garden.
struct NocturneGardenControls: View {
    let port: ExperienceActionPort
    let mirror: NocturneGardenMirror
    /// The presenter (feature 385): hints, retry, undo and the daily level.
    let presenter: NocturneGardenPresenter
    /// Returns the camera to the authored view (feature 384).
    let resetView: () -> Void
    /// Sends a control the way the presenter does (refusals shown and logged).
    let sender: (String, [Double]) -> Void

    /// The text size: rows become columns at accessibility sizes (feature 386).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the ambient loop plays only while it is.
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 386).
    static let readableWidth: CGFloat = 520

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                pickRow
                bloomRow
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 386).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 387).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Play the next move of the replay")
                    .accessibilityValue("Move \(mirror.replayPosition) of \(mirror.replayLength)")
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue("\(mirror.replayLength) moves")
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
        }
    }

    /// The replay position line: "Replay: move k of n" (feature 387).
    static func replayPositionText(_ mirror: NocturneGardenMirror) -> String {
        "Replay: move \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// The Sound toggle (feature 386; off by default; saved through `settings.sound` since feature 387).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityLabel("Ambient sound")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
    }

    /// The level, moves and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · moves \(mirror.moves) of \(mirror.budget)")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Garden")
            .accessibilityValue(mirror.summary)
        Text(mirror.measureLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let preview = mirror.previewText {
            // Feature 384 convergence (T-R02G0904-014): the drag's exact preview in words.
            Text("Dragging: " + preview).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Drag preview")
                .accessibilityValue(preview)
        }
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The kind, column, row and size pickers and the plant button.
    @ViewBuilder private var pickRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.kindLabel,
                    onIncrement: { mirror.pickKind(1) },
                    onDecrement: { mirror.pickKind(-1) })
                .accessibilityLabel("Bloom kind to plant")
                .accessibilityValue(mirror.kindLabel)
            Stepper(mirror.columnLabel,
                    onIncrement: { mirror.stepColumn(1) },
                    onDecrement: { mirror.stepColumn(-1) })
                .accessibilityLabel("Column of the anchor cell")
                .accessibilityValue(mirror.columnLabel)
            Stepper(mirror.rowLabel,
                    onIncrement: { mirror.stepRow(1) },
                    onDecrement: { mirror.stepRow(-1) })
                .accessibilityLabel("Row of the anchor cell")
                .accessibilityValue(mirror.rowLabel)
            Stepper(mirror.sizeLabel,
                    onIncrement: { mirror.stepSize(1) },
                    onDecrement: { mirror.stepSize(-1) })
                .accessibilityLabel("Bloom size")
                .accessibilityValue(mirror.sizeLabel)
            Button("Plant") {
                send("bloom.plant", [Double(mirror.kind), Double(mirror.column), Double(mirror.row),
                                     Double(mirror.size)])
            }
            .accessibilityLabel("Plant the chosen bloom at the chosen cell")
            .accessibilityValue(mirror.kindLabel + ", " + mirror.columnLabel + ", " + mirror.rowLabel + ", "
                                + mirror.sizeLabel)
        }
    }

    /// The bloom picker with move, resize and remove.
    @ViewBuilder private var bloomRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.bloomLabel,
                    onIncrement: { mirror.pickBloom(1) },
                    onDecrement: { mirror.pickBloom(-1) })
                .accessibilityLabel("Planted bloom to change")
                .accessibilityValue(mirror.bloomLabel)
            row {
                Button("Move") {
                    send("bloom.move", [Double(mirror.bloom), Double(mirror.column), Double(mirror.row)])
                }
                .accessibilityLabel("Move the chosen bloom to the chosen cell")
                .accessibilityValue(Self.values(mirror).move)
                Button("Resize") { send("bloom.resize", [Double(mirror.bloom), Double(mirror.size)]) }
                    .accessibilityLabel("Give the chosen bloom the chosen size")
                    .accessibilityValue(Self.values(mirror).resize)
                Button("Remove") { send("bloom.remove", [Double(mirror.bloom)]) }
                    .accessibilityLabel("Remove the chosen bloom")
                    .accessibilityValue(Self.values(mirror).remove)
            }
        }
    }

    /// Sun − and +, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            row {
                // Feature 386: the sun picker is adjustable (swipe up or down) over the allowed elevations.
                Stepper(mirror.sunPickLabel,
                        onIncrement: { mirror.stepSun(1) },
                        onDecrement: { mirror.stepSun(-1) })
                    .accessibilityLabel("Sun elevation to set")
                    .accessibilityValue(mirror.sunPickLabel)
                Button("Set sun") { send("sun.set", [Double(mirror.sunPick)]) }
                    .accessibilityLabel("Move the sun to the picked elevation")
                    .accessibilityValue(mirror.sunLabel + "; picked " + mirror.sunPickLabel)
            }
            row {
                Button("Undo") { send("play.undo") }
                    .accessibilityLabel("Undo the last move")
                    .accessibilityValue(Self.values(mirror).moves)
                Button("Redo") { send("play.redo") }
                    .accessibilityLabel("Redo the move")
                    .accessibilityValue(Self.values(mirror).moves)
                Button("Next level") { send("level.next") }
                    .accessibilityLabel("Go to the next level")
                    .accessibilityValue(Self.values(mirror).nextLevel)
                Button("Reset view") { resetView() }
                    .accessibilityLabel("Return the camera to the authored view")
                    .accessibilityValue(Self.viewValue(presenter.gestures.orbit == .authored))
            }
        }
    }

    /// The tutorial instruction, the hint and the failure explanation (feature 385).
    @ViewBuilder private var teaching: some View {
        if let instruction = mirror.instruction {
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityValue(instruction)
            }
        }
        row {
            Button("Hint") { presenter.showHint() }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            Text("Goal: match in \(mirror.smallest) moves; budget \(mirror.budget)")
                .font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                row {
                    Button("Undo") { presenter.undoMove(port: port) }
                        .accessibilityLabel("Undo the last move")
                        .accessibilityValue(Self.values(mirror).moves)
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                        .accessibilityValue(Self.values(mirror).retry)
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 385).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with a larger move budget")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "practice"))
        }
        row {
            Stepper(levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityLabel("Level to play")
                .accessibilityValue(levelLabel(mirror.pickedLevel))
            Button("Play level") { send("level.select", [Double(mirror.pickedLevel)]) }
                .accessibilityLabel("Play the picked level")
                .accessibilityValue(Self.values(mirror).playLevel)
        }
    }

    /// The accessibility values in words of the buttons that act on the picks or the play (feature 386 convergence,
    /// T-R02G0906-013): every native control carries a value.
    struct Values: Equatable {
        /// Move: the chosen bloom and the target cell.
        let move: String
        /// Resize: the chosen bloom and the chosen size.
        let resize: String
        /// Remove: the chosen bloom.
        let remove: String
        /// Undo and redo: the moves made of the budget.
        let moves: String
        /// Next level: the next open level, or that none is open.
        let nextLevel: String
        /// Retry: the level and the mode.
        let retry: String
        /// Play level: the picked level.
        let playLevel: String
    }

    /// The button values of `mirror` (see ``Values``).
    static func values(_ mirror: NocturneGardenMirror) -> Values {
        let bloom: String = mirror.bloomLabel
        let next: String = mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
            : "no further level open"
        return Values(move: bloom + " to " + mirror.columnLabel + ", " + mirror.rowLabel,
                      resize: bloom + " to " + mirror.sizeLabel,
                      remove: bloom,
                      moves: "\(mirror.moves) of \(mirror.budget) moves made",
                      nextLevel: next,
                      retry: "level \(mirror.levelNumber), " + modeName(mirror.mode),
                      playLevel: "level \(mirror.pickedLevel)")
    }

    /// The Reset view value: "authored view" or "orbited view".
    static func viewValue(_ authored: Bool) -> String { authored ? "authored view" : "orbited view" }

    /// A mode button's value: "selected" or "not selected".
    static func selectedValue(_ selected: Bool) -> String { selected ? "selected" : "not selected" }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band = NocturneGardenProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily, practice or replay.
    static func modeName(_ mode: NocturneGardenMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
