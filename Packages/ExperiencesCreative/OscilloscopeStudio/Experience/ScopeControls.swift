// ScopeControls — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-122, FR-A08-130). The native controls of
// Oscilloscope Studio in three sections:
//   Signal: the source picker (`source.picker`: Test signal / File / Microphone; the test signal and the microphone go
//     through the presenter's `pickSource(_:)`, which checks the permission first; File opens the system file
//     importer, audio types only, read in place), the status line (`source.status`), "Choose file…" (`source.file`),
//     the message (`source.message`) with "Use test signal" (`source.test-signal`) and the Settings link
//     (`settings`) when they apply, the waveform picker (`signal.waveform`: Sine, Square, Sweep) and the frequency
//     picker (`signal.frequency`: 100 Hz … 5 kHz; not shown for the sweep).
//   Display: the gain picker (`gain.select`: ×0.5 … ×10), the timebase picker (`timebase.select`: 0.1 … 5 ms per
//     division) and the trace status (`trace.status`: channels, trigger state, clipping).
//   Trigger: the level slider (`trigger.level`, −1…1 in steps of 0.05), the slope picker (`trigger.slope`: Rising,
//     Falling) and the mode picker (`trigger.mode`: Auto, Normal).
// Feature 062 (A08-P02) T-A08-206 (FR-A08-211): the Display section starts with the view picker (`display.select`,
//   label "View": Waveform, XY) and, while XY is chosen for a one-channel source, the mark "XY needs two channels"
//   (`display.status`); the chosen view stays XY, so a stereo source shows XY again without a new choice.
// Feature 063 (A08-P03) T-A08-303 (FR-A08-304, FR-A08-305): the view picker lists every `ScopeDisplay` case —
//   Waveform, XY, Spectrum; in the spectrum view the trace status reads the analysed channel, the peak readout (or the
//   reason none is shown) and the axes' marks. Levels are dBFS, relative to full scale.
// Feature 064 (A08-P04) T-A08-403 / T-A08-404 (FR-A08-401, FR-A08-402, FR-A08-410, FR-A08-412; contract api.md):
//   Measure: the Freeze toggle (`freeze.toggle`, through the presenter's `setFrozen(_:)`, which refuses an empty window
//     with "Nothing to freeze yet"), the Cursors toggle (`cursors.show`), and while the cursors are shown the sliders
//     `cursor.a`, `cursor.b` and `cursor.level` (waveform and the mono XY fallback) or `cursor.frequency` (spectrum)
//     with the readout (`cursor.readout`); the hint about pinching in the spectrum view (`display.hint`).
//   Presets: one row per preset (`preset.<index>`, built-ins first; a tap applies it through the presenter's
//     `apply(_:)` and selects it), the name field (`preset.name`), Save (`preset.save`), Rename (`preset.rename`) and
//     Delete (`preset.delete`) for the selected user preset, the store's message and the counts of unreadable and newer
//     files. Without storage only the built-ins are listed and the editing controls are hidden.
// Every control has an accessible label and value and an identifier from the port; hit areas are at least 44 points
// high and text wraps. Levels are relative to full scale only; nothing claims a calibrated measurement.
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import OscilloscopeStudioCore
import VisualCoreAudioDSP
import VisualCoreExperienceHost

/// The controls of Oscilloscope Studio.
struct ScopeControls: View {
    let port: ExperienceActionPort
    let presenter: ScopePresenter
    let mirror: ScopeMirror
    /// The preset store (nil without storage: only the built-ins are listed).
    let presets: ScopePresetStore?

    @State private var importing = false
    @State private var presetName = ""
    @State private var selectedPreset: UUID?

    /// The step of the trigger level slider.
    static let levelStep = 0.05
    /// The step of the cursor sliders.
    static let cursorStep = 0.005

