// FractalControls — feature 193 (UA-F07) T-U07-024 (FR-U07-002, FR-U07-020, FR-U07-022; rule E-12). The native controls
// of Fractal Explorer inside the one app: the family, the view (zoom, reset, go to), iterations with their render cost,
// palettes and animation, the Julia seed, tours, bookmarks and capture. Go-to text is parsed here with the app's own
// `GoToInput`; the core receives numbers. Every change is an action through the port; every control has a VoiceOver
// label, a hit area of at least 44 by 44 points and text that wraps at the largest sizes.
import CoreTransferable
import FractalExplorerAdapterCore
import FractalExplorerCore
import SwiftUI
import UniformTypeIdentifiers
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreParameters
import VisualCoreRendering

/// A PNG made by capture, offered to the system's share interface without a file of the app's own.
struct FractalCapture: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}

/// The controls of Fractal Explorer.
struct FractalControls: View {
    let port: ExperienceActionPort
    let mirror: FractalMirror
    let library: FractalBookmarks
    let reduceMotion: Bool

    @Environment(\.experienceStillRenderer) private var still
    @State private var real = ""
    @State private var imaginary = ""
    @State private var zoom = ""
    @State private var goToError: String?
    @State private var bookmarkName = ""
    @State private var renaming: FractalBookmarkEntry?
    @State private var newName = ""
    @State private var removing: FractalBookmarkEntry?
    @State private var captured: FractalCapture?
    @State private var captureMessage: String?

