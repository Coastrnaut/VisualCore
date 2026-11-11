// ProjectMReferenceApp.swift — harness entry point (feature 008 T-F702; FR-F701). UI arrives in T-F710.
import ProjectMBridge
import SwiftUI

@main
struct ProjectMReferenceApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ProjectM Reference — engine max PCM frames per call: \(ProjectMEngine.maxSamplesPerFrame)")
                .padding()
                .accessibilityIdentifier("reference.title")
        }
    }
}
