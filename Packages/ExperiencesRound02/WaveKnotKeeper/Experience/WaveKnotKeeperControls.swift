// WaveKnotKeeperControls — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-005; clarification Q5). The minimal
// control panel: a point picker (selects a control point, presentation only), six direction buttons that move the
// selected point one lattice step, undo, redo and next level, each with an accessibility label and value; every change
// is a kernel action sent through the action port. Dragging handles, orbit and gestures come in R02-G03-04; full
// accessibility in R02-G03-06.
// Feature 325 (R02-G03-05) T-R02G0305-005 (FR-R02G0305-001 … 005): the tutorial instruction with Dismiss, a Hint button
// that reveals the next hint level, the failure explanation with Undo and Retry, the goal (moves allowed, best
// possible), the mode (Campaign, Daily, Practice) and a level picker of the open levels by band with their stars. The
// body is split into small sections so the type checker stays fast. Every text is plain panel text read by VoiceOver.
// Feature 326 (R02-G03-06) T-R02G0306-006 (FR-R02G0306-001, 005, 006; clarification Q5): every control carries a label
// and a value, button rows become columns at accessibility text sizes, the panel keeps a readable width of at most 520
// points (padding included), a Sound toggle (off by default) drives the ambient loop, refusals show in words, and the
// panel tells the presenter when it is on screen.
// Feature 327 (R02-G03-07) T-R02G0307-005: Replay best solution for a verified solved level, and during replay its
// position with Step and Stop, each with a label and a value.
// Feature 329 (R02-G03-09) T-R02G0309-003 (FR-R02G0309-001; clarification Q1): every control carries the identifier
// `experience.r02-g03.wave-knot-keeper.<name>` (`port.identifier`), the names listed in ``identifierNames``.
#if os(iOS)
import SwiftUI
import VisualCoreExperienceHost
import WaveKnotKeeperCore

/// The control panel of Wave Knot Keeper.
struct WaveKnotKeeperControls: View {
    let port: ExperienceActionPort
    let mirror: WaveKnotKeeperMirror
    /// The presenter (feature 325): hints, retry, the daily date and "Reset view" (feature 324).
    let presenter: WaveKnotKeeperPresenter

    /// The button titles and spoken names of the six directions, in `WaveKnotKeeperDirection.allCases` order.
    static let titles: [String] = ["+x", "−x", "+y", "−y", "Over", "Under"]
    static let spoken: [String] = ["right", "left", "up", "down", "towards you (over)", "away from you (under)"]
    /// The identifier names of the six direction buttons, in `WaveKnotKeeperDirection.allCases` order (feature 329).
    static let directionNames: [String] = ["move-plus-x", "move-minus-x", "move-plus-y", "move-minus-y", "move-over",
                                           "move-under"]
    /// Every control's identifier name (clarification Q1 of feature 329), each once.
    static let identifierNames: [String] = ["point-picker"] + directionNames
        + ["undo", "redo", "next-level", "reset-view", "hint", "dismiss-tutorial", "failure-undo", "retry", "campaign",
           "daily", "practice", "replay", "replay-step", "replay-stop", "level-picker", "sound"]

    @Environment(\.dynamicTypeSize) private var typeSize

