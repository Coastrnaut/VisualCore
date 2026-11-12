// LauncherView — feature 190 T-U04-011 (FR-U04-020 to FR-U04-024, FR-U04-030; data-model sections 2 and 6). The
// catalog route: a search field, then what the launcher state says — sections with headings and tiles, or one
// of the three plain statements (nothing available, nothing found, catalog not loaded). Two rows at the top of
// the list lead to the settings and to the about page. The launcher creates no rendering context.
import SwiftUI
import VisualCoreExperience

/// The launcher: search, tiles by category and the ways to the settings and the about page.
struct LauncherView: View {
    let model: AppModel
    /// Counts the times typed text was cut to the model's limit. It is the identity of the search field: a cut
    /// replaces the field by a new one that shows the text the model holds, because a field that is being typed
    /// in does not take a shorter text back from its binding (FR-U04-022). The focus is given to the new field.
    @State private var cuts = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        List {
            Group {
                Section {
                    searchField
                }
                // Settings and about are rows of the list, not toolbar items: a navigation bar clips text at the
                // largest accessibility sizes, a list row wraps it. They come before the tiles so that they are always
                // in reach.
                Section {
                    Button { model.go(.settings) } label: {
                        navLabel(AppStrings.text(.navSettings), symbol: "gearshape")
                    }
                    .accessibilityIdentifier(ShellID.navSettings)
                    Button { model.go(.about) } label: {
                        navLabel(AppStrings.text(.navAbout), symbol: "info.circle")
                    }
                    .accessibilityIdentifier(ShellID.navAbout)
                }
                content
            }
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        // An opaque grouped background also where the catalog is a sidebar: the translucent sidebar material does
        // not give text the contrast the accessibility audit asks for.
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .headerProminence(.increased)
        .routeRoot(ShellID.routeCatalog)
        .navigationTitle(AppStrings.text(.catalogTitle))
    }

    private func navLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .accessibilityHidden(true)
            Text(title)
                .font(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The search text of the model. A longer text is cut to `ShellPreferences.maxSearchLength` characters.
    private var searchText: Binding<String> {
        Binding(get: { model.searchText }, set: { text in
            let kept = String(text.prefix(ShellPreferences.maxSearchLength))
            if model.searchText != kept { model.searchText = kept }
            if kept != text {
                cuts &+= 1
                Task { @MainActor in searchFocused = true }
            }
        })
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .accessibilityHidden(true)
            // A vertical axis lets the prompt and the text wrap at the largest text sizes instead of clipping.
            TextField(AppStrings.text(.catalogSearch), text: searchText, axis: .vertical)
                .lineLimit(1...4)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .frame(minHeight: 44)
                .accessibilityLabel(AppStrings.text(.catalogSearch))
                .accessibilityIdentifier(ShellID.search)
                .focused($searchFocused)
                .id(cuts)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(AppStrings.text(.catalogSearchClear))
                .accessibilityIdentifier(ShellID.searchClear)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.launcher {
        case .sections(let sections):
            ForEach(sections) { section in
                Section {
                    ForEach(section.tiles) { tile in
                        TileView(tile: tile) {
                            Task { await model.open(tile.id) }
                        }
                    }
                } header: {
                    // The label colour itself, not the header's default grey, which the accessibility audit rates as
                    // only nearly sufficient on the grouped background.
                    Text(section.title)
                        .foregroundStyle(Color(uiColor: .label))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(ShellID.sectionPrefix + section.id.rawValue)
                }
            }
        case .empty:
            statement(AppStrings.text(.catalogEmpty), identifier: ShellID.empty)
        case .noMatch:
            statement(AppStrings.text(.catalogNoMatch), identifier: ShellID.noMatch)
        case .error(let code):
            statement(AppStrings.text(.catalogError, code), identifier: ShellID.error)
        }
    }

    private func statement(_ text: String, identifier: String) -> some View {
        Section {
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(identifier)
        }
    }
}
