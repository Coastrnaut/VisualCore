// GardenControls — feature 146 (A20-P02) T-A20-204 (FR-A20-205; clarification Q3). The native controls of Digital Zen
// Garden. Every control reads the presenter's mirror, sends through the action port, and has a spoken label, a hint
// and the identifier `experience.a20.digital-zen-garden.<name>` (`ExperienceActionPort.identifier`):
//
//   - `rake` segmented picker (Fine rake, Wide rake → `rake.style [0 / 1]`);
//   - `tone` menu (the three sand tones → `sand.tone [0…2]`);
//   - `undo` and `redo` buttons (→ `edit.undo []`, `edit.redo []`), each disabled when the history cannot go that way;
//   - four pattern buttons `pattern-rows`, `pattern-circle`, `pattern-wave` and `pattern-spiral`, each raking one
//     stroke of `StrokePatterns` with the chosen rake through `stroke.begin`, `stroke.add` and `stroke.end` — the
//     native alternative of every gesture action;
//   - `message`: the short sentence of a refused stroke (the garden is full), when there is one.
import DigitalZenGardenCore
import SwiftUI
import VisualCoreExperienceHost

/// The native controls of Digital Zen Garden (see the file header).
struct GardenControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: GardenMirror

    /// The rake titles, by index of `GardenPalette.rakes`.
    static var rakeTitles: [String] { GardenPalette.rakes.map(\.name) }
    /// The tone titles, by index of `GardenPalette.tones`.
    static var toneTitles: [String] { GardenPalette.tones.map(\.name) }

    /// The spoken label of the pattern button at `index`: "Rake rows", "Rake a circle", "Rake a wave", "Rake a
    /// spiral".
    static func patternLabel(_ index: Int) -> String {
        ["Rake rows", "Rake a circle", "Rake a wave", "Rake a spiral"][min(max(index, 0), 3)]
    }

    /// The controls.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Digital Zen Garden").font(.headline).accessibilityAddTraits(.isHeader)
            rakePicker
            toneMenu
            HStack(spacing: 12) {
                editButton("Undo", name: "undo", control: "edit.undo", enabled: mirror.canUndo,
                           hint: "Removes the last stroke or tone change")
                editButton("Redo", name: "redo", control: "edit.redo", enabled: mirror.canRedo,
                           hint: "Restores what was undone last")
            }
            patternButtons
            if let message = mirror.message {
                Text(verbatim: message).font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("message"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The rake picker (sends `rake.style` when the choice changes).
    private var rakePicker: some View {
        let titles = Self.rakeTitles
        let current = min(max(mirror.rakeStyle, 0), titles.count - 1)
        return Picker(selection: Binding(get: { current },
                                         set: { next in
                                             guard next != current else { return }
                                             port.send("rake.style", [Double(next)])
                                         })) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(verbatim: title).tag(index)
            }
        } label: {
            Text(verbatim: "Rake")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Rake, " + titles[current]))
        .accessibilityHint(Text(verbatim: "Chooses the rake of the next stroke"))
        .accessibilityIdentifier(port.identifier("rake"))
    }

    /// The tone menu (sends `sand.tone` when the choice changes).
    private var toneMenu: some View {
        let titles = Self.toneTitles
        let current = min(max(mirror.tone, 0), titles.count - 1)
        return HStack {
            Text(verbatim: "Sand").accessibilityHidden(true)
            Spacer(minLength: 8)
            Menu {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    Button(title) {
                        guard index != current else { return }
                        port.send("sand.tone", [Double(index)])
                    }
                }
            } label: {
                Text(verbatim: titles[current]).frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "Sand tone, " + titles[current]))
            .accessibilityHint(Text(verbatim: "Chooses the colour of the sand"))
            .accessibilityIdentifier(port.identifier("tone"))
        }
    }

    /// An undo or redo button sending `control`, disabled unless `enabled`.
    private func editButton(_ title: String, name: String, control: String, enabled: Bool,
                            hint: String) -> some View {
        Button {
            port.send(control)
        } label: {
            Text(verbatim: title).frame(minWidth: 44, minHeight: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// The four pattern buttons, each raking one stroke with the chosen rake.
    private var patternButtons: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Rake a pattern").font(.subheadline).accessibilityHidden(true)
            HStack(spacing: 8) {
                ForEach(Array(StrokePatterns.names.enumerated()), id: \.offset) { index, name in
                    Button {
                        StrokePatterns.send(StrokePatterns.points(index: index), rake: mirror.rakeStyle, port: port)
                    } label: {
                        Text(verbatim: StrokePatterns.titles[index]).frame(minHeight: 44)
                    }
                    .accessibilityLabel(Text(verbatim: Self.patternLabel(index)))
                    .accessibilityHint(Text(verbatim: "Rakes the pattern into the sand with the chosen rake"))
                    .accessibilityIdentifier(port.identifier("pattern-" + name))
                }
            }
        }
    }
}
