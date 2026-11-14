// GeometryControls — feature 040 (A05-P01) T-A05-105 (FR-A05-120, FR-A05-121). The native controls of Infinite
// Geometry: the four curated presets, the symmetry order (disabled for the tilings, whose lattice fixes it), the
// repetitions, the scale, the palette and a new motif seed. Every change is an action through the port; every control
// has a VoiceOver label, an identifier from the port, a hit area of at least 44 by 44 points and text that wraps.
//
// Feature 041 (A05-P02) T-A05-207 (FR-A05-212): the "View" section gives every camera gesture a button — pan
// arrows (2D presets), zoom in and out (the 2D zoom, or the distance on the 3D composition), orbit arrows (3D
// composition) and reset — sending the same actions as the gestures.
//
// Feature 042 (A05-P03) T-A05-306 (FR-A05-315): the pan arrows are shown on the 3D composition too (they move the
// orbit target by a fixed step in world units), and "Wider"/"Narrower" step the field of view by 5°, clamped into
// 30…75° before the action is sent; both have labels, hints and identifiers like the other camera buttons.
//
// Feature 043 (A05-P04) T-A05-404 (FR-A05-410–413, 430, 431): the "Saved compositions" section (a name field, "Save
// composition", and Open / Rename / Delete for every saved composition, with notes for unreadable files and files of
// a newer version) and the "Export" section ("Export picture" renders the composition through the host's still
// renderer at the canvas's aspect, long edge 2048 pixels, and offers it through "Share picture"). Opening sends the one
// atomic `composition.open` action with the document's 18 values; a refusal changes nothing and shows a message.
import InfiniteGeometryCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters
import VisualCoreRendering

/// The controls of Infinite Geometry.
struct GeometryControls: View {
    let port: ExperienceActionPort
    let mirror: GeometryMirror
    /// The saved compositions (feature 043 A05-P04); nil hides the section.
    let library: GeometryLibrary?

    /// The message shown when the experience refuses a saved composition.
    static let openFailure = "The composition could not be opened."
    /// The message shown when an export fails.
    static let exportFailure = "The picture could not be exported. Please try again."
    /// The message shown when the canvas has no size yet.
    static let exportNoCanvas = "The canvas has no size yet. Please try again in a moment."
    /// The message shown when no still renderer is available.
    static let exportUnavailable = "The picture cannot be made now."

    @Environment(\.experienceStillRenderer) private var still
    @State private var compositionName = ""
    @State private var renaming: GeometryLibraryEntry?
    @State private var renameText = ""
    @State private var exported: GeometryCapture?
    @State private var exportMessage: String?

    /// Controls over `port` and `mirror`, with the saved compositions of `library` when there is one.
    init(port: ExperienceActionPort, mirror: GeometryMirror, library: GeometryLibrary? = nil) {
        self.port = port
        self.mirror = mirror
        self.library = library
    }

    /// The state digest of `core` in hex, as the engine computes it (domain: the experience id); nil when the core
    /// cannot be digested.
    static func digest(of core: GeometryCore) -> String? {
        var builder = DigestBuilder(domain: GeometryCore.experienceID)
        do {
            try core.writeDigest(into: &builder)
        } catch {
            return nil
        }
        return builder.finish().hex
    }

    /// One pan button's step: a quarter of the visible half-side, in world units at zoom 1.
    static let panStep = 0.25
    /// One zoom button's factor (its inverse zooms out).
    static let zoomStep = 1.25
    /// One orbit button's angle in radians.
    static let orbitStep = 0.2
    /// One "Wider"/"Narrower" step of the field of view in degrees.
    static let fovStep = 5.0

    /// The field of view one step from `degrees` (`direction` +1 wider, −1 narrower), clamped into
    /// `GeometryCore.fovRange`.
    static func steppedFieldOfView(_ degrees: Double, direction: Double) -> Double {
        let range = GeometryCore.fovRange
        return min(max(degrees + direction * fovStep, range.lowerBound), range.upperBound)
    }

