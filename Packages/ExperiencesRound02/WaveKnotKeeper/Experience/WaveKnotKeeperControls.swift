// WaveKnotKeeperControls — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-005; clarification Q5). The minimal
// control panel: a point picker (selects a control point, presentation only), six direction buttons that move the
// selected point one lattice step, undo, redo and next level, each with an accessibility label and value; every change
// is a kernel action sent through the action port. Dragging handles, orbit and gestures come in R02-G03-04; full
// accessibility in R02-G03-06.
#if os(iOS)
import SwiftUI
import VisualCoreExperienceHost
import WaveKnotKeeperCore

/// The control panel of Wave Knot Keeper.
struct WaveKnotKeeperControls: View {
    let port: ExperienceActionPort
    let mirror: WaveKnotKeeperMirror
    /// Feature 324: "Reset view" returns the camera to the authored view.
    var resetView: () -> Void = {}

    /// The button titles and spoken names of the six directions, in `WaveKnotKeeperDirection.allCases` order.
    static let titles: [String] = ["+x", "−x", "+y", "−y", "Over", "Under"]
    static let spoken: [String] = ["right", "left", "up", "down", "towards you (over)", "away from you (under)"]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                pointPicker
                directionRow
                playRow
            }
            .padding()
        }
    }

    /// The level, moves and signature lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · moves \(mirror.spent) of \(mirror.allowance)")
            .font(.headline)
        Text("Crossings \(mirror.crossings), writhe \(mirror.writhe) · target \(mirror.targetCrossings), \(mirror.targetWrithe)")
            .font(.subheadline)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The point picker: previous and next point.
    @ViewBuilder private var pointPicker: some View {
        if mirror.pointCount > 0 {
            Stepper("Point \(mirror.selected + 1) of \(mirror.pointCount)",
                    onIncrement: { select((mirror.selected + 1) % mirror.pointCount) },
                    onDecrement: { select((mirror.selected + mirror.pointCount - 1) % mirror.pointCount) })
                .accessibilityLabel("Selected point")
                .accessibilityValue("\(mirror.selected + 1) of \(mirror.pointCount)")
        }
    }

    /// One button per direction, moving the selected point one step.
    @ViewBuilder private var directionRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<WaveKnotKeeperDirection.allCases.count, id: \.self) { index in
                Button(Self.titles[index]) { send("point.move", [Double(mirror.selected), Double(index)]) }
                    .accessibilityLabel("Move the selected point \(Self.spoken[index])")
                    .accessibilityValue("Point \(mirror.selected + 1)")
            }
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last move")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the move")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
        }
    }

    /// Selects point `index` (no move).
    private func select(_ index: Int) {
        send("point.select", [Double(index)])
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : "That change was refused: \(result.code)"
    }
}
#endif
