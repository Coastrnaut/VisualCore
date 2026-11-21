// AuroraLoomControls — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-005; clarification Q5). The minimal control
// panel: one row per ribbon with a wave and a phase stepper (0 … 15) and undo and redo, each with an accessibility label;
// every change is a kernel move sent through the action port. Gestures, dials, anchors and the camera come in
// R02-G01-04; full accessibility in R02-G01-06. Feature 304 (R02-G01-04) T-R02G0104-004: a stepper selects its ribbon,
// "Reset view" returns the camera to the authored pose, the selection is announced and a refused move is shown.
// Feature 305 (R02-G01-05) T-R02G0105-005: the tutorial instruction with "Skip tutorial", the goal (allowance, best
// possible) and stars, a Hint button revealing the next hint level, the failure explanation with Undo and Retry, a
// picker of the open levels and the Daily, Practice and Campaign modes.
// Feature 306 (R02-G01-06) T-R02G0106-006: the panel scrolls, uses Dynamic Type text styles, wraps button rows that do
// not fit, keeps a 520-point readable width on iPad, labels every control with its value, routes every action through
// the presenter (refusals are announced and felt), steps with `adjust(ribbon:control:by:port:)` and has a Sound toggle;
// it reports appearing, disappearing and the scene phase for the ambient loop.
// Feature 309 (R02-G01-09) T-R02G0109-003 (FR-R02G0109-001, 008; spec Amendment): every control carries the identifier
// `experience.r02-g01.aurora-loom.<name>` (`port.identifier`); the steppers set pending steps (no move; the value shown
// is the pending step, the title adds the current one), and Apply commits each pending change as one move while Clear
// drops them; both are shown only while a step is pending.
#if os(iOS)
import AuroraLoomCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Aurora Loom.
struct AuroraLoomControls: View {
    let port: ExperienceActionPort
    let mirror: AuroraLoomMirror
    /// The presenter: every action goes through it so refusals are announced and felt (feature 306).
    let presenter: AuroraLoomPresenter
    @Environment(\.scenePhase) private var scenePhase

