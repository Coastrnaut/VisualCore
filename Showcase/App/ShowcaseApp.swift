// ShowcaseApp.swift — VisualCore Showcase: a split view of scenes that collapses to a stack on iPhone
// (feature 007 T-F604; FR-F601, FR-F609). Uses only VisualCore packages (FR-F610 audit).
import SwiftUI

@main
struct ShowcaseApp: App {
    @State private var settings = ShowcaseSettings()
    var body: some Scene {
        WindowGroup {
            #if DEBUG || VISUALCORE_AUTOMATION
            if let mode = ShowcaseAutomation.mode {
                AutomationRootView(mode: mode, settings: settings)
            } else {
                ShowcaseRoot(settings: settings)
            }
            #else
            ShowcaseRoot(settings: settings)
            #endif
        }
    }
}

struct ShowcaseRoot: View {
    let settings: ShowcaseSettings
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Scenes") {
                    if SceneCatalog.all.isEmpty { Text("No scenes yet") }
                    ForEach(SceneCatalog.all) { scene in
                        NavigationLink(value: scene.id) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scene.title).font(.headline)
                                Text(scene.summary).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(scene.title)
                        .accessibilityHint(scene.summary)
                        .accessibilityIdentifier("showcase.scene.\(scene.id)")
                    }
                }
                Section("Accessibility") {
                    Toggle("Reduce Flashing", isOn: Binding(get: { settings.reduceFlashing }, set: { settings.reduceFlashing = $0 }))
                        .accessibilityHint("Limits rapid brightness changes in post-processing.")
                        .accessibilityIdentifier("showcase.reduceFlashing")
                }
            }
            .navigationTitle("VisualCore")
            .accessibilityIdentifier("showcase.title")
        } detail: {
            if let id = selection, let scene = SceneCatalog.all.first(where: { $0.id == id }) {
                SceneHostView(descriptor: scene, settings: settings).id(id)
            } else {
                Text("Choose a scene").foregroundStyle(.secondary)
            }
        }
    }
}
