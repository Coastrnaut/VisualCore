// BookmarksView.swift — the bookmark sheet: the saved locations with coordinates, zoom and precision level, saving the
// current view under a name, and open / rename / favorite / delete (feature 028 T-A03-305; FR-A03-304; clarification 3;
// checklist CHK002, CHK004).
import FractalExplorerCore
import SwiftUI
import VisualCorePersistence

struct BookmarksView: View {
    @Bindable var model: ExplorerModel
    @Environment(\.dismiss) private var dismiss
    @State private var naming = false
    @State private var name = ""
    @State private var renaming: UUID?
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.bookmarks.entries.isEmpty {
                    Text("No bookmarks yet. Save the current view to come back to it later.")
                        .multilineTextAlignment(.center)
                        .padding()
                        .accessibilityIdentifier("fe.bookmarks.empty")
                } else {
                    List {
                        ForEach(Array(model.bookmarks.entries.enumerated()), id: \.element.id) { index, entry in
                            row(entry, index: index)
                        }
                    }
                    .accessibilityIdentifier("fe.bookmarks.list")
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("fe.bookmarks.done")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { name = ""; naming = true } label: { Label("Save current view", systemImage: "bookmark") }
                        .accessibilityIdentifier("fe.bookmark.save")
                }
            }
            .alert("Save bookmark", isPresented: $naming) {
                TextField("Name", text: $name).accessibilityIdentifier("fe.bookmark.name")
                Button("Save") { model.saveBookmark(name: name) }.accessibilityIdentifier("fe.bookmark.confirm")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The coordinates, zoom, settings and precision mode are kept.")
            }
            .alert("Rename bookmark", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName).accessibilityIdentifier("fe.bookmark.newName")
                Button("Rename") { if let id = renaming { model.renameBookmark(id, to: newName) } }
                    .accessibilityIdentifier("fe.bookmark.renameConfirm")
                Button("Cancel", role: .cancel) {}
            }
            .alert("Bookmarks", isPresented: Binding(get: { model.bookmarkError != nil },
                                                     set: { if !$0 { model.bookmarkError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.bookmarkError ?? "")
            }
        }
        .onAppear { model.reloadBookmarks() }
    }

    /// "Name, −0.5 + 0i · zoom 1×[, Near precision limit][, favorite]".
    static func label(_ entry: BookmarkLibrary.Entry) -> String {
        var parts = [entry.name, entry.payload.summary]
        if let level = entry.payload.precision.level.displayText { parts.append(level) }
        if entry.favorite { parts.append("favorite") }
        return parts.joined(separator: ", ")
    }

    private func row(_ entry: BookmarkLibrary.Entry, index: Int) -> some View {
        Button {
            model.open(entry.id)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if entry.favorite { Image(systemName: "star.fill").accessibilityHidden(true) }
                    Text(entry.name).font(.headline)
                }
                Text(entry.payload.summary).font(.subheadline)
                if let level = entry.payload.precision.level.displayText {
                    Text(level).font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())   // the whole row opens the bookmark, not only its text
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(entry))
        .accessibilityHint("Opens this location")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("fe.bookmark.row.\(index)")
        .accessibilityAction(named: "Rename") { newName = entry.name; renaming = entry.id }
        .accessibilityAction(named: entry.favorite ? "Remove favorite" : "Mark favorite") { model.setFavorite(entry.id, !entry.favorite) }
        .accessibilityAction(named: "Delete") { model.deleteBookmark(entry.id) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { model.deleteBookmark(entry.id) } label: { Label("Delete", systemImage: "trash") }
            Button { newName = entry.name; renaming = entry.id } label: { Label("Rename", systemImage: "pencil") }
        }
        .swipeActions(edge: .leading) {
            Button { model.setFavorite(entry.id, !entry.favorite) } label: {
                Label(entry.favorite ? "Remove favorite" : "Favorite", systemImage: entry.favorite ? "star.slash" : "star")
            }
        }
        .contextMenu {
            Button { newName = entry.name; renaming = entry.id } label: { Label("Rename", systemImage: "pencil") }
                .accessibilityIdentifier("fe.bookmark.rename")
            Button { model.setFavorite(entry.id, !entry.favorite) } label: {
                Label(entry.favorite ? "Remove favorite" : "Mark favorite", systemImage: "star")
            }
            .accessibilityIdentifier("fe.bookmark.favorite")
            Button(role: .destructive) { model.deleteBookmark(entry.id) } label: { Label("Delete", systemImage: "trash") }
                .accessibilityIdentifier("fe.bookmark.delete")
        }
    }
}
