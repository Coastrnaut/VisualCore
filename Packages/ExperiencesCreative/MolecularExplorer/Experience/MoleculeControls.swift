// MoleculeControls — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5) and feature 111 (A15-P02)
// T-A15-205 (FR-A15-210, FR-A15-220, FR-A15-230; clarifications Q2–Q4). The native controls of Molecular Explorer in
// one section:
//   Previous molecule and Next molecule (`previous-molecule`, `next-molecule` → `molecule.previous` /
//     `molecule.next`; disabled at water and at caffeine, with a hint saying so);
//   the Molecule menu (`molecule` → `molecule.select [index]`) listing the five titles in library order;
//   the name and formula line (`name`: "Caffeine — C8H10N4O2"), the counts line (`counts`: "24 atoms, 25 bonds"), the
//     source line (`source`: "PubChem Compound CID 2519, 3D conformer — public domain"), the status line (`status`:
//     "Caffeine selected, molecule 5 of 5") and the answer to a refused action (`message`, shown only when there is
//     one);
//   the display mode, a segmented picker Ball and stick / Space filling (`display-mode` → `display.mode [0 / 1]`, sent
//     only when the choice changes), with the mode's legend below (`legend`: "… Display radii, not measured sizes.");
//   Turn left and Turn right (`turn-left`, `turn-right` → `camera.orbit [−1 / +1]`, 15° each, never disabled), Tilt up
//     and Tilt down (`tilt-up`, `tilt-down` → `camera.tilt [+1 / −1]`, 10° each, disabled at +80° and −80° with a hint
//     saying so), each with the value "Turned 30°, tilted 20°"; Zoom in and Zoom out (`zoom-in`, `zoom-out` →
//     `camera.zoom [+1 / −1]`, disabled at steps 4 and −4) with the value "Zoom step 0 of −4 to 4"; Reset view
//     (`reset-view` → `view.reset`) with both values.
// Feature 112 (A15-P03) T-A15-305 and T-A15-306 (FR-A15-301, FR-A15-302, FR-A15-311, FR-A15-322; clarifications Q2,
// Q3, Q5): Pan left, Pan right, Pan up and Pan down (`pan-left`, `pan-right`, `pan-up`, `pan-down` →
// `camera.pan [−1, 0]`, `[1, 0]`, `[0, 1]`, `[0, −1]`: one step of the view, so the molecule moves the other way;
// disabled at −10 and 10 steps with a hint saying so) with the value "View centred" / "View panned 2 right and 1 up";
// Previous atom and Next atom (`previous-atom`, `next-atom` → `atom.previous` / `atom.next`; with no selection they
// select the last and the first atom; disabled at the first and the last atom and for a molecule without atoms) and
// Clear selection (`clear-atom` → `atom.clear`, disabled when no atom is selected), each with the value "Nitrogen (N),
// atom 3 of 24" or "No atom selected"; the selected atom's panel (`atom-panel`: its name and place, position and radii
// lines, or "No atom selected") and one line per bond (`atom-bond-<n>`, n = 1, 2, …: "Single bond to carbon, atom 8,
// recorded"). The canvas gestures send the same actions as these buttons (`GestureAlternatives.missing` is empty).
// Feature 113 (A15-P04) T-A15-405 (FR-A15-401, FR-A15-420, FR-A15-440; clarification Q4; contracts/library.md):
// the Library section, one button per library molecule (`library-<id>` → `molecule.select [index]`, as the Molecule
// menu sends it) whose words are the name and formula ("Caffeine — C8H10N4O2"), the counts ("24 atoms, 25 bonds") and
// the source ("Source: PubChem Compound CID 2519, 3D conformer — public domain", from the molecule's source record);
// the Recent menu (`recent` → `molecule.select [index]`) listing the recent titles newest first, or "No recent
// molecules"; the Labels picker (`labels`: All, Selected, None), which is not an engine action: it sets the label mode
// through the presenter (the settings store and the overlay); and the stores' messages (`recent-message`,
// `settings-message`, shown only when there is one).
// Feature 114 (A15-P05) T-A15-507 (FR-A15-501, FR-A15-540; contracts/import.md): the Import button (`import`, "Import
// XYZ file", hint "Opens a small XYZ file from Files") shows the system file importer for one `.xyz` or plain-text
// file (its shown state lives in the mirror, so the view keeps holding references only); the picked file goes to the
// presenter's `importFile(at:)` and a cancel does nothing. The import's answer (`import-message`, shown only when there
// is one), the panel line `inferred-note` ("Bonds marked inferred are estimated from atom distances.") under the
// bonds, the imported molecule in the Molecule menu (molecule 6, by its file's title) and in the Recent menu (through
// the presenter, which replays the stored copy when the engine holds no import). Previous and Next molecule stay
// within the library, so both are disabled at the imported molecule.
// Every control and line has an accessible label and value (controls a hint too) and the identifier
// `experience.a15.molecular-explorer.<name>` from the port; hit areas are at least 44 points high and text wraps.
//
// The view holds references only — the port, the mirror and the presenter — and no closure: the host rebuilds the
// controls on every port revision, and SwiftUI keeps an open Molecule menu only when the rebuilt view compares equal
// (a stored closure never does; feature 108 T-A14-609, docs/automatedtesting.md). Actions go through the presenter.
import MolecularExplorerCore
import SwiftUI
import UniformTypeIdentifiers
import VisualCoreExperience
import VisualCoreExperienceHost

