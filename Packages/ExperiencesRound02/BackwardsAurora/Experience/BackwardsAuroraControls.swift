// BackwardsAuroraControls — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-005; clarification Q5). The minimal
// control panel: labelled steppers for the section's start and end (presentation state only), reverse (the kernel
// action through the action port), undo, redo and next level, each with an accessibility label and value. Tapping
// segment ends, swiping to reverse and the timeline freeze preview come in R02-G10-04 (feature 394 adds "Reset view"
// and the preview line); full accessibility in R02-G10-06.
#if os(iOS)
import BackwardsAuroraCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Backwards Aurora.
struct BackwardsAuroraControls: View {
    let port: ExperienceActionPort
    let mirror: BackwardsAuroraMirror
    /// Returns the camera to the authored view (feature 394).
    let resetView: () -> Void
    /// Sends a control the way the presenter does (refusals shown and logged).
    let sender: (String, [Double]) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                sectionRow
                playRow
            }
            .padding()
        }
    }

    /// The level, reversals and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · reversals \(mirror.spent) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        Text(mirror.measureLabel).font(.footnote)
        Text(mirror.targetLabel).font(.footnote)
        if let preview = mirror.previewText {
            Text(preview).font(.footnote)
        }
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The start and end steppers and the reverse button.
    @ViewBuilder private var sectionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.startLabel,
                    onIncrement: { mirror.stepStart(1) },
                    onDecrement: { mirror.stepStart(-1) })
                .accessibilityLabel("Start of the section to reverse")
                .accessibilityValue(mirror.startLabel)
            Stepper(mirror.endLabel,
                    onIncrement: { mirror.stepEnd(1) },
                    onDecrement: { mirror.stepEnd(-1) })
                .accessibilityLabel("End of the section to reverse")
                .accessibilityValue(mirror.endLabel)
            Button("Reverse") { send("wave.reverse", [Double(mirror.start), Double(mirror.end)]) }
                .accessibilityLabel("Reverse the chosen section in time")
                .accessibilityValue(mirror.sectionLabel)
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last reversal")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the reversal")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
        }
    }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
