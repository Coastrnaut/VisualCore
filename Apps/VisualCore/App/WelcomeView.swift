// WelcomeView — feature 190 T-U04-011 (FR-U04-040 to FR-U04-042; data-model section 3). The welcome of the first
// start: the app's name, one sentence and one primary action. It asks for nothing: no account, no purchase and
// no permission.
import SwiftUI

/// The welcome with its one action, which opens the first free experience (or the catalog when there is none).
struct WelcomeView: View {
    let model: AppModel
    @State private var starting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(AppStrings.text(.welcomeTitle))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(ShellID.welcome)
                Text(AppStrings.text(.welcomeBody))
                    .font(.body)
                    .multilineTextAlignment(.center)
                Button {
                    guard !starting else { return }
                    starting = true
                    Task { await model.finishWelcome(openFirst: true) }
                } label: {
                    Text(AppStrings.text(.welcomeStart))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(ShellID.welcomeStart)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }
}
