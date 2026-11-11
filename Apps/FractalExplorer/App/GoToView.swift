// GoToView.swift — "Go to coordinates": real part, imaginary part and zoom, validated with an inline error (feature 028
// T-A03-309; FR-A03-305; US4; clarification 3).
import FractalExplorerCore
import SwiftUI

struct GoToView: View {
    let model: ExplorerModel
    @Environment(\.dismiss) private var dismiss
    @State private var real = ""
    @State private var imaginary = ""
    @State private var zoom = ""
    @State private var error: GoToError?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Real part, for example −0.743643887", text: $real)
                        .keyboardType(.numbersAndPunctuation)
                        .accessibilityLabel("Real part")
                        .accessibilityIdentifier("fe.goto.real")
                    TextField("Imaginary part, for example 0.131825904", text: $imaginary)
                        .keyboardType(.numbersAndPunctuation)
                        .accessibilityLabel("Imaginary part")
                        .accessibilityIdentifier("fe.goto.imaginary")
                    TextField("Zoom, for example 1000", text: $zoom)
                        .keyboardType(.numbersAndPunctuation)
                        .accessibilityLabel("Zoom")
                        .accessibilityIdentifier("fe.goto.zoom")
                } footer: {
                    Text("Coordinates between −4 and 4. Zoom 1 shows the whole set; the precision limit still applies.")
                }
                if let error {
                    Text("\(Self.fieldName(error.field)): \(error.message)")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("fe.goto.error")
                }
                Button("Go") {
                    if let problem = model.goTo(real: real, imaginary: imaginary, zoom: zoom) {
                        error = problem
                        AccessibilityNotification.Announcement("\(Self.fieldName(problem.field)): \(problem.message)").post()
                    } else {
                        dismiss()
                    }
                }
                .accessibilityIdentifier("fe.goto.go")
            }
            .navigationTitle("Go to coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("fe.goto.cancel")
                }
            }
        }
    }

    static func fieldName(_ f: GoToError.Field) -> String {
        switch f {
        case .real: "Real part"
        case .imaginary: "Imaginary part"
        case .zoom: "Zoom"
        }
    }
}
