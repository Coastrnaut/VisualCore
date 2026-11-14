// OdysseyControls — feature 054 (A07-P01) T-A07-104 (FR-A07-121, FR-A07-122). The native controls of Audio Odyssey:
// the world picker (Tunnel, Landscape, Star corridor), the speed picker (Slow, Medium, Fast), Pause or Resume and New
// journey. Every button sends its action through the port; every control has a VoiceOver label and hint, an identifier
// from the port (`world.0…2`, `speed.0…2`, `flight.pause` / `flight.resume`, `journey.reseed`), a hit area of at least
// 44 by 44 points and text that wraps. Nothing animates and nothing claims any effect on comfort or well-being.
// Feature 055 (A07-P02) T-A07-205 (FR-A07-220, FR-A07-221): the sound source (Demo signal, Microphone, Choose file…
// through the system file importer, audio types only, read in place), the status line and a plain message with a link
// to Settings when microphone access is off, worded as Music Lab's. The demo button sends its action through the port;
// the microphone and file choices go through the presenter, which checks the permission or opens the file first.
// Identifiers `source.demo`, `source.microphone`, `source.file`, `source.status`, `source.message`, `settings`.
// Nothing claims to measure sound.
// Feature 056 (A07-P03) T-A07-303 (FR-A07-301–303, FR-A07-312): the speed slider (0.5…7 units per second in 0.5 steps,
// `speed.slider`, sends `speed.set`) above the kept presets (`speed.0…2`, selected only when the target equals the
// preset), the easing picker (Gentle, Standard, Brisk; `easing.0…2`), the calm-motion toggle (`comfort.calm`), and the
// mapping editor of the world shown: what the music moves (`mapping.primary.channel`, `mapping.primary.sensitivity`,
// `mapping.light.channel`, `mapping.light.sensitivity`, each a menu picker sending `mapping.set`) and "Reset all
// mappings" (`mapping.reset`). Every control has an accessible label, value or hint.
// Feature 057 (A07-P04) T-A07-403 (FR-A07-401, FR-A07-403, FR-A07-410, FR-A07-430): the controls are grouped in four
// sections. Journey: the world picker, Pause or Resume, New journey. Sound: the segmented picker (`source.picker`, Demo /
// Microphone / File, through the presenter's `pickSource(_:)` or the file importer), the status line (`source.status`:
// "Demo signal", "Microphone" or the file's name), "Choose file…" (`source.file`), the permission message and Settings
// link, then the mapping editor. Comfort: the speed slider and presets, the easing, calm motion. Journeys: one row per
// journey (`preset.0…`, built-ins first; a tap applies it with `preset.apply`), and with storage the name field
// (`preset.name`), Save (`preset.save`), Rename (`preset.rename`) and Delete (`preset.delete`, confirmed) for the
// selected user journey, the store's message (`preset.message`) and the counts of unreadable (`preset.unreadable`) and
// newer (`preset.newer`) files when above zero.
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioOdysseyCore
import VisualCoreExperienceHost

/// The controls of Audio Odyssey.
struct OdysseyControls: View {
    let port: ExperienceActionPort
    let presenter: OdysseyPresenter
    let mirror: OdysseyMirror

    @State private var importing = false
    @State private var presetName = ""
    @State private var deleting = false

