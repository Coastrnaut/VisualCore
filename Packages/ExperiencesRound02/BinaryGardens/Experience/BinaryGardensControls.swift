// BinaryGardensControls — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-005, 010; clarification Q5). The
// minimal control panel: a labelled star picker (star 1 or star 2, the star the panel edits); ring − and + (`star.ring
// [star, index]`, the neighbouring ring, clamped to the level's rings: one action of the budget); phase − and + by the
// level's phase step g (`star.phase [star, step]`, read cyclically over 0 … 47, so always on the phase grid: one
// action); luminosity − and + (`star.luminosity [star, index]`, clamped to the level's levels: one action); tilt − and
// + (`orbit.tilt [step]`, clamped to 0 … T_max: one action); the shown tick (tick − and +, `clock.show [tick]` read
// cyclically over 1 … 48); running the light (`light.run`), undo, redo and next level (kernel actions through the
// action port), each with an accessibility label, value and identifier. The shown tick is presentation state of the
// adapter (a level opens at tick 48, the starting configuration). A change the kernel refuses (a locked ring, phase,
// luminosity or tilt, the unchanged value at an end of its range, a separation break, no action left) is still sent:
// the kernel refuses it and the panel says why. The header shows the actions left of the budget, the status (stage, or
// the failure in words), the progress description, the level in words, the tutorial on levels that have one, the
// failure in words and a refused action in words; the worlds at the shown tick are named in words, so no information
// is carried by colour alone. Dragging the stars, scrubbing the cycle and full accessibility come in later features
// of R02-G21. Modelled on `MushroomWeatherControls` (feature 493).
#if os(iOS)
import BinaryGardensCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Binary Gardens.
struct BinaryGardensControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows (and the panel's selection).
    @Bindable var mirror: BinaryGardensMirror

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                starRow
                ringRow
                phaseRow
                luminosityRow
                tiltRow
                tickRow
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

    /// Choose the star the panel edits.
    @ViewBuilder private var starRow: some View {
        Picker("Star", selection: $mirror.star) {
            Text("Star 1").tag(0)
            Text("Star 2").tag(1)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Star to adjust")
        .accessibilityValue("star \(mirror.selectedStar + 1)")
        .accessibilityIdentifier(port.identifier("star"))
        Text(mirror.starLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("star-detail"))
    }

    /// Move the selected star to the inner or outer neighbouring ring.
    @ViewBuilder private var ringRow: some View {
        HStack(spacing: 16) {
            Button("Ring −") { send("star.ring", [Double(mirror.selectedStar), Double(mirror.ring(moved: -1))]) }
                .accessibilityLabel("Move the star to the inner ring")
                .accessibilityValue(mirror.starLabel)
                .accessibilityIdentifier(port.identifier("ring-minus"))
            Text("ring \(mirror.ring + 1) of \(mirror.ringCount)")
                .accessibilityLabel("Ring")
                .accessibilityValue("ring \(mirror.ring + 1) of \(mirror.ringCount)")
                .accessibilityIdentifier(port.identifier("ring"))
            Button("Ring +") { send("star.ring", [Double(mirror.selectedStar), Double(mirror.ring(moved: 1))]) }
                .accessibilityLabel("Move the star to the outer ring")
                .accessibilityValue(mirror.starLabel)
                .accessibilityIdentifier(port.identifier("ring-plus"))
        }
    }

    /// Shift the selected star's phase by the level's phase step.
    @ViewBuilder private var phaseRow: some View {
        HStack(spacing: 16) {
            Button("Phase −") { send("star.phase", [Double(mirror.selectedStar), Double(mirror.phase(moved: -1))]) }
                .accessibilityLabel("Shift the star's phase back by \(mirror.phaseStep)")
                .accessibilityValue(mirror.starLabel)
                .accessibilityIdentifier(port.identifier("phase-minus"))
            Text("phase \(mirror.phase), step \(mirror.phaseStep)")
                .accessibilityLabel("Phase")
                .accessibilityValue("phase \(mirror.phase) of 47, step \(mirror.phaseStep)")
                .accessibilityIdentifier(port.identifier("phase"))
            Button("Phase +") { send("star.phase", [Double(mirror.selectedStar), Double(mirror.phase(moved: 1))]) }
                .accessibilityLabel("Shift the star's phase forward by \(mirror.phaseStep)")
                .accessibilityValue(mirror.starLabel)
                .accessibilityIdentifier(port.identifier("phase-plus"))
        }
    }

    /// Dim or brighten the selected star.
    @ViewBuilder private var luminosityRow: some View {
        HStack(spacing: 16) {
            Button("Luminosity −") {
                send("star.luminosity", [Double(mirror.selectedStar), Double(mirror.luminosity(moved: -1))])
            }
            .accessibilityLabel("Dim the star")
            .accessibilityValue(mirror.starLabel)
            .accessibilityIdentifier(port.identifier("luminosity-minus"))
            Text("level \(mirror.luminosity + 1) of \(mirror.luminosityCount)")
                .accessibilityLabel("Luminosity")
                .accessibilityValue("level \(mirror.luminosity + 1) of \(mirror.luminosityCount)")
                .accessibilityIdentifier(port.identifier("luminosity"))
            Button("Luminosity +") {
                send("star.luminosity", [Double(mirror.selectedStar), Double(mirror.luminosity(moved: 1))])
            }
            .accessibilityLabel("Brighten the star")
            .accessibilityValue(mirror.starLabel)
            .accessibilityIdentifier(port.identifier("luminosity-plus"))
        }
    }

    /// Tilt the orbit plane of the stars.
    @ViewBuilder private var tiltRow: some View {
        HStack(spacing: 16) {
            Button("Tilt −") { send("orbit.tilt", [Double(mirror.tilt(moved: -1))]) }
                .accessibilityLabel("Tilt the star orbits flatter")
                .accessibilityValue(mirror.tiltLabel)
                .accessibilityIdentifier(port.identifier("tilt-minus"))
            Text(mirror.tiltLabel)
                .accessibilityIdentifier(port.identifier("tilt"))
            Button("Tilt +") { send("orbit.tilt", [Double(mirror.tilt(moved: 1))]) }
                .accessibilityLabel("Tilt the star orbits steeper")
                .accessibilityValue(mirror.tiltLabel)
                .accessibilityIdentifier(port.identifier("tilt-plus"))
        }
    }

    /// Show an earlier or later tick of the cycle, and run the light.
    @ViewBuilder private var tickRow: some View {
        HStack(spacing: 16) {
            Button("Tick −") { show(tick: mirror.shownTick - 1) }
                .accessibilityLabel("Show the cycle one tick earlier")
                .accessibilityValue(mirror.tickLabel)
                .accessibilityIdentifier(port.identifier("tick-minus"))
            Text("tick \(mirror.shownTick)")
                .accessibilityIdentifier(port.identifier("tick"))
            Button("Tick +") { show(tick: mirror.shownTick + 1) }
                .accessibilityLabel("Show the cycle one tick later")
                .accessibilityValue(mirror.tickLabel)
                .accessibilityIdentifier(port.identifier("tick-plus"))
            Button("Run") { send("light.run") }
                .accessibilityLabel("Run the light and end the level")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("run"))
        }
        Text(mirror.tickLabel + ": " + mirror.worldsLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("tick-detail"))
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last ring, phase, luminosity, tilt or run")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the ring, phase, luminosity, tilt or run")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
    }

    /// Shows tick `tick` read cyclically over 1 … 48.
    private func show(tick: Int) {
        send("clock.show", [Double(BinaryGardensMirror.wrappedTick(tick))])
    }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(BinaryGardensMirror.refusalText(code: result.code))."
    }
}
#endif
