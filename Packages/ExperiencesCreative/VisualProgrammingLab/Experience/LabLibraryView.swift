// LabLibraryView — feature 169 (A23-P04) T-A23-404 (FR-A23-401, FR-A23-403; clarifications Q1, Q2; contracts/library.md
// "Identifiers"; Edge Case "Opening over unsaved work"). The graph library of Visual Programming Lab, shown in a sheet
// from the `library` button of the controls. Every element is named `experience.a23.visual-programming-lab.<name>`
// (`ExperienceActionPort.identifier`), `<file>` being the file's name without `.json` (`graph-<n>`):
//
//   - `library-name` (the name field; autocorrection and autocapitalisation off) and `library-save` ("Save graph"),
//     which saves the open graph under the typed name;
//   - per saved graph a row `library-row-<file>` labelled with its name (an unreadable file: its name and
//     "unreadable" with its code), with `library-open-<file>` (asks first through `library-replace-confirm` when the
//     open graph differs from the last saved or opened one; the sheet closes once the graph is opened),
//     `library-rename-<file>` (an alert with the field `library-rename-name` and `library-rename-confirm`) and
//     `library-remove-<file>` (asks first, `library-remove-confirm`; an unreadable file has this button only, as only
//     this explicit action removes a file);
//   - `library-message`: the outcome or the refusal's sentence (``GraphLibraryFailure/message``), spoken by its label.
//
// The note at the top says that opening replaces the open graph. The buttons stack vertically at accessibility text
// sizes (``LabLibraryView/stacksButtons(_:)``). Nothing compiles here: the preview compiles the opened graph at the next
// frame.
import Foundation
import SwiftUI
import VisualCoreExperienceHost
import VisualProgrammingLabCore

/// What the library view and the controls act with: the presenter's library, its actions and the replace
/// confirmation (each a no-op once the presenter is gone).
@MainActor
struct LabLibraryActions {
    /// The saved graphs; nil when the experience was made without storage.
    let library: GraphLibrary?
    /// Saves the open graph under a name (``LabPresenter/save(name:)``).
    let save: @MainActor (String) -> Result<GraphLibraryEntry, GraphLibraryFailure>
    /// Opens a saved graph or an example, or keeps it pending for the confirmation (``LabPresenter/request(_:)``);
    /// true when it was opened now.
    let request: @MainActor (LabOpenTarget) -> Bool
    /// Renames a saved graph (``LabPresenter/rename(file:to:)``).
    let rename: @MainActor (String, String) -> Result<GraphLibraryEntry, GraphLibraryFailure>
    /// Removes a saved graph (``LabPresenter/remove(file:)``).
    let remove: @MainActor (String) -> Result<GraphLibraryEntry, GraphLibraryFailure>
    /// Opens the pending replacement (``LabPresenter/confirmReplace()``).
    let confirm: @MainActor () -> Void
    /// Forgets the pending replacement (``LabPresenter/declineReplace()``).
    let decline: @MainActor () -> Void

    /// The actions of `presenter`, held weakly.
    init(presenter: LabPresenter) {
        library = presenter.library
        save = { [weak presenter] name in presenter?.save(name: name) ?? .failure(.unavailable) }
        request = { [weak presenter] target in presenter?.request(target) ?? false }
        rename = { [weak presenter] file, name in presenter?.rename(file: file, to: name) ?? .failure(.unavailable) }
        remove = { [weak presenter] file in presenter?.remove(file: file) ?? .failure(.unavailable) }
        confirm = { [weak presenter] in presenter?.confirmReplace() }
        decline = { [weak presenter] in presenter?.declineReplace() }
    }
}

/// The replace confirmation (`library-replace-confirm`), shown while the mirror holds a pending replacement.
struct ReplaceConfirmation: ViewModifier {
    /// The port that names the elements.
    let port: ExperienceActionPort
    /// What the controls show (the pending replacement).
    let mirror: LabMirror
    /// The presenter's actions.
    let actions: LabLibraryActions
    /// Whether this view presents the dialog (the controls do not while the library sheet is up).
    var active = true
    /// Called after the person confirmed.
    var confirmed: @MainActor () -> Void = {}

    /// The question asked before an open graph is replaced.
    static let question = "Replace the open graph? Changes since it was last saved or opened are lost."

    /// The view with the dialog.
    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text(verbatim: Self.question),
            // The buttons decide: Replace confirms, the cancel button (also a tap outside the dialog) declines; the
            // binding's own dismissal changes nothing, so it can never undo a confirmation.
            isPresented: Binding(get: { active && mirror.pendingReplace != nil }, set: { _ in }),
            titleVisibility: .visible) {
            Button(role: .destructive) {
                actions.confirm()
                confirmed()
            } label: { Text(verbatim: "Replace") }
                .accessibilityIdentifier(port.identifier("library-replace-confirm"))
            Button(role: .cancel) { actions.decline() } label: { Text(verbatim: "Keep the open graph") }
                .accessibilityIdentifier(port.identifier("library-replace-cancel"))
        }
    }
}

/// The graph library (see the file header).
struct LabLibraryView: View {
    /// The port that names the elements.
    let port: ExperienceActionPort
    /// What the controls show (the library's message and the pending replacement).
    let mirror: LabMirror
    /// The library and the presenter's actions.
    let actions: LabLibraryActions
    /// Closes the sheet.
    let close: @MainActor () -> Void

    /// The name typed for a save.
    @State private var name = ""
    /// The entry being renamed; nil when none.
    @State private var renaming: GraphLibraryEntry?
    /// The new name typed for a rename.
    @State private var newName = ""
    /// The entry the person asked to remove; nil when none.
    @State private var removing: GraphLibraryEntry?
    /// The type size of the environment.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The note at the top of the library.
    static let note = "Opening a saved graph replaces the open graph. Save first to keep your changes."