    var body: some View {
        Group {
            if let world = mirror.world {
                content(world: world)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { presenter.chooseFile(url: url) }
        }
    }

    @ViewBuilder private func content(world: JourneyWorld) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Journey") {
                ForEach(JourneyWorld.allCases, id: \.rawValue) { option in
                    choice(option.displayName, selected: world == option, identifier: "world.\(option.rawValue)",
                           hint: "Flies through the \(option.displayName.lowercased()) from the same place") {
                        if world != option { _ = port.send("world.select", [Double(option.rawValue)]) }
                    }
                }
                if mirror.paused {
                    button("Resume", identifier: "flight.resume", hint: "Continues the flight from where it stopped") {
                        _ = port.send("flight.resume")
                    }
                } else {
                    button("Pause", identifier: "flight.pause", hint: "Eases the flight to a stop") {
                        _ = port.send("flight.pause")
                    }
                }
                button("New journey", identifier: "journey.reseed", hint: "Builds a new path and new surroundings") {
                    _ = port.send("journey.reseed")
                }
            }
            section("Sound") {
                soundPicker
                Text(verbatim: mirror.sourceName)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Playing: \(mirror.sourceName)"))
                    .accessibilityIdentifier(port.identifier("source.status"))
                button(mirror.source == .file ? "Choose another file…" : "Choose file…", identifier: "source.file",
                       hint: "The journey follows an audio file you pick; it is read in place, not copied") {
                    importing = true
                }
                if let message = mirror.message {
                    Text(verbatim: message)
                        .font(.footnote).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(port.identifier("source.message"))
                    if mirror.showsSettingsLink, let url = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: url) {
                            Text(verbatim: "Open Settings").font(.body).frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(Text(verbatim: "Open Settings"))
                        .accessibilityHint(Text(verbatim: "Opens VisualCore's settings to allow microphone access"))
                        .accessibilityIdentifier(port.identifier("settings"))
                    }
                }
                Text(verbatim: "What the music moves").font(.subheadline).accessibilityAddTraits(.isHeader)
                mappingEditor(world: world)
            }
            section("Comfort") {
                speedSlider
                ForEach(SpeedChoice.allCases, id: \.rawValue) { option in
                    let selected = mirror.speedTarget == option.unitsPerSecond
                    choice("\(option.displayName) (\(OdysseyPresenter.speedWords(option.unitsPerSecond)))",
                           selected: selected, identifier: "speed.\(option.rawValue)",
                           hint: "Eases the flight to \(option.displayName.lowercased()) speed") {
                        if !selected { _ = port.send("speed.select", [Double(option.rawValue)]) }
                    }
                }
                Text(verbatim: "Flight easing").font(.subheadline).accessibilityAddTraits(.isHeader)
                ForEach(Easing.allCases, id: \.rawValue) { option in
                    choice(option.displayName, selected: mirror.easing == option, identifier: "easing.\(option.rawValue)",
                           hint: Self.easingHint(option)) {
                        if mirror.easing != option { _ = port.send("easing.select", [Double(option.rawValue)]) }
                    }
                }
                Toggle(isOn: Binding(get: { mirror.calmMotion },
                                     set: { on in if on != mirror.calmMotion { _ = port.send("comfort.calm", [on ? 1 : 0]) } })) {
                    Text(verbatim: "Calm motion").font(.body).fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Calm motion"))
                .accessibilityHint(Text(verbatim: "Flies at most 2.5 units per second, without sideways sway"))
                .accessibilityIdentifier(port.identifier("comfort.calm"))
            }
            section("Journeys") {
                journeys
            }
        }
    }

    /// The segmented sound picker (feature 057): Demo, Microphone, File. Demo and Microphone go through the
    /// presenter's `pickSource(_:)`; File opens the system file importer first.
    private var soundPicker: some View {
        Picker(selection: Binding(get: { mirror.source },
                                  set: { source in
                                      guard source != mirror.source else { return }
                                      if source == .file {
                                          importing = true
                                      } else {
                                          Task { _ = await presenter.pickSource(source) }
                                      }
                                  })) {
            ForEach(SourceKind.allCases, id: \.rawValue) { source in
                Text(verbatim: Self.pickerName(source)).tag(source)
            }
        } label: {
            Text(verbatim: "Sound source")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .disabled(mirror.isRequestingPermission)
        .accessibilityLabel(Text(verbatim: "Sound source"))
        .accessibilityValue(Text(verbatim: mirror.sourceName))
        .accessibilityHint(Text(verbatim: "Demo needs no permission; the microphone is never recorded or sent; a file is read in place"))
        .accessibilityIdentifier(port.identifier("source.picker"))
    }

    /// The journeys (feature 057): one row per journey (`preset.0…`, a tap applies it), then, with storage, the name
    /// field, Save, Rename and Delete for the selected user journey, the store's message and the counts of files that
    /// could not be read or are newer.
    @ViewBuilder private var journeys: some View {
        let entries = presenter.presetEntries
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, preset in
            choice(preset.isBuiltIn ? "\(preset.name) (built in)" : preset.name,
                   selected: mirror.selectedPresetID == preset.id, identifier: "preset.\(index)",
                   hint: "Changes to the \(preset.world.displayName.lowercased()) at "
                       + "\(OdysseyPresenter.speedWords(preset.speedTarget)) with this journey's mapping; the flight eases there") {
                _ = presenter.apply(preset)
            }
        }
        if let store = presenter.presets {
            TextField("Journey name", text: $presetName)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Journey name"))
                .accessibilityIdentifier(port.identifier("preset.name"))
            button("Save journey", identifier: "preset.save",
                   hint: "Saves the world, mappings, speed, easing and calm motion under this name") {
                if presenter.saveCurrentPreset(named: presetName) != nil { presetName = "" }
            }
            if let selected = presenter.selectedUserPreset {
                button("Rename \(selected.name)", identifier: "preset.rename",
                       hint: "Gives the selected journey the name in the field") {
                    if presenter.renameSelectedPreset(to: presetName) { presetName = "" }
                }
                button("Delete \(selected.name)", identifier: "preset.delete", hint: "Deletes the selected journey") {
                    deleting = true
                }
                .confirmationDialog("Delete journey?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { _ = presenter.deleteSelectedPreset() }
                    Button("Cancel", role: .cancel) {}
                }
            }
            if let message = store.lastMessage {
                Text(verbatim: message)
                    .font(.footnote).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("preset.message"))
            }
            if store.unreadable > 0 {
                Text(verbatim: Self.countText(store.unreadable, one: "journey file can't be read",
                                              many: "journey files can't be read"))
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("preset.unreadable"))
            }
            if store.newer > 0 {
                Text(verbatim: Self.countText(store.newer, one: "journey was saved by a newer version",
                                              many: "journeys were saved by a newer version"))
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("preset.newer"))
            }
        }
    }

    /// "1 journey file can't be read", "3 journey files can't be read".
    static func countText(_ count: Int, one: String, many: String) -> String {
        "\(count) " + (count == 1 ? one : many)
    }

    /// The short name of a source in the segmented picker: Demo, Microphone, File.
    static func pickerName(_ source: SourceKind) -> String {
        switch source {
        case .demo: "Demo"
        case .microphone: "Microphone"
        case .file: "File"
        }
    }

    /// The continuous speed: 0.5…7 units per second in steps of 0.5; each new value sends `speed.set`.
    private var speedSlider: some View {
        let range = JourneyState.speedTargetRange
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Speed: \(OdysseyPresenter.speedWords(mirror.speedTarget))")
                .font(.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Slider(value: Binding(get: { mirror.speedTarget },
                                  set: { value in
                                      guard let snapped = JourneyState.snappedSpeedTarget(value),
                                            snapped != mirror.speedTarget else { return }
                                      _ = port.send("speed.set", [snapped])
                                  }),
                   in: range, step: JourneyState.speedTargetStep) {
                Text(verbatim: "Speed")
            } minimumValueLabel: {
                Text(verbatim: "0.5").font(.footnote)
            } maximumValueLabel: {
                Text(verbatim: "7").font(.footnote)
            }
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "Speed"))
            .accessibilityValue(Text(verbatim: OdysseyPresenter.speedWords(mirror.speedTarget)))
            .accessibilityHint(Text(verbatim: "The flight eases to the chosen speed"))
            .accessibilityIdentifier(port.identifier("speed.slider"))
        }
    }

    /// The mapping editor of `world`: channel and sensitivity of the primary response and of the light, and the reset.
    @ViewBuilder private func mappingEditor(world: JourneyWorld) -> some View {
        let mapping = mirror.mapping
        Text(verbatim: "In the \(world.displayName.lowercased()), changes apply at once.")
            .font(.footnote).fixedSize(horizontal: false, vertical: true)
        mappingRow(Self.primaryName(world), target: 0, key: "primary", source: mapping.primary)
        mappingRow("Light", target: 1, key: "light", source: mapping.light)
        button("Reset all mappings", identifier: "mapping.reset",
               hint: "Returns every world to its default mapping") {
            _ = port.send("mapping.reset")
        }
    }

    /// One response's pickers: its channel and its sensitivity; a change sends `mapping.set [target, channel,
    /// sensitivity]` for the world shown.
    private func mappingRow(_ title: String, target: Double, key: String, source: ChannelMapping) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Picker(selection: Binding(get: { source.channel },
                                      set: { channel in
                                          guard channel != source.channel else { return }
                                          _ = port.send("mapping.set", [target, Double(channel.rawValue),
                                                                        Double(source.sensitivity.rawValue)])
                                      })) {
                ForEach(EnvelopeChannel.allCases, id: \.rawValue) { channel in
                    Text(verbatim: channel.displayName).tag(channel)
                }
            } label: {
                Text(verbatim: "\(title) follows")
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "\(title) follows"))
            .accessibilityValue(Text(verbatim: source.channel.displayName))
            .accessibilityIdentifier(port.identifier("mapping.\(key).channel"))
            Picker(selection: Binding(get: { source.sensitivity },
                                      set: { sensitivity in
                                          guard sensitivity != source.sensitivity else { return }
                                          _ = port.send("mapping.set", [target, Double(source.channel.rawValue),
                                                                        Double(sensitivity.rawValue)])
                                      })) {
                ForEach(Sensitivity.allCases, id: \.rawValue) { sensitivity in
                    Text(verbatim: sensitivity.displayName).tag(sensitivity)
                }
            } label: {
                Text(verbatim: "\(title) sensitivity")
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "\(title) sensitivity"))
            .accessibilityValue(Text(verbatim: source.sensitivity.displayName))
            .accessibilityIdentifier(port.identifier("mapping.\(key).sensitivity"))
        }
    }

    /// The name of `world`'s primary response: tunnel width, landscape height, star sparkle.
    static func primaryName(_ world: JourneyWorld) -> String {
        switch world {
        case .tunnel: "Tunnel width"
        case .landscape: "Landscape height"
        case .starCorridor: "Star sparkle"
        }
    }

    /// The VoiceOver hint of an easing choice.
    static func easingHint(_ easing: Easing) -> String {
        switch easing {
        case .gentle: "Speed changes take about three times as long as brisk"
        case .standard: "Speed changes take about one and a half times as long as brisk"
        case .brisk: "Speed changes as quickly as the comfort limits allow"
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choice(_ title: String, selected: Bool, identifier: String, hint: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title).font(.body).multilineTextAlignment(.leading)
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(port.identifier(identifier))
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
