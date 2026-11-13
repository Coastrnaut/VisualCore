// GenerativeArtControls — feature 193 (UA-F07) T-U07-009 (FR-U07-002, FR-U07-020, FR-U07-022; rule E-12). The native
// controls of Generative Art Studio inside the one app: the families of the gallery, time, presets, palettes, seed,
// parameters, the library and export. Every change is an action through the port; the view reads the state from
// the presenter's mirror. Every control has a VoiceOver label, a hit area of at least 44 by 44 points and text that
// wraps at the largest sizes.
import CoreTransferable
import GenerativeArtStudioCore
import SwiftUI
import UniformTypeIdentifiers
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters
import VisualCoreRendering
import VisualCoreSimulation

/// A PNG made by export, offered to the system's share interface without a file of the app's own.
struct ExportedImage: Transferable {
    /// The PNG data.
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}

/// The controls of Generative Art Studio.
struct GenerativeArtControls: View {
    let port: ExperienceActionPort
    let mirror: GenerativeArtMirror
    let library: GenerativeArtLibrary
    let experienceID: ExperienceID
    let reduceMotion: Bool

    /// The edge of an exported square image in pixels.
    static let exportEdge = 2048

    @Environment(\.experienceStillRenderer) private var still
    @State private var saveName = ""
    @State private var renaming: GenerativeArtEntry?
    @State private var newName = ""
    @State private var removing: GenerativeArtEntry?
    @State private var exported: ExportedImage?
    @State private var exportError: String?
    @State private var motionApplied = false