    /// Whether the buttons stack vertically: at accessibility text sizes.
    static func stacksButtons(_ size: DynamicTypeSize) -> Bool { size.isAccessibilitySize }

    /// The spoken label of a row: "Saved graph <name>", or "<name>, unreadable: <code>".
    static func rowLabel(_ entry: GraphLibraryEntry) -> String {
        guard let code = entry.refusal else { return "Saved graph " + entry.name }
        return entry.name + ", unreadable: " + code
    }

    /// The identifier names of `entry`'s row and buttons: the row, then open and rename (readable only), then
    /// remove.
    static func identifierNames(_ entry: GraphLibraryEntry) -> [String] {
        let stem = entry.stem
        let row = "library-row-" + stem
        if entry.isReadable {
            return [row, "library-open-" + stem, "library-rename-" + stem, "library-remove-" + stem]
        }
        return [row, "library-remove-" + stem]
    }

    /// The library.
    var body: some View {
        let entries = actions.library?.entries ?? []
        let readOnly = actions.library?.isReadOnly ?? false
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(verbatim: "Library").font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { close() } label: { Text(verbatim: "Done").frame(minHeight: 44) }
                        .accessibilityIdentifier(port.identifier("library-done"))
                }
                Text(verbatim: Self.note).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if readOnly {
                    Text(verbatim: GraphLibraryFailure.readOnly.message).font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
                saveRow
                if let message = mirror.libraryMessage {
                    Text(verbatim: message).font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(verbatim: message))
                        .accessibilityIdentifier(port.identifier("library-message"))
                }
                if entries.isEmpty {
                    Text(verbatim: "No saved graphs").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in row(entry) }
            }
            .padding()
        }
        .accessibilityIdentifier(port.identifier("library"))
        .modifier(ReplaceConfirmation(port: port, mirror: mirror, actions: actions, confirmed: { close() }))
        .alert(Text(verbatim: "Rename \(renaming?.name ?? "")"),
               isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(text: $newName) { Text(verbatim: "New name") }
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier(port.identifier("library-rename-name"))
            Button { confirmRename() } label: { Text(verbatim: "Rename") }
                .accessibilityIdentifier(port.identifier("library-rename-confirm"))
            Button(role: .cancel) { renaming = nil } label: { Text(verbatim: "Cancel") }
        }
        .confirmationDialog(Text(verbatim: "Remove the saved graph \(removing?.name ?? "")?"),
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible) {
            Button(role: .destructive) { confirmRemove() } label: { Text(verbatim: "Remove") }
                .accessibilityIdentifier(port.identifier("library-remove-confirm"))
            Button(role: .cancel) { removing = nil } label: { Text(verbatim: "Cancel") }
        }
    }

    /// The name field and the save button.
    private var saveRow: some View {
        let layout = Self.stacksButtons(dynamicTypeSize) ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                          : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            TextField(text: $name) { Text(verbatim: "Graph name") }
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { save() }
                .accessibilityLabel(Text(verbatim: "Graph name"))
                .accessibilityHint(Text(verbatim: "1 to \(GraphLibrary.maxNameLength) characters"))
                .accessibilityIdentifier(port.identifier("library-name"))
            button("library-save", "Save graph", label: "Save graph",
                   hint: "Saves the open graph under this name") { save() }
        }
    }

    /// One saved graph: its label and its buttons.
    private func row(_ entry: GraphLibraryEntry) -> some View {
        let stem = entry.stem
        let layout = Self.stacksButtons(dynamicTypeSize) ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                          : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.name)
                if let code = entry.refusal {
                    Text(verbatim: "Unreadable: " + code).font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: Self.rowLabel(entry)))
            .accessibilityIdentifier(port.identifier("library-row-" + stem))
            layout {
                if entry.isReadable {
                    button("library-open-" + stem, "Open", label: "Open " + entry.name,
                           hint: "Replaces the open graph with this saved graph") {
                        if actions.request(.file(entry.file)) { close() }
                    }
                    button("library-rename-" + stem, "Rename", label: "Rename " + entry.name,
                           hint: "Gives this saved graph a new name", enabled: !(actions.library?.isReadOnly ?? false)) {
                        newName = entry.name
                        renaming = entry
                    }
                }
                button("library-remove-" + stem, "Remove", label: "Remove " + entry.name,
                       hint: entry.isReadable ? "Removes this saved graph from the library"
                                              : "Removes the unreadable file",
                       enabled: !(actions.library?.isReadOnly ?? false)) {
                    removing = entry
                }
            }
        }
    }

    /// A bordered button named `id`, shown as `title` and spoken as `label`.
    private func button(_ id: String, _ title: String, label: String, hint: String, enabled: Bool = true,
                        action: @escaping @MainActor () -> Void) -> some View {
        Button { action() } label: { Text(verbatim: title).frame(minHeight: 44) }
            .buttonStyle(.bordered)
            .disabled(!enabled)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityHint(Text(verbatim: hint))
            .accessibilityIdentifier(port.identifier(id))
    }

    /// Saves the open graph under the typed name; the field is cleared after a save.
    private func save() {
        if case .success = actions.save(name) { name = "" }
    }

    /// Renames the entry being renamed to the typed name.
    private func confirmRename() {
        guard let entry = renaming else { return }
        renaming = nil
        _ = actions.rename(entry.file, newName)
    }

    /// Removes the entry the person asked to remove.
    private func confirmRemove() {
        guard let entry = removing else { return }
        removing = nil
        _ = actions.remove(entry.file)
    }
}