/// The controls of Molecular Explorer.
struct MoleculeControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: MoleculeMirror
    /// The presenter every action goes through (it shows the answer to a refused action in the mirror). A reference,
    /// not a closure, so that the view compares equal from one host update to the next.
    let presenter: MoleculePresenter

    /// The titles of the molecules in library order (the Molecule menu's entries).
    static var moleculeTitles: [String] { MoleculeCore.library.map(\.title) }

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// The words of the library entry at `index`: the name and formula line, the counts line and "Source: " with the
    /// source line ("Source: PubChem Compound CID 2519, 3D conformer — public domain"); empty outside the library.
    static func libraryWords(index: Int) -> [String] {
        guard MoleculeCore.molecule(index: index) != nil else { return [] }
        return [MoleculeCore.nameLine(index: index), MoleculeCore.countsLine(index: index),
                "Source: " + MoleculeCore.sourceLine(index: index)]
    }

    /// The words of an empty Recent menu.
    static let noRecentWords = "No recent molecules"

    /// The Recent menu's value: the recent titles newest first, joined by commas, or "No recent molecules".
    static func recentValue(_ titles: [String]) -> String {
        titles.isEmpty ? noRecentWords : titles.joined(separator: ", ")
    }

    /// The selected molecule in words: "Caffeine, molecule 5 of 5".
    static func moleculeWords(index: Int, count: Int) -> String {
        moleculeWords(title: MoleculeCore.title(index: index), index: index, count: count)
    }

    /// The molecule `title` at `index` in words: "Caffeine, molecule 5 of 5"; the imported molecule (index 5) counts
    /// as molecule 6 of 6 (feature 114).
    static func moleculeWords(title: String, index: Int, count: Int) -> String {
        let total = index == MoleculeCore.importedSelection ? MoleculeCore.importedSelection + 1 : count
        return "\(title), molecule \(index + 1) of \(total)"
    }

    /// The Import button's label (feature 114).
    static let importLabel = "Import XYZ file"
    /// The Import button's hint (feature 114).
    static let importHint = "Opens a small XYZ file from Files"
    /// The file types the importer offers: `.xyz` files and plain text (feature 114).
    static var importTypes: [UTType] {
        [UTType(filenameExtension: "xyz"), UTType.plainText].compactMap { $0 }
    }

    /// The controls, or a progress indicator before the first state; the file importer of the Import button.
    var body: some View {
        Group {
            if mirror.ready {
                content
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
        .fileImporter(isPresented: Binding(get: { mirror.importing }, set: { mirror.importing = $0 }),
                      allowedContentTypes: Self.importTypes, allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { presenter.importFile(at: url) }
        }
    }

    /// The buttons, the menu and the lines.
    @ViewBuilder private var content: some View {
        let words = Self.moleculeWords(title: mirror.title, index: mirror.selection, count: mirror.moleculeCount)
        let atImport = mirror.selection >= mirror.moleculeCount
        let atFirst = mirror.selection <= 0 || atImport
        let atLast = mirror.selection >= mirror.moleculeCount - 1
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Molecular Explorer").font(.headline).accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                button("Previous molecule", name: "previous-molecule", value: words,
                       hint: atImport ? "Steps through the library molecules only"
                           : atFirst ? "Water is the first molecule" : "Selects the previous molecule",
                       enabled: !atFirst) { send("molecule.previous") }
                button("Next molecule", name: "next-molecule", value: words,
                       hint: atImport ? "Steps through the library molecules only"
                           : atLast ? "Caffeine is the last molecule" : "Selects the next molecule",
                       enabled: !atLast) { send("molecule.next") }
            }
            Menu {
                ForEach(Self.moleculeTitles.indices, id: \.self) { index in
                    Button {
                        send("molecule.select", [Double(index)])
                    } label: {
                        Text(verbatim: Self.moleculeTitles[index])
                    }
                }
                if mirror.hasImport {
                    Button {
                        send("molecule.select", [Double(MoleculeCore.importedSelection)])
                    } label: {
                        Text(verbatim: mirror.importTitle)
                    }
                }
            } label: {
                Text(verbatim: "Molecule")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(verbatim: "Molecule"))
            .accessibilityValue(Text(verbatim: words))
            .accessibilityHint(Text(verbatim: mirror.hasImport ? "Selects any of the five molecules or the imported one"
                                        : "Selects any of the five molecules"))
            .accessibilityIdentifier(port.identifier("molecule"))
            line(mirror.nameLine, label: "Name and formula", name: "name", font: .subheadline)
            line(mirror.countsLine, label: "Counts", name: "counts", font: .footnote)
            line(mirror.sourceLine, label: "Source", name: "source", font: .footnote)
            line(Self.sentence(mirror.status), label: "Status", name: "status", font: .footnote)
            modePicker
            line(mirror.legend, label: "Legend", name: "legend", font: .footnote)
            cameraButtons
            panButtons
            atomButtons
            atomPanel
            line(MoleculePresenter.inferredNote, label: "Inferred bonds", name: "inferred-note", font: .footnote)
            labelsPicker
            recentMenu
            importButton
            if !mirror.importMessage.isEmpty {
                line(mirror.importMessage, label: "Import message", name: "import-message", font: .footnote)
            }
            librarySection
            if !mirror.message.isEmpty {
                line(mirror.message, label: "Message", name: "message", font: .footnote)
            }
            if !mirror.recentMessage.isEmpty {
                line(mirror.recentMessage, label: "Recent molecules message", name: "recent-message", font: .footnote)
            }
            if !mirror.settingsMessage.isEmpty {
                line(mirror.settingsMessage, label: "Settings message", name: "settings-message", font: .footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The segmented display-mode picker: Ball and stick and Space filling (sends `display.mode [0 / 1]` only when
    /// the choice changes).
    private var modePicker: some View {
        Picker(selection: Binding(get: { mirror.mode },
                                  set: { mode in
                                      guard mode != mirror.mode else { return }
                                      send("display.mode", [Double(mode.rawValue)])
                                  })) {
            ForEach(DisplayMode.allCases, id: \.rawValue) { mode in
                Text(verbatim: MoleculePresenter.modeTitle(mode)).tag(mode)
            }
        } label: {
            Text(verbatim: "Display")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Display"))
        .accessibilityValue(Text(verbatim: MoleculePresenter.modeTitle(mirror.mode)))
        .accessibilityHint(Text(verbatim: "Ball and stick shows small atoms joined by sticks; space filling shows "
                                    + "atoms at their van der Waals radius"))
        .accessibilityIdentifier(port.identifier("display-mode"))
    }

    /// The segmented Labels picker: All, Selected and None (feature 113; not an engine action: the presenter writes
    /// the settings and filters the overlay's labels).
    private var labelsPicker: some View {
        Picker(selection: Binding(get: { mirror.labelMode },
                                  set: { mode in
                                      guard mode != mirror.labelMode else { return }
                                      presenter.setLabelMode(mode)
                                  })) {
            ForEach(LabelMode.allCases, id: \.rawValue) { mode in
                Text(verbatim: MoleculePresenter.labelTitle(mode)).tag(mode)
            }
        } label: {
            Text(verbatim: "Labels")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Labels"))
        .accessibilityValue(Text(verbatim: MoleculePresenter.labelTitle(mirror.labelMode)))
        .accessibilityHint(Text(verbatim: "Shows element labels for all atoms, only the selected atom, or none"))
        .accessibilityIdentifier(port.identifier("labels"))
    }

    /// The Recent menu: the recent molecules newest first (each sends `molecule.select [index]`), or "No recent
    /// molecules" (feature 113).
    private var recentMenu: some View {
        let ids = mirror.recentIDs
        let value = Self.recentValue(mirror.recentTitles)
        return Menu {
            if ids.isEmpty {
                Text(verbatim: Self.noRecentWords)
            } else {
                ForEach(ids.indices, id: \.self) { position in
                    Button {
                        _ = presenter.chooseRecent(ids[position], through: port)
                    } label: {
                        Text(verbatim: mirror.recentTitles.indices.contains(position) ? mirror.recentTitles[position]
                                 : ids[position])
                    }
                }
            }
        } label: {
            Text(verbatim: "Recent")
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: "Recent"))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityHint(Text(verbatim: ids.isEmpty ? "No molecule was opened yet"
                                    : "Opens a recently viewed molecule, newest first"))
        .accessibilityIdentifier(port.identifier("recent"))
    }

    /// The Import button: shows the system file importer for one XYZ or plain-text file (feature 114).
    private var importButton: some View {
        button(Self.importLabel, name: "import", value: mirror.importMessage, hint: Self.importHint, enabled: true) {
            mirror.importing = true
        }
    }

    /// The Library section: one button per library molecule with its name, formula, counts and source (feature 113;
    /// each sends `molecule.select [index]`, as the Molecule menu does).
    @ViewBuilder private var librarySection: some View {
        Text(verbatim: "Library").font(.headline).accessibilityAddTraits(.isHeader)
        ForEach(Self.moleculeTitles.indices, id: \.self) { index in
            let words = Self.libraryWords(index: index)
            let id = MoleculeCore.library[index].id
            Button {
                send("molecule.select", [Double(index)])
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(words.indices, id: \.self) { line in
                        Text(verbatim: words[line])
                            .font(line == 0 ? .body : .footnote)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(verbatim: MoleculeCore.title(index: index)))
            .accessibilityValue(Text(verbatim: words.joined(separator: "; ")))
            .accessibilityHint(Text(verbatim: index == mirror.selection ? "This molecule is open"
                                        : "Opens this molecule"))
            .accessibilityIdentifier(port.identifier("library-\(id)"))
        }
    }

    /// Turn left and right, Tilt up and down, Zoom in and out, and Reset view.
    @ViewBuilder private var cameraButtons: some View {
        let view = mirror.cameraWords, zoom = mirror.zoomWords
        let atTop = mirror.tiltSteps >= CameraSettings.tiltRange.upperBound
        let atBottom = mirror.tiltSteps <= CameraSettings.tiltRange.lowerBound
        let closest = mirror.zoomSteps >= CameraSettings.zoomRange.upperBound
        let farthest = mirror.zoomSteps <= CameraSettings.zoomRange.lowerBound
        HStack(spacing: 8) {
            button("Turn left", name: "turn-left", value: view, hint: "Turns the molecule view 15 degrees to the left",
                   enabled: true) { send("camera.orbit", [-1]) }
            button("Turn right", name: "turn-right", value: view,
                   hint: "Turns the molecule view 15 degrees to the right", enabled: true) { send("camera.orbit", [1]) }
        }
        HStack(spacing: 8) {
            button("Tilt up", name: "tilt-up", value: view,
                   hint: atTop ? "The camera is at its highest tilt, 80 degrees" : "Raises the camera 10 degrees",
                   enabled: !atTop) { send("camera.tilt", [1]) }
            button("Tilt down", name: "tilt-down", value: view,
                   hint: atBottom ? "The camera is at its lowest tilt, minus 80 degrees"
                       : "Lowers the camera 10 degrees",
                   enabled: !atBottom) { send("camera.tilt", [-1]) }
        }
        HStack(spacing: 8) {
            button("Zoom in", name: "zoom-in", value: zoom,
                   hint: closest ? "The camera is at its closest" : "Moves the camera closer",
                   enabled: !closest) { send("camera.zoom", [1]) }
            button("Zoom out", name: "zoom-out", value: zoom,
                   hint: farthest ? "The camera is at its farthest" : "Moves the camera farther away",
                   enabled: !farthest) { send("camera.zoom", [-1]) }
        }
        button("Reset view", name: "reset-view", value: view + ", " + zoom,
               hint: "Returns to the framed default view; the molecule and the display stay",
               enabled: true) { send("view.reset") }
    }

    /// Pan left, right, up and down (feature 112): one step of the view each, disabled at ±10 steps.
    @ViewBuilder private var panButtons: some View {
        let words = mirror.panWords
        let limit = CameraSettings.panRange
        let atLeft = mirror.panX <= limit.lowerBound, atRight = mirror.panX >= limit.upperBound
        let atBottom = mirror.panY <= limit.lowerBound, atTop = mirror.panY >= limit.upperBound
        HStack(spacing: 8) {
            button("Pan left", name: "pan-left", value: words,
                   hint: atLeft ? "The view is panned as far left as it goes" : "Moves the view left; the molecule "
                       + "moves right", enabled: !atLeft) { send("camera.pan", [-1, 0]) }
            button("Pan right", name: "pan-right", value: words,
                   hint: atRight ? "The view is panned as far right as it goes" : "Moves the view right; the molecule "
                       + "moves left", enabled: !atRight) { send("camera.pan", [1, 0]) }
        }
        HStack(spacing: 8) {
            button("Pan up", name: "pan-up", value: words,
                   hint: atTop ? "The view is panned as far up as it goes" : "Moves the view up; the molecule moves "
                       + "down", enabled: !atTop) { send("camera.pan", [0, 1]) }
            button("Pan down", name: "pan-down", value: words,
                   hint: atBottom ? "The view is panned as far down as it goes" : "Moves the view down; the molecule "
                       + "moves up", enabled: !atBottom) { send("camera.pan", [0, -1]) }
        }
    }

    /// Previous atom, Next atom and Clear selection (feature 112).
    @ViewBuilder private var atomButtons: some View {
        let words = mirror.atomWords
        let count = mirror.atomCount
        let selected = mirror.selectedAtom
        let atFirst = count == 0 || selected == 0
        let atLast = count == 0 || selected == count - 1
        HStack(spacing: 8) {
            button("Previous atom", name: "previous-atom", value: words,
                   hint: atFirst ? "This is the first atom" : "Selects the previous atom, or the last one when none "
                       + "is selected", enabled: !atFirst) { send("atom.previous") }
            button("Next atom", name: "next-atom", value: words,
                   hint: atLast ? "This is the last atom" : "Selects the next atom, or the first one when none is "
                       + "selected", enabled: !atLast) { send("atom.next") }
        }
        button("Clear selection", name: "clear-atom", value: words,
               hint: selected == nil ? "No atom is selected" : "Clears the selected atom",
               enabled: selected != nil) { send("atom.clear") }
    }

    /// The selected atom's panel and one line per bond (feature 112).
    @ViewBuilder private var atomPanel: some View {
        let panel = mirror.atomPanel.isEmpty ? MoleculePresenter.noAtomWords
            : mirror.atomPanel.joined(separator: "\n")
        line(panel, label: "Selected atom", name: "atom-panel", font: .footnote)
        ForEach(mirror.bondLines.indices, id: \.self) { index in
            line(mirror.bondLines[index], label: "Bond \(index + 1)", name: "atom-bond-\(index + 1)",
                 font: .footnote)
        }
    }

    /// Sends `control` with `values` through the presenter, which shows the answer when it is refused.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, through: port)
    }

    /// A wrapping text line `text` with the accessible label `label`, the value `text` and the identifier `name`.
    private func line(_ text: String, label: String, name: String, font: Font) -> some View {
        Text(verbatim: text)
            .font(font)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityValue(Text(verbatim: text))
            .accessibilityIdentifier(port.identifier(name))
    }

    /// A bordered button `title` with the identifier `name`, the accessible value `value` and the hint `hint`.
    private func button(_ title: String, name: String, value: String, hint: String, enabled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }
}
