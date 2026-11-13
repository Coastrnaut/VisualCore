// LibraryView.swift — saved compositions: favorites first, then most recent; open, favorite, duplicate, rename, delete
// (feature 014 T-A01-304; FR-A01-302, FR-A01-304, FR-A01-305, FR-A01-310).
import GenerativeArtStudioCore
import SwiftUI
import VisualCoreParameters

struct LibraryView: View {
    @Bindable var model: LibraryModel
    let open: (LibraryEntry) -> Void
    @State private var renaming: LibraryEntry?
    @State private var newName = ""
    @State private var deleting: LibraryEntry?

    var body: some View {
        List {
            if model.problemCount > 0 {
                Label("\(model.problemCount) composition\(model.problemCount == 1 ? "" : "s") couldn’t be read", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .accessibilityIdentifier("gas.library.problems")
            }
            if model.entries.isEmpty {
                Text("No saved compositions yet. Open a scene and tap Save.")
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("gas.library.empty")
            }
            ForEach(model.entries) { entry in row(entry) }
        }
        .accessibilityIdentifier("gas.library")
        .navigationTitle("Library")
        .onAppear { model.reload() }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName).accessibilityIdentifier("gas.library.renameField")
            Button("Rename") { if let e = renaming { model.rename(e.id, to: newName) }; renaming = nil }
                .accessibilityIdentifier("gas.library.renameConfirm")
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .alert("Delete “\(deleting?.name ?? "")”?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) { if let e = deleting { model.delete(e.id) }; deleting = nil }
                .accessibilityIdentifier("gas.library.confirmDelete")
            Button("Cancel", role: .cancel) { deleting = nil }
                .accessibilityIdentifier("gas.library.cancelDelete")
        } message: { Text("This can’t be undone.") }
    }

    private func row(_ entry: LibraryEntry) -> some View {
        let family = entry.document.family
        return HStack(spacing: 12) {
            Button { open(entry) } label: {
                HStack(spacing: 12) {
                    Image(systemName: family?.symbol ?? "questionmark").frame(width: 28).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name).font(.headline)
                        Text("\(family?.title ?? entry.document.familyID) · \(entry.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.primary)
                    }
                    Spacer(minLength: 4)
                    PaletteSwatch(palette: FamilyCatalog.palette(entry.document.paletteID) ?? Palette.builtIns[0])
                        .frame(width: 32, height: 32).accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.name)
            .accessibilityHint("Opens this \(family?.title ?? "composition")")
            .accessibilityIdentifier("gas.library.row.\(entry.id.uuidString)")
            Button { model.toggleFavorite(entry.id) } label: {
                Image(systemName: entry.favorite ? "star.fill" : "star")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(entry.favorite ? "Remove from favorites" : "Add to favorites")
            .accessibilityIdentifier("gas.library.favorite.\(entry.id.uuidString)")
            Menu {
                Button("Duplicate") { model.duplicate(entry.id) }.accessibilityIdentifier("gas.library.duplicate")
                Button("Rename") { newName = entry.name; renaming = entry }.accessibilityIdentifier("gas.library.rename")
                Button("Delete", role: .destructive) { deleting = entry }.accessibilityIdentifier("gas.library.delete")
            } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("More actions for \(entry.name)")
                .accessibilityIdentifier("gas.library.more.\(entry.id.uuidString)")
        }
    }
}