    var body: some View {
        Group {
            if let core = mirror.core {
                content(core)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
    }

    @ViewBuilder private func content(_ core: FractalCore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Family") {
                ForEach(Array(FractalMode.allCases.enumerated()), id: \.offset) { index, mode in
                    choice(mode.name, selected: core.mode == mode, identifier: "mode." + mode.rawValue) {
                        if core.mode != mode { port.send("mode", [Double(index)]) }
                    }
                }
                Text(verbatim: FractalExplanations.text(for: core.mode)).font(.footnote)
                    .accessibilityIdentifier(port.identifier("mode.explanation"))
            }
            section("View") {
                HStack {
                    button("Zoom in", identifier: "zoomIn") { port.send("zoomIn") }
                    button("Zoom out", identifier: "zoomOut") { port.send("zoomOut") }
                    button("Reset view", identifier: "resetView") { port.send("resetView") }
                }
                if core.limitReached {
                    Text(verbatim: "Precision limit reached — zoom stops here").font(.footnote)
                        .accessibilityIdentifier(port.identifier("precision"))
                }
            }
            section("Go to") {
                field("Real part", text: $real, identifier: "goto.real")
                field("Imaginary part", text: $imaginary, identifier: "goto.imaginary")
                field("Zoom", text: $zoom, identifier: "goto.zoom")
                button("Go", identifier: "goto.go") { goTo() }
                if let goToError {
                    Text(verbatim: goToError).font(.footnote).foregroundStyle(.primary)   // primary, not red: small red text fails contrast (E-12)
                        .accessibilityIdentifier(port.identifier("goto.error"))
                }
            }
            section("Iterations") {
                HStack {
                    button("Halve", identifier: "cap.down", hint: "Halves the iterations per point") { port.send("cap.down") }
                    Text(verbatim: "\(core.cap)").font(.body.monospacedDigit())
                        .accessibilityLabel(Text(verbatim: "\(core.cap) iterations"))
                        .accessibilityIdentifier(port.identifier("cap"))
                    button("Double", identifier: "cap.up", hint: "Doubles the iterations per point") { port.send("cap.up") }
                }
                Text(verbatim: CapControl.costText(cap: core.cap, pixels: mirror.canvasSize.x * mirror.canvasSize.y))
                    .font(.footnote)
                    .accessibilityIdentifier(port.identifier("cost"))
            }
            section("Palette") {
                ForEach(Array(FractalCore.paletteIDs.enumerated()), id: \.offset) { index, id in
                    choice(Palette.builtIn(id)?.name ?? id, selected: core.paletteID == id, identifier: "palette." + id) {
                        port.send("palette", [Double(index)])
                    }
                }
                Toggle(isOn: Binding(get: { core.animate }, set: { port.send("animate", [$0 ? 1 : 0]) })) {
                    Text(verbatim: "Animate palette")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier(port.identifier("animate"))
            }
            if core.mode == .julia {
                section("Julia seed") {
                    Text(verbatim: "Seed: " + FractalState.complex(core.juliaSeed)).font(.body)
                        .accessibilityIdentifier(port.identifier("seed"))
                    seedSlider("Seed real part", identifier: "seed.real", value: core.juliaSeed.x) {
                        port.send("seed", [$0, core.juliaSeed.y])
                    }
                    seedSlider("Seed imaginary part", identifier: "seed.imaginary", value: core.juliaSeed.y) {
                        port.send("seed", [core.juliaSeed.x, $0])
                    }
                }
            }
            section("Tours") {
                if let caption = core.tourCaption {
                    Text(verbatim: caption).font(.footnote).accessibilityIdentifier(port.identifier("tour.caption"))
                }
                if core.tourPlaying {
                    button("Stop tour", identifier: "tour.stop") { port.send("tour.stop") }
                }
                ForEach(Array(FractalTours.all.enumerated()), id: \.offset) { index, tour in
                    choice(tour.name, selected: core.tourIndex == index, identifier: "tour." + tour.id,
                           hint: tour.summary) {
                        port.send("tour.start", [Double(index), reduceMotion ? 1 : 0])
                    }
                }
            }
            bookmarkSection(core)
            section("Capture") {
                HStack {
                    button("Capture", identifier: "capture", hint: "Makes a picture of the view") { capture(core) }
                    if let captured {
                        ShareLink(item: captured, preview: SharePreview(Text(verbatim: "Fractal")))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel(Text(verbatim: "Share picture"))
                            .accessibilityIdentifier(port.identifier("capture.share"))
                    }
                }
                if let captureMessage {
                    Text(verbatim: captureMessage).font(.footnote)
                        .accessibilityIdentifier(port.identifier("capture.message"))
                }
            }
        }
        .alert(Text(verbatim: "Rename"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
               presenting: renaming) { entry in
            TextField(text: $newName) { Text(verbatim: "Name") }
                .accessibilityIdentifier(port.identifier("bookmark.newName"))
            Button { library.rename(entry.id, to: newName) } label: { Text(verbatim: "Rename") }
                .accessibilityIdentifier(port.identifier("bookmark.renameConfirm"))
            Button(role: .cancel) {} label: { Text(verbatim: "Cancel") }
        }
        .confirmationDialog(Text(verbatim: "Remove this view?"),
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            presenting: removing) { entry in
            Button(role: .destructive) { library.remove(entry.id) } label: { Text(verbatim: "Remove") }
                .accessibilityIdentifier(port.identifier("bookmark.removeConfirm"))
        }
    }

    private func bookmarkSection(_ core: FractalCore) -> some View {
        section("Bookmarks") {
            HStack {
                field("Bookmark name", text: $bookmarkName, identifier: "bookmark.name")
                button("Save", identifier: "bookmark.save") {
                    let viewport = core.framing.viewport(size: mirror.canvasSize)
                    let precision = PrecisionMode(viewport: viewport, mantissaBits: FractalCore.limitMantissaBits,
                                                  pixelsPerPoint: FractalCore.limitPixelsPerPoint)
                    let bookmark = Bookmark(mode: core.mode, framing: core.framing, juliaSeed: core.juliaSeed,
                                            iterationCap: core.cap, escapeRadius: core.radius,
                                            paletteID: core.paletteID, precision: precision)
                    library.save(bookmark, name: bookmarkName.isEmpty ? core.mode.name : bookmarkName)
                }
            }
            if let message = library.errorMessage {
                Text(verbatim: message).font(.footnote).foregroundStyle(.primary)   // primary, not red: small red text fails contrast (E-12)
                    .accessibilityIdentifier(port.identifier("bookmark.error"))
            }
            if library.unreadable > 0 {
                Text(verbatim: "\(library.unreadable) saved file(s) could not be read.").font(.footnote)
            }
            ForEach(library.entries) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text(verbatim: entry.name).font(.body)
                        Text(verbatim: entry.bookmark.summary).font(.footnote)
                    }
                    Spacer()
                    button("Open", identifier: "bookmark.open." + entry.id.uuidString.lowercased()) { open(entry) }
                    iconButton("pencil", label: "Rename " + entry.name,
                               identifier: "bookmark.rename." + entry.id.uuidString.lowercased()) {
                        newName = entry.name
                        renaming = entry
                    }
                    iconButton("trash", label: "Remove " + entry.name,
                               identifier: "bookmark.remove." + entry.id.uuidString.lowercased()) { removing = entry }
                }
            }
        }
    }

    // MARK: Actions

    private func goTo() {
        switch GoToInput.parse(real: real, imaginary: imaginary, zoom: zoom) {
        case .success(let target):
            goToError = nil
            port.send("goTo", [target.center.x, target.center.y, target.zoom])
        case .failure(let error):
            goToError = "\(error.field.rawValue.capitalized): \(error.message)"
        }
    }

    private func open(_ entry: FractalBookmarkEntry) {
        let b = entry.bookmark
        guard let palette = FractalCore.paletteIDs.firstIndex(of: b.paletteID) else {
            library.errorMessage = "This view cannot be opened."
            return
        }
        let values = [b.mode == .julia ? 1.0 : 0, b.framing.center.x, b.framing.center.y, b.framing.span,
                      b.juliaSeed.x, b.juliaSeed.y, Double(b.iterationCap), Double(palette)]
        guard port.send("bookmark.open", values).isAccepted else {
            library.errorMessage = "This view cannot be opened."
            return
        }
        if b.escapeRadius != FractalMath.minimumRadius { port.send("radius", [b.escapeRadius]) }
    }

    private func capture(_ core: FractalCore) {
        captured = nil
        guard let still else {
            captureMessage = "The picture cannot be made now."
            return
        }
        let size = mirror.canvasSize
        let sizing = CaptureSizing.longEdge(viewport: core.framing.viewport(size: size),
                                            pixelsPerPoint: FractalCore.limitPixelsPerPoint,
                                            mantissaBits: FractalCore.limitMantissaBits)
        let scale = Double(sizing.longEdge) / max(size.x, size.y)
        do {
            let image = try still(width: max(1, Int((size.x * scale).rounded())),
                                  height: max(1, Int((size.y * scale).rounded())))
            captured = FractalCapture(data: try StillImageEncoder.pngData(image))
            captureMessage = sizing.limited ? "The picture is smaller here: precision limits the size." : nil
        } catch {
            captureMessage = "The picture could not be captured. Please try again."
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

    private func field(_ title: String, text: Binding<String>, identifier: String) -> some View {
        // The name is a label above the field, which wraps; the field's placeholder is short, so nothing clips at the
        // largest text sizes (E-12).
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title).font(.subheadline).accessibilityHidden(true)
            TextField(text: text) { Text(verbatim: "0") }
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityIdentifier(port.identifier(identifier))
        }
    }

    private func seedSlider(_ title: String, identifier: String, value: Double,
                            set: @escaping (Double) -> Void) -> some View {
        Slider(value: Binding(get: { value }, set: set), in: -2...2)
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityValue(Text(verbatim: String(format: "%.3f", value)))
            .accessibilityIdentifier(port.identifier(identifier))
    }

    private func choice(_ title: String, selected: Bool, identifier: String, hint: String? = nil,
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
