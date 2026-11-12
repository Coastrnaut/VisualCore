// UnreadableStateView — feature 191 T-U05-017 (UA-F05, US2; FR-U05-031 to FR-U05-033; research R3). The notice
// the experience route shows when the stored state of an experience cannot be read. Nothing runs behind it. Reset
// keeps a copy of the stored state and starts the experience afresh; Back returns to the catalog and changes
// nothing, so the same notice comes again at the next open.
import SwiftUI
import VisualCoreExperience

/// The notice for a stored state that cannot be read, with Reset and Back.
struct UnreadableStateView: View {
    let model: AppModel
    let notice: UnreadableState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppStrings.text(.unreadableTitle))
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(AppStrings.text(notice.problem.newer ? .unreadableNewer : .unreadableDamaged))
                    .font(.body)
                    .accessibilityIdentifier(ShellID.unreadable)
                Text(AppStrings.text(.unreadableResetNote))
                    .font(.body)
                Text(AppStrings.text(.unreadableCode, notice.problem.code))
                    .font(.footnote)
                    .accessibilityIdentifier(ShellID.unreadableCode)
                Button {
                    Task { await model.resetUnreadable() }
                } label: {
                    Text(AppStrings.text(.unreadableReset))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(ShellID.unreadableReset)
                Button {
                    model.dismissUnreadable()
                } label: {
                    Text(AppStrings.text(.unreadableBack))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(ShellID.unreadableBack)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }
}
