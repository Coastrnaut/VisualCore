// LauncherView — feature 190 T-U04-011 (FR-U04-020 to FR-U04-024, FR-U04-030; data-model sections 2 and 6). The
// catalog route: a search field, then what the launcher state says — sections with headings and tiles, or one
// of the three plain statements (nothing available, nothing found, catalog not loaded). Two rows at the top of
// the list lead to the settings and to the about page. The launcher creates no rendering context.
import SwiftUI
import VisualCoreExperience

/// The launcher: search, tiles by category and the ways to the settings and the about page.
struct LauncherView: View {
    let model: AppModel
    /// The text of the search field. It is cut to the model's limit as it is typed, so that the field never shows
    /// more than the model holds (FR-U04-022).
    @State private var typed = ""

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

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .accessibilityHidden(true)
            // A vertical axis lets the prompt and the text wrap at the largest text sizes instead of clipping.
            TextField(AppStrings.text(.catalogSearch), text: $typed, axis: .vertical)
                .lineLimit(1...4)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .frame(minHeight: 44)
                .accessibilityLabel(AppStrings.text(.catalogSearch))
                .accessibilityIdentifier(ShellID.search)
                .onAppear { typed = model.searchText }
                .onChange(of: typed) { _, text in
                    let kept = String(text.prefix(ShellPreferences.maxSearchLength))
                    if kept != text { typed = kept }
                    if model.searchText != kept { model.searchText = kept }
                }
                .onChange(of: model.searchText) { _, text in
                    if typed != text { typed = text }
                }
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
