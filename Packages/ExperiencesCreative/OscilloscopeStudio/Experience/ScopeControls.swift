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

    @State private var importing = false

    /// The step of the trigger level slider.
    static let levelStep = 0.05

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
