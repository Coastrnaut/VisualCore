// DiagnosticsOverlay.swift — live lifecycle / context-loss diagnostics (feature 007 T-F604; FR-F607, US4).
import SwiftUI

struct DiagnosticsOverlay: View {
    let snapshot: DiagnosticsSnapshot
    let contextLoss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.label)
                .font(.caption2.monospacedDigit())
                .accessibilityIdentifier("showcase.diagnostics")
                .accessibilityLabel(snapshot.label)
            Button("Simulate context loss", action: contextLoss)
                .font(.footnote)
                .buttonStyle(.bordered)
                .accessibilityHint("Destroys and recreates the graphics context; the scene rebuilds its resources.")
                .accessibilityIdentifier("showcase.contextLoss")
        }
    }
}
