// StudioLibraryView — feature 162 (A22-P04) T-A22-410 (FR-A22-405, FR-A22-406, FR-A22-408; clarification Q4;
// contracts/limits.md "Library"). The project library of Shader Studio, shown in a sheet from the `library` button of
// the controls. Every element is named `experience.a22.shader-studio.<name>` (`ExperienceActionPort.identifier`):
//
//   - `save`: shows the name field `project-name` (autocorrection and autocapitalisation off) and `save-confirm`,
//     which saves the editor's document with the inspector's values and textures; the sheet stays open and the new
//     project is listed first;
//   - rows `project-<k>` (k from 0, the library's order: newest first, then the unreadable files), labelled with the
//     name (an unreadable file: its name and "unreadable" with its code); a tap selects a row;
//   - `open` (the selected readable project: it replaces the editor's document, sets its values and textures and
//     queues a Run; the sheet closes), `rename` (the name field again, then `rename-confirm`) and `remove` (the
//     selected file, readable or not; only this explicit action removes a file);
//   - `library-message`: the outcome or the refusal's sentence (`ProjectLibraryFailure.message`).
//
// The hint of `open` and the note at the top say that opening replaces the editor's document. The action buttons
// stack vertically at accessibility text sizes (``StudioLibraryView/stacksButtons(_:)``). Nothing compiles here.
import Foundation
import ShaderStudioCore
import SwiftUI
import VisualCoreExperienceHost

/// What the library view acts with: the library and the presenter's save and open.
struct StudioLibraryActions {
    /// The saved projects.
    let library: ProjectLibrary
    /// Saves the document under a name (`StudioPresenter.saveProject(name:)`).
    let save: @MainActor (String) -> Result<ProjectLibraryEntry, ProjectLibraryFailure>
    /// Opens a saved file (`StudioPresenter.openProject(_:)`).
    let open: @MainActor (String) -> Result<OpenedProject, ProjectLibraryFailure>
}

/// The project library (see the file header).
struct StudioLibraryView: View {
    /// What the name field is for.
    enum NameMode: Equatable {
        /// Not shown.
        case hidden
        /// Saving a new project.
        case saving
        /// Renaming the selected project.
        case renaming
    }

    /// The port that names the elements.
    let port: ExperienceActionPort
    /// The library and the presenter's save and open.
    let actions: StudioLibraryActions
    /// Closes the sheet.
    let close: @MainActor () -> Void

    /// The selected file; nil when none is selected.
    @State private var selected: String?
    /// What the name field is for.
    @State private var mode = NameMode.hidden
    /// The name typed.
    @State private var name = ""
    /// The last outcome or refusal sentence.
    @State private var message = ""
    /// The type size of the environment.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The note at the top of the library.
    static let note = "Opening a project replaces the editor's document. Save first to keep your changes."

    /// Whether the action buttons stack vertically: at accessibility text sizes.
    static func stacksButtons(_ size: DynamicTypeSize) -> Bool { size.isAccessibilitySize }

    /// The spoken label of a row: the name, or the name with "unreadable" and its code.
    static func rowLabel(_ entry: ProjectLibraryEntry) -> String {
        guard let code = entry.refusal else { return entry.name }
        return entry.name + ", unreadable: " + code
    }

    /// The library.
    var body: some View {
        let library = actions.library
        let selection = selected.flatMap { library.entry(file: $0) }
        let layout = Self.stacksButtons(dynamicTypeSize) ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                          : AnyLayout(HStackLayout(spacing: 12))
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
                if library.isReadOnly {
                    Text(verbatim: ProjectLibraryFailure.readOnly.message).font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
                layout {
                    button("save", "Save", hint: "Saves the editor's shader with its uniform values and textures") {
                        mode = .saving
                        name = ""
                    }
                    button("open", "Open", hint: "Replaces the editor's document with the selected project and runs it",
                           enabled: selection?.isReadable == true) { openSelected() }
                    button("rename", "Rename", hint: "Gives the selected project a new name",
                           enabled: selection?.isReadable == true) {
                        mode = .renaming
                        name = selection?.name ?? ""
                    }
                    button("remove", "Remove", hint: "Removes the selected project from the library",
                           enabled: selection != nil) { removeSelected() }
                }
                if mode != .hidden { nameField }
                if !message.isEmpty {
                    Text(verbatim: message).font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(port.identifier("library-message"))
                }
                if library.entries.isEmpty {
                    Text(verbatim: "No saved projects").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(Array(library.entries.enumerated()), id: \.element.file) { k, entry in
                    row(k, entry, isSelected: entry.file == selected)
                }
            }
            .padding()
        }
    }

    /// The name field and its confirm button.
    private var nameField: some View {
        let confirm = mode == .saving ? "save-confirm" : "rename-confirm"
        let layout = Self.stacksButtons(dynamicTypeSize) ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                          : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            TextField(text: $name) { Text(verbatim: "Project name") }
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { confirmName() }
                .accessibilityLabel(Text(verbatim: "Project name"))
                .accessibilityHint(Text(verbatim: "1 to \(ProjectLibrary.maxNameLength) characters"))
                .accessibilityIdentifier(port.identifier("project-name"))
            button(confirm, mode == .saving ? "Save project" : "Rename project",
                   hint: mode == .saving ? "Saves under this name" : "Renames the selected project") { confirmName() }
        }
    }

    /// One row of the list.
    private func row(_ k: Int, _ entry: ProjectLibraryEntry, isSelected: Bool) -> some View {
        Button {
            selected = entry.file
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: entry.name)
                    if let code = entry.refusal {
                        Text(verbatim: "Unreadable: " + code).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: Self.rowLabel(entry)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text(verbatim: "Selects this project"))
        .accessibilityIdentifier(port.identifier("project-\(k)"))
    }

    /// A bordered button named `id`.
    private func button(_ id: String, _ title: String, hint: String, enabled: Bool = true,
                        action: @escaping @MainActor () -> Void) -> some View {
        Button { action() } label: { Text(verbatim: title).frame(minHeight: 44) }
            .buttonStyle(.bordered)
            .disabled(!enabled)
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityHint(Text(verbatim: hint))
            .accessibilityIdentifier(port.identifier(id))
    }

    /// Saves or renames with the typed name.
    private func confirmName() {
        switch mode {
        case .hidden:
            return
        case .saving:
            switch actions.save(name) {
            case .success(let entry):
                message = "Saved " + entry.name + "."
                selected = entry.file
                mode = .hidden
            case .failure(let failure):
                message = failure.message
            }
        case .renaming:
            guard let file = selected else { return }
            switch actions.library.rename(file, to: name) {
            case .success(let entry):
                message = "Renamed to " + entry.name + "."
                mode = .hidden
            case .failure(let failure):
                message = failure.message
            }
        }
    }

    /// Opens the selected project and closes the sheet.
    private func openSelected() {
        guard let file = selected else { return }
        switch actions.open(file) {
        case .success(let opened):
            message = "Opened " + opened.entry.name + "."
            close()
        case .failure(let failure):
            message = failure.message
        }
    }

    /// Removes the selected file.
    private func removeSelected() {
        guard let file = selected else { return }
        switch actions.library.remove(file) {
        case .success(let entry):
            message = "Removed " + entry.name + "."
            selected = nil
            mode = .hidden
        case .failure(let failure):
            message = failure.message
        }
    }
}