    /// The widest the panel's content grows, padding included (clarification Q5).
    static let readableWidth: CGFloat = 520

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teachingSection
                failureSection
                hintRow
                pointPicker
                directionRow
                playRow
                modeRow
                levelMenu
                replaySection
                soundToggle
            }
            .padding()
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
        }
        .onAppear { presenter.controlsAppeared() }
        .onDisappear { presenter.controlsDisappeared() }
    }

    /// A row of controls that becomes a column at accessibility text sizes (feature 326).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 16) { content() }
        }
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 327).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text("Replay: move \(mirror.replayPosition) of \(mirror.replayLength)").font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Play the next move of the replay")
                    .accessibilityValue("Move \(mirror.replayPosition) of \(mirror.replayLength)")
                    .accessibilityIdentifier(port.identifier("replay-step"))
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue("\(mirror.replayLength) moves")
                    .accessibilityIdentifier(port.identifier("replay-stop"))
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
                .accessibilityIdentifier(port.identifier("replay"))
        }
    }

    /// The Sound toggle (feature 326; off by default).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) }))
            .accessibilityLabel("Ambient sound")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// The value of the play buttons: the level and the moves spent.
    static func progressValue(_ mirror: WaveKnotKeeperMirror) -> String {
        "Level \(mirror.levelNumber), moves \(mirror.spent) of \(mirror.allowance)"
    }

    /// The mode's name: "Campaign", "Daily level" or "Practice".
    static func modeName(_ mode: WaveKnotKeeperMode) -> String {
        switch mode {
        case .campaign: "Campaign"
        case .practice: "Practice"
        case .daily: "Daily level"
        case .replay: "Replay"
        }
    }

    /// The level, moves and signature lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · moves \(mirror.spent) of \(mirror.allowance)")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        Text("Crossings \(mirror.crossings), writhe \(mirror.writhe) · target \(mirror.targetCrossings), \(mirror.targetWrithe)")
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The goal line and the tutorial instruction with Dismiss (feature 325).
    @ViewBuilder private var teachingSection: some View {
        Text(Self.goal(mirror)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        if let instruction = mirror.instruction {
            row {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityValue("Tutorial shown")
                    .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
            }
        }
    }

    /// The failure explanation with Undo and Retry (feature 325).
    @ViewBuilder private var failureSection: some View {
        if let failure = mirror.failureText {
            Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
            row {
                Button("Undo") { send("play.undo") }
                    .accessibilityLabel("Undo the last move")
                    .accessibilityValue(Self.progressValue(mirror))
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Retry the level")
                    .accessibilityValue(Self.modeName(mirror.mode))
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The Hint button and the hint revealed so far (feature 325).
    @ViewBuilder private var hintRow: some View {
        row {
            Button("Hint") { presenter.showHint(port: port) }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
                .accessibilityIdentifier(port.identifier("hint"))
            if let hint = mirror.hintText { Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true) }
        }
    }

    /// Campaign, Daily and Practice (feature 325).
    @ViewBuilder private var modeRow: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(mirror.mode == .campaign ? "Selected" : "Not selected")
                .accessibilityAddTraits(mirror.mode == .campaign ? .isSelected : [])
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.isDaily(mirror.mode) ? "Selected" : "Not selected")
                .accessibilityAddTraits(Self.isDaily(mirror.mode) ? .isSelected : [])
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more moves")
                .accessibilityValue(mirror.mode == .practice ? "Selected" : "Not selected")
                .accessibilityAddTraits(mirror.mode == .practice ? .isSelected : [])
                .accessibilityIdentifier(port.identifier("practice"))
        }
    }

    /// The level picker: the open levels by band of 20, with their stars (feature 325).
    @ViewBuilder private var levelMenu: some View {
        Menu("Levels") {
            ForEach(0..<5, id: \.self) { band in
                Section("Band \(band + 1)") {
                    ForEach((band * 20 + 1)...(band * 20 + 20), id: \.self) { level in
                        if level <= mirror.frontier {
                            Button(Self.levelTitle(level, stars: mirror.stars[level])) {
                                send("level.select", [Double(level)])
                            }
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Choose an open level")
        .accessibilityValue("Levels 1 to \(mirror.frontier) open")
        .accessibilityIdentifier(port.identifier("level-picker"))
    }

    /// The goal line: moves allowed, the best possible and the mode.
    static func goal(_ mirror: WaveKnotKeeperMirror) -> String {
        let mode: String
        switch mirror.mode {
        case .campaign: mode = "Campaign"
        case .practice: mode = "Practice"
        case .daily: mode = "Daily level"
        case .replay: mode = "Replay"
        }
        return "\(mode) · goal: \(mirror.allowance) moves allowed, best possible \(mirror.shortest)"
    }

    /// Whether `mode` is daily.
    static func isDaily(_ mode: WaveKnotKeeperMode) -> Bool {
        if case .daily = mode { return true }
        return false
    }

    /// A level picker entry: "Level 7 · 3 stars", or "Level 7" when unsolved.
    static func levelTitle(_ level: Int, stars: Int?) -> String {
        guard let stars else { return "Level \(level)" }
        return "Level \(level) · \(stars) \(stars == 1 ? "star" : "stars")"
    }

    /// The point picker: previous and next point.
    @ViewBuilder private var pointPicker: some View {
        if mirror.pointCount > 0 {
            Stepper("Point \(mirror.selected + 1) of \(mirror.pointCount)",
                    onIncrement: { select((mirror.selected + 1) % mirror.pointCount) },
                    onDecrement: { select((mirror.selected + mirror.pointCount - 1) % mirror.pointCount) })
                .accessibilityLabel("Selected point")
                .accessibilityValue("\(mirror.selected + 1) of \(mirror.pointCount)")
                .accessibilityIdentifier(port.identifier("point-picker"))
        }
    }

    /// One button per direction, moving the selected point one step.
    @ViewBuilder private var directionRow: some View {
        row {
            ForEach(0..<WaveKnotKeeperDirection.allCases.count, id: \.self) { index in
                Button(Self.titles[index]) { send("point.move", [Double(mirror.selected), Double(index)]) }
                    .accessibilityLabel("Move the selected point \(Self.spoken[index])")
                    .accessibilityValue("Point \(mirror.selected + 1)")
                    .accessibilityIdentifier(port.identifier(Self.directionNames[index]))
            }
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last move")
                .accessibilityValue(Self.progressValue(mirror))
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the move")
                .accessibilityValue(Self.progressValue(mirror))
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue("Level \(mirror.levelNumber) now")
                .accessibilityIdentifier(port.identifier("next-level"))
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue("Camera")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// Selects point `index` (no move).
    private func select(_ index: Int) {
        send("point.select", [Double(index)])
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
