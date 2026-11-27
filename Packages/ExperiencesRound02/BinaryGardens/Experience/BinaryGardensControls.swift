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
// is carried by colour alone. Full accessibility comes in a later feature of R02-G21. Modelled on
// `MushroomWeatherControls` (feature 493).
// Feature 504 (R02-G21-04) T-R02G2104-005 (FR-R02G2104-001, 013, 015): every kernel control sends through the
// presenter (so refusals are shown and logged with their code), every row is kept, and the panel gains direct choices
// that each send one action for the selected star: a Ring picker (ring 1 … n, `star.ring [star, index]`), a Luminosity
// picker (level 1 … L, `star.luminosity [star, index]`) and a Phase target stepper by the phase step g (presentation
// only) with "Set phase" (`star.phase [star, target]`); a Tilt picker (0 … T_max, `orbit.tilt [step]`, shown when
// T_max > 0); an "Inspect" picker (none, world 1 … W; presentation only) with the inspected world's words below it;
// and "Reset view" (the authored camera, presentation only). A choice of the current value sends nothing. A refused
// drag preview is named in words in the header. A star tapped on the canvas is selected here. Modelled on
// `MushroomWeatherControls` (feature 494).
// Feature 505 (R02-G21-05) T-R02G2105-005 (FR-R02G2105-001 … 005, 008; clarifications Q1 … Q5): a teaching block under
// the header — the tutorial instruction with "Dismiss tutorial" (`tutorial.dismiss`), "Hint" (each press shows the next
// of three levels through the presenter's `showHint()`; hints send nothing) with the hint text, the failure explanation
// (in place of the short failure words), and the level's band, goal and best stars — and a progress block after the
// view row: "Campaign" (`mode.campaign`), "Daily" (`mode.daily [year, month, day]` with today's local date from the
// presenter) and "Practice" (`mode.practice`), and a picker of the open levels (1 … the frontier, with their bands and
// stars) with "Play level" (`level.select [n]`). All wrapping text in the panel, never over the scene; refusals read in
// words. The existing rows, identifiers and the feature 504 gesture wiring are unchanged. Modelled on
// `MushroomWeatherControls` (feature 495).
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
    /// The presenter (feature 505): hints, the tutorial, the modes and the daily date; nil sends through `sendAction`.
    var presenter: BinaryGardensPresenter? = nil
    /// Sends a control with its values through the presenter (feature 504).
    let sendAction: (String, [Double]) -> Void
    /// Inspects a world, or clears the inspection with nil, through the presenter (feature 504).
    let inspect: (Int?) -> Void
    /// Returns the camera to the authored view (feature 504).
    let resetView: () -> Void

    /// The "Inspect" picker's tag for no world (feature 504).
    private static let noWorld = -1

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                starRow
                ringRow
                phaseRow
                luminosityRow
                tiltRow
                tickRow
                playRow
                choiceRows
                inspectRow
                viewRow
                progressRows
            }
            .padding()
        }
        .onChange(of: mirror.star) { _, _ in mirror.phaseTarget = mirror.phase }
    }

    /// The level, actions, status, failure (while no explanation replaces it) and refusal lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · \(mirror.actionsLeft) of \(mirror.budget) actions left")
            .font(.headline)
            .accessibilityIdentifier(port.identifier("actions"))
        Text(mirror.status).font(.subheadline)
            .accessibilityIdentifier(port.identifier("status"))
        if let failure = mirror.failureText, mirror.explanation == nil {
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
        if let refused = mirror.previewRefusalLabel {
            Text(refused).font(.footnote)
                .accessibilityIdentifier(port.identifier("preview-refusal"))
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

    /// The direct choices of the selected star and the tilt (feature 504): each choice of another value sends one
    /// action.
    @ViewBuilder private var choiceRows: some View {
        Picker("Ring", selection: ringChoice) {
            ForEach(0..<mirror.ringCount, id: \.self) { index in
                Text("Ring \(index + 1)").tag(index)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Ring of the star")
        .accessibilityValue("ring \(mirror.ring + 1) of \(mirror.ringCount)")
        .accessibilityIdentifier(port.identifier("ring-choice"))
        Picker("Luminosity", selection: luminosityChoice) {
            ForEach(0..<mirror.luminosityCount, id: \.self) { index in
                Text("Level \(index + 1)").tag(index)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Luminosity of the star")
        .accessibilityValue("level \(mirror.luminosity + 1) of \(mirror.luminosityCount)")
        .accessibilityIdentifier(port.identifier("luminosity-choice"))
        HStack(spacing: 16) {
            Stepper("Phase target \(mirror.gridPhaseTarget)",
                    onIncrement: { mirror.phaseTarget = mirror.phaseTarget(moved: 1) },
                    onDecrement: { mirror.phaseTarget = mirror.phaseTarget(moved: -1) })
                .accessibilityLabel("Phase target, in steps of \(mirror.phaseStep)")
                .accessibilityValue("phase \(mirror.gridPhaseTarget) of 47")
                .accessibilityIdentifier(port.identifier("phase-target"))
            Button("Set phase") { setPhase() }
                .accessibilityLabel("Shift the star to the phase target")
                .accessibilityValue(mirror.starLabel)
                .accessibilityIdentifier(port.identifier("set-phase"))
        }
        if mirror.maxTilt > 0 {
            Picker("Tilt", selection: tiltChoice) {
                ForEach(0...mirror.maxTilt, id: \.self) { step in
                    Text("Tilt \(step)").tag(step)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Tilt of the star orbits")
            .accessibilityValue(mirror.tiltLabel)
            .accessibilityIdentifier(port.identifier("tilt-choice"))
        }
    }

    /// Inspect a world (feature 504; presentation only), with its words below.
    @ViewBuilder private var inspectRow: some View {
        Picker("Inspect", selection: inspectChoice) {
            Text("None").tag(Self.noWorld)
            ForEach(0..<mirror.worldCount, id: \.self) { world in
                Text("World \(world + 1)").tag(world)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Inspect a world")
        .accessibilityValue(mirror.inspectedWorld.map { "world \($0 + 1)" } ?? "none")
        .accessibilityIdentifier(port.identifier("inspect"))
        if let words = mirror.inspectedLabel {
            Text(words).font(.footnote)
                .accessibilityIdentifier(port.identifier("inspect-detail"))
        }
    }

    /// The tutorial instruction with Dismiss tutorial, Hint with the hint text, the failure explanation, and the band,
    /// goal and best stars (feature 505).
    @ViewBuilder private var teaching: some View {
        if let tutorial = mirror.tutorialText {
            Text(tutorial).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("tutorial"))
            Button("Dismiss tutorial") { dismissTutorial() }
                .accessibilityLabel("Dismiss the tutorial")
                .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
        }
        Button("Hint") { presenter?.showHint() }
            .disabled(presenter == nil)
            .accessibilityLabel("Show a hint")
            .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            .accessibilityIdentifier(port.identifier("hint"))
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("hint-text"))
        }
        if let explanation = mirror.explanation {
            Text(explanation).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("failure"))
        }
        HStack(spacing: 12) {
            Text(mirror.bandLabel).font(.footnote)
                .accessibilityIdentifier(port.identifier("band"))
            Text(mirror.starsLabel).font(.footnote)
                .accessibilityIdentifier(port.identifier("stars"))
        }
        Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("goal"))
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 505).
    @ViewBuilder private var progressRows: some View {
        Text(mirror.modeLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("mode"))
        HStack(spacing: 12) {
            Button("Campaign") { campaign() }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(modeValue("campaign"))
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { daily() }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(modeValue("daily"))
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { practice() }
                .accessibilityLabel("Practise this level with more actions")
                .accessibilityValue(modeValue("practice"))
                .accessibilityIdentifier(port.identifier("practice"))
        }
        HStack(spacing: 12) {
            Stepper(mirror.levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityLabel("Level to play")
                .accessibilityValue(mirror.levelLabel(mirror.pickedLevel))
                .accessibilityIdentifier(port.identifier("level-picker"))
            Button("Play level") { selectLevel(mirror.pickedLevel) }
                .accessibilityLabel("Play the picked level")
                .accessibilityValue(mirror.levelLabel(mirror.pickedLevel))
                .accessibilityIdentifier(port.identifier("play-level"))
        }
    }

    /// "selected" when `name` is the current mode's name, else "not selected".
    private func modeValue(_ name: String) -> String {
        BinaryGardensMirror.modeName(mirror.mode) == name ? "selected" : "not selected"
    }

    /// Ends the tutorial of the level (`tutorial.dismiss`).
    private func dismissTutorial() {
        if let presenter { presenter.dismissTutorial(port: port) } else { send("tutorial.dismiss") }
    }

    /// Returns to the campaign (`mode.campaign`).
    private func campaign() {
        if let presenter { presenter.playCampaign(port: port) } else { send("mode.campaign") }
    }

    /// Plays today's daily level (`mode.daily` with the presenter's local calendar date).
    private func daily() {
        if let presenter {
            presenter.playDaily(port: port)
        } else {
            send("mode.daily", BinaryGardensPresenter.dateValues(BinaryGardensPresenter.today()))
        }
    }

    /// Replays the level with the practice budget (`mode.practice`).
    private func practice() {
        if let presenter { presenter.playPractice(port: port) } else { send("mode.practice") }
    }

    /// Plays open level `level` (`level.select [level]`).
    private func selectLevel(_ level: Int) {
        if let presenter { presenter.selectLevel(level, port: port) } else { send("level.select", [Double(level)]) }
    }

    /// Reset the view (feature 504; presentation only).
    @ViewBuilder private var viewRow: some View {
        HStack(spacing: 16) {
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// The Ring picker's selection: the selected star's ring; choosing another sends `star.ring [star, index]`.
    private var ringChoice: Binding<Int> {
        Binding(get: { mirror.ring }, set: { index in choose("star.ring", index, current: mirror.ring) })
    }

    /// The Luminosity picker's selection: the selected star's level; choosing another sends `star.luminosity [star,
    /// index]`.
    private var luminosityChoice: Binding<Int> {
        Binding(get: { mirror.luminosity },
                set: { index in choose("star.luminosity", index, current: mirror.luminosity) })
    }

    /// The Tilt picker's selection: the tilt; choosing another sends `orbit.tilt [step]`.
    private var tiltChoice: Binding<Int> {
        Binding(get: { mirror.tilt }, set: { step in chooseTilt(step) })
    }

    /// The Inspect picker's selection: the inspected world, or ``noWorld``.
    private var inspectChoice: Binding<Int> {
        Binding(get: { mirror.inspectedWorld ?? Self.noWorld }, set: { world in inspect(world < 0 ? nil : world) })
    }

    /// Sends `control [selected star, value]` when `value` differs from `current`.
    private func choose(_ control: String, _ value: Int, current: Int) {
        guard value != current else { return }
        send(control, [Double(mirror.selectedStar), Double(value)])
    }

    /// Sends `orbit.tilt [step]` when `step` differs from the tilt.
    private func chooseTilt(_ step: Int) {
        guard step != mirror.tilt else { return }
        send("orbit.tilt", [Double(step)])
    }

    /// Sends `star.phase [selected star, phase target]` (one action; the kernel refuses the unchanged phase).
    private func setPhase() {
        send("star.phase", [Double(mirror.selectedStar), Double(mirror.gridPhaseTarget)])
    }

    /// Shows tick `tick` read cyclically over 1 … 48.
    private func show(tick: Int) {
        send("clock.show", [Double(BinaryGardensMirror.wrappedTick(tick))])
    }

    /// Sends `control` through the presenter, which shows a refusal in words and logs its code.
    private func send(_ control: String, _ values: [Double] = []) {
        sendAction(control, values)
    }
}
#endif
