// LissajousLabyrinthControls — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-005; clarification Q5). The minimal
// control panel: a stepper for each of the four dials (frequency A and B 1 … 9, phase A and C 0 … 15), undo, redo and
// next level, each with an accessibility label and value. Feature 314 (R02-G02-04) T-R02G0204-005 (FR-R02G0204-005,
// 006; clarification Q4): the steppers set pending values (no action; the value shown is the pending one, the title adds
// the current one) and select their dial; Apply sends each pending change as one action in the planner's order and Clear
// drops them, both shown only while something is pending; "Reset view" returns the camera to the authored view.
// Feature 315 (R02-G02-05) T-R02G0205-005 (FR-R02G0205-001 … 005): the tutorial instruction with Dismiss, a Hint button
// that reveals the next hint level, the failure explanation with Undo and Retry, the goal (actions allowed, best
// possible), the mode (Campaign, Daily, Practice) and a level picker of the open levels by band with their stars. Every
// text is plain panel text read by VoiceOver. Feature 316 (R02-G02-06) T-R02G0206-005 (FR-R02G0206-001, 005, 006;
// clarification Q5): every control carries a label and a value, button rows become columns at accessibility text sizes,
// the panel keeps a readable width of at most 520 points, a Sound toggle (off by default) drives the ambient loop, and
// the panel tells the presenter when it is on screen. Feature 319 (R02-G02-09) T-R02G0209-003 (FR-R02G0209-001;
// clarification Q1): every control carries the identifier `experience.r02-g02.lissajous-labyrinth.<name>`
// (`port.identifier`), the names listed in ``identifierNames``.
#if os(iOS)
import LissajousLabyrinthCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Lissajous Labyrinth.
struct LissajousLabyrinthControls: View {
    let port: ExperienceActionPort
    let mirror: LissajousLabyrinthMirror
    let presenter: LissajousLabyrinthPresenter
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The widest the panel's content grows (clarification Q5).
    static let readableWidth: CGFloat = 520