    /// The mode's name.
    private var modeName: String {
        switch mirror.mode {
        case .campaign: "Campaign"
        case .practice: "Practice"
        case .daily: "Daily"
        case .replay: "Replay"
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Level \(mirror.levelNumber) · band \(mirror.band) · \(modeName)")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Moves \(mirror.spent) of \(mirror.allowance) · best possible \(mirror.shortest)"
                     + (mirror.stars.map { " · \($0) of 3 stars" } ?? ""))
                    .font(.subheadline)
                if let instruction = mirror.instruction {
                    Text(instruction).font(.body)
                    Button("Skip tutorial") { presenter.send("tutorial.dismiss", port: port) }
                        .accessibilityLabel("Skip the tutorial")
                        .accessibilityIdentifier(port.identifier("skip-tutorial"))
                }
                Text("Ribbon \(mirror.selectedRibbon + 1) selected")
                    .font(.footnote)
                    .accessibilityLabel("Ribbon \(mirror.selectedRibbon + 1) selected")
                if let message = mirror.message {
                    Text(message).font(.footnote)
                }
                if let hint = mirror.hintText {
                    Text("Hint \(mirror.hintLevel) of 3: \(hint)")
                        .font(.body)
                        .accessibilityLabel("Hint \(mirror.hintLevel) of 3: \(hint)")
                }
                if let failure = mirror.failureText {
                    Text(failure).font(.body)
                    HStack(spacing: 16) {
                        Button("Undo") { presenter.send("play.undo", port: port) }
                            .accessibilityLabel("Undo the last move")
                            .accessibilityIdentifier(port.identifier("failure-undo"))
                        Button("Retry") { presenter.retry(port: port) }
                            .accessibilityLabel("Start this level again")
                            .accessibilityIdentifier(port.identifier("retry"))
                    }
                }
                if let steps = mirror.steps {
                    let shown = mirror.pending ?? steps
                    ForEach(0..<3, id: \.self) { ribbon in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ribbon \(ribbon + 1)").font(.subheadline)
                            Stepper(Self.title("Wave", shown.wave[ribbon], now: steps.wave[ribbon]),
                                    onIncrement: { presenter.stepPending(ribbon: ribbon, control: 0, by: 1) },
                                    onDecrement: { presenter.stepPending(ribbon: ribbon, control: 0, by: -1) })
                                .accessibilityLabel("Ribbon \(ribbon + 1) wave")
                                .accessibilityValue("\(shown.wave[ribbon])")
                                .accessibilityIdentifier(port.identifier("wave-\(ribbon + 1)"))
                            Stepper(Self.title("Phase", shown.phase[ribbon], now: steps.phase[ribbon]),
                                    onIncrement: { presenter.stepPending(ribbon: ribbon, control: 1, by: 1) },
                                    onDecrement: { presenter.stepPending(ribbon: ribbon, control: 1, by: -1) })
                                .accessibilityLabel("Ribbon \(ribbon + 1) phase")
                                .accessibilityValue("\(shown.phase[ribbon])")
                                .accessibilityIdentifier(port.identifier("phase-\(ribbon + 1)"))
                        }
                    }
                    if let pending = mirror.pending, pending != steps {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) { pendingButtons }
                            VStack(alignment: .leading, spacing: 8) { pendingButtons }
                        }
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { playButtons }
                    VStack(alignment: .leading, spacing: 8) { playButtons }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { modeButtons }
                    VStack(alignment: .leading, spacing: 8) { modeButtons }
                }
                if mirror.replaying || mirror.replayAvailable {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { replayButtons }
                        VStack(alignment: .leading, spacing: 8) { replayButtons }
                    }
                }
                Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) }))
                    .accessibilityLabel("Ambient sound")
                    .accessibilityValue(mirror.soundOn ? "On" : "Off")
                    .accessibilityIdentifier(port.identifier("sound"))
            }
            .padding()
            .frame(maxWidth: Self.maximumWidth, alignment: .leading)
        }
        .onAppear { presenter.controlsAppeared() }
        .onDisappear { presenter.controlsDisappeared() }
        .onChange(of: scenePhase) { _, phase in presenter.sceneActive(phase == .active) }
    }

    /// Replay of the level's stored winning moves (feature 307): Replay when one is stored; Step and Stop while
    /// replaying, with the position as the value.
    @ViewBuilder private var replayButtons: some View {
        if mirror.replaying {
            Button("Step") { presenter.stepReplay(port: port) }
                .accessibilityLabel("Play the next replay move")
                .accessibilityValue("Move \(mirror.replayPosition) of \(mirror.replayLength)")
                .accessibilityIdentifier(port.identifier("replay-step"))
            Button("Stop") { presenter.stopReplay(port: port) }
                .accessibilityLabel("Stop the replay")
                .accessibilityIdentifier(port.identifier("replay-stop"))
        } else {
            Button("Replay") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("\(mirror.replayLength) moves")
                .accessibilityIdentifier(port.identifier("replay"))
        }
    }

    /// A stepper's title: "Wave 15" when nothing is pending for it, "Wave 15 (now 3)" when the pending step differs.
    static func title(_ name: String, _ shown: Int, now current: Int) -> String {
        shown == current ? "\(name) \(shown)" : "\(name) \(shown) (now \(current))"
    }

    /// Apply (each pending change as one move) and Clear (drop the pending steps); feature 309.
    @ViewBuilder private var pendingButtons: some View {
        Button("Apply") { presenter.applyPending(port: port) }
            .accessibilityLabel("Apply the pending steps as moves")
            .accessibilityIdentifier(port.identifier("apply"))
        Button("Clear") { presenter.clearPending() }
            .accessibilityLabel("Clear the pending steps")
            .accessibilityIdentifier(port.identifier("clear"))
    }

    /// The panel's readable width on iPad (clarification Q5).
    static let maximumWidth: CGFloat = 520

    /// Undo, redo, next level, reset view and hint.
    @ViewBuilder private var playButtons: some View {
        Button("Undo") { presenter.send("play.undo", port: port) }
            .accessibilityLabel("Undo the last move")
            .accessibilityIdentifier(port.identifier("undo"))
        Button("Redo") { presenter.send("play.redo", port: port) }
            .accessibilityLabel("Redo the move")
            .accessibilityIdentifier(port.identifier("redo"))
        Button("Next level") { presenter.send("level.next", port: port) }
            .accessibilityLabel("Go to the next level")
            .accessibilityIdentifier(port.identifier("next-level"))
        Button("Reset view") { presenter.resetView() }
            .accessibilityLabel("Reset the camera view")
            .accessibilityIdentifier(port.identifier("reset-view"))
        Button("Hint") { presenter.showHint() }
            .disabled(mirror.stage != .playing)
            .accessibilityLabel("Show the next hint")
            .accessibilityIdentifier(port.identifier("hint"))
    }

    /// The level picker and the three modes.
    @ViewBuilder private var modeButtons: some View {
        Menu("Level") {
            ForEach(1...max(mirror.frontier, 1), id: \.self) { level in
                Button("Level \(level)") { presenter.send("level.select", [Double(level)], port: port) }
            }
        }
        .accessibilityLabel("Choose an open level")
        .accessibilityValue("Level \(mirror.levelNumber)")
        .accessibilityIdentifier(port.identifier("level-picker"))
        Button("Daily") { presenter.playDaily(port: port) }
            .accessibilityLabel("Play today's daily level")
            .accessibilityIdentifier(port.identifier("daily"))
        Button("Practice") { presenter.send("mode.practice", port: port) }
            .accessibilityLabel("Practice this level without a move limit")
            .accessibilityIdentifier(port.identifier("practice"))
        Button("Campaign") { presenter.send("mode.campaign", port: port) }
            .accessibilityLabel("Return to the campaign")
            .accessibilityIdentifier(port.identifier("campaign"))
    }
}
#endif