    var body: some View {
        Group {
            if let core = mirror.core {
                content(core)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
        .task {
            // Reduce Motion: half speed once per open, as the standalone app's clock (adapter difference 2). The
            // controls can appear before the experience is active, when the action is refused, so it is retried for at
            // most 5 s.
            guard reduceMotion, !motionApplied else { return }
            for _ in 0..<50 {
                if let rate = mirror.core?.rate, rate != 1 { motionApplied = true; return }
                if mirror.core != nil, port.send("rate", [SceneClock.reducedMotionFactor]).isAccepted {
                    motionApplied = true
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    // MARK: Sections

    @ViewBuilder private func content(_ core: GenerativeArtCore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            familySection(core)
            timeSection(core)
            presetSection(core)
            paletteSection(core)
            seedSection(core)
            parameterSection(core)
            librarySection(core)
            exportSection()
        }
        // `presenting:` hands the entry to the actions: the binding is cleared when the alert closes, which can be
        // before an action reads it.
        .alert(Text(verbatim: "Rename"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
               presenting: renaming) { entry in
            TextField(text: $newName) { Text(verbatim: "Name") }
                .accessibilityIdentifier(port.identifier("library.rename.name"))
            Button { library.rename(entry.id, to: newName) } label: { Text(verbatim: "Rename") }
                .accessibilityIdentifier(port.identifier("library.rename.confirm"))
            Button(role: .cancel) {} label: { Text(verbatim: "Cancel") }
        }
        .confirmationDialog(Text(verbatim: "Remove this composition?"),
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            presenting: removing) { entry in
            Button(role: .destructive) { library.remove(entry.id) } label: { Text(verbatim: "Remove") }
                .accessibilityIdentifier(port.identifier("library.remove.confirm"))
        }
    }

    private func familySection(_ core: GenerativeArtCore) -> some View {
        section("Scene") {
            ForEach(Array(FamilyCatalog.all.enumerated()), id: \.offset) { index, family in
                choice(family.title, symbol: family.symbol, selected: core.family.id == family.id,
                       identifier: "family." + family.id.rawValue, hint: family.summary) {
                    port.send("family", [Double(index)])
                }
            }
        }
    }

    private func timeSection(_ core: GenerativeArtCore) -> some View {
        section("Time") {
            HStack(spacing: 12) {
                Button { port.send(core.playing ? "pause" : "play") } label: {
                    Image(systemName: core.playing ? "pause.fill" : "play.fill")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(verbatim: core.playing ? "Pause" : "Play"))
                .accessibilityIdentifier(port.identifier("time.playPause"))
                Spacer()
                Text(verbatim: String(format: "%.1f s", core.time))
                    .font(.subheadline.monospacedDigit())
                    .accessibilityIdentifier(port.identifier("time.value"))
            }
            // The slider has its own full-width row, so that a drag never lands on its neighbours.
            Slider(value: Binding(get: { core.time }, set: { port.send("scrub", [$0]) }),
                   in: 0...GenerativeArtCore.duration)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Time"))
                .accessibilityValue(Text(verbatim: String(format: "%.1f seconds", core.time)))
                .accessibilityIdentifier(port.identifier("time.scrub"))
        }
    }

    private func presetSection(_ core: GenerativeArtCore) -> some View {
        section("Preset") {
            ForEach(Array(core.family.presets.enumerated()), id: \.offset) { index, preset in
                choice(preset.title, selected: core.presetID == preset.id, identifier: "preset." + preset.id) {
                    port.send("preset", [Double(index)])
                }
            }
        }
    }

    private func paletteSection(_ core: GenerativeArtCore) -> some View {
        section("Palette") {
            ForEach(Array(FamilyCatalog.palettes.enumerated()), id: \.offset) { index, palette in
                choice(palette.name, selected: core.document.paletteID == palette.id,
                       identifier: "palette." + palette.id) {
                    port.send("palette", [Double(index)])
                }
            }
        }
    }

    private func seedSection(_ core: GenerativeArtCore) -> some View {
        section("Seed") {
            HStack {
                Text(verbatim: String(core.document.seed))
                    .font(.footnote.monospacedDigit())
                    .textSelection(.enabled)
                    .accessibilityLabel(Text(verbatim: "Seed " + String(core.document.seed)))
                    .accessibilityIdentifier(port.identifier("seed.value"))
                Spacer()
                button("Shuffle", identifier: "seed.shuffle", hint: "Picks a new seed") { port.send("seed.shuffle") }
            }
        }
    }

    private func parameterSection(_ core: GenerativeArtCore) -> some View {
        section("Parameters") {
            ForEach(core.family.schema.definitions, id: \.name) { definition in
                let value = core.document.parameters[definition.name] ?? definition.defaultValue
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(verbatim: definition.title).font(.body)
                        Spacer()
                        Text(verbatim: String(format: "%.2f %@", value, definition.unit))
                            .font(.subheadline.monospacedDigit())
                        if value != core.baseline[definition.name] {
                            Button { port.send("reset." + definition.name) } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(Text(verbatim: "Reset " + definition.title))
                            .accessibilityIdentifier(port.identifier("reset." + definition.name))
                        }
                    }
                    Slider(value: Binding(get: { definition.normalized(value) },
                                          set: { port.send("parameter." + definition.name, [$0]) }), in: 0...1)
                        .frame(minHeight: 44)
                        .accessibilityLabel(Text(verbatim: definition.title))
                        .accessibilityValue(Text(verbatim: String(format: "%.2f %@", value, definition.unit)))
                        .accessibilityIdentifier(port.identifier("parameter." + definition.name))
                }
            }
            button("Reset all", identifier: "resetAll") { port.send("resetAll") }
        }
    }

    private func librarySection(_ core: GenerativeArtCore) -> some View {
        section("Library") {
            HStack {
                TextField(text: $saveName) { Text(verbatim: "Name") }
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 44)
                    .accessibilityLabel(Text(verbatim: "Composition name"))
                    .accessibilityIdentifier(port.identifier("library.name"))
                button("Save", identifier: "save") {
                    let name = saveName.isEmpty ? core.family.title : saveName
                    if library.save(core.savedDocument, name: name) != nil { port.send("save") }
                }
            }
            if let message = library.errorMessage {
                Text(verbatim: message).font(.footnote).foregroundStyle(.primary)   // primary, not red: small red text fails contrast (E-12)
                    .accessibilityIdentifier(port.identifier("library.error"))
            }
            if library.unreadable > 0 {
                Text(verbatim: "\(library.unreadable) saved file(s) could not be read.").font(.footnote)
            }
            ForEach(library.entries) { entry in
                HStack {
                    Text(verbatim: entry.name).font(.body)
                    Spacer()
                    button("Open", identifier: "library.open." + entry.id.uuidString.lowercased()) { open(entry) }
                    iconButton("pencil", label: "Rename " + entry.name,
                               identifier: "library.rename." + entry.id.uuidString.lowercased()) {
                        newName = entry.name
                        renaming = entry
                    }
                    iconButton("trash", label: "Remove " + entry.name,
                               identifier: "library.remove." + entry.id.uuidString.lowercased()) { removing = entry }
                }
            }
        }
    }

    private func exportSection() -> some View {
        section("Export") {
            HStack {
                button("Make image", identifier: "export.make",
                       hint: "Draws the picture at \(Self.exportEdge) by \(Self.exportEdge) pixels") { makeImage() }
                if let exported {
                    ShareLink(item: exported, preview: SharePreview(Text(verbatim: "Composition")))
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(Text(verbatim: "Share image"))
                        .accessibilityIdentifier(port.identifier("export.share"))
                }
            }
            if let exportError {
                Text(verbatim: exportError).font(.footnote).foregroundStyle(.primary)   // primary, not red: small red text fails contrast (E-12)
                    .accessibilityIdentifier(port.identifier("export.error"))
            }
        }
    }

    // MARK: Actions

    /// Opens a saved composition: its family, palette, seed and time, then its values, then the values become the
    /// reset baseline (adapter difference 5 of the core).
    private func open(_ entry: GenerativeArtEntry) {
        let document = entry.document
        guard let family = FamilyCatalog.all.firstIndex(where: { $0.id.rawValue == document.familyID }),
              let palette = FamilyCatalog.palettes.firstIndex(where: { $0.id == document.paletteID }) else {
            library.errorMessage = "This composition cannot be opened."
            return
        }
        let seed = GenerativeArtCore.halves(of: document.seed)
        guard port.send("open", [Double(family), Double(palette), seed.high, seed.low,
                                 document.previewTime]).isAccepted else { return }
        for name in document.parameters.keys.sorted() {
            port.send("value." + name, [document.parameters[name] ?? 0])
        }
        port.send("rebase")
        saveName = entry.name
    }

    /// Renders the current picture off screen and offers it to the share interface.
    private func makeImage() {
        exported = nil
        guard let still else {
            exportError = "The picture cannot be drawn now."
            return
        }
        do {
            let image = try still(width: Self.exportEdge, height: Self.exportEdge)
            exported = ExportedImage(data: try StillImageEncoder.pngData(image))
            exportError = nil
        } catch {
            exportError = "The picture could not be made."
        }
    }

    // MARK: Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choice(_ title: String, symbol: String? = nil, selected: Bool, identifier: String,
                        hint: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                Text(verbatim: title).font(.body).multilineTextAlignment(.leading)
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint ?? ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(port.identifier(identifier))
    }

    private func button(_ title: String, identifier: String, hint: String? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.body).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint ?? ""))
        .accessibilityIdentifier(port.identifier(identifier))
    }

    private func iconButton(_ symbol: String, label: String, identifier: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityIdentifier(port.identifier(identifier))
    }
}
