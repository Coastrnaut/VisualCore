// ToursView.swift — the list of curated tours (feature 029 T-A03-409; FR-A03-406; US3).
import FractalExplorerCore
import SwiftUI

struct ToursView: View {
    let model: ExplorerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(FractalTours.all) { tour in
                Button {
                    model.startTour(tour.id)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tour.name).font(.headline)
                        Text(tour.summary).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Starts the tour")
                .accessibilityIdentifier("fe.tour.\(tour.id)")
            }
            .navigationTitle("Tours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("fe.tours.cancel")
                }
            }
        }
    }
}