    var body: some View {
        Group {
            if mirror.ready {
                content
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { presenter.chooseFile(url: url) }
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Signal") {
                sourcePicker
                Text(verbatim: mirror.sourceName)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Showing: \(mirror.sourceName)"))
                    .accessibilityIdentifier(port.identifier("source.status"))
                button(mirror.source == .file ? "Choose another file…" : "Choose file…", identifier: "source.file",
                       hint: "Shows an audio file you pick; it is read in place, not copied") {
                    importing = true
                }
                if let message = mirror.message {
                    Text(verbatim: message)
                        .font(.footnote).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(port.identifier("source.message"))
                    if mirror.offersTestSignal {
                        button("Use test signal", identifier: "source.test-signal",
                               hint: "Shows the built-in test signal, which needs no permission") {
                            presenter.useTestSignal()
                        }
                    }
                    if mirror.showsSettingsLink, let url = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: url) {
                            Text(verbatim: "Open Settings").font(.body).frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(Text(verbatim: "Open Settings"))
                        .accessibilityHint(Text(verbatim: "Opens VisualCore's settings to allow microphone access"))
                        .accessibilityIdentifier(port.identifier("settings"))
                    }
                }
                choicePicker("Waveform", identifier: "signal.waveform", selection: mirror.waveformIndex,
                             options: ScopeSettings.waveforms.map { ScopeSettings.displayName(of: $0) },
                             hint: "The shape of the test signal") { index in
                    _ = port.send("signal.waveform", [Double(index)])
                }
                if mirror.waveformIndex != ScopePresenter.sweepIndex {
                    choicePicker("Frequency", identifier: "signal.frequency", selection: mirror.frequencyIndex,
                                 options: ScopeSettings.frequencies.indices.map { ScopeSettings.frequencyName($0) },
                                 hint: "The frequency of the test signal") { index in
                        _ = port.send("signal.frequency", [Double(index)])
                    }
                }
            }
            section("Display") {
                choicePicker("View", identifier: "display.select", selection: mirror.display.rawValue,
                             options: ScopeDisplay.allCases.map { Self.viewName($0) },
                             hint: "Waveform draws each channel against time; XY plots the left channel against the right; "
                                + "Spectrum shows the left channel's levels against frequency, relative to full scale") { index in
                    _ = port.send("display.select", [Double(index)])
                }
                if let note = mirror.displayNote {
                    Text(verbatim: note)
                        .font(.footnote).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(verbatim: "\(note); showing the waveform"))
                        .accessibilityIdentifier(port.identifier("display.status"))
                }
                choicePicker("Gain", identifier: "gain.select", selection: mirror.gainIndex,
                             options: ScopeSettings.gains.indices.map { ScopeSettings.gainName($0) },
                             hint: "Scales the trace; values beyond full scale are clipped at the edge") { index in
                    _ = port.send("gain.select", [Double(index)])
                }
                choicePicker("Timebase", identifier: "timebase.select", selection: mirror.timebaseIndex,
                             options: ScopeSettings.timebasesMilliseconds.indices.map { ScopeSettings.timebaseName($0) },
                             hint: "The time of one of the ten divisions across the screen") { index in
                    _ = port.send("timebase.select", [Double(index)])
                }
                Text(verbatim: Self.sentence(mirror.status))
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("trace.status"))
            }
            section("Measure") {
                toggle("Freeze", identifier: "freeze.toggle", isOn: mirror.frozen,
                       hint: "Holds the shown trace with its sample rate and channels while the input keeps running") { on in
                    presenter.setFrozen(on)
                }
                toggle("Cursors", identifier: "cursors.show", isOn: mirror.cursorsShown,
                       hint: "Shows cursors to read time, frequency and level; drag them on the trace or use the sliders") { on in
                    _ = port.send("cursors.show", [on ? 1 : 0])
                }
                if mirror.cursorsShown {
                    if mirror.display == .spectrum {
                        cursorSlider("Frequency cursor", identifier: "cursor.frequency", value: mirror.frequencyCursor,
                                     range: ScopeState.positionRange, valueText: Self.percent(mirror.frequencyCursor),
                                     hint: "Moves the frequency cursor across the spectrum")
                    } else {
                        cursorSlider("Cursor A", identifier: "cursor.a", value: mirror.cursorA,
                                     range: ScopeState.positionRange, valueText: Self.percent(mirror.cursorA),
                                     hint: "Moves time cursor A across the window")
                        cursorSlider("Cursor B", identifier: "cursor.b", value: mirror.cursorB,
                                     range: ScopeState.positionRange, valueText: Self.percent(mirror.cursorB),
                                     hint: "Moves time cursor B across the window")
                        cursorSlider("Level cursor", identifier: "cursor.level", value: mirror.levelCursor,
                                     range: ScopeState.levelCursorRange,
                                     valueText: "\(ScopePresenter.levelWords(mirror.levelCursor)) of full scale",
                                     hint: "Moves the level line up and down, relative to full scale")
                    }
                    if let readout = mirror.cursorReadout {
                        Text(verbatim: readout)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(Text(verbatim: "Cursor readout: \(readout)"))
                            .accessibilityIdentifier(port.identifier("cursor.readout"))
                    }
                }
                if let hint = mirror.hint {
                    Text(verbatim: hint)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(port.identifier("display.hint"))
                }
            }
            section("Presets") {
                presetSection
            }
            section("Trigger") {
                levelSlider
                choicePicker("Slope", identifier: "trigger.slope", selection: mirror.slopeIndex,
                             options: ScopeSettings.slopes.map { ScopeSettings.displayName(of: $0) },
                             hint: "Starts the trace where the signal crosses the level in this direction") { index in
                    _ = port.send("trigger.slope", [Double(index)])
                }
                choicePicker("Mode", identifier: "trigger.mode", selection: mirror.modeIndex,
                             options: ScopeSettings.modes.map { ScopeSettings.displayName(of: $0) },
                             hint: "Auto runs freely without a crossing; Normal keeps the last triggered trace") { index in
                    _ = port.send("trigger.mode", [Double(index)])
                }
            }
        }
    }

    /// The segmented source picker: Test signal and Microphone go through the presenter's `pickSource(_:)`; File opens
    /// the system file importer first.
    private var sourcePicker: some View {
        Picker(selection: Binding(get: { mirror.source },
                                  set: { source in
                                      guard source != mirror.source else { return }
                                      if source == .file {
                                          importing = true
                                      } else {
                                          Task { _ = await presenter.pickSource(source) }
                                      }
                                  })) {
            ForEach(ScopeSource.allCases, id: \.rawValue) { source in
                Text(verbatim: source.displayName).tag(source)
            }
        } label: {
            Text(verbatim: "Source")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .disabled(mirror.isRequestingPermission)
        .accessibilityLabel(Text(verbatim: "Source"))
        .accessibilityValue(Text(verbatim: mirror.sourceName))
        .accessibilityHint(Text(verbatim: "The test signal needs no permission; the microphone is never recorded or sent; a file is read in place"))
        .accessibilityIdentifier(port.identifier("source.picker"))
    }

    /// The trigger level: −1…1 of full scale in steps of 0.05; each new value sends `trigger.level`.
    private var levelSlider: some View {
        let words = ScopePresenter.levelWords(mirror.triggerLevel)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Level: \(words) of full scale")
                .font(.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Slider(value: Binding(get: { mirror.triggerLevel },
                                  set: { value in
                                      let snapped = min(max((value / Self.levelStep).rounded() * Self.levelStep, -1), 1)
                                      guard snapped.isFinite, snapped != mirror.triggerLevel else { return }
                                      _ = port.send("trigger.level", [snapped])
                                  }),
                   in: ScopeSettings.triggerLevelRange, step: Self.levelStep) {
                Text(verbatim: "Trigger level")
            } minimumValueLabel: {
                Text(verbatim: "−1").font(.footnote)
            } maximumValueLabel: {
                Text(verbatim: "1").font(.footnote)
            }
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "Trigger level"))
            .accessibilityValue(Text(verbatim: "\(words) of full scale"))
            .accessibilityHint(Text(verbatim: "The level the signal crosses where the trace starts"))
            .accessibilityIdentifier(port.identifier("trigger.level"))
        }
    }

    /// The preset rows (built-ins first) and, with storage, the name field, Save, Rename, Delete, the store's message
    /// and the counts of files that could not be read.
    @ViewBuilder private var presetSection: some View {
        let entries = presets?.entries ?? ScopePreset.builtIns
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, preset in
            let selected = selectedPreset == preset.id
            Button {
                selectedPreset = preset.id
                presetName = preset.isBuiltIn ? presetName : preset.name
                presenter.apply(preset)
            } label: {
                HStack {
                    Text(verbatim: preset.name).font(.body).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Text(verbatim: preset.isBuiltIn ? "Built-in" : "Apply").font(.footnote)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(verbatim: "Apply preset \(preset.name)"))
            .accessibilityValue(Text(verbatim: (preset.isBuiltIn ? "built-in" : "saved") + (selected ? ", selected" : "")))
            .accessibilityHint(Text(verbatim: "Applies the preset's settings; the source, freeze and cursors stay"))
            .accessibilityIdentifier(port.identifier("preset.\(index)"))
        }
        if let presets {
            TextField(text: $presetName) { Text(verbatim: "Preset name") }
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Preset name"))
                .accessibilityHint(Text(verbatim: "1 to \(ScopePreset.nameLimit) characters"))
                .accessibilityIdentifier(port.identifier("preset.name"))
            button("Save preset", identifier: "preset.save",
                   hint: "Saves the current settings under this name; the source, freeze and cursors are not saved") {
                if let saved = presenter.savePreset(named: presetName) { selectedPreset = saved.id }
            }
            let user = selectedPreset.flatMap { id in presets.preset(id) }.flatMap { $0.isBuiltIn ? nil : $0 }
            button("Rename preset", identifier: "preset.rename", hint: "Gives the selected saved preset this name") {
                if let user { presenter.renamePreset(user.id, to: presetName) }
            }
            .disabled(user == nil)
            button("Delete preset", identifier: "preset.delete", hint: "Deletes the selected saved preset") {
                if let user, presenter.deletePreset(user.id) { selectedPreset = nil }
            }
            .disabled(user == nil)
            if let message = presets.lastMessage {
                Text(verbatim: message)
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("preset.message"))
            }
            if presets.unreadable > 0 || presets.newer > 0 {
                Text(verbatim: Self.skippedWords(unreadable: presets.unreadable, newer: presets.newer))
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("preset.skipped"))
            }
        }
    }

    /// The files left out of the list in words: "2 preset files can't be read; 1 was made by a newer version".
    static func skippedWords(unreadable: Int, newer: Int) -> String {
        var parts: [String] = []
        if unreadable > 0 { parts.append("\(unreadable) preset \(unreadable == 1 ? "file" : "files") can't be read") }
        if newer > 0 { parts.append("\(newer) \(newer == 1 ? "was" : "were") made by a newer version") }
        return parts.joined(separator: "; ")
    }

    /// A position as a whole percentage: "25 %".
    static func percent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded())) %"
    }

    /// A cursor slider over `range` in steps of 0.005; each new value sends the action `identifier`.
    private func cursorSlider(_ title: String, identifier: String, value: Double, range: ClosedRange<Double>,
                              valueText: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(title): \(valueText)")
                .font(.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Slider(value: Binding(get: { value },
                                  set: { new in
                                      let snapped = min(max((new / Self.cursorStep).rounded() * Self.cursorStep,
                                                            range.lowerBound), range.upperBound)
                                      guard snapped.isFinite, snapped != value else { return }
                                      _ = port.send(identifier, [snapped])
                                  }),
                   in: range, step: Self.cursorStep) {
                Text(verbatim: title)
            }
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityValue(Text(verbatim: valueText))
            .accessibilityHint(Text(verbatim: hint))
            .accessibilityIdentifier(port.identifier(identifier))
        }
    }

    /// A labelled toggle; a new value calls `send`.
    private func toggle(_ title: String, identifier: String, isOn: Bool, hint: String,
                        send: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: { on in if on != isOn { send(on) } })) {
            Text(verbatim: title).font(.body)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
    }

    /// The picker name of a view: "Waveform", "XY" or "Spectrum".
    static func viewName(_ display: ScopeDisplay) -> String {
        Self.sentence(display.displayName)
    }

    /// `status` with a capital first letter ("No samples yet" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "No samples yet" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// A menu picker over `options` whose selection is the index `selection`; a new index calls `send`.
    private func choicePicker(_ title: String, identifier: String, selection: Int, options: [String], hint: String,
                              send: @escaping (Int) -> Void) -> some View {
        Picker(selection: Binding(get: { selection },
                                  set: { index in if index != selection { send(index) } })) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, name in
                Text(verbatim: name).tag(index)
            }
        } label: {
            Text(verbatim: title)
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: options.indices.contains(selection) ? options[selection] : ""))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func button(_ title: String, identifier: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.body).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
    }
}