    var body: some View {
        Group {
            if let core = mirror.core {
                content(core)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
    }

    @ViewBuilder private func content(_ core: GeometryCore) -> some View {
        let preset = core.preset
        VStack(alignment: .leading, spacing: 16) {
            section("Preset") {
                ForEach(Array(GeometryPreset.curated.enumerated()), id: \.offset) { index, curated in
                    choice(GeometryCore.kindName(curated.kind), selected: core.presetIndex == index,
                           identifier: "preset.\(index)") {
                        if core.presetIndex != index { _ = port.send("preset.select", [Double(index)]) }
                    }
                }
                Text(verbatim: "Symmetry: \(GeometryCore.symmetryText(preset)); \(core.elementCount) elements")
                    .font(.footnote).accessibilityIdentifier(port.identifier("summary"))
            }
            section("Symmetry") {
                stepper("Symmetry order", identifier: "symmetry.order", value: preset.order,
                        range: GeometryPreset.orderRange,
                        text: preset.usesOrder ? "\(preset.order)-fold" : "Fixed by the lattice",
                        hint: preset.usesOrder ? "Sets the number of symmetric copies"
                            : "A tiling has its lattice's symmetry")
                    .disabled(!preset.usesOrder)
                stepper("Repetitions", identifier: "repeats.set", value: preset.repeats,
                        range: GeometryPreset.repeatsRange, text: "\(preset.repeats)",
                        hint: "Sets the number of rings around the centre")
                slider("Scale", identifier: "scale.set", value: preset.scale, range: GeometryPreset.scaleRange,
                       text: String(format: "×%.2f", preset.scale))
            }
            section("Palette") {
                ForEach(Array(Palette.builtIns.enumerated()), id: \.offset) { index, palette in
                    if GeometryPreset.paletteRange.contains(index) {
                        choice(palette.name, selected: preset.palette == index, identifier: "palette.\(palette.id)") {
                            if preset.palette != index { _ = port.send("palette.set", [Double(index)]) }
                        }
                    }
                }
            }
            cameraSection(core)
            section("Motif") {
                button("New motif", identifier: "reseed", hint: "Draws a new motif with the next seed") {
                    _ = port.send("reseed")
                }
            }
            if let library { librarySection(core, library: library) }
            exportSection()
        }
    }

    // MARK: Saved compositions (FR-A05-401–403, 430)

    @ViewBuilder private func librarySection(_ core: GeometryCore, library: GeometryLibrary) -> some View {
        section("Saved compositions") {
            TextField(text: $compositionName) { Text(verbatim: "Composition name") }
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Composition name"))
                .accessibilityIdentifier(port.identifier("library.name"))
            button("Save composition", identifier: "library.save",
                   hint: "Saves the current composition under the name") {
                save(core, library: library)
            }
            if let message = library.errorMessage {
                Text(verbatim: message).font(.footnote).foregroundStyle(.primary)   // primary, not red: contrast (E-12)
                    .accessibilityIdentifier(port.identifier("library.message"))
            }
            if library.unreadable > 0 {
                Text(verbatim: "\(library.unreadable) saved composition\(library.unreadable == 1 ? "" : "s") could not be read")
                    .font(.footnote).accessibilityIdentifier(port.identifier("library.problems"))
            }
            if library.newer > 0 {
                Text(verbatim: "\(library.newer) saved composition\(library.newer == 1 ? " was" : "s were") made by a newer version")
                    .font(.footnote).accessibilityIdentifier(port.identifier("library.newer"))
            }
            ForEach(Array(library.entries.enumerated()), id: \.element.id) { index, entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: entry.name).font(.body)
                        .accessibilityIdentifier(port.identifier("library.entry.\(index)"))
                    if renaming?.id == entry.id {
                        TextField(text: $renameText) { Text(verbatim: "New name") }
                            .textFieldStyle(.roundedBorder)
                            .frame(minHeight: 44)
                            .accessibilityLabel(Text(verbatim: "New name for \(entry.name)"))
                            .accessibilityIdentifier(port.identifier("library.renameText.\(index)"))
                        HStack(spacing: 8) {
                            button("Done", identifier: "library.renameDone.\(index)", hint: "Renames the composition") {
                                if library.rename(entry, to: renameText) { renaming = nil }
                            }
                            button("Cancel", identifier: "library.renameCancel.\(index)", hint: "Keeps the name") {
                                renaming = nil
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        button("Open", identifier: "library.open.\(index)",
                               hint: "Replaces the composition with \(entry.name)") {
                            open(entry, library: library)
                        }
                        button("Rename", identifier: "library.rename.\(index)", hint: "Gives \(entry.name) a new name") {
                            renaming = entry
                            renameText = entry.name
                        }
                        button("Delete", identifier: "library.delete.\(index)", hint: "Deletes \(entry.name)") {
                            if renaming?.id == entry.id { renaming = nil }
                            library.delete(entry)
                        }
                    }
                }
            }
        }
    }

    /// Saves the current composition under the field's name (empty → "Untitled") with the digest at save time.
    private func save(_ core: GeometryCore, library: GeometryLibrary) {
        guard let digest = Self.digest(of: core) else {
            library.errorMessage = "The composition could not be saved."
            return
        }
        if library.save(GeometryDocument(core: core, name: compositionName), digest: digest) != nil {
            compositionName = ""
        }
    }

    /// Sends the saved composition as one atomic `composition.open` action (all values applied, or none).
    private func open(_ entry: GeometryLibraryEntry, library: GeometryLibrary) {
        guard let document = library.document(for: entry) else { return }
        if port.send("composition.open", document.openValues).isAccepted {
            library.errorMessage = nil
        } else {
            library.errorMessage = Self.openFailure
        }
    }

    // MARK: Export (FR-A05-410–413, 431)

    @ViewBuilder private func exportSection() -> some View {
        section("Export") {
            HStack(spacing: 8) {
                button("Export picture", identifier: "export",
                       hint: "Makes a picture of the composition, 2048 pixels on the long edge") { export() }
                if let exported {
                    ShareLink(item: exported, preview: SharePreview(Text(verbatim: "Infinite Geometry")))
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(Text(verbatim: "Share picture"))
                        .accessibilityHint(Text(verbatim: "\(exported.width) by \(exported.height) pixels"))
                        .accessibilityIdentifier(port.identifier("export.share"))
                }
            }
            if let exportMessage {
                Text(verbatim: exportMessage).font(.footnote).foregroundStyle(.primary)   // primary, not red (E-12)
                    .accessibilityIdentifier(port.identifier("export.message"))
            }
        }
    }

    /// Renders the current composition at the export size and keeps the PNG in memory for the share interface.
    private func export() {
        exported = nil
        guard let still else {
            exportMessage = Self.exportUnavailable
            return
        }
        let canvas = CGSize(width: mirror.canvasSize.x, height: mirror.canvasSize.y)
        guard GeometryExport.size(canvas: canvas, maxEdge: GeometryExport.longEdge) != nil else {
            exportMessage = Self.exportNoCanvas
            return
        }
        do {
            exported = try GeometryExport.png(still: still, canvas: canvas, maxEdge: GeometryExport.longEdge)
            exportMessage = nil
        } catch {
            exportMessage = Self.exportFailure
        }
    }

    // MARK: View

    /// The camera buttons: pan arrows, zoom and reset on every preset; orbit arrows and the field of view on the 3D
    /// composition.
    @ViewBuilder private func cameraSection(_ core: GeometryCore) -> some View {
        let solid = core.preset.kind == .solid
        let pan = solid ? Self.panStep : Self.panStep / max(core.view2D.zoom, 1e-6)
        let fov = core.orbit3D.fovDegrees
        section("View") {
            if solid {
                HStack(spacing: 8) {
                    arrow("Orbit left", symbol: "arrow.left", identifier: "camera.orbit.left",
                          hint: "Turns the composition to the left") { _ = port.send("camera.orbit", [Self.orbitStep, 0]) }
                    arrow("Orbit right", symbol: "arrow.right", identifier: "camera.orbit.right",
                          hint: "Turns the composition to the right") { _ = port.send("camera.orbit", [-Self.orbitStep, 0]) }
                    arrow("Orbit up", symbol: "arrow.up", identifier: "camera.orbit.up",
                          hint: "Looks at the composition from higher up") { _ = port.send("camera.orbit", [0, Self.orbitStep]) }
                    arrow("Orbit down", symbol: "arrow.down", identifier: "camera.orbit.down",
                          hint: "Looks at the composition from lower down") { _ = port.send("camera.orbit", [0, -Self.orbitStep]) }
                }
            }
            HStack(spacing: 8) {
                arrow("Pan left", symbol: "arrow.left", identifier: "camera.pan.left",
                      hint: "Moves the view to the left") { _ = port.send("camera.pan", [-pan, 0]) }
                arrow("Pan right", symbol: "arrow.right", identifier: "camera.pan.right",
                      hint: "Moves the view to the right") { _ = port.send("camera.pan", [pan, 0]) }
                arrow("Pan up", symbol: "arrow.up", identifier: "camera.pan.up",
                      hint: "Moves the view up") { _ = port.send("camera.pan", [0, pan]) }
                arrow("Pan down", symbol: "arrow.down", identifier: "camera.pan.down",
                      hint: "Moves the view down") { _ = port.send("camera.pan", [0, -pan]) }
            }
            if solid {
                HStack(spacing: 8) {
                    button("Wider", identifier: "camera.fov.wider", hint: "Widens the field of view by 5 degrees") {
                        let next = Self.steppedFieldOfView(fov, direction: 1)
                        if next != fov { _ = port.send("camera.fov", [next]) }
                    }
                    .disabled(fov >= GeometryCore.fovRange.upperBound)
                    button("Narrower", identifier: "camera.fov.narrower", hint: "Narrows the field of view by 5 degrees") {
                        let next = Self.steppedFieldOfView(fov, direction: -1)
                        if next != fov { _ = port.send("camera.fov", [next]) }
                    }
                    .disabled(fov <= GeometryCore.fovRange.lowerBound)
                }
            }
            HStack(spacing: 8) {
                arrow("Zoom in", symbol: "plus.magnifyingglass", identifier: "camera.zoom.in",
                      hint: solid ? "Moves the camera closer" : "Magnifies the view") {
                    _ = port.send("camera.zoom", [Self.zoomStep])
                }
                arrow("Zoom out", symbol: "minus.magnifyingglass", identifier: "camera.zoom.out",
                      hint: solid ? "Moves the camera away" : "Shows more of the composition") {
                    _ = port.send("camera.zoom", [1 / Self.zoomStep])
                }
                button("Reset view", identifier: "camera.reset", hint: "Returns the camera to the preset's view") {
                    _ = port.send("camera.reset")
                }
            }
            Text(verbatim: solid
                 ? String(format: "Pitch %.0f°, distance %.1f, field of view %.0f°", core.orbit3D.pitch * 180 / Double.pi,
                          core.orbit3D.distance, fov)
                 : String(format: "Zoom ×%.2f, centre %.2f, %.2f", core.view2D.zoom, core.view2D.centerX, core.view2D.centerY))
                .font(.footnote).accessibilityIdentifier(port.identifier("camera.summary"))
        }
    }

    private func arrow(_ title: String, symbol: String, identifier: String, hint: String,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
    }

    // MARK: Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepper(_ title: String, identifier: String, value: Int, range: ClosedRange<Int>, text: String,
                         hint: String) -> some View {
        Stepper(value: Binding(get: { value }, set: { _ = port.send(identifier, [Double($0)]) }), in: range) {
            HStack {
                Text(verbatim: title).font(.body)
                Spacer()
                Text(verbatim: text).font(.subheadline.monospacedDigit()).multilineTextAlignment(.trailing)
            }
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: text))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
    }

    private func slider(_ title: String, identifier: String, value: Double, range: ClosedRange<Double>,
                        text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: title).font(.body)
                Spacer()
                Text(verbatim: text).font(.subheadline.monospacedDigit())
            }
            Slider(value: Binding(get: { value }, set: { _ = port.send(identifier, [$0]) }), in: range)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityValue(Text(verbatim: text))
                .accessibilityIdentifier(port.identifier(identifier))
        }
    }

    private func choice(_ title: String, selected: Bool, identifier: String, action: @escaping () -> Void) -> some View {
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
