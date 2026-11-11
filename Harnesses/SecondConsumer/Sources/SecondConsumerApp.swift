// SecondConsumerApp.swift — Lumen Garden shell (feature 009 T-F801). Game UI arrives in T-F806.
import GardenKit
import SwiftUI

@main
struct SecondConsumerApp: App {
    var body: some Scene {
        WindowGroup { Text("Lumen Garden \(GardenKitInfo.version)").accessibilityIdentifier("garden.title") }
    }
}