    /// A row of buttons that becomes a column at accessibility text sizes.
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 16) { content() }
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Level \(mirror.levelNumber) · actions \(mirror.spent) of \(mirror.allowance)")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.goal(mirror)).font(.subheadline)
                if let instruction = mirror.instruction {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(instruction).font(.callout)
                        Button("Dismiss") { presenter.dismissTutorial(port: port) }
                            .accessibilityLabel("Dismiss the tutorial")
                            .accessibilityValue("Tutorial shown")
                            .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
                    }
                }
                if let failure = mirror.failureText {
                    Text(failure).font(.callout)
                    row {
                        Button("Undo") { presenter.send("play.undo", port: port) }
                            .accessibilityLabel("Undo the last change")
                            .accessibilityValue(Self.progressValue(mirror))
                            .accessibilityIdentifier(port.identifier("failure-undo"))
                        Button("Retry") { presenter.retry(port: port) }
                            .accessibilityLabel("Retry the level")
                            .accessibilityValue(Self.modeName(mirror.mode))
                            .accessibilityIdentifier(port.identifier("retry"))
                    }
                }
                row {
                    Button("Hint") { presenter.showHint(port: port) }
                        .accessibilityLabel("Show a hint")
                        .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
                        .accessibilityIdentifier(port.identifier("hint"))
                    if let hint = mirror.hintText { Text(hint).font(.callout) }
                }
                if let message = mirror.message {
                    Text(message).font(.footnote)
                }
                if let dials = mirror.dials {
                    ForEach(0..<4, id: \.self) { index in
                        let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[index]
                        let current: Int = dials[dial]
                        let shown: Int = mirror.pending.values[dial] ?? current
                        Stepper(Self.title(dial, shown: shown, current: current),
                                onIncrement: { presenter.stepPending(dial, by: 1) },
                                onDecrement: { presenter.stepPending(dial, by: -1) })
                            .accessibilityLabel(LissajousLabyrinthPresenter.title(dial))
                            .accessibilityValue(shown == current ? "\(shown)" : "\(shown), pending; now \(current)")
                            .accessibilityIdentifier(port.identifier(Self.identifierName(dial)))
                    }
                    if !mirror.pending.isEmpty {
                        row {
                            Button("Apply") { presenter.applyPending(port: port) }
                                .accessibilityLabel("Apply the pending dial values")
                                .accessibilityValue("\(mirror.pending.values.count) pending")
                                .accessibilityIdentifier(port.identifier("apply"))
                            Button("Clear") { presenter.clearPending() }
                                .accessibilityLabel("Clear the pending dial values")
                                .accessibilityValue("\(mirror.pending.values.count) pending")
                                .accessibilityIdentifier(port.identifier("clear"))
                        }
                    }
                }
                row {
                    Button("Undo") { presenter.send("play.undo", port: port) }
                        .accessibilityLabel("Undo the last change")
                        .accessibilityValue(Self.progressValue(mirror))
                        .accessibilityIdentifier(port.identifier("undo"))
                    Button("Redo") { presenter.send("play.redo", port: port) }
                        .accessibilityLabel("Redo the change")
                        .accessibilityValue("Level \(mirror.levelNumber)")
                        .accessibilityIdentifier(port.identifier("redo"))
                    Button("Next level") { presenter.send("level.next", port: port) }
                        .accessibilityLabel("Go to the next level")
                        .accessibilityValue("Level \(mirror.levelNumber) now")
                        .accessibilityIdentifier(port.identifier("next-level"))
                    Button("Reset view") { presenter.resetView() }
                        .accessibilityLabel("Return the camera to the authored view")
                        .accessibilityValue("Camera")
                        .accessibilityIdentifier(port.identifier("reset-view"))
                }
                row {
                    Button("Campaign") { presenter.send("mode.campaign", port: port) }
                        .accessibilityLabel("Play the campaign")
                        .accessibilityValue(mirror.mode == .campaign ? "Selected" : "Not selected")
                        .accessibilityAddTraits(mirror.mode == .campaign ? .isSelected : [])
                        .accessibilityIdentifier(port.identifier("campaign"))
                    Button("Daily") { presenter.playDaily(port: port) }
                        .accessibilityLabel("Play today's daily level")
                        .accessibilityValue(Self.isDaily(mirror.mode) ? "Selected" : "Not selected")
                        .accessibilityAddTraits(Self.isDaily(mirror.mode) ? .isSelected : [])
                        .accessibilityIdentifier(port.identifier("daily"))
                    Button("Practice") { presenter.send("mode.practice", port: port) }
                        .accessibilityLabel("Practise this level with more actions")
                        .accessibilityValue(mirror.mode == .practice ? "Selected" : "Not selected")
                        .accessibilityAddTraits(mirror.mode == .practice ? .isSelected : [])
                        .accessibilityIdentifier(port.identifier("practice"))
                }
                if mirror.replaying {
                    Text("Replay: action \(mirror.replayPosition) of \(mirror.replayLength)").font(.callout)
                    row {
                        Button("Step") { presenter.stepReplay(port: port) }
                            .accessibilityLabel("Play the next action of the replay")
                            .accessibilityValue("Action \(mirror.replayPosition) of \(mirror.replayLength)")
                            .accessibilityIdentifier(port.identifier("replay-step"))
                        Button("Stop") { presenter.stopReplay(port: port) }
                            .accessibilityLabel("Stop the replay")
                            .accessibilityValue("\(mirror.replayLength) actions")
                            .accessibilityIdentifier(port.identifier("replay-stop"))
                    }
                } else if mirror.replayAvailable {
                    Button("Replay best solution") { presenter.startReplay(port: port) }
                        .accessibilityLabel("Replay your best solution of this level")
                        .accessibilityValue("Level \(mirror.levelNumber)")
                        .accessibilityIdentifier(port.identifier("replay"))
                }
                Menu("Levels") {
                    ForEach(0..<5, id: \.self) { band in
                        Section("Band \(band + 1)") {
                            ForEach((band * 20 + 1)...(band * 20 + 20), id: \.self) { level in
                                if level <= mirror.frontier {
                                    Button(Self.levelTitle(level, stars: mirror.stars[level])) {
                                        presenter.send("level.select", [Double(level)], port: port)
                                    }
                                }
                            }
                        }
                    }
                }
                .accessibilityLabel("Choose an open level")
                .accessibilityValue("Levels 1 to \(mirror.frontier) open")
                .accessibilityIdentifier(port.identifier("level-picker"))
                Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) }))
                    .accessibilityLabel("Ambient sound")
                    .accessibilityValue(mirror.soundOn ? "on" : "off")
                    .accessibilityIdentifier(port.identifier("sound"))
            }
            .padding()
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
        }
        .onAppear { presenter.controlsAppeared() }
        .onDisappear { presenter.controlsDisappeared() }
    }

    /// The identifier names of the panel's controls (feature 319, clarification Q1), each used once with the prefix
    /// `experience.r02-g02.lissajous-labyrinth.` through `port.identifier`.
    static let identifierNames: [String] = ["frequency-a", "frequency-b", "phase-a", "phase-c", "apply", "clear", "undo",
                                            "redo", "next-level", "reset-view", "hint", "dismiss-tutorial",
                                            "failure-undo", "retry", "campaign", "daily", "practice", "replay",
                                            "replay-step", "replay-stop", "level-picker", "sound"]

    /// The identifier name of `dial`'s stepper: "frequency-a", "frequency-b", "phase-a" or "phase-c".
    static func identifierName(_ dial: LissajousLabyrinthDial) -> String {
        identifierNames[LissajousLabyrinthDial.allCases.firstIndex(of: dial) ?? 0]
    }

    /// The goal line: actions allowed, the best possible and the mode.
    static func goal(_ mirror: LissajousLabyrinthMirror) -> String {
        let mode: String
        switch mirror.mode {
        case .campaign: mode = "Campaign"
        case .practice: mode = "Practice"
        case .daily: mode = "Daily level"
        case .replay: mode = "Replay"
        }
        return "\(mode) · goal: \(mirror.allowance) actions allowed, best possible \(mirror.shortest)"
    }

    /// The value of the undo buttons: the level and the actions spent.
    static func progressValue(_ mirror: LissajousLabyrinthMirror) -> String {
        "Level \(mirror.levelNumber), actions \(mirror.spent) of \(mirror.allowance)"
    }

    /// The mode's name: "Campaign", "Daily level" or "Practice".
    static func modeName(_ mode: LissajousLabyrinthMode) -> String {
        switch mode {
        case .campaign: "Campaign"
        case .practice: "Practice"
        case .daily: "Daily level"
        case .replay: "Replay"
        }
    }

    /// Whether `mode` is daily.
    static func isDaily(_ mode: LissajousLabyrinthMode) -> Bool {
        if case .daily = mode { return true }
        return false
    }

    /// A level picker entry: "Level 7 · 3 stars", or "Level 7" when unsolved.
    static func levelTitle(_ level: Int, stars: Int?) -> String {
        guard let stars else { return "Level \(level)" }
        return "Level \(level) · \(stars) \(stars == 1 ? "star" : "stars")"
    }

    /// A stepper's title: "Phase C 12" when nothing is pending for it, "Phase C 3 (now 12)" when the pending value
    /// differs.
    static func title(_ dial: LissajousLabyrinthDial, shown: Int, current: Int) -> String {
        let name = LissajousLabyrinthPresenter.title(dial)
        return shown == current ? "\(name) \(shown)" : "\(name) \(shown) (now \(current))"
    }
}
#endif
