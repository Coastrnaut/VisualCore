// BackwardsAuroraControls — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-005; clarification Q5). The minimal
// control panel: labelled steppers for the section's start and end (presentation state only), reverse (the kernel
// action through the action port), undo, redo and next level, each with an accessibility label and value. Tapping
// segment ends, swiping to reverse and the timeline freeze preview come in R02-G10-04 (feature 394 adds "Reset view"
// and the preview line); full accessibility in R02-G10-06. Feature 395 (R02-G10-05) T-R02G1005-005: the tutorial
// instruction with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the
// goal with the level's band and best stars, Campaign / Daily / Practice and a picker of the open levels; all as
// wrapping text in the panel, never over the aurora. Feature 396 (R02-G10-06) T-R02G1006-005 (FR-R02G1006-001, 005,
// 006; clarification Q5): the summary element ("Aurora"), adjustable start and end steppers whose values name the
// sample and its height, a value in words on every control (feature 386's convergence lesson), refusals in words, the
// Sound toggle (off by default), rows that become columns at accessibility text sizes, wrapping text and a 520-point
// readable width. Feature 397 (R02-G10-07) T-R02G1007-005 (clarifications Q2, Q4, Q5): "Replay best solution" for a
// level with a verified stored solution, and during replay its position ("Replay: reversal k of n") with Step and Stop,
// each with a label and a value; the Sound toggle saves the choice through `settings.sound`.
#if os(iOS)
import BackwardsAuroraCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Backwards Aurora.
struct BackwardsAuroraControls: View {
    let port: ExperienceActionPort
    let mirror: BackwardsAuroraMirror
    /// The presenter (feature 395): hints, retry, undo and the daily level.
    let presenter: BackwardsAuroraPresenter
    /// Returns the camera to the authored view (feature 394).
    let resetView: () -> Void
    /// Sends a control the way the presenter does (refusals shown and logged).
    let sender: (String, [Double]) -> Void
    /// The text size: rows become columns at accessibility sizes (feature 396).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the ambient loop plays only while it is.
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 396).
    static let readableWidth: CGFloat = 520

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                sectionRow
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 396).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 397).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Play the next reversal of the replay")
                    .accessibilityValue("Reversal \(mirror.replayPosition) of \(mirror.replayLength)")
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue("\(mirror.replayLength) reversals")
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
        }
    }

    /// The replay position line: "Replay: reversal k of n" (feature 397).
    static func replayPositionText(_ mirror: BackwardsAuroraMirror) -> String {
        "Replay: reversal \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// The Sound toggle (feature 396; off by default; saved through `settings.sound` since feature 397).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityLabel("Ambient sound")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
    }

    /// The level, reversals and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · reversals \(mirror.spent) of \(mirror.budget)")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Aurora")
            .accessibilityValue(mirror.summary)
        Text(mirror.measureLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let preview = mirror.previewText {
            Text(preview).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The start and end steppers and the reverse button.
    @ViewBuilder private var sectionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Feature 396: adjustable (swipe up or down); the value names the sample and its height.
            Stepper(mirror.startLabel,
                    onIncrement: { mirror.stepStart(1); presenter.refreshSummary() },
                    onDecrement: { mirror.stepStart(-1); presenter.refreshSummary() })
                .accessibilityLabel("Start of the section to reverse")
                .accessibilityValue(Self.values(mirror).start)
            Stepper(mirror.endLabel,
                    onIncrement: { mirror.stepEnd(1); presenter.refreshSummary() },
                    onDecrement: { mirror.stepEnd(-1); presenter.refreshSummary() })
                .accessibilityLabel("End of the section to reverse")
                .accessibilityValue(Self.values(mirror).end)
            Button("Reverse") { send("wave.reverse", [Double(mirror.start), Double(mirror.end)]) }
                .accessibilityLabel("Reverse the chosen section in time")
                .accessibilityValue(mirror.sectionLabel)
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last reversal")
                .accessibilityValue(Self.values(mirror).reversals)
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the reversal")
                .accessibilityValue(Self.values(mirror).reversals)
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue(Self.values(mirror).nextLevel)
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue(Self.viewValue(presenter.gestures.orbit == .authored))
        }
    }

    /// The tutorial instruction, the hint, the goal and the failure explanation (feature 395).
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
            Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                row {
                    Button("Undo") { presenter.undoReversal(port: port) }
                        .accessibilityLabel("Undo the last reversal")
                        .accessibilityValue(Self.values(mirror).reversals)
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                        .accessibilityValue(Self.values(mirror).retry)
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 395).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with a larger reversal budget")
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

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band = BackwardsAuroraProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily, practice or replay.
    static func modeName(_ mode: BackwardsAuroraMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// The accessibility values in words of the controls that act on the section or the play (feature 396, after
    /// feature 386's convergence lesson): every native control carries a value.
    struct Values: Equatable {
        /// Start: the start sample and its height.
        let start: String
        /// End: the end sample and its height.
        let end: String
        /// Undo and redo: the reversals spent of the budget.
        let reversals: String
        /// Next level: the next open level, or that none is open.
        let nextLevel: String
        /// Retry: the level and the mode.
        let retry: String
        /// Play level: the picked level.
        let playLevel: String
    }

    /// The button values of `mirror` (see ``Values``).
    static func values(_ mirror: BackwardsAuroraMirror) -> Values {
        let samples: [Int] = mirror.play?.wave.samples ?? []
        func sample(_ k: Int) -> String {
            samples.indices.contains(k) ? "sample \(k), height \(samples[k])" : "sample \(k)"
        }
        let next: String = mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
            : "no further level open"
        return Values(start: sample(mirror.start), end: sample(mirror.end),
                      reversals: "\(mirror.spent) of \(mirror.budget) reversals spent",
                      nextLevel: next,
                      retry: "level \(mirror.levelNumber), " + modeName(mirror.mode),
                      playLevel: "level \(mirror.pickedLevel)")
    }

    /// The Reset view value: "authored view" or "orbited view".
    static func viewValue(_ authored: Bool) -> String { authored ? "authored view" : "orbited view" }

    /// A mode button's value: "selected" or "not selected".
    static func selectedValue(_ selected: Bool) -> String { selected ? "selected" : "not selected" }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
