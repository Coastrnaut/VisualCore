// GalleryView.swift — the gallery of four scene families (feature 012 T-A01-110; FR-A01-101, FR-A01-112).
import GenerativeArtStudioCore
import SwiftUI
import VisualCoreParameters

/// Navigation targets: a family's default preset, or a saved composition.
enum Route: Hashable {
    case family(SceneFamilyID)
    case entry(UUID)
    case library
}

struct GalleryView: View {
    @State private var path: [Route] = []
    @State private var library = LibraryModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(FamilyCatalog.all) { family in
                        NavigationLink(value: Route.family(family.id)) { FamilyRow(family: family) }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(family.title)
                            .accessibilityHint(family.summary)
                            .accessibilityIdentifier("gas.family.\(family.id.rawValue)")
                    }
                } header: {
                    Text("Generative Art Studio")
                        .font(.title2.bold())
                        .textCase(nil)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Generative Art Studio")
                        .accessibilityIdentifier("gas.home.title")
                }
            }
            .accessibilityIdentifier("gas.gallery")
            .navigationTitle("Gallery")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .family(let id):
                    SceneScreen(family: FamilyCatalog.family(id), library: library,
                                openingData: id == LaunchComposition.family ? LaunchComposition.data : nil)
                case .entry(let id):
                    if let entry = library.library.entry(id), let family = entry.document.family {
                        SceneScreen(family: family, library: library, entry: entry)
                    } else {
                        ContentUnavailableView("Composition not found", systemImage: "questionmark.folder")
                    }
                case .library:
                    LibraryView(model: library) { entry in path.append(.entry(entry.id)) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                        .accessibilityIdentifier("gas.settings.open")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.library) } label: { Label("Library", systemImage: "books.vertical") }
                        .accessibilityIdentifier("gas.library.open")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear {
                // DEBUG launch data opens its scene directly (recovery path, feature 013).
                if LaunchComposition.data != nil, path.isEmpty { path = [.family(LaunchComposition.family)] }
            }
            .alert("Library", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
                Button("OK") { library.errorMessage = nil }
            } message: { Text(library.errorMessage ?? "") }
        }
    }
}

struct FamilyRow: View {
    let family: SceneFamily
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: family.symbol)
                .font(.title2)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(family.title).font(.headline)
                Text(family.summary).font(.subheadline).foregroundStyle(.secondary)
                Text("\(family.presets.count) presets").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            PaletteSwatch(palette: FamilyCatalog.palette(family.defaultPaletteID) ?? Palette.builtIns[0])
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}

/// A rounded gradient of a palette's sRGB stops (decorative; the family title carries the meaning).
struct PaletteSwatch: View {
    let palette: Palette
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(colors: palette.stops.map { Color(.sRGB, red: $0.x, green: $0.y, blue: $0.z) },
                                 startPoint: .bottomLeading, endPoint: .topTrailing))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.4)))
    }
}
